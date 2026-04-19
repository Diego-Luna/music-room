import { Test, TestingModule } from '@nestjs/testing';
import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { DelegationService } from './delegation.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';

type Fn = ReturnType<typeof vi.fn>;

describe('DelegationService', () => {
  let service: DelegationService;
  let prisma: {
    room: { findUnique: Fn; update: Fn };
    roomMember: { findUnique: Fn };
    socialAccount: { findUnique: Fn };
  };
  let realtime: { emitToRoom: Fn; emitToUser: Fn };

  const baseRoom = {
    id: 'r1',
    kind: 'DELEGATE',
    ownerId: 'owner',
    visibility: 'PUBLIC',
    delegateUserId: null as string | null,
    delegateGrantedAt: null as Date | null,
  };

  beforeEach(async () => {
    prisma = {
      room: { findUnique: vi.fn(), update: vi.fn() },
      roomMember: { findUnique: vi.fn() },
      socialAccount: { findUnique: vi.fn() },
    };
    realtime = { emitToRoom: vi.fn(), emitToUser: vi.fn() };
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DelegationService,
        { provide: PrismaService, useValue: prisma },
        { provide: RealtimeService, useValue: realtime },
      ],
    }).compile();
    service = module.get(DelegationService);
  });

  describe('grant', () => {
    it('rejects when the room is not DELEGATE', async () => {
      prisma.room.findUnique.mockResolvedValue({ ...baseRoom, kind: 'VOTE' });
      await expect(service.grant('r1', 'owner', 'u2')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('rejects when caller is not the owner', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      await expect(service.grant('r1', 'someone', 'u2')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('rejects granting to the owner themselves', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      await expect(service.grant('r1', 'owner', 'owner')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('rejects when the delegate is not a member', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.roomMember.findUnique.mockResolvedValue(null);
      await expect(service.grant('r1', 'owner', 'u2')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('rejects when the delegate has no Spotify connection', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.roomMember.findUnique.mockResolvedValue({ role: 'MEMBER' });
      prisma.socialAccount.findUnique.mockResolvedValue(null);
      await expect(service.grant('r1', 'owner', 'u2')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('sets the delegate and broadcasts delegate:granted', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.roomMember.findUnique.mockResolvedValue({ role: 'MEMBER' });
      prisma.socialAccount.findUnique.mockResolvedValue({ id: 'sa1' });
      prisma.room.update.mockResolvedValue({
        ...baseRoom,
        delegateUserId: 'u2',
        delegateGrantedAt: new Date(),
      });

      const res = await service.grant('r1', 'owner', 'u2');
      expect(prisma.room.update).toHaveBeenCalledWith({
        where: { id: 'r1' },
        data: expect.objectContaining({ delegateUserId: 'u2' }),
      });
      expect(res.delegateUserId).toBe('u2');
      expect(realtime.emitToRoom).toHaveBeenCalledWith(
        'r1',
        'delegate:granted',
        expect.objectContaining({ delegateUserId: 'u2' }),
      );
      expect(realtime.emitToUser).toHaveBeenCalledWith(
        'u2',
        'delegate:you-are-dj',
        expect.objectContaining({ roomId: 'r1' }),
      );
    });
  });

  describe('revoke', () => {
    it('lets the owner revoke', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        delegateUserId: 'u2',
      });
      prisma.room.update.mockResolvedValue({ ...baseRoom, delegateUserId: null });
      await service.revoke('r1', 'owner');
      expect(prisma.room.update).toHaveBeenCalledWith({
        where: { id: 'r1' },
        data: { delegateUserId: null, delegateGrantedAt: null },
      });
      expect(realtime.emitToRoom).toHaveBeenCalledWith(
        'r1',
        'delegate:revoked',
        expect.objectContaining({ previousDelegateId: 'u2' }),
      );
    });

    it('lets the current delegate revoke themselves', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        delegateUserId: 'u2',
      });
      prisma.room.update.mockResolvedValue({ ...baseRoom, delegateUserId: null });
      await service.revoke('r1', 'u2');
      expect(prisma.room.update).toHaveBeenCalled();
    });

    it('rejects revoke by a random member', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        delegateUserId: 'u2',
      });
      await expect(service.revoke('r1', 'stranger')).rejects.toThrow(
        ForbiddenException,
      );
    });
  });

  describe('getCurrent', () => {
    it('returns the delegate for the owner', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        delegateUserId: 'u2',
      });
      const res = await service.getCurrent('r1', 'owner');
      expect(res.delegateUserId).toBe('u2');
    });

    it('404s on PRIVATE for non-members', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        visibility: 'PRIVATE',
        delegateUserId: 'u2',
      });
      prisma.roomMember.findUnique.mockResolvedValue(null);
      await expect(service.getCurrent('r1', 'stranger')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('requireDelegateOrOwner', () => {
    it('allows the owner', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      const r = await service.requireDelegateOrOwner('r1', 'owner');
      expect(r.id).toBe('r1');
    });

    it('allows the current delegate', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        delegateUserId: 'u2',
      });
      const r = await service.requireDelegateOrOwner('r1', 'u2');
      expect(r.delegateUserId).toBe('u2');
    });

    it('rejects a non-delegate non-owner', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        delegateUserId: 'u2',
      });
      await expect(
        service.requireDelegateOrOwner('r1', 'someone-else'),
      ).rejects.toThrow(ForbiddenException);
    });
  });
});
