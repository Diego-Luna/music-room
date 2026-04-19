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
  ) {}

  async addTrack(roomId: string, userId: string, dto: AddTrackDto) {
    const room = await this.requireRoom(roomId);
    if (room.kind !== 'VOTE') {
      throw new BadRequestException('Room is not a VOTE room');
    }
    await this.requireMember(roomId, userId);

    const provider = dto.provider ?? 'spotify';
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
        addedById: userId,
      },
    });
    this.realtime?.emitToRoom(roomId, 'track:added', track);
    return track;
  }

  async vote(
    roomId: string,
    trackId: string,
    userId: string,
    dto: VoteTrackDto,
  ) {
    const room = await this.requireRoom(roomId);
    if (room.kind !== 'VOTE') {
      throw new BadRequestException('Room is not a VOTE room');
    }
    await this.requireMember(roomId, userId);
    this.enforceVoteWindow(room);
    this.enforceGeoGate(room, dto);

    const track = await this.prisma.track.findUnique({
      where: { id: trackId },
    });
    if (!track || track.roomId !== roomId) {
      throw new NotFoundException('Track not found');
    }

    const previous = await this.prisma.trackVote.findUnique({
      where: { trackId_userId: { trackId, userId } },
    });
    const oldValue = previous?.value ?? 0;
    const delta = dto.value - oldValue;

    const updated = await this.prisma.$transaction(async (tx) => {
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
      return tx.track.update({
        where: { id: trackId },
        data: { score: { increment: delta } },
      });
    });

    this.realtime?.emitToRoom(roomId, 'track:voted', {
      trackId,
      userId,
      value: dto.value,
      score: updated.score,
    });
    return updated;
  }

  async removeTrack(roomId: string, trackId: string, userId: string) {
    const room = await this.requireRoom(roomId);
    const track = await this.prisma.track.findUnique({
      where: { id: trackId },
    });
    if (!track || track.roomId !== roomId) {
      throw new NotFoundException('Track not found');
    }
    const isOwner = room.ownerId === userId;
    const isAuthor = track.addedById === userId;
    if (!isOwner && !isAuthor) {
      const member = await this.prisma.roomMember.findUnique({
        where: { roomId_userId: { roomId, userId } },
      });
      if (member?.role !== 'ADMIN') {
        throw new ForbiddenException('Not allowed to remove this track');
      }
    }
    await this.prisma.track.delete({ where: { id: trackId } });
    this.realtime?.emitToRoom(roomId, 'track:removed', { trackId });
  }

  async listRanked(roomId: string, userId: string) {
    const room = await this.requireRoom(roomId);
    if (room.visibility === 'PRIVATE' && room.ownerId !== userId) {
      const member = await this.prisma.roomMember.findUnique({
        where: { roomId_userId: { roomId, userId } },
      });
      if (!member) throw new NotFoundException('Room not found');
    }
    return this.prisma.track.findMany({
      where: { roomId, playedAt: null },
      orderBy: [{ score: 'desc' }, { addedAt: 'asc' }],
    });
  }

  // ── helpers ─────────────────────────────────────────────────────
  private async requireRoom(roomId: string): Promise<Room> {
    const room = (await this.prisma.room.findUnique({
      where: { id: roomId },
    })) as Room | null;
    if (!room) throw new NotFoundException('Room not found');
    return room;
  }

  private async requireMember(roomId: string, userId: string) {
    const room = await this.requireRoom(roomId);
    if (room.ownerId === userId) return;
    const member = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId, userId } },
    });
    if (!member) throw new ForbiddenException('Not a member of this room');
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
