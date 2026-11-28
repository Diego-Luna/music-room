import { randomUUID } from 'node:crypto';
import { ConflictException } from '@nestjs/common';
import { PrismaService } from '@/prisma/prisma.service';
import { TracksService } from '@/rooms/tracks.service';
import { PlaylistService } from '@/rooms/playlist.service';

/**
 * Concurrency against a real PostgreSQL (V.2.1 and V.2.3 "competition
 * problematics"). Row locks, advisory locks and unique constraints only
 * exist in the database, so these run without mocks. CI provides the
 * database; locally, point DATABASE_URL at a disposable one.
 */
describe.skipIf(!process.env.DATABASE_URL)('Concurrency (e2e, real DB)', () => {
  let prisma: PrismaService;
  let tracks: TracksService;
  let playlist: PlaylistService;

  const run = randomUUID().slice(0, 8);
  const ownerId = randomUUID();
  const aliceId = randomUUID();
  const bobId = randomUUID();
  const roomIds: string[] = [];

  const newTrack = (roomId: string, n: number, position?: string) =>
    prisma.track.create({
      data: {
        roomId,
        providerId: `${run}-${n}`,
        title: `Track ${n}`,
        artist: 'Artist',
        durationMs: 180_000,
        addedById: ownerId,
        position: position ?? null,
      },
    });

  const newRoom = async (kind: 'VOTE' | 'PLAYLIST') => {
    const room = await prisma.room.create({
      data: { name: `concurrency-${run}`, kind, ownerId },
    });
    roomIds.push(room.id);
    return room;
  };

  const expectScoresMatchVotes = async (roomId: string) => {
    const rows = await prisma.track.findMany({
      where: { roomId },
      include: { votes: true },
    });
    for (const row of rows) {
      const total = row.votes.reduce((sum, vote) => sum + vote.value, 0);
      expect(row.score).toBe(total);
    }
  };

  beforeAll(async () => {
    prisma = new PrismaService();
    await prisma.$connect();
    tracks = new TracksService(prisma);
    playlist = new PlaylistService(prisma);
    await prisma.user.createMany({
      data: [ownerId, aliceId, bobId].map((id, i) => ({
        id,
        email: `concurrency-${run}-${i}@example.com`,
        displayName: `Concurrency ${i}`,
      })),
    });
  });

  afterAll(async () => {
    await prisma.trackVote.deleteMany({ where: { roomId: { in: roomIds } } });
    await prisma.room.deleteMany({ where: { id: { in: roomIds } } });
    await prisma.user.deleteMany({
      where: { id: { in: [ownerId, aliceId, bobId] } },
    });
    await prisma.$disconnect();
  });

  it('one user voting for two tracks at once keeps a single vote', async () => {
    const room = await newRoom('VOTE');
    const [t1, t2] = await Promise.all([newTrack(room.id, 1), newTrack(room.id, 2)]);

    for (let i = 0; i < 5; i++) {
      await Promise.all([
        tracks.vote(room.id, t1.id, aliceId, { value: 1 }),
        tracks.vote(room.id, t2.id, aliceId, { value: 1 }),
      ]);
      const votes = await prisma.trackVote.count({
        where: { roomId: room.id, userId: aliceId },
      });
      expect(votes).toBe(1);
    }
    await expectScoresMatchVotes(room.id);
  });

  it('two users swapping votes in opposite directions never deadlock', async () => {
    const room = await newRoom('VOTE');
    const [t1, t2] = await Promise.all([newTrack(room.id, 1), newTrack(room.id, 2)]);
    await tracks.vote(room.id, t1.id, aliceId, { value: 1 });
    await tracks.vote(room.id, t2.id, bobId, { value: 1 });

    for (let i = 0; i < 10; i++) {
      const [aliceTo, bobTo] = i % 2 === 0 ? [t2, t1] : [t1, t2];
      const results = await Promise.allSettled([
        tracks.vote(room.id, aliceTo.id, aliceId, { value: 1 }),
        tracks.vote(room.id, bobTo.id, bobId, { value: 1 }),
      ]);
      expect(results.map((r) => r.status)).toEqual(['fulfilled', 'fulfilled']);
    }
    await expectScoresMatchVotes(room.id);
  });

  it('many users voting for the same track count every vote once', async () => {
    const room = await newRoom('VOTE');
    const t1 = await newTrack(room.id, 1);

    await Promise.all(
      [ownerId, aliceId, bobId].map((userId) =>
        tracks.vote(room.id, t1.id, userId, { value: 1 }),
      ),
    );

    const fresh = await prisma.track.findUniqueOrThrow({ where: { id: t1.id } });
    expect(fresh.score).toBe(3);
  });

  it('two users suggesting the same track at once get one track and one 409', async () => {
    const room = await newRoom('VOTE');
    const dto = {
      providerId: `${run}-same`,
      title: 'Same',
      artist: 'Artist',
      durationMs: 180_000,
    };

    const results = await Promise.allSettled([
      tracks.addTrack(room.id, aliceId, dto),
      tracks.addTrack(room.id, bobId, dto),
    ]);

    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    const rejected = results.find((r) => r.status === 'rejected');
    expect((rejected as PromiseRejectedResult).reason).toBeInstanceOf(
      ConflictException,
    );
    expect(await prisma.track.count({ where: { roomId: room.id } })).toBe(1);
  });

  it('two users moving tracks into the same gap keep distinct positions', async () => {
    const room = await newRoom('PLAYLIST');
    const a = await newTrack(room.id, 1, 'a0');
    const b = await newTrack(room.id, 2, 'a1');
    const c = await newTrack(room.id, 3, 'a2');
    const d = await newTrack(room.id, 4, 'a3');

    await Promise.all([
      playlist.moveItem(room.id, c.id, aliceId, { afterTrackId: a.id }),
      playlist.moveItem(room.id, d.id, bobId, { afterTrackId: a.id }),
    ]);

    const rows = await prisma.track.findMany({ where: { roomId: room.id } });
    const positions = rows.map((row) => row.position);
    expect(new Set(positions).size).toBe(rows.length);
    expect(rows.find((row) => row.id === b.id)?.position).toBe('a1');
  });
});
