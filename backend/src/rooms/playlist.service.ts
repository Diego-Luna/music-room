import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { generateKeyBetween } from 'fractional-indexing';
import { isUniqueViolation } from '../prisma/prisma-errors';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';
import { AddPlaylistItemDto, MovePlaylistItemDto } from './dto/playlist.dto';

type Room = {
  id: string;
  kind: string;
  ownerId: string;
  visibility: string;
  editAccess: string;
};

type TrackRow = {
  id: string;
  roomId: string;
  position: string | null;
  addedById: string;
};

type Db = Prisma.TransactionClient;

@Injectable()
export class PlaylistService {
  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly realtime?: RealtimeService,
  ) {}

  async addItem(roomId: string, userId: string, dto: AddPlaylistItemDto) {
    const room = await this.requirePlaylistRoom(roomId);
    await this.requireEditor(room, userId);

    if (dto.afterTrackId && dto.beforeTrackId) {
      throw new BadRequestException(
        'Provide afterTrackId OR beforeTrackId, not both',
      );
    }

    const provider = dto.provider ?? 'deezer';
    let track;
    try {
      track = await this.prisma.$transaction(async (tx) => {
        await this.lockPlaylist(tx, roomId);
        const dup = await tx.track.findUnique({
          where: {
            roomId_provider_providerId: {
              roomId,
              provider,
              providerId: dto.providerId,
            },
          },
        });
        if (dup) throw new ConflictException('Track already in this playlist');

        const position = await this.computePosition(
          tx,
          roomId,
          dto.afterTrackId,
          dto.beforeTrackId,
        );

        return tx.track.create({
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
            position,
          },
        });
      });
    } catch (error) {
      if (isUniqueViolation(error)) {
        throw new ConflictException('Track already in this playlist');
      }
      throw error;
    }
    this.realtime?.emitToRoom(roomId, 'playlist:item-added', track);
    return track;
  }

  async moveItem(
    roomId: string,
    trackId: string,
    userId: string,
    dto: MovePlaylistItemDto,
  ) {
    const room = await this.requirePlaylistRoom(roomId);
    await this.requireEditor(room, userId);

    if (!dto.afterTrackId && !dto.beforeTrackId) {
      throw new BadRequestException(
        'Provide afterTrackId OR beforeTrackId',
      );
    }
    if (dto.afterTrackId && dto.beforeTrackId) {
      throw new BadRequestException(
        'Provide afterTrackId OR beforeTrackId, not both',
      );
    }
    if (dto.afterTrackId === trackId || dto.beforeTrackId === trackId) {
      throw new BadRequestException('Cannot place a track relative to itself');
    }

    // ! Moves on one playlist run one after another: each reads the order
    //   left by the previous one, so two users dropping into the same gap
    //   never get the same position.
    const updated = await this.prisma.$transaction(async (tx) => {
      await this.lockPlaylist(tx, roomId);
      const track = await tx.track.findUnique({
        where: { id: trackId },
      });
      if (!track || track.roomId !== roomId) {
        throw new NotFoundException('Track not found');
      }

      const position = await this.computePosition(
        tx,
        roomId,
        dto.afterTrackId,
        dto.beforeTrackId,
        trackId,
      );

      return tx.track.update({
        where: { id: trackId },
        data: { position },
      });
    });
    this.realtime?.emitToRoom(roomId, 'playlist:item-moved', {
      roomId,
      trackId,
      position: updated.position,
    });
    return updated;
  }

  async removeItem(roomId: string, trackId: string, userId: string) {
    const room = await this.requirePlaylistRoom(roomId);
    await this.requireEditor(room, userId);
    await this.prisma.$transaction(async (tx) => {
      await this.lockPlaylist(tx, roomId);
      const track = await tx.track.findUnique({
        where: { id: trackId },
      });
      if (!track || track.roomId !== roomId) {
        throw new NotFoundException('Track not found');
      }
      await tx.track.delete({ where: { id: trackId } });
    });
    this.realtime?.emitToRoom(roomId, 'playlist:item-removed', { trackId });
  }

  async listOrdered(roomId: string, userId: string) {
    const room = await this.requirePlaylistRoom(roomId);
    await this.requireRoomAccess(room, userId);
    return this.prisma.track.findMany({
      where: { roomId, position: { not: null } },
      orderBy: [{ position: 'asc' }, { addedAt: 'asc' }],
    });
  }

  // ── helpers ─────────────────────────────────────────────────────
  private async lockPlaylist(tx: Db, roomId: string): Promise<void> {
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${roomId}))`;
  }

  private async requirePlaylistRoom(roomId: string): Promise<Room> {
    const room = (await this.prisma.room.findUnique({
      where: { id: roomId },
    })) as Room | null;
    if (!room) throw new NotFoundException('Room not found');
    if (room.kind !== 'PLAYLIST') {
      throw new BadRequestException('Room is not a PLAYLIST room');
    }
    return room;
  }

  // PUBLIC room → reachable by any authenticated user; PRIVATE → owner or
  // member, else 404 (do not leak the room's existence).
  private async requireRoomAccess(room: Room, userId: string): Promise<void> {
    if (room.visibility === 'PUBLIC') return;
    if (room.ownerId === userId) return;
    const member = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId: room.id, userId } },
    });
    if (!member) throw new NotFoundException('Room not found');
  }

  // V.2.3 edit license: EVERYONE → anyone with room access may edit;
  // INVITED_ONLY → only the owner and users the owner invited.
  private async requireEditor(room: Room, userId: string): Promise<void> {
    await this.requireRoomAccess(room, userId);
    if (room.editAccess === 'EVERYONE') return;
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
        'Only invited users can edit this playlist',
      );
    }
  }

  private async computePosition(
    db: Db,
    roomId: string,
    afterTrackId?: string,
    beforeTrackId?: string,
    excludeTrackId?: string,
  ): Promise<string> {
    const findPosition = async (id?: string): Promise<string | null> => {
      if (!id) return null;
      const row = (await db.track.findUnique({
        where: { id },
      })) as TrackRow | null;
      if (!row || row.roomId !== roomId || !row.position) {
        throw new NotFoundException('Anchor track not found in playlist');
      }
      return row.position;
    };

    let after = await findPosition(afterTrackId);
    let before = await findPosition(beforeTrackId);
    const excludeFilter = excludeTrackId ? { id: { not: excludeTrackId } } : {};

    if (!after && !before) {
      const last = (await db.track.findFirst({
        where: { roomId, position: { not: null }, ...excludeFilter },
        orderBy: { position: 'desc' },
      })) as TrackRow | null;
      after = last?.position ?? null;
    } else if (after && !before) {
      // * Find the immediate successor so inserting after a middle track lands
      //   strictly between `after` and the next track instead of colliding.
      const next = (await db.track.findFirst({
        where: { roomId, position: { gt: after }, ...excludeFilter },
        orderBy: { position: 'asc' },
      })) as TrackRow | null;
      before = next?.position ?? null;
    } else if (before && !after) {
      // * Find the immediate predecessor so inserting before a middle track
      //   lands strictly between the previous track and `before`.
      const prev = (await db.track.findFirst({
        where: { roomId, position: { lt: before }, ...excludeFilter },
        orderBy: { position: 'desc' },
      })) as TrackRow | null;
      after = prev?.position ?? null;
    }

    return generateKeyBetween(after, before);
  }
}
