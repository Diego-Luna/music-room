import { Test, TestingModule } from '@nestjs/testing';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { FriendsService } from './friends.service';
import { PrismaService } from '../prisma/prisma.service';

type Fn = ReturnType<typeof vi.fn>;

describe('FriendsService', () => {
  let service: FriendsService;
  let prisma: {
    user: { findUnique: Fn };
    friendship: {
      findFirst: Fn;
      findUnique: Fn;
      findMany: Fn;
      create: Fn;
      update: Fn;
      delete: Fn;
    };
  };

  beforeEach(async () => {
    prisma = {
      user: { findUnique: vi.fn() },
      friendship: {
        findFirst: vi.fn(),
        findUnique: vi.fn(),
        findMany: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
      },
    };
    const mod: TestingModule = await Test.createTestingModule({
      providers: [
        FriendsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = mod.get(FriendsService);
  });

  describe('request', () => {
    it('refuses to send a request to oneself', async () => {
      await expect(service.request('a', 'a')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('throws when the target user does not exist', async () => {
      prisma.user.findUnique.mockResolvedValue(null);
      await expect(service.request('a', 'b')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('creates a fresh PENDING when no prior friendship exists', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'b' });
      prisma.friendship.findFirst.mockResolvedValue(null);
      prisma.friendship.create.mockResolvedValue({
        id: 'f1',
        requesterId: 'a',
        addresseeId: 'b',
        status: 'PENDING',
      });
      const f = await service.request('a', 'b');
      expect(f.status).toBe('PENDING');
      expect(prisma.friendship.create).toHaveBeenCalled();
    });

    it('rejects when the pair is already ACCEPTED', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'b' });
      prisma.friendship.findFirst.mockResolvedValue({
        id: 'f1',
        status: 'ACCEPTED',
      });
      await expect(service.request('a', 'b')).rejects.toThrow(
        ConflictException,
      );
    });

    it('rejects when a PENDING request is already in flight', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'b' });
      prisma.friendship.findFirst.mockResolvedValue({
        id: 'f1',
        status: 'PENDING',
      });
      await expect(service.request('a', 'b')).rejects.toThrow(
        ConflictException,
      );
    });

    it('reopens a prior DECLINED friendship as a fresh PENDING', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'b' });
      prisma.friendship.findFirst.mockResolvedValue({
        id: 'f1',
        status: 'DECLINED',
      });
      prisma.friendship.update.mockResolvedValue({
        id: 'f1',
        requesterId: 'a',
        addresseeId: 'b',
        status: 'PENDING',
      });
      const f = await service.request('a', 'b');
      expect(f.status).toBe('PENDING');
      expect(prisma.friendship.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'f1' },
          data: expect.objectContaining({
            requesterId: 'a',
            addresseeId: 'b',
            status: 'PENDING',
          }),
        }),
      );
    });
  });

  describe('accept / decline', () => {
    it('accept: only the addressee can accept', async () => {
      prisma.friendship.findUnique.mockResolvedValue({
        id: 'f1',
        addresseeId: 'b',
        status: 'PENDING',
      });
      await expect(service.accept('a', 'f1')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('accept: refuses non-PENDING friendships', async () => {
      prisma.friendship.findUnique.mockResolvedValue({
        id: 'f1',
        addresseeId: 'b',
        status: 'ACCEPTED',
      });
      await expect(service.accept('b', 'f1')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('accept: marks ACCEPTED with respondedAt', async () => {
      prisma.friendship.findUnique.mockResolvedValue({
        id: 'f1',
        addresseeId: 'b',
        status: 'PENDING',
      });
      prisma.friendship.update.mockResolvedValue({
        id: 'f1',
        status: 'ACCEPTED',
      });
      await service.accept('b', 'f1');
      expect(prisma.friendship.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'f1' },
          data: expect.objectContaining({ status: 'ACCEPTED' }),
        }),
      );
    });

    it('decline: only the addressee can decline', async () => {
      prisma.friendship.findUnique.mockResolvedValue({
        id: 'f1',
        addresseeId: 'b',
        status: 'PENDING',
      });
      await expect(service.decline('a', 'f1')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('decline: marks DECLINED', async () => {
      prisma.friendship.findUnique.mockResolvedValue({
        id: 'f1',
        addresseeId: 'b',
        status: 'PENDING',
      });
      prisma.friendship.update.mockResolvedValue({
        id: 'f1',
        status: 'DECLINED',
      });
      await service.decline('b', 'f1');
      expect(prisma.friendship.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'f1' },
          data: expect.objectContaining({ status: 'DECLINED' }),
        }),
      );
    });
  });

  describe('cancel / unfriend', () => {
    it('rejects unrelated users', async () => {
      prisma.friendship.findUnique.mockResolvedValue({
        id: 'f1',
        requesterId: 'a',
        addresseeId: 'b',
        status: 'PENDING',
      });
      await expect(service.cancel('c', 'f1')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('deletes when ACCEPTED (= unfriend)', async () => {
      prisma.friendship.findUnique.mockResolvedValue({
        id: 'f1',
        requesterId: 'a',
        addresseeId: 'b',
        status: 'ACCEPTED',
      });
      prisma.friendship.delete.mockResolvedValue({});
      const r = (await service.cancel('a', 'f1')) as { removed: boolean };
      expect(r.removed).toBe(true);
      expect(prisma.friendship.delete).toHaveBeenCalled();
    });

    it('marks CANCELED when requester cancels a PENDING', async () => {
      prisma.friendship.findUnique.mockResolvedValue({
        id: 'f1',
        requesterId: 'a',
        addresseeId: 'b',
        status: 'PENDING',
      });
      prisma.friendship.update.mockResolvedValue({});
      await service.cancel('a', 'f1');
      expect(prisma.friendship.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ status: 'CANCELED' }),
        }),
      );
    });

    it('rejects DECLINED state for cancellation', async () => {
      prisma.friendship.findUnique.mockResolvedValue({
        id: 'f1',
        requesterId: 'a',
        addresseeId: 'b',
        status: 'DECLINED',
      });
      await expect(service.cancel('a', 'f1')).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('listAccepted', () => {
    it('projects friends with the friendId being the OTHER side', async () => {
      prisma.friendship.findMany.mockResolvedValue([
        {
          id: 'f1',
          requesterId: 'a',
          addresseeId: 'b',
          respondedAt: new Date('2026-05-01'),
        },
        {
          id: 'f2',
          requesterId: 'c',
          addresseeId: 'a',
          respondedAt: new Date('2026-05-02'),
        },
      ]);
      const friends = await service.listAccepted('a');
      expect(friends).toEqual([
        { friendshipId: 'f1', friendId: 'b', since: new Date('2026-05-01') },
        { friendshipId: 'f2', friendId: 'c', since: new Date('2026-05-02') },
      ]);
    });
  });

  describe('areFriends', () => {
    it('returns true when self-comparing', async () => {
      const r = await service.areFriends('a', 'a');
      expect(r).toBe(true);
      expect(prisma.friendship.findFirst).not.toHaveBeenCalled();
    });

    it('returns true when an ACCEPTED row exists in either direction', async () => {
      prisma.friendship.findFirst.mockResolvedValue({ id: 'f1' });
      const r = await service.areFriends('a', 'b');
      expect(r).toBe(true);
    });

    it('returns false when no ACCEPTED row exists', async () => {
      prisma.friendship.findFirst.mockResolvedValue(null);
      const r = await service.areFriends('a', 'b');
      expect(r).toBe(false);
    });
  });
});
