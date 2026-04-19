import { Test, TestingModule } from '@nestjs/testing';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { generateKeyBetween } from 'fractional-indexing';
import { PlaylistService } from './playlist.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';

const keyA = generateKeyBetween(null, null);
const keyB = generateKeyBetween(keyA, null);

type Fn = ReturnType<typeof vi.fn>;

describe('PlaylistService', () => {
  let service: PlaylistService;
  let prisma: {
    room: { findUnique: Fn };
    roomMember: { findUnique: Fn };
    track: {
      findUnique: Fn;
      findFirst: Fn;
      findMany: Fn;
      create: Fn;
      update: Fn;
      delete: Fn;
    };
  };
  let realtime: { emitToRoom: Fn; emitToUser: Fn };

  const baseRoom = {
    id: 'r1',
    kind: 'PLAYLIST',
    ownerId: 'owner',
    visibility: 'PUBLIC',
    allowMembersEdit: true,
  };

  beforeEach(async () => {
    prisma = {
      room: { findUnique: vi.fn() },
      roomMember: { findUnique: vi.fn() },
      track: {
        findUnique: vi.fn(),
        findFirst: vi.fn(),
        findMany: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
      },
    };
    realtime = { emitToRoom: vi.fn(), emitToUser: vi.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PlaylistService,
        { provide: PrismaService, useValue: prisma },
        { provide: RealtimeService, useValue: realtime },
      ],
    }).compile();

    service = module.get(PlaylistService);
  });

  const baseDto = {
    providerId: 'p1',
    title: 'Song',
    artist: 'Artist',
    durationMs: 180_000,
  };

  describe('addItem', () => {
    it('rejects non-PLAYLIST rooms', async () => {
      prisma.room.findUnique.mockResolvedValue({ ...baseRoom, kind: 'VOTE' });
      await expect(
        service.addItem('r1', 'owner', { ...baseDto }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects non-members', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.roomMember.findUnique.mockResolvedValue(null);
      await expect(
        service.addItem('r1', 'stranger', { ...baseDto }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects a regular member when allowMembersEdit=false', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        allowMembersEdit: false,
      });
      prisma.roomMember.findUnique.mockResolvedValue({ role: 'MEMBER' });
      await expect(
        service.addItem('r1', 'someone', { ...baseDto }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('allows admin when allowMembersEdit=false', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        allowMembersEdit: false,
      });
      prisma.roomMember.findUnique.mockResolvedValue({ role: 'ADMIN' });
      prisma.track.findUnique.mockResolvedValue(null);
      prisma.track.findFirst.mockResolvedValue(null);
      prisma.track.create.mockResolvedValue({ id: 't1', roomId: 'r1' });
      await service.addItem('r1', 'admin', { ...baseDto });
      expect(prisma.track.create).toHaveBeenCalled();
    });

    it('rejects when both afterTrackId and beforeTrackId are given', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      await expect(
        service.addItem('r1', 'owner', {
          ...baseDto,
          afterTrackId: 'a',
          beforeTrackId: 'b',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects a duplicate track', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique.mockResolvedValue({ id: 'dup' });
      await expect(
        service.addItem('r1', 'owner', { ...baseDto }),
      ).rejects.toThrow(ConflictException);
    });

    it('appends to the end of an empty playlist and broadcasts playlist:item-added', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique.mockResolvedValue(null);
      prisma.track.findFirst.mockResolvedValue(null);
      prisma.track.create.mockImplementation(async (args: { data: { position: string } }) => ({
        id: 't1',
        roomId: 'r1',
        position: args.data.position,
      }));

      const track = await service.addItem('r1', 'owner', { ...baseDto });

      expect(track.id).toBe('t1');
      expect(typeof track.position).toBe('string');
      expect(track.position.length).toBeGreaterThan(0);
      expect(realtime.emitToRoom).toHaveBeenCalledWith(
        'r1',
        'playlist:item-added',
        expect.objectContaining({ id: 't1' }),
      );
    });

    it('inserts after an anchor track', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique
        .mockResolvedValueOnce(null) // duplicate check
        .mockResolvedValueOnce({ id: 'a', roomId: 'r1', position: keyA }); // anchor
      prisma.track.create.mockImplementation(async (args: { data: { position: string } }) => ({
        id: 't2',
        position: args.data.position,
      }));

      const track = await service.addItem('r1', 'owner', {
        ...baseDto,
        afterTrackId: 'a',
      });

      expect(track.position > keyA).toBe(true);
    });

    it('404 when anchor track is not in the room', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique
        .mockResolvedValueOnce(null) // duplicate check
        .mockResolvedValueOnce({ id: 'a', roomId: 'other', position: keyA });
      await expect(
        service.addItem('r1', 'owner', { ...baseDto, afterTrackId: 'a' }),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('moveItem', () => {
    beforeEach(() => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
    });

    it('requires at least one anchor', async () => {
      prisma.track.findUnique.mockResolvedValue({
        id: 't1',
        roomId: 'r1',
        position: keyA,
      });
      await expect(
        service.moveItem('r1', 't1', 'owner', {}),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects self-anchoring', async () => {
      prisma.track.findUnique.mockResolvedValue({
        id: 't1',
        roomId: 'r1',
        position: keyA,
      });
      await expect(
        service.moveItem('r1', 't1', 'owner', { afterTrackId: 't1' }),
      ).rejects.toThrow(BadRequestException);
    });

    it('404 when the track does not belong to the room', async () => {
      prisma.track.findUnique.mockResolvedValue({
        id: 't1',
        roomId: 'other',
        position: keyA,
      });
      await expect(
        service.moveItem('r1', 't1', 'owner', { afterTrackId: 'a' }),
      ).rejects.toThrow(NotFoundException);
    });

    it('updates position and broadcasts playlist:item-moved', async () => {
      prisma.track.findUnique
        .mockResolvedValueOnce({ id: 't1', roomId: 'r1', position: 'a0' })
        .mockResolvedValueOnce({ id: 'a', roomId: 'r1', position: keyB });
      prisma.track.update.mockImplementation(
        async (args: { data: { position: string } }) => ({
          id: 't1',
          position: args.data.position,
        }),
      );

      const res = await service.moveItem('r1', 't1', 'owner', {
        afterTrackId: 'a',
      });

      expect(res.position > keyB).toBe(true);
      expect(realtime.emitToRoom).toHaveBeenCalledWith(
        'r1',
        'playlist:item-moved',
        expect.objectContaining({ trackId: 't1' }),
      );
    });
  });

  describe('removeItem', () => {
    it('lets the author remove their own item', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique.mockResolvedValue({
        id: 't1',
        roomId: 'r1',
        addedById: 'u1',
      });
      await service.removeItem('r1', 't1', 'u1');
      expect(prisma.track.delete).toHaveBeenCalledWith({ where: { id: 't1' } });
      expect(realtime.emitToRoom).toHaveBeenCalledWith(
        'r1',
        'playlist:item-removed',
        { trackId: 't1' },
      );
    });

    it('lets the owner remove any item', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique.mockResolvedValue({
        id: 't1',
        roomId: 'r1',
        addedById: 'other',
      });
      await service.removeItem('r1', 't1', 'owner');
      expect(prisma.track.delete).toHaveBeenCalled();
    });

    it('rejects a regular member removing another user item', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique.mockResolvedValue({
        id: 't1',
        roomId: 'r1',
        addedById: 'other',
      });
      prisma.roomMember.findUnique.mockResolvedValue({ role: 'MEMBER' });
      await expect(
        service.removeItem('r1', 't1', 'someone'),
      ).rejects.toThrow(ForbiddenException);
    });

    it('allows an admin to remove any item', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique.mockResolvedValue({
        id: 't1',
        roomId: 'r1',
        addedById: 'other',
      });
      prisma.roomMember.findUnique.mockResolvedValue({ role: 'ADMIN' });
      await service.removeItem('r1', 't1', 'admin');
      expect(prisma.track.delete).toHaveBeenCalled();
    });
  });

  describe('listOrdered', () => {
    it('returns tracks ordered by position asc, addedAt asc', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findMany.mockResolvedValue([{ id: 't1' }]);
      const list = await service.listOrdered('r1', 'u1');
      expect(prisma.track.findMany).toHaveBeenCalledWith({
        where: { roomId: 'r1', position: { not: null } },
        orderBy: [{ position: 'asc' }, { addedAt: 'asc' }],
      });
      expect(list).toHaveLength(1);
    });

    it('returns 404 for a PRIVATE room non-member', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        visibility: 'PRIVATE',
      });
      prisma.roomMember.findUnique.mockResolvedValue(null);
      await expect(service.listOrdered('r1', 'stranger')).rejects.toThrow(
        NotFoundException,
      );
    });
  });
});
