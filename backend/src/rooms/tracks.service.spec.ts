import { Test, TestingModule } from '@nestjs/testing';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { TracksService } from './tracks.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';

type Fn = ReturnType<typeof vi.fn>;

describe('TracksService', () => {
  let service: TracksService;
  let prisma: {
    room: { findUnique: Fn };
    roomMember: { findUnique: Fn };
    track: {
      findUnique: Fn;
      findMany: Fn;
      create: Fn;
      update: Fn;
      delete: Fn;
    };
    trackVote: {
      findUnique: Fn;
      create: Fn;
      update: Fn;
      delete: Fn;
    };
    $transaction: Fn;
  };
  let realtime: { emitToRoom: Fn; emitToUser: Fn };

  const baseRoom = {
    id: 'r1',
    kind: 'VOTE',
    ownerId: 'owner',
    visibility: 'PUBLIC',
    voteWindow: 'ALWAYS',
    voteStartsAt: null,
    voteEndsAt: null,
    voteLocationLat: null,
    voteLocationLng: null,
    voteLocationRadiusM: null,
  };

  beforeEach(async () => {
    prisma = {
      room: { findUnique: vi.fn() },
      roomMember: { findUnique: vi.fn() },
      track: {
        findUnique: vi.fn(),
        findMany: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
      },
      trackVote: {
        findUnique: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
      },
      $transaction: vi.fn(async (cb: unknown) =>
        typeof cb === 'function'
          ? (cb as (p: unknown) => Promise<unknown>)(prisma)
          : cb,
      ),
    };
    realtime = { emitToRoom: vi.fn(), emitToUser: vi.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TracksService,
        { provide: PrismaService, useValue: prisma },
        { provide: RealtimeService, useValue: realtime },
      ],
    }).compile();

    service = module.get(TracksService);
  });

  describe('addTrack', () => {
    it('rejects when the room is not a VOTE room', async () => {
      prisma.room.findUnique.mockResolvedValue({ ...baseRoom, kind: 'PLAYLIST' });
      await expect(
        service.addTrack('r1', 'owner', {
          providerId: 'p1',
          title: 't',
          artist: 'a',
          durationMs: 1000,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects a non-member', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.roomMember.findUnique.mockResolvedValue(null);
      await expect(
        service.addTrack('r1', 'stranger', {
          providerId: 'p1',
          title: 't',
          artist: 'a',
          durationMs: 1000,
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects a duplicate track', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique.mockResolvedValue({ id: 't1' });
      await expect(
        service.addTrack('r1', 'owner', {
          providerId: 'p1',
          title: 't',
          artist: 'a',
          durationMs: 1000,
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('creates a track and broadcasts track:added', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique.mockResolvedValue(null);
      prisma.track.create.mockResolvedValue({ id: 't1', roomId: 'r1' });

      const track = await service.addTrack('r1', 'owner', {
        providerId: 'p1',
        title: 'Song',
        artist: 'Artist',
        durationMs: 200_000,
      });

      expect(track.id).toBe('t1');
      expect(realtime.emitToRoom).toHaveBeenCalledWith(
        'r1',
        'track:added',
        expect.objectContaining({ id: 't1' }),
      );
    });
  });

  describe('vote', () => {
    beforeEach(() => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique.mockResolvedValue({ id: 't1', roomId: 'r1' });
      // u1 is a member in vote tests
      prisma.roomMember.findUnique.mockResolvedValue({ role: 'MEMBER' });
    });

    it('creates a +1 vote and increments the score', async () => {
      prisma.trackVote.findUnique.mockResolvedValue(null);
      prisma.track.update.mockResolvedValue({ id: 't1', score: 1 });

      const res = await service.vote('r1', 't1', 'u1', { value: 1 });
      expect(prisma.trackVote.create).toHaveBeenCalled();
      expect(prisma.track.update).toHaveBeenCalledWith({
        where: { id: 't1' },
        data: { score: { increment: 1 } },
      });
      expect(res.score).toBe(1);
      expect(realtime.emitToRoom).toHaveBeenCalledWith(
        'r1',
        'track:voted',
        expect.objectContaining({ trackId: 't1', value: 1, score: 1 }),
      );
    });

    it('flipping -1 → +1 applies a delta of +2', async () => {
      prisma.trackVote.findUnique.mockResolvedValue({ value: -1 });
      prisma.track.update.mockResolvedValue({ id: 't1', score: 1 });

      await service.vote('r1', 't1', 'u1', { value: 1 });
      expect(prisma.trackVote.update).toHaveBeenCalled();
      expect(prisma.track.update).toHaveBeenCalledWith({
        where: { id: 't1' },
        data: { score: { increment: 2 } },
      });
    });

    it('value=0 clears an existing vote and applies the reverse delta', async () => {
      prisma.trackVote.findUnique.mockResolvedValue({ value: 1 });
      prisma.track.update.mockResolvedValue({ id: 't1', score: -1 });

      await service.vote('r1', 't1', 'u1', { value: 0 });
      expect(prisma.trackVote.delete).toHaveBeenCalled();
      expect(prisma.track.update).toHaveBeenCalledWith({
        where: { id: 't1' },
        data: { score: { increment: -1 } },
      });
    });

    it('rejects voting when the window is closed (SCHEDULED)', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        voteWindow: 'SCHEDULED',
        voteStartsAt: new Date(Date.now() - 2 * 3600_000),
        voteEndsAt: new Date(Date.now() - 3600_000),
      });
      await expect(
        service.vote('r1', 't1', 'u1', { value: 1 }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('accepts voting inside the SCHEDULED window', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        voteWindow: 'SCHEDULED',
        voteStartsAt: new Date(Date.now() - 3600_000),
        voteEndsAt: new Date(Date.now() + 3600_000),
      });
      prisma.trackVote.findUnique.mockResolvedValue(null);
      prisma.track.update.mockResolvedValue({ id: 't1', score: 1 });
      await service.vote('r1', 't1', 'u1', { value: 1 });
      expect(prisma.track.update).toHaveBeenCalled();
    });

    it('rejects voting outside the geo radius', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        voteLocationLat: 48.8566,
        voteLocationLng: 2.3522,
        voteLocationRadiusM: 500,
      });
      // New York ~5850 km from Paris
      await expect(
        service.vote('r1', 't1', 'u1', {
          value: 1,
          lat: 40.7128,
          lng: -74.006,
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('accepts voting inside the geo radius', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        voteLocationLat: 48.8566,
        voteLocationLng: 2.3522,
        voteLocationRadiusM: 5000,
      });
      prisma.trackVote.findUnique.mockResolvedValue(null);
      prisma.track.update.mockResolvedValue({ id: 't1', score: 1 });
      // ~1 km away from the center (Eiffel Tower)
      await service.vote('r1', 't1', 'u1', {
        value: 1,
        lat: 48.8584,
        lng: 2.2945,
      });
      expect(prisma.track.update).toHaveBeenCalled();
    });

    it('rejects voting on a geo-gated room without lat/lng', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        voteLocationLat: 48.8566,
        voteLocationLng: 2.3522,
        voteLocationRadiusM: 500,
      });
      await expect(
        service.vote('r1', 't1', 'u1', { value: 1 }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('returns 404 when the track is not in the room', async () => {
      prisma.track.findUnique.mockResolvedValue({ id: 't1', roomId: 'other' });
      await expect(
        service.vote('r1', 't1', 'u1', { value: 1 }),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('removeTrack', () => {
    it('lets the author remove their own track', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique.mockResolvedValue({
        id: 't1',
        roomId: 'r1',
        addedById: 'u1',
      });
      await service.removeTrack('r1', 't1', 'u1');
      expect(prisma.track.delete).toHaveBeenCalledWith({ where: { id: 't1' } });
      expect(realtime.emitToRoom).toHaveBeenCalledWith('r1', 'track:removed', {
        trackId: 't1',
      });
    });

    it('lets the owner remove any track', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique.mockResolvedValue({
        id: 't1',
        roomId: 'r1',
        addedById: 'someone-else',
      });
      await service.removeTrack('r1', 't1', 'owner');
      expect(prisma.track.delete).toHaveBeenCalled();
    });

    it('rejects a regular member removing another user track', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique.mockResolvedValue({
        id: 't1',
        roomId: 'r1',
        addedById: 'other',
      });
      prisma.roomMember.findUnique.mockResolvedValue({ role: 'MEMBER' });
      await expect(
        service.removeTrack('r1', 't1', 'someone'),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('listRanked', () => {
    it('returns tracks sorted by score desc, addedAt asc, excluding played', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findMany.mockResolvedValue([{ id: 't1' }]);
      const list = await service.listRanked('r1', 'u1');
      expect(prisma.track.findMany).toHaveBeenCalledWith({
        where: { roomId: 'r1', playedAt: null },
        orderBy: [{ score: 'desc' }, { addedAt: 'asc' }],
      });
      expect(list).toHaveLength(1);
    });

    it('returns 404 for a PRIVATE room non-member', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        visibility: 'PRIVATE',
      });
      prisma.roomMember.findUnique.mockResolvedValue(null);
      await expect(service.listRanked('r1', 'stranger')).rejects.toThrow(
        NotFoundException,
      );
    });
  });
});
