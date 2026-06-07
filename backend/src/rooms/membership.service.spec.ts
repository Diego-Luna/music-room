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
    name: 'Test Room',
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
        findMany: vi.fn(),
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
      prisma.roomInvitation.findUnique.mockResolvedValue(null);
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

    it('rejects when the invitee already has a PENDING invitation', async () => {
      prisma.room.findUnique.mockResolvedValue(privateRoom);
      prisma.user.findUnique.mockResolvedValue({ id: 'invited' });
      prisma.roomMember.findUnique.mockResolvedValue(null);
      prisma.roomInvitation.findUnique.mockResolvedValue({ id: 'inv-existing' });

      await expect(
        service.invite('room-1', 'owner-1', { userId: 'invited' }),
      ).rejects.toThrow(ConflictException);
      expect(prisma.roomInvitation.create).not.toHaveBeenCalled();
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

    it('lets the owner kick an ADMIN', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      // Owner caller → requireAdmin returns early; only the target lookup fires.
      prisma.roomMember.findUnique.mockResolvedValue({
        userId: 'admin-2',
        role: 'ADMIN',
      });
      await service.removeMember('room-1', 'owner-1', 'admin-2');
      expect(prisma.roomMember.delete).toHaveBeenCalled();
    });

    it('refuses an ADMIN trying to kick another ADMIN (only owner can)', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      prisma.roomMember.findUnique
        .mockResolvedValueOnce({ userId: 'admin-1', role: 'ADMIN' }) // requireAdmin
        .mockResolvedValueOnce({ userId: 'admin-2', role: 'ADMIN' }); // target
      await expect(
        service.removeMember('room-1', 'admin-1', 'admin-2'),
      ).rejects.toThrow(ForbiddenException);
      expect(prisma.roomMember.delete).not.toHaveBeenCalled();
    });

    it('still lets an ADMIN kick a regular MEMBER', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      prisma.roomMember.findUnique
        .mockResolvedValueOnce({ userId: 'admin-1', role: 'ADMIN' }) // requireAdmin
        .mockResolvedValueOnce({ userId: 'kicked', role: 'MEMBER' }); // target
      await service.removeMember('room-1', 'admin-1', 'kicked');
      expect(prisma.roomMember.delete).toHaveBeenCalled();
    });

    it('rejects an ADMIN trying to kick themselves (use leave instead)', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      await expect(
        service.removeMember('room-1', 'admin-1', 'admin-1'),
      ).rejects.toThrow(BadRequestException);
      expect(prisma.roomMember.delete).not.toHaveBeenCalled();
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

    it('emits invitation:new to the invitee with roomName', async () => {
      prisma.room.findUnique.mockResolvedValue(privateRoom);
      prisma.user.findUnique.mockResolvedValue({ id: 'invited' });
      prisma.roomMember.findUnique.mockResolvedValue(null);
      prisma.roomInvitation.findFirst.mockResolvedValue(null);
      prisma.roomInvitation.create.mockResolvedValue({ id: 'inv-99' });

      await service.invite('room-1', 'owner-1', { userId: 'invited' });
      expect(realtime.emitToUser).toHaveBeenCalledWith(
        'invited',
        'invitation:new',
        expect.objectContaining({
          invitationId: 'inv-99',
          roomId: 'room-1',
          roomName: 'Test Room',
          inviterId: 'owner-1',
        }),
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
        { roomId: 'room-1', roomName: 'Test Room' },
      );
    });

    it('member:removed room broadcast does NOT leak the acting admin identity', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      prisma.roomMember.findUnique.mockResolvedValue({
        userId: 'kicked',
        role: 'MEMBER',
      });

      await service.removeMember('room-1', 'owner-1', 'kicked');

      const call = realtime.emitToRoom.mock.calls.find(
        (c: unknown[]) => c[1] === 'member:removed',
      );
      expect(call).toBeDefined();
      const payload = call![2] as Record<string, unknown>;
      expect(payload).not.toHaveProperty('by');
      expect(payload).not.toHaveProperty('byUserId');
      expect(payload).not.toHaveProperty('actingUserId');
    });

    it('room:kicked payload does NOT leak the acting admin identity', async () => {
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      prisma.roomMember.findUnique.mockResolvedValue({
        userId: 'kicked',
        role: 'MEMBER',
      });

      await service.removeMember('room-1', 'owner-1', 'kicked');

      const call = realtime.emitToUser.mock.calls.find(
        (c: unknown[]) => c[1] === 'room:kicked',
      );
      expect(call).toBeDefined();
      const payload = call![2] as Record<string, unknown>;
      expect(payload).not.toHaveProperty('byUserId');
      expect(payload).not.toHaveProperty('actingUserId');
      expect(payload).not.toHaveProperty('kickedById');
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

  describe('invitations inbox', () => {
    const future = new Date(Date.now() + 60_000);
    const past = new Date(Date.now() - 60_000);

    it('lists only the caller pending non-expired invitations', async () => {
      prisma.roomInvitation.findMany.mockResolvedValue([
        { id: 'inv-1', roomId: 'room-1' },
      ]);

      const result = await service.listMyInvitations('invitee-1');

      expect(prisma.roomInvitation.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            inviteeId: 'invitee-1',
            status: 'PENDING',
            expiresAt: { gt: expect.any(Date) },
          }),
        }),
      );
      expect(result).toHaveLength(1);
    });

    it('accept: 404 when invitation is missing or not the caller', async () => {
      prisma.roomInvitation.findUnique.mockResolvedValue(null);
      await expect(
        service.acceptInvitation('invitee-1', 'inv-x'),
      ).rejects.toThrow(NotFoundException);

      prisma.roomInvitation.findUnique.mockResolvedValue({
        id: 'inv-1',
        inviteeId: 'someone-else',
        status: 'PENDING',
        expiresAt: future,
      });
      await expect(
        service.acceptInvitation('invitee-1', 'inv-1'),
      ).rejects.toThrow(NotFoundException);
    });

    it('accept: conflict when invitation is not PENDING', async () => {
      prisma.roomInvitation.findUnique.mockResolvedValue({
        id: 'inv-1',
        inviteeId: 'invitee-1',
        status: 'ACCEPTED',
        expiresAt: future,
      });
      await expect(
        service.acceptInvitation('invitee-1', 'inv-1'),
      ).rejects.toThrow(ConflictException);
    });

    it('accept: rejects an expired invitation', async () => {
      prisma.roomInvitation.findUnique.mockResolvedValue({
        id: 'inv-1',
        roomId: 'room-1',
        inviteeId: 'invitee-1',
        status: 'PENDING',
        expiresAt: past,
      });
      await expect(
        service.acceptInvitation('invitee-1', 'inv-1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('accept: delegates to join() and returns the roomId', async () => {
      prisma.roomInvitation.findUnique.mockResolvedValue({
        id: 'inv-1',
        roomId: 'room-1',
        inviteeId: 'invitee-1',
        inviterId: 'owner-1',
        status: 'PENDING',
        expiresAt: future,
      });
      const joinSpy = vi
        .spyOn(service, 'join')
        .mockResolvedValue(undefined as never);

      const res = await service.acceptInvitation('invitee-1', 'inv-1');

      expect(joinSpy).toHaveBeenCalledWith('room-1', 'invitee-1');
      expect(res).toEqual({ message: 'Joined', roomId: 'room-1' });
    });

    it('lists sent invitations filtered to caller as inviter, PENDING, not expired', async () => {
      prisma.roomInvitation.findMany.mockResolvedValue([
        { id: 'inv-out', roomId: 'room-1', inviteeId: 'invitee-x' },
      ]);

      const result = await service.listSentInvitations('owner-1');

      expect(prisma.roomInvitation.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            inviterId: 'owner-1',
            status: 'PENDING',
            expiresAt: { gt: expect.any(Date) },
          }),
        }),
      );
      expect(result).toHaveLength(1);
    });

    it('revoke: 404 when the invitation does not exist', async () => {
      prisma.roomInvitation.findUnique.mockResolvedValue(null);
      await expect(
        service.revokeInvitation('owner-1', 'inv-x'),
      ).rejects.toThrow(NotFoundException);
    });

    it('revoke: conflict when the invitation is not PENDING', async () => {
      prisma.roomInvitation.findUnique.mockResolvedValue({
        id: 'inv-1',
        inviterId: 'owner-1',
        status: 'ACCEPTED',
        expiresAt: future,
      });
      await expect(
        service.revokeInvitation('owner-1', 'inv-1'),
      ).rejects.toThrow(ConflictException);
    });

    it('revoke: forbidden when caller is neither inviter nor room admin', async () => {
      prisma.roomInvitation.findUnique.mockResolvedValue({
        id: 'inv-1',
        roomId: 'room-1',
        inviterId: 'owner-1',
        inviteeId: 'invitee-1',
        status: 'PENDING',
        expiresAt: future,
      });
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      prisma.roomMember.findUnique.mockResolvedValue({
        userId: 'random',
        role: 'MEMBER',
      });

      await expect(
        service.revokeInvitation('random', 'inv-1'),
      ).rejects.toThrow(ForbiddenException);
    });

    it('revoke: the original inviter can cancel (status REVOKED, notifies invitee)', async () => {
      prisma.roomInvitation.findUnique.mockResolvedValue({
        id: 'inv-1',
        roomId: 'room-1',
        inviterId: 'owner-1',
        inviteeId: 'invitee-1',
        status: 'PENDING',
        expiresAt: future,
        room: { name: 'Test Room' },
      });
      prisma.roomInvitation.update.mockResolvedValue({
        id: 'inv-1',
        status: 'REVOKED',
      });

      await service.revokeInvitation('owner-1', 'inv-1');

      expect(prisma.roomInvitation.update).toHaveBeenCalledWith({
        where: { id: 'inv-1' },
        data: { status: 'REVOKED', respondedAt: expect.any(Date) },
      });
      expect(realtime.emitToUser).toHaveBeenCalledWith(
        'invitee-1',
        'invitation:revoked',
        expect.objectContaining({
          invitationId: 'inv-1',
          roomId: 'room-1',
          roomName: 'Test Room',
        }),
      );
      // privacy: the invitee must NOT receive the revoking admin's identity.
      const call = realtime.emitToUser.mock.calls.find(
        (c: unknown[]) => c[1] === 'invitation:revoked',
      );
      const payload = call![2] as Record<string, unknown>;
      expect(payload).not.toHaveProperty('revokedById');
    });

    it('revoke: a different admin (not the inviter) can also cancel', async () => {
      prisma.roomInvitation.findUnique.mockResolvedValue({
        id: 'inv-1',
        roomId: 'room-1',
        inviterId: 'owner-1',
        inviteeId: 'invitee-1',
        status: 'PENDING',
        expiresAt: future,
        room: { name: 'Test Room' },
      });
      prisma.room.findUnique.mockResolvedValue(publicRoom);
      prisma.roomMember.findUnique.mockResolvedValue({
        userId: 'admin-2',
        role: 'ADMIN',
      });
      prisma.roomInvitation.update.mockResolvedValue({
        id: 'inv-1',
        status: 'REVOKED',
      });

      await service.revokeInvitation('admin-2', 'inv-1');

      expect(prisma.roomInvitation.update).toHaveBeenCalled();
    });

    it('decline: marks DECLINED and notifies the inviter', async () => {
      prisma.roomInvitation.findUnique.mockResolvedValue({
        id: 'inv-1',
        roomId: 'room-1',
        inviteeId: 'invitee-1',
        inviterId: 'owner-1',
        status: 'PENDING',
        expiresAt: future,
      });
      prisma.roomInvitation.update.mockResolvedValue({
        id: 'inv-1',
        status: 'DECLINED',
      });

      await service.declineInvitation('invitee-1', 'inv-1');

      expect(prisma.roomInvitation.update).toHaveBeenCalledWith({
        where: { id: 'inv-1' },
        data: { status: 'DECLINED', respondedAt: expect.any(Date) },
      });
      expect(realtime.emitToUser).toHaveBeenCalledWith(
        'owner-1',
        'invitation:declined',
        expect.objectContaining({ invitationId: 'inv-1', roomId: 'room-1' }),
      );
    });
  });
});
