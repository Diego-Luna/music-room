import { Test, TestingModule } from '@nestjs/testing';
import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { RoomsService } from './rooms.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  RoomKind,
  RoomVisibility,
  VoteWindow,
} from './dto/create-room.dto';

describe('RoomsService', () => {
  let service: RoomsService;
  let prisma: Record<string, Record<string, ReturnType<typeof vi.fn>>>;

  const roomRow = {
    id: 'room-1',
    name: 'Chill',
    description: null,
    kind: 'VOTE',
    visibility: 'PUBLIC',
    licenseTier: 'FREE',
    ownerId: 'user-1',
    allowMembersEdit: true,
    voteWindow: 'ALWAYS',
    voteStartsAt: null,
    voteEndsAt: null,
    voteLocationLat: null,
    voteLocationLng: null,
    voteLocationRadiusM: null,
    createdAt: new Date('2026-04-18'),
    updatedAt: new Date('2026-04-18'),
  };

  beforeEach(async () => {
    prisma = {
      room: {
        create: vi.fn().mockResolvedValue(roomRow),
        findUnique: vi.fn(),
        findMany: vi.fn(),
        update: vi.fn().mockResolvedValue(roomRow),
        delete: vi.fn(),
      },
      roomMember: {
        create: vi.fn(),
        findUnique: vi.fn(),
        findMany: vi.fn(),
        delete: vi.fn(),
        update: vi.fn(),
      },
      $transaction: vi.fn((fn: (tx: unknown) => unknown) => fn(prisma)),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RoomsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<RoomsService>(RoomsService);
  });

  describe('create', () => {
    it('creates a room and adds the owner as OWNER member in one transaction', async () => {
      const room = await service.create('user-1', {
        name: 'Chill',
        kind: RoomKind.VOTE,
      });

      expect(prisma.$transaction).toHaveBeenCalled();
      expect(prisma.room.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          name: 'Chill',
          kind: 'VOTE',
          ownerId: 'user-1',
          visibility: 'PUBLIC',
        }),
      });
      expect(prisma.roomMember.create).toHaveBeenCalledWith({
        data: { roomId: 'room-1', userId: 'user-1', role: 'OWNER' },
      });
      expect(room.id).toBe('room-1');
    });

    it('rejects a SCHEDULED vote window missing start/end', async () => {
      await expect(
        service.create('user-1', {
          name: 'Bad',
          kind: RoomKind.VOTE,
          voteWindow: VoteWindow.SCHEDULED,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects a SCHEDULED window where end <= start', async () => {
      await expect(
        service.create('user-1', {
          name: 'Bad',
          kind: RoomKind.VOTE,
          voteWindow: VoteWindow.SCHEDULED,
          voteStartsAt: '2026-04-18T12:00:00Z',
          voteEndsAt: '2026-04-18T11:00:00Z',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects a location with missing longitude or radius', async () => {
      await expect(
        service.create('user-1', {
          name: 'Bad',
          kind: RoomKind.VOTE,
          voteLocationLat: 48.85,
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('findOne', () => {
    it('returns a public room to anyone', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...roomRow,
        visibility: 'PUBLIC',
      });
      prisma.roomMember.findUnique.mockResolvedValue(null);
      const room = await service.findOne('room-1', 'another-user');
      expect(room.id).toBe('room-1');
    });

    it('returns a private room to a member', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...roomRow,
        visibility: 'PRIVATE',
      });
      prisma.roomMember.findUnique.mockResolvedValue({
        roomId: 'room-1',
        userId: 'user-2',
        role: 'MEMBER',
      });
      const room = await service.findOne('room-1', 'user-2');
      expect(room.id).toBe('room-1');
    });

    it('hides a private room from non-members (404)', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...roomRow,
        visibility: 'PRIVATE',
      });
      prisma.roomMember.findUnique.mockResolvedValue(null);
      await expect(
        service.findOne('room-1', 'another-user'),
      ).rejects.toThrow(NotFoundException);
    });

    it('throws 404 for a missing room', async () => {
      prisma.room.findUnique.mockResolvedValue(null);
      await expect(service.findOne('missing', 'user-1')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('list', () => {
    it('returns the public rooms + rooms the user owns + rooms the user is a member of', async () => {
      prisma.room.findMany.mockResolvedValue([roomRow]);
      const rooms = await service.list('user-1');

      const call = prisma.room.findMany.mock.calls[0][0] as {
        where: { OR: unknown[] };
      };
      expect(call.where.OR).toEqual(
        expect.arrayContaining([
          { visibility: 'PUBLIC' },
          { ownerId: 'user-1' },
          { members: { some: { userId: 'user-1' } } },
        ]),
      );
      expect(rooms).toHaveLength(1);
    });
  });

  describe('update', () => {
    it('lets the owner update name and visibility', async () => {
      prisma.room.findUnique.mockResolvedValue(roomRow);
      prisma.roomMember.findUnique.mockResolvedValue(null);

      await service.update('room-1', 'user-1', {
        name: 'New',
        visibility: RoomVisibility.PRIVATE,
      });

      expect(prisma.room.update).toHaveBeenCalledWith({
        where: { id: 'room-1' },
        data: expect.objectContaining({
          name: 'New',
          visibility: 'PRIVATE',
        }),
      });
    });

    it('lets an ADMIN member update the room', async () => {
      prisma.room.findUnique.mockResolvedValue(roomRow);
      prisma.roomMember.findUnique.mockResolvedValue({
        userId: 'admin-1',
        role: 'ADMIN',
      });

      await expect(
        service.update('room-1', 'admin-1', { name: 'X' }),
      ).resolves.not.toThrow();
    });

    it('rejects a regular MEMBER', async () => {
      prisma.room.findUnique.mockResolvedValue(roomRow);
      prisma.roomMember.findUnique.mockResolvedValue({
        userId: 'member-1',
        role: 'MEMBER',
      });
      await expect(
        service.update('room-1', 'member-1', { name: 'X' }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects a stranger with 404 (never leaks existence of a private room)', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...roomRow,
        visibility: 'PRIVATE',
      });
      prisma.roomMember.findUnique.mockResolvedValue(null);
      await expect(
        service.update('room-1', 'stranger', { name: 'X' }),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('remove', () => {
    it('lets the owner delete the room', async () => {
      prisma.room.findUnique.mockResolvedValue(roomRow);
      await service.remove('room-1', 'user-1');
      expect(prisma.room.delete).toHaveBeenCalledWith({
        where: { id: 'room-1' },
      });
    });

    it('rejects an ADMIN (only the owner can delete)', async () => {
      prisma.room.findUnique.mockResolvedValue(roomRow);
      prisma.roomMember.findUnique.mockResolvedValue({
        userId: 'admin-1',
        role: 'ADMIN',
      });
      await expect(
        service.remove('room-1', 'admin-1'),
      ).rejects.toThrow(ForbiddenException);
    });
  });
});
