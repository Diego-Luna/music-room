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
import { QueueProgressionService } from './queue-progression.service';

type Fn = ReturnType<typeof vi.fn>;

describe('TracksService', () => {
  let service: TracksService;
  let prisma: {
    room: { findUnique: Fn };
    roomMember: { findUnique: Fn };
    roomInvitation: { findFirst: Fn };
    track: {
      findUnique: Fn;
      findMany: Fn;
      create: Fn;
      update: Fn;
      delete: Fn;
    };
    trackVote: {
      findUnique: Fn;
      findMany: Fn;
      create: Fn;
      update: Fn;
      delete: Fn;
      deleteMany: Fn;
    };
    $transaction: Fn;
    $queryRaw: Fn;
    $executeRaw: Fn;
  };
  let realtime: { emitToRoom: Fn; emitToUser: Fn };
  let queue: { startIdle: Fn };

  const baseRoom = {
    id: 'r1',
    kind: 'VOTE',
    ownerId: 'owner',
    visibility: 'PUBLIC',
    voteAccess: 'EVERYONE',
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
      roomInvitation: { findFirst: vi.fn() },
      track: {
        findUnique: vi.fn(),
        findMany: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
      },
      trackVote: {
        findUnique: vi.fn(),
        findMany: vi.fn().mockResolvedValue([]),
        create: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
        deleteMany: vi.fn(),
      },
      $transaction: vi.fn(async (cb: unknown) =>
        typeof cb === 'function'
          ? (cb as (p: unknown) => Promise<unknown>)(prisma)
          : cb,
      ),
      $queryRaw: vi.fn().mockResolvedValue([{ id: 't1', playedAt: null }]),
      $executeRaw: vi.fn().mockResolvedValue(1),
    };
    realtime = { emitToRoom: vi.fn(), emitToUser: vi.fn() };
    queue = { startIdle: vi.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TracksService,
        { provide: PrismaService, useValue: prisma },
        { provide: RealtimeService, useValue: realtime },
        { provide: QueueProgressionService, useValue: queue },
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

    it('rejects a non-member of a PRIVATE room', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        visibility: 'PRIVATE',
      });
      prisma.roomMember.findUnique.mockResolvedValue(null);
      await expect(
        service.addTrack('r1', 'stranger', {
          providerId: 'p1',
          title: 't',
          artist: 'a',
          durationMs: 1000,
        }),
      ).rejects.toThrow(NotFoundException);
    });

    it('lets any authenticated user add to a PUBLIC room (no membership)', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.roomMember.findUnique.mockResolvedValue(null);
      prisma.track.findUnique.mockResolvedValue(null);
      prisma.track.create.mockResolvedValue({ id: 't1', roomId: 'r1' });

      const track = await service.addTrack('r1', 'stranger', {
        providerId: 'p1',
        title: 't',
        artist: 'a',
        durationMs: 1000,
      });

      expect(track.id).toBe('t1');
    });

    it('rejects a non-invited user when voteAccess=INVITED_ONLY', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        voteAccess: 'INVITED_ONLY',
      });
      prisma.roomInvitation.findFirst.mockResolvedValue(null);
      await expect(
        service.addTrack('r1', 'stranger', {
          providerId: 'p1',
          title: 't',
          artist: 'a',
          durationMs: 1000,
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('allows an invited user to suggest when voteAccess=INVITED_ONLY', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        voteAccess: 'INVITED_ONLY',
      });
      prisma.roomInvitation.findFirst.mockResolvedValue({ id: 'inv-1' });
      prisma.track.findUnique.mockResolvedValue(null);
      prisma.track.create.mockResolvedValue({ id: 't1', roomId: 'r1' });

      const track = await service.addTrack('r1', 'invited-user', {
        providerId: 'p1',
        title: 't',
        artist: 'a',
        durationMs: 1000,
      });
      expect(track.id).toBe('t1');
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

    it('puts a track that already played back in the queue at score 0', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique.mockResolvedValue({
        id: 't1',
        playedAt: new Date('2020-01-01'),
      });
      prisma.track.update.mockResolvedValue({
        id: 't1',
        roomId: 'r1',
        score: 0,
        playedAt: null,
      });

      const track = await service.addTrack('r1', 'owner', {
        providerId: 'p1',
        title: 'Song',
        artist: 'Artist',
        durationMs: 180000,
      });

      expect(prisma.trackVote.deleteMany).toHaveBeenCalledWith({
        where: { trackId: 't1' },
      });
      expect(prisma.track.update).toHaveBeenCalledWith({
        where: { id: 't1' },
        data: expect.objectContaining({
          title: 'Song',
          addedById: 'owner',
          playedAt: null,
          score: 0,
        }),
      });
      expect(prisma.track.create).not.toHaveBeenCalled();
      expect(realtime.emitToRoom).toHaveBeenCalledWith(
        'r1',
        'track:added',
        expect.objectContaining({ id: 't1', score: 0 }),
      );
      expect(queue.startIdle).toHaveBeenCalledWith('r1');
      expect(track.score).toBe(0);
    });

    it('rejects suggesting the track that is currently playing', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        currentTrackId: 't1',
      });
      prisma.track.findUnique.mockResolvedValue({
        id: 't1',
        playedAt: new Date('2020-01-01'),
      });

      await expect(
        service.addTrack('r1', 'owner', {
          providerId: 'p1',
          title: 'Song',
          artist: 'Artist',
          durationMs: 180000,
        }),
      ).rejects.toThrow(ConflictException);
      expect(prisma.track.update).not.toHaveBeenCalled();
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

    it('starts the track immediately when the VOTE room is idle', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique.mockResolvedValue(null);
      prisma.track.create.mockResolvedValue({ id: 't1', roomId: 'r1' });

      await service.addTrack('r1', 'owner', {
        providerId: 'p1',
        title: 'Song',
        artist: 'Artist',
        durationMs: 200_000,
      });

      expect(queue.startIdle).toHaveBeenCalledWith('r1');
    });

    it('does not start a track when the room already has one playing', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        currentTrackId: 'already-playing',
      });
      prisma.track.findUnique.mockResolvedValue(null);
      prisma.track.create.mockResolvedValue({ id: 't2', roomId: 'r1' });

      await service.addTrack('r1', 'owner', {
        providerId: 'p2',
        title: 'Song 2',
        artist: 'Artist',
        durationMs: 200_000,
      });

      expect(queue.startIdle).not.toHaveBeenCalled();
    });
  });

  describe('addTrack concurrency', () => {
    it('turns two simultaneous suggestions of one track into 409, not 500', async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique.mockResolvedValue(null);
      prisma.track.create.mockRejectedValue({ code: 'P2002' });

      await expect(
        service.addTrack('r1', 'u1', {
          providerId: 'p1',
          title: 'Song',
          artist: 'Artist',
          durationMs: 200_000,
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('vote', () => {
    beforeEach(() => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findUnique.mockResolvedValue({ id: 't1', roomId: 'r1' });
      // u1 is a member in vote tests
      prisma.roomMember.findUnique.mockResolvedValue({ role: 'MEMBER' });
    });

    it('rejects a track marked played under the row lock', async () => {
      prisma.$queryRaw.mockResolvedValue([{ id: 't1', playedAt: new Date() }]);

      await expect(service.vote('r1', 't1', 'u1', { value: 1 })).rejects.toThrow(
        BadRequestException,
      );
      expect(prisma.trackVote.create).not.toHaveBeenCalled();
      expect(prisma.track.update).not.toHaveBeenCalled();
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
        { trackId: 't1', score: 1 },
      );
    });

    it('moves an existing vote onto the newly chosen track', async () => {
      prisma.trackVote.findMany.mockResolvedValueOnce([
        { trackId: 't2', value: 1, userId: 'u1', roomId: 'r1' },
      ]);
      prisma.trackVote.findUnique.mockResolvedValue(null);
      prisma.track.update
        .mockResolvedValueOnce({ id: 't2', score: 2 })
        .mockResolvedValueOnce({ id: 't1', score: 4 });

      const res = await service.vote('r1', 't1', 'u1', { value: 1 });

      expect(prisma.trackVote.delete).toHaveBeenCalledWith({
        where: { trackId_userId: { trackId: 't2', userId: 'u1' } },
      });
      expect(prisma.track.update).toHaveBeenNthCalledWith(1, {
        where: { id: 't2' },
        data: { score: { increment: -1 } },
      });
      expect(res.score).toBe(4);
      expect(realtime.emitToRoom).toHaveBeenCalledWith('r1', 'track:voted', {
        trackId: 't2',
        score: 2,
      });
      expect(realtime.emitToRoom).toHaveBeenCalledWith('r1', 'track:voted', {
        trackId: 't1',
        score: 4,
      });
    });

    it('does not move a vote off the track that is already playing', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        currentTrackId: 't2',
      });
      prisma.trackVote.findMany.mockResolvedValueOnce([
        { trackId: 't2', value: 1, userId: 'u1', roomId: 'r1' },
      ]);

      await expect(service.vote('r1', 't1', 'u1', { value: 1 })).rejects.toThrow(
        'already playing',
      );
      expect(prisma.trackVote.delete).not.toHaveBeenCalled();
      expect(prisma.track.update).not.toHaveBeenCalled();
    });

    it('track:voted broadcast does NOT leak the voter identity', async () => {
      prisma.trackVote.findUnique.mockResolvedValue(null);
      prisma.track.update.mockResolvedValue({ id: 't1', score: 1 });

      await service.vote('r1', 't1', 'u1', { value: 1 });

      const call = realtime.emitToRoom.mock.calls.find(
        (c: unknown[]) => c[1] === 'track:voted',
      );
      expect(call).toBeDefined();
      const payload = call![2] as Record<string, unknown>;
      expect(payload).not.toHaveProperty('userId');
      expect(payload).not.toHaveProperty('value');
    });

    it('rejects a negative vote', async () => {
      await expect(
        service.vote('r1', 't1', 'u1', { value: -1 }),
      ).rejects.toThrow(BadRequestException);
      expect(prisma.$transaction).not.toHaveBeenCalled();
    });

    it('rejects a vote once the track has started', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        currentTrackId: 't1',
      });

      await expect(
        service.vote('r1', 't1', 'u1', { value: 1 }),
      ).rejects.toThrow(BadRequestException);
      expect(prisma.trackVote.create).not.toHaveBeenCalled();
    });

    it('correcting a stored -1 to +1 applies a delta of +2', async () => {
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

    it('lets any authenticated user vote in a PUBLIC room (no membership)', async () => {
      prisma.roomMember.findUnique.mockResolvedValue(null);
      prisma.trackVote.findUnique.mockResolvedValue(null);
      prisma.track.update.mockResolvedValue({ id: 't1', score: 1 });

      const res = await service.vote('r1', 't1', 'stranger', { value: 1 });
      expect(res.score).toBe(1);
    });

    it('rejects voting in a PRIVATE room for a non-member', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        visibility: 'PRIVATE',
      });
      prisma.roomMember.findUnique.mockResolvedValue(null);
      await expect(
        service.vote('r1', 't1', 'stranger', { value: 1 }),
      ).rejects.toThrow(NotFoundException);
    });

    it('rejects a non-invited user when voteAccess=INVITED_ONLY', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        voteAccess: 'INVITED_ONLY',
      });
      prisma.roomInvitation.findFirst.mockResolvedValue(null);
      await expect(
        service.vote('r1', 't1', 'stranger', { value: 1 }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('allows an invited user to vote when voteAccess=INVITED_ONLY', async () => {
      prisma.room.findUnique.mockResolvedValue({
        ...baseRoom,
        voteAccess: 'INVITED_ONLY',
      });
      prisma.roomInvitation.findFirst.mockResolvedValue({ id: 'inv-1' });
      prisma.trackVote.findUnique.mockResolvedValue(null);
      prisma.track.update.mockResolvedValue({ id: 't1', score: 1 });

      const res = await service.vote('r1', 't1', 'invited-user', { value: 1 });
      expect(res.score).toBe(1);
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
      expect(list[0].myVote).toBe(0);
    });

    it("attaches the caller's vote so a reload can restore it", async () => {
      prisma.room.findUnique.mockResolvedValue(baseRoom);
      prisma.track.findMany.mockResolvedValue([{ id: 't1', score: 2 }]);
      prisma.trackVote.findMany.mockResolvedValue([
        { trackId: 't1', value: 1 },
      ]);

      const list = await service.listRanked('r1', 'u1');

      expect(list[0].myVote).toBe(1);
      expect(prisma.trackVote.findMany).toHaveBeenCalledWith({
        where: { roomId: 'r1', userId: 'u1' },
        select: { trackId: true, value: true },
      });
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
