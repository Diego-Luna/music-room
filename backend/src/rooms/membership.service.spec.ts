import { Test, TestingModule } from '@nestjs/testing';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { RoomMembershipService } from './membership.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';
import { MemberRole } from './dto/invite-member.dto';

describe('RoomMembershipService', () => {
  let service: RoomMembershipService;
  let prisma: Record<string, Record<string, ReturnType<typeof vi.fn>>>;
  let realtime: {
    emitToRoom: ReturnType<typeof vi.fn>;
    emitToUser: ReturnType<typeof vi.fn>;
  };

  const publicRoom = {
    id: 'room-1',
    visibility: 'PUBLIC',
    ownerId: 'owner-1',
  };
  const privateRoom = { ...publicRoom, visibility: 'PRIVATE' };

  beforeEach(async () => {
    prisma = {
      room: { findUnique: vi.fn() },
      roomMember: {
        create: vi.fn(),
        findUnique: vi.fn(),
        findMany: vi.fn(),
        delete: vi.fn(),
        update: vi.fn(),
      },
      roomInvitation: {
        create: vi.fn(),
        findUnique: vi.fn(),
        findFirst: vi.fn(),
        update: vi.fn(),
      },
      user: { findUnique: vi.fn() },
    };

    realtime = { emitToRoom: vi.fn(), emitToUser: vi.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RoomMembershipService,
        { provide: PrismaService, useValue: prisma },
        { provide: RealtimeService, useValue: realtime },
      ],
    }).compile();

    service = module.get(RoomMembershipService);
  });

  describe('join', () => {
    it('lets a user join a PUBLIC room as MEMBER', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      prisma.roomMember.findUnique.mockResolvedValue(null);
      prisma.roomMember.create.mockResolvedValue({
        roomId: 'room-1',
        userId: 'newcomer',
        role: 'MEMBER',
      });

      await service.join('room-1', 'newcomer');

      expect(prisma.roomMember.create).toHaveBeenCalledWith({
        data: { roomId: 'room-1', userId: 'newcomer', role: 'MEMBER' },
      });
    });

    it('rejects joining a PRIVATE room without a pending invitation', async () => {
      prisma.room.findUnique.mockResolvedValue(privateRoom);
      prisma.roomMember.findUnique.mockResolvedValue(null);
      prisma.roomInvitation.findFirst.mockResolvedValue(null);

      await expect(service.join('room-1', 'stranger')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('lets a user join a PRIVATE room when they have a pending invitation, marking it ACCEPTED', async () => {
      prisma.room.findUnique.mockResolvedValue(privateRoom);
      prisma.roomMember.findUnique.mockResolvedValue(null);
      prisma.roomInvitation.findFirst.mockResolvedValue({
        id: 'inv-1',
        status: 'PENDING',
        expiresAt: new Date(Date.now() + 60_000),
      });

      await service.join('room-1', 'invited');

      expect(prisma.roomInvitation.update).toHaveBeenCalledWith({
        where: { id: 'inv-1' },
        data: {
          status: 'ACCEPTED',
          respondedAt: expect.any(Date),
        },
      });
      expect(prisma.roomMember.create).toHaveBeenCalled();
    });

    it('rejects joining when already a member', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      prisma.roomMember.findUnique.mockResolvedValue({
        userId: 'exists',
        role: 'MEMBER',
      });

      await expect(service.join('room-1', 'exists')).rejects.toThrow(
        ConflictException,
      );
    });

    it('throws 404 when the room does not exist', async () => {
      prisma.room.findUnique.mockResolvedValue(null);
      await expect(service.join('missing', 'u')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('leave', () => {
    it('removes a non-owner member', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      prisma.roomMember.findUnique.mockResolvedValue({
        userId: 'member-1',
        role: 'MEMBER',
      });

      await service.leave('room-1', 'member-1');

      expect(prisma.roomMember.delete).toHaveBeenCalledWith({
        where: { roomId_userId: { roomId: 'room-1', userId: 'member-1' } },
      });
    });

    it('rejects when the owner tries to leave (must transfer ownership or delete)', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      await expect(service.leave('room-1', 'owner-1')).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('invite', () => {
    it('lets the owner invite a user to a private room', async () => {
      prisma.room.findUnique.mockResolvedValue(privateRoom);
      prisma.user.findUnique.mockResolvedValue({ id: 'invited' });
      prisma.roomMember.findUnique.mockResolvedValue(null);
      prisma.roomInvitation.findFirst.mockResolvedValue(null);
      prisma.roomInvitation.create.mockResolvedValue({ id: 'inv-1' });

      const inv = await service.invite('room-1', 'owner-1', {
        userId: 'invited',
      });

      expect(inv.id).toBe('inv-1');
      expect(prisma.roomInvitation.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          roomId: 'room-1',
          inviterId: 'owner-1',
          inviteeId: 'invited',
          status: 'PENDING',
        }),
      });
    });

    it('rejects when the inviter is not owner/admin', async () => {
      prisma.room.findUnique.mockResolvedValue(privateRoom);
      prisma.roomMember.findUnique
        .mockResolvedValueOnce({ userId: 'member-1', role: 'MEMBER' })
        .mockResolvedValueOnce(null);

      await expect(
        service.invite('room-1', 'member-1', { userId: 'invited' }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects when the invitee is already a member', async () => {
      prisma.room.findUnique.mockResolvedValue(privateRoom);
      prisma.user.findUnique.mockResolvedValue({ id: 'existing' });
      prisma.roomMember.findUnique.mockResolvedValue({
        userId: 'existing',
        role: 'MEMBER',
      });

      await expect(
        service.invite('room-1', 'owner-1', { userId: 'existing' }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('updateRole', () => {
    it('lets the owner promote a member to ADMIN', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      prisma.roomMember.findUnique.mockResolvedValue({
        userId: 'member-1',
        role: 'MEMBER',
      });

      await service.updateRole('room-1', 'owner-1', 'member-1', {
        role: MemberRole.ADMIN,
      });

      expect(prisma.roomMember.update).toHaveBeenCalledWith({
        where: { roomId_userId: { roomId: 'room-1', userId: 'member-1' } },
        data: { role: 'ADMIN' },
      });
    });

    it('refuses to demote the owner', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      await expect(
        service.updateRole('room-1', 'owner-1', 'owner-1', {
          role: MemberRole.MEMBER,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects a non-owner trying to change roles', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      prisma.roomMember.findUnique.mockResolvedValueOnce({
        userId: 'admin-1',
        role: 'ADMIN',
      });
      await expect(
        service.updateRole('room-1', 'admin-1', 'member-1', {
          role: MemberRole.ADMIN,
        }),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('removeMember', () => {
    it('lets owner kick a member', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      prisma.roomMember.findUnique.mockResolvedValue({
        userId: 'kicked',
        role: 'MEMBER',
      });

      await service.removeMember('room-1', 'owner-1', 'kicked');

      expect(prisma.roomMember.delete).toHaveBeenCalledWith({
        where: { roomId_userId: { roomId: 'room-1', userId: 'kicked' } },
      });
    });

    it('refuses to kick the owner', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      await expect(
        service.removeMember('room-1', 'owner-1', 'owner-1'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('realtime broadcasts', () => {
    it('broadcasts member:joined on PUBLIC join', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      prisma.roomMember.findUnique.mockResolvedValue(null);
      prisma.roomMember.create.mockResolvedValue({ role: 'MEMBER' });

      await service.join('room-1', 'newbie');
      expect(realtime.emitToRoom).toHaveBeenCalledWith(
        'room-1',
        'member:joined',
        expect.objectContaining({ userId: 'newbie', role: 'MEMBER' }),
      );
    });

    it('broadcasts member:left on leave', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      prisma.roomMember.findUnique.mockResolvedValue({
        userId: 'member-1',
        role: 'MEMBER',
      });

      await service.leave('room-1', 'member-1');
      expect(realtime.emitToRoom).toHaveBeenCalledWith(
        'room-1',
        'member:left',
        expect.objectContaining({ userId: 'member-1' }),
      );
    });

    it('emits invitation:new to the invitee', async () => {
      prisma.room.findUnique.mockResolvedValue(privateRoom);
      prisma.user.findUnique.mockResolvedValue({ id: 'invited' });
      prisma.roomMember.findUnique.mockResolvedValue(null);
      prisma.roomInvitation.findFirst.mockResolvedValue(null);
      prisma.roomInvitation.create.mockResolvedValue({ id: 'inv-99' });

      await service.invite('room-1', 'owner-1', { userId: 'invited' });
      expect(realtime.emitToUser).toHaveBeenCalledWith(
        'invited',
        'invitation:new',
        expect.objectContaining({ invitationId: 'inv-99', roomId: 'room-1' }),
      );
    });

    it('emits room:kicked to the target on removeMember', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      prisma.roomMember.findUnique.mockResolvedValue({
        userId: 'kicked',
        role: 'MEMBER',
      });

      await service.removeMember('room-1', 'owner-1', 'kicked');
      expect(realtime.emitToUser).toHaveBeenCalledWith(
        'kicked',
        'room:kicked',
        { roomId: 'room-1' },
      );
    });
  });

  describe('listMembers', () => {
    it('returns members for a visible room', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      prisma.roomMember.findMany.mockResolvedValue([
        {
          userId: 'owner-1',
          role: 'OWNER',
          joinedAt: new Date(),
          user: { id: 'owner-1', displayName: 'Owner', avatarUrl: null },
        },
      ]);

      const members = await service.listMembers('room-1', 'random');
      expect(members).toHaveLength(1);
      expect(members[0].role).toBe('OWNER');
    });
  });
});
