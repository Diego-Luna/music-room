import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { generateKeyBetween } from 'fractional-indexing';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';
import { AddPlaylistItemDto, MovePlaylistItemDto } from './dto/playlist.dto';

type Room = {
  id: string;
  kind: string;
  ownerId: string;
  visibility: string;
  allowMembersEdit: boolean;
};

type TrackRow = {
  id: string;
  roomId: string;
  position: string | null;
  addedById: string;
};

const EDIT_ROLES = new Set(['OWNER', 'ADMIN']);

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

    const provider = dto.provider ?? 'spotify';
    const dup = await this.prisma.track.findUnique({
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
      roomId,
      dto.afterTrackId,
      dto.beforeTrackId,
    );

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
        position,
      },
    });
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

    const track = await this.prisma.track.findUnique({
      where: { id: trackId },
    });
    if (!track || track.roomId !== roomId) {
      throw new NotFoundException('Track not found');
    }

    const position = await this.computePosition(
      roomId,
      dto.afterTrackId,
      dto.beforeTrackId,
    );

    const updated = await this.prisma.track.update({
      where: { id: trackId },
      data: { position },
    });
    this.realtime?.emitToRoom(roomId, 'playlist:item-moved', {
      trackId,
      position,
    });
    return updated;
  }

  async removeItem(roomId: string, trackId: string, userId: string) {
    const room = await this.requirePlaylistRoom(roomId);
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
    this.realtime?.emitToRoom(roomId, 'playlist:item-removed', { trackId });
  }

  async listOrdered(roomId: string, userId: string) {
    const room = await this.requirePlaylistRoom(roomId);
    if (room.visibility === 'PRIVATE' && room.ownerId !== userId) {
      const member = await this.prisma.roomMember.findUnique({
        where: { roomId_userId: { roomId, userId } },
      });
      if (!member) throw new NotFoundException('Room not found');
    }
    return this.prisma.track.findMany({
      where: { roomId, position: { not: null } },
      orderBy: [{ position: 'asc' }, { addedAt: 'asc' }],
    });
  }

  // ── helpers ─────────────────────────────────────────────────────
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

  private async requireEditor(room: Room, userId: string) {
    if (room.ownerId === userId) return;
    const member = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId: room.id, userId } },
    });
    if (!member) throw new ForbiddenException('Not a member of this room');
    if (room.allowMembersEdit) return;
    if (!EDIT_ROLES.has(member.role)) {
      throw new ForbiddenException('Only the owner or an admin can edit');
    }
  }

  private async computePosition(
    roomId: string,
    afterTrackId?: string,
    beforeTrackId?: string,
  ): Promise<string> {
    const findPosition = async (id?: string): Promise<string | null> => {
      if (!id) return null;
      const row = (await this.prisma.track.findUnique({
        where: { id },
      })) as TrackRow | null;
      if (!row || row.roomId !== roomId || !row.position) {
        throw new NotFoundException('Anchor track not found in playlist');
      }
      return row.position;
    };

    let after = await findPosition(afterTrackId);
    let before = await findPosition(beforeTrackId);

    if (!after && !before) {
      const last = (await this.prisma.track.findFirst({
        where: { roomId, position: { not: null } },
        orderBy: { position: 'desc' },
      })) as TrackRow | null;
      after = last?.position ?? null;
    }

    return generateKeyBetween(after, before);
  }
}
