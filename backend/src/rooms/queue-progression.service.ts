import { randomUUID } from 'node:crypto';
import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';
import { RedisService } from '../redis/redis.service';

const TICK_MS = 1000;
const TICK_LOCK_KEY = 'queue:progression:tick';
const TICK_LOCK_TTL_S = 10;

type RoomWithCurrent = {
  id: string;
  currentTrackId: string | null;
  currentTrackStartedAt: Date | null;
  currentTrack: { id: string; durationMs: number } | null;
};

/**
 * Drives VOTE-room playback. A VOTE room has no DJ: the queue advances on its
 * own. When the current track's duration elapses, the highest-voted pending
 * track becomes current. Idle rooms with a pending queue start automatically.
 *
 * Durability comes from the DB (`Room.currentTrackStartedAt`), so progression
 * survives restarts. The Redis lock only ensures a single instance ticks when
 * the backend is scaled horizontally; it fails open if Redis is unavailable.
 */
@Injectable()
export class QueueProgressionService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(QueueProgressionService.name);
  private readonly instanceId = randomUUID();
  private timer?: ReturnType<typeof setInterval>;
  private running = false;

  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly realtime?: RealtimeService,
    @Optional() private readonly redis?: RedisService,
  ) {}

  onModuleInit(): void {
    if (process.env.NODE_ENV === 'test') return;
    this.timer = setInterval(() => void this.tick(), TICK_MS);
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  async tick(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      if (!(await this.acquireTickLock())) return;
      const rooms = (await this.prisma.room.findMany({
        where: { kind: 'VOTE' },
        select: {
          id: true,
          currentTrackId: true,
          currentTrackStartedAt: true,
          currentTrack: { select: { id: true, durationMs: true } },
        },
      })) as RoomWithCurrent[];

      const now = Date.now();
      for (const room of rooms) {
        if (
          room.currentTrack &&
          room.currentTrackStartedAt &&
          now >=
            room.currentTrackStartedAt.getTime() +
              room.currentTrack.durationMs
        ) {
          await this.advance(room.id, room.currentTrack.id);
        } else if (!room.currentTrackId) {
          await this.startIdle(room.id);
        }
      }
    } catch (err) {
      this.logger.warn(`progression tick failed: ${(err as Error).message}`);
    } finally {
      await this.releaseTickLock();
      this.running = false;
    }
  }

  /** Current track finished → mark it played, promote the next one. */
  async advance(roomId: string, finishedTrackId: string): Promise<void> {
    const next = await this.pickNext(roomId, finishedTrackId);

    const advanced = await this.prisma.$transaction(async (tx) => {
      // Conditional swap: only this caller wins if currentTrackId is unchanged.
      const claimed = await tx.room.updateMany({
        where: { id: roomId, currentTrackId: finishedTrackId },
        data: {
          currentTrackId: next?.id ?? null,
          currentTrackStartedAt: next ? new Date() : null,
        },
      });
      if (claimed.count === 0) return false;
      await tx.track.update({
        where: { id: finishedTrackId },
        data: { playedAt: new Date() },
      });
      return true;
    });

    if (advanced) {
      this.realtime?.emitToRoom(roomId, 'track:nowPlaying', {
        roomId,
        track: next ?? null,
      });
    }
  }

  /** No current track but a queue exists → start the top of the queue. */
  async startIdle(roomId: string): Promise<void> {
    const next = await this.pickNext(roomId);
    if (!next) return;

    const started = await this.prisma.room.updateMany({
      where: { id: roomId, currentTrackId: null },
      data: { currentTrackId: next.id, currentTrackStartedAt: new Date() },
    });
    if (started.count > 0) {
      this.realtime?.emitToRoom(roomId, 'track:nowPlaying', {
        roomId,
        track: next,
      });
    }
  }

  private pickNext(roomId: string, excludeTrackId?: string) {
    return this.prisma.track.findFirst({
      where: {
        roomId,
        playedAt: null,
        ...(excludeTrackId ? { id: { not: excludeTrackId } } : {}),
      },
      orderBy: [{ score: 'desc' }, { addedAt: 'asc' }],
    });
  }

  private async acquireTickLock(): Promise<boolean> {
    if (!this.redis) return true;
    try {
      const res = await this.redis
        .getClient()
        .set(TICK_LOCK_KEY, this.instanceId, 'EX', TICK_LOCK_TTL_S, 'NX');
      return res === 'OK';
    } catch {
      return true; // Redis down → single-instance fallback, keep ticking.
    }
  }

  private async releaseTickLock(): Promise<void> {
    if (!this.redis) return;
    try {
      await this.redis.del(TICK_LOCK_KEY);
    } catch {
      /* lock will expire via TTL */
    }
  }
}
