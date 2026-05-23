import { Test, TestingModule } from '@nestjs/testing';
import { QueueProgressionService } from './queue-progression.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';

describe('QueueProgressionService', () => {
  let service: QueueProgressionService;
  let prisma: Record<string, Record<string, ReturnType<typeof vi.fn>>> & {
    $transaction: ReturnType<typeof vi.fn>;
  };
  let realtime: { emitToRoom: ReturnType<typeof vi.fn> };
  let tx: {
    room: { updateMany: ReturnType<typeof vi.fn> };
    track: { update: ReturnType<typeof vi.fn> };
  };

  beforeEach(async () => {
    tx = {
      room: { updateMany: vi.fn() },
      track: { update: vi.fn() },
    };
    prisma = {
      room: { findMany: vi.fn(), updateMany: vi.fn() },
      track: { findFirst: vi.fn(), update: vi.fn() },
      $transaction: vi.fn((cb: (t: typeof tx) => unknown) => cb(tx)),
    };
    realtime = { emitToRoom: vi.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        QueueProgressionService,
        { provide: PrismaService, useValue: prisma },
        { provide: RealtimeService, useValue: realtime },
      ],
    }).compile();

    service = module.get(QueueProgressionService);
  });

  describe('advance', () => {
    it('promotes the next track, marks the finished one played, broadcasts', async () => {
      prisma.track.findFirst.mockResolvedValue({
        id: 'track-2',
        durationMs: 200_000,
      });
      tx.room.updateMany.mockResolvedValue({ count: 1 });

      await service.advance('room-1', 'track-1');

      expect(tx.room.updateMany).toHaveBeenCalledWith({
        where: { id: 'room-1', currentTrackId: 'track-1' },
        data: {
          currentTrackId: 'track-2',
          currentTrackStartedAt: expect.any(Date),
        },
      });
      expect(tx.track.update).toHaveBeenCalledWith({
        where: { id: 'track-1' },
        data: { playedAt: expect.any(Date) },
      });
      expect(realtime.emitToRoom).toHaveBeenCalledWith(
        'room-1',
        'track:nowPlaying',
        { roomId: 'room-1', track: { id: 'track-2', durationMs: 200_000 } },
      );
    });

    it('clears the current track when the queue is empty', async () => {
      prisma.track.findFirst.mockResolvedValue(null);
      tx.room.updateMany.mockResolvedValue({ count: 1 });

      await service.advance('room-1', 'track-1');

      expect(tx.room.updateMany).toHaveBeenCalledWith({
        where: { id: 'room-1', currentTrackId: 'track-1' },
        data: { currentTrackId: null, currentTrackStartedAt: null },
      });
      expect(realtime.emitToRoom).toHaveBeenCalledWith(
        'room-1',
        'track:nowPlaying',
        { roomId: 'room-1', track: null },
      );
    });

    it('does not broadcast when the conditional claim is lost', async () => {
      prisma.track.findFirst.mockResolvedValue({
        id: 'track-2',
        durationMs: 1000,
      });
      tx.room.updateMany.mockResolvedValue({ count: 0 });

      await service.advance('room-1', 'track-1');

      expect(tx.track.update).not.toHaveBeenCalled();
      expect(realtime.emitToRoom).not.toHaveBeenCalled();
    });
  });

  describe('startIdle', () => {
    it('promotes the top track for an idle room', async () => {
      prisma.track.findFirst.mockResolvedValue({
        id: 'track-1',
        durationMs: 1000,
      });
      prisma.room.updateMany.mockResolvedValue({ count: 1 });

      await service.startIdle('room-1');

      expect(prisma.room.updateMany).toHaveBeenCalledWith({
        where: { id: 'room-1', currentTrackId: null },
        data: {
          currentTrackId: 'track-1',
          currentTrackStartedAt: expect.any(Date),
        },
      });
      expect(realtime.emitToRoom).toHaveBeenCalledWith(
        'room-1',
        'track:nowPlaying',
        { roomId: 'room-1', track: { id: 'track-1', durationMs: 1000 } },
      );
    });

    it('is a no-op when the queue is empty', async () => {
      prisma.track.findFirst.mockResolvedValue(null);

      await service.startIdle('room-1');

      expect(prisma.room.updateMany).not.toHaveBeenCalled();
      expect(realtime.emitToRoom).not.toHaveBeenCalled();
    });
  });

  describe('tick', () => {
    it('advances a room whose current track has elapsed', async () => {
      prisma.room.findMany.mockResolvedValue([
        {
          id: 'room-1',
          currentTrackId: 'track-1',
          currentTrackStartedAt: new Date(Date.now() - 10_000),
          currentTrack: { id: 'track-1', durationMs: 5000 },
        },
      ]);
      prisma.track.findFirst.mockResolvedValue({
        id: 'track-2',
        durationMs: 3000,
      });
      tx.room.updateMany.mockResolvedValue({ count: 1 });

      await service.tick();

      expect(prisma.$transaction).toHaveBeenCalled();
    });

    it('leaves a room alone while its track is still playing', async () => {
      prisma.room.findMany.mockResolvedValue([
        {
          id: 'room-1',
          currentTrackId: 'track-1',
          currentTrackStartedAt: new Date(Date.now() - 1000),
          currentTrack: { id: 'track-1', durationMs: 200_000 },
        },
      ]);

      await service.tick();

      expect(prisma.$transaction).not.toHaveBeenCalled();
      expect(realtime.emitToRoom).not.toHaveBeenCalled();
    });

    it('starts an idle room that has a pending queue', async () => {
      prisma.room.findMany.mockResolvedValue([
        {
          id: 'room-1',
          currentTrackId: null,
          currentTrackStartedAt: null,
          currentTrack: null,
        },
      ]);
      prisma.track.findFirst.mockResolvedValue({
        id: 'track-1',
        durationMs: 3000,
      });
      prisma.room.updateMany.mockResolvedValue({ count: 1 });

      await service.tick();

      expect(prisma.room.updateMany).toHaveBeenCalledWith({
        where: { id: 'room-1', currentTrackId: null },
        data: {
          currentTrackId: 'track-1',
          currentTrackStartedAt: expect.any(Date),
        },
      });
    });
  });
});
