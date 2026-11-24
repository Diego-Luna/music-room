import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';
import { AddTrackDto, VoteTrackDto } from './dto/track.dto';
import { QueueProgressionService } from './queue-progression.service';

const EARTH_RADIUS_M = 6_371_000;

function haversineMeters(
  a: { lat: number; lng: number },
  b: { lat: number; lng: number },
): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(h));
}

type Room = {
  id: string;
  kind: string;
  ownerId: string;
  visibility: string;
  voteAccess: string;
  currentTrackId: string | null;
  voteWindow: string;
  voteStartsAt: Date | null;
  voteEndsAt: Date | null;
  voteLocationLat: number | null;
  voteLocationLng: number | null;
  voteLocationRadiusM: number | null;
};

@Injectable()
export class TracksService {
  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly realtime?: RealtimeService,
    @Optional() private readonly queue?: QueueProgressionService,
  ) {}

  async addTrack(roomId: string, userId: string, dto: AddTrackDto) {
    const room = await this.requireRoom(roomId);
    if (room.kind !== 'VOTE') {
      throw new BadRequestException('Room is not a VOTE room');
    }
    await this.requireVoter(room, userId);

    const provider = dto.provider ?? 'deezer';
    const existing = await this.prisma.track.findUnique({
      where: {
        roomId_provider_providerId: {
          roomId,
          provider,
          providerId: dto.providerId,
        },
      },
    });
    if (existing) {
      throw new ConflictException('Track already in the queue');
    }

    const track = await this.prisma.track.create({
      data: {
        roomId,
        provider,
        providerId: dto.providerId,
        title: dto.title,
        artist: dto.artist,
        durationMs: dto.durationMs,
        artworkUrl: dto.artworkUrl ?? null,
        previewUrl: dto.previewUrl ?? null,
        addedById: userId,
      },
    });
    this.realtime?.emitToRoom(roomId, 'track:added', track);
    // A VOTE room has no DJ: if it was idle, the track we just added
    // starts now instead of waiting for the next progression tick.
    if (!room.currentTrackId) {
      await this.queue?.startIdle(roomId);
    }
    return track;
  }

  async vote(
    roomId: string,
    trackId: string,
    userId: string,
    dto: VoteTrackDto,
  ) {
    if (dto.value !== 0 && dto.value !== 1) {
      throw new BadRequestException('Vote must be 1 or 0');
    }

    const room = await this.requireRoom(roomId);
    if (room.kind !== 'VOTE') {
      throw new BadRequestException('Room is not a VOTE room');
    }
    await this.requireVoter(room, userId);
    this.enforceVoteWindow(room);
    this.enforceGeoGate(room, dto);

    const track = await this.prisma.track.findUnique({
      where: { id: trackId },
    });
    if (!track || track.roomId !== roomId) {
      throw new NotFoundException('Track not found');
    }
    if (track.playedAt) {
      throw new BadRequestException('Cannot vote on a played track');
    }
    if (room.currentTrackId === trackId) {
      throw new BadRequestException(
        'Cannot change a vote once the track has started',
      );
    }

    // ! Lock the track, then read the previous vote and update the score in
    //   the same transaction. A second vote from this user waits, sees the
    //   row already written, and applies a zero delta instead of a 500.
    const updated = await this.prisma.$transaction(async (tx) => {
      const locked = await tx.$queryRaw<Array<{ playedAt: Date | null }>>`
        SELECT "playedAt" FROM "Track" WHERE "id" = ${trackId} FOR UPDATE
      `;
      const lockedTrack = locked[0];
      if (!lockedTrack) {
        throw new NotFoundException('Track not found');
      }
      if (lockedTrack.playedAt) {
        throw new BadRequestException('Cannot vote on a played track');
      }
      const playing = await tx.room.findUnique({
        where: { id: roomId },
        select: { currentTrackId: true },
      });
      if (playing?.currentTrackId === trackId) {
        throw new BadRequestException(
          'Cannot change a vote once the track has started',
        );
      }

      // One vote per person. Choosing another track moves the vote.
      const released: Array<{ trackId: string; score: number }> = [];
      if (dto.value === 1) {
        const others = await tx.trackVote.findMany({
          where: { roomId, userId, NOT: { trackId } },
        });
        for (const other of others) {
          if (!other.value) continue;
          await tx.$queryRaw`
            SELECT "id" FROM "Track" WHERE "id" = ${other.trackId} FOR UPDATE
          `;
          const stillPlaying = await tx.room.findUnique({
            where: { id: roomId },
            select: { currentTrackId: true },
          });
          if (stillPlaying?.currentTrackId === other.trackId) {
            throw new BadRequestException(
              'Your vote stays on the track that is already playing',
            );
          }
          await tx.trackVote.delete({
            where: { trackId_userId: { trackId: other.trackId, userId } },
          });
          const cleared = await tx.track.update({
            where: { id: other.trackId },
            data: { score: { increment: -other.value } },
          });
          released.push({ trackId: other.trackId, score: cleared.score });
        }
      }

      const previous = await tx.trackVote.findUnique({
        where: { trackId_userId: { trackId, userId } },
      });
      const oldValue = previous?.value ?? 0;
      const delta = dto.value - oldValue;

      if (dto.value === 0) {
        if (previous) {
          await tx.trackVote.delete({
            where: { trackId_userId: { trackId, userId } },
          });
        }
      } else if (previous) {
        await tx.trackVote.update({
          where: { trackId_userId: { trackId, userId } },
          data: { value: dto.value },
        });
      } else {
        await tx.trackVote.create({
          data: { roomId, trackId, userId, value: dto.value },
        });
      }
      const updated = await tx.track.update({
        where: { id: trackId },
        data: { score: { increment: delta } },
      });
      return { updated, released };
    });

    // Votes are anonymous in the broadcast — only the resulting score is
    // shared. The voter's identity stays server-side (the TrackVote row).
    for (const moved of updated.released) {
      this.realtime?.emitToRoom(roomId, 'track:voted', moved);
    }
    this.realtime?.emitToRoom(roomId, 'track:voted', {
      trackId,
      score: updated.updated.score,
    });
    return updated.updated;
  }

  async listRanked(roomId: string, userId: string) {
    const room = await this.requireRoom(roomId);
    await this.requireRoomAccess(room, userId);
    const tracks = await this.prisma.track.findMany({
      where: { roomId, playedAt: null },
      orderBy: [{ score: 'desc' }, { addedAt: 'asc' }],
    });
    const votes = await this.prisma.trackVote.findMany({
      where: { roomId, userId },
      select: { trackId: true, value: true },
    });
    const mine = new Map(votes.map((vote) => [vote.trackId, vote.value]));
    return tracks.map((track) => ({
      ...track,
      myVote: mine.get(track.id) ?? 0,
    }));
  }

  // ── helpers ─────────────────────────────────────────────────────
  private async requireRoom(roomId: string): Promise<Room> {
    const room = (await this.prisma.room.findUnique({
      where: { id: roomId },
    })) as Room | null;
    if (!room) throw new NotFoundException('Room not found');
    return room;
  }

  // A PUBLIC room is open to any authenticated user — no membership row
  // is required to suggest or vote (the subject: "all the users can find
  // your event and vote if your event is public"). A PRIVATE room is
  // reachable only by its owner or an invited member; otherwise 404, so
  // the room's existence is not leaked.
  private async requireRoomAccess(room: Room, userId: string): Promise<void> {
    if (room.visibility === 'PUBLIC') return;
    if (room.ownerId === userId) return;
    const member = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId: room.id, userId } },
    });
    if (!member) throw new NotFoundException('Room not found');
  }

  // V.2.1 vote license: EVERYONE → anyone with room access may suggest or
  // vote; INVITED_ONLY → only the owner and users the owner invited.
  private async requireVoter(room: Room, userId: string): Promise<void> {
    await this.requireRoomAccess(room, userId);
    if (room.voteAccess === 'EVERYONE') return;
    if (room.ownerId === userId) return;
    const invitation = await this.prisma.roomInvitation.findFirst({
      where: {
        roomId: room.id,
        inviteeId: userId,
        OR: [
          { status: 'ACCEPTED' },
          { status: 'PENDING', expiresAt: { gt: new Date() } },
        ],
      },
    });
    if (!invitation) {
      throw new ForbiddenException(
        'Only invited users can vote in this room',
      );
    }
  }

  private enforceVoteWindow(room: Room) {
    if (room.voteWindow !== 'SCHEDULED') return;
    const now = Date.now();
    if (
      !room.voteStartsAt ||
      !room.voteEndsAt ||
      now < room.voteStartsAt.getTime() ||
      now > room.voteEndsAt.getTime()
    ) {
      throw new ForbiddenException('Voting is closed for this room');
    }
  }

  private enforceGeoGate(room: Room, dto: VoteTrackDto) {
    if (
      room.voteLocationLat == null ||
      room.voteLocationLng == null ||
      room.voteLocationRadiusM == null
    ) {
      return;
    }
    if (dto.lat == null || dto.lng == null) {
      throw new ForbiddenException('Geo-gated room: lat/lng required');
    }
    const d = haversineMeters(
      { lat: room.voteLocationLat, lng: room.voteLocationLng },
      { lat: dto.lat, lng: dto.lng },
    );
    if (d > room.voteLocationRadiusM) {
      throw new ForbiddenException('Out of voting radius');
    }
  }
}
