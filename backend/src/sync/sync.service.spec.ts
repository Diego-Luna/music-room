import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { SyncService } from './sync.service';
import { PrismaService } from '../prisma/prisma.service';

describe('SyncService', () => {
  let service: SyncService;
  let prisma: {
    user: { findUnique: ReturnType<typeof vi.fn> };
    room: { findMany: ReturnType<typeof vi.fn> };
    roomInvitation: { findMany: ReturnType<typeof vi.fn> };
    friendship: { findMany: ReturnType<typeof vi.fn> };
  };

  beforeEach(async () => {
    prisma = {
      user: { findUnique: vi.fn() },
      room: { findMany: vi.fn().mockResolvedValue([]) },
      roomInvitation: { findMany: vi.fn().mockResolvedValue([]) },
      friendship: { findMany: vi.fn().mockResolvedValue([]) },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SyncService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<SyncService>(SyncService);
  });

  it('returns a snapshot with profile, rooms, invitations and friendships', async () => {
    const me = { id: 'user-1', email: 'a@b.c', displayName: 'A' };
    prisma.user.findUnique.mockResolvedValue(me);
    prisma.room.findMany.mockResolvedValue([{ id: 'room-1' }]);
    prisma.roomInvitation.findMany.mockResolvedValue([{ id: 'inv-1' }]);
    prisma.friendship.findMany.mockResolvedValue([{ id: 'fr-1' }]);

    const snap = await service.snapshot('user-1');

    expect(snap.me).toEqual(me);
    expect(snap.rooms).toHaveLength(1);
    expect(snap.invitations).toHaveLength(1);
    expect(snap.friendships).toHaveLength(1);
    expect(typeof snap.serverTime).toBe('string');
  });

  it('queries rooms the user owns OR is a member of', async () => {
    prisma.user.findUnique.mockResolvedValue({ id: 'user-1' });
    await service.snapshot('user-1');
    const where = prisma.room.findMany.mock.calls[0][0].where;
    expect(where.OR).toEqual(
      expect.arrayContaining([
        { ownerId: 'user-1' },
        { members: { some: { userId: 'user-1' } } },
      ]),
    );
  });

  it('only returns PENDING non-expired invitations', async () => {
    prisma.user.findUnique.mockResolvedValue({ id: 'user-1' });
    await service.snapshot('user-1');
    const where = prisma.roomInvitation.findMany.mock.calls[0][0].where;
    expect(where.inviteeId).toBe('user-1');
    expect(where.status).toBe('PENDING');
    expect(where.expiresAt).toEqual({ gt: expect.any(Date) });
  });

  it('throws NotFound if the user does not exist', async () => {
    prisma.user.findUnique.mockResolvedValue(null);
    await expect(service.snapshot('ghost')).rejects.toThrow(NotFoundException);
  });
});
