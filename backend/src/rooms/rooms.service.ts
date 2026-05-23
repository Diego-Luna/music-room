import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';
import { SubscriptionService } from '../subscription/subscription.service';
import { CreateRoomDto, RoomKind, VoteWindow } from './dto/create-room.dto';
import { UpdateRoomDto } from './dto/update-room.dto';

const EDIT_ROLES = new Set(['OWNER', 'ADMIN']);

@Injectable()
export class RoomsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly subscription: SubscriptionService,
    @Optional() private readonly realtime?: RealtimeService,
  ) {}

  async create(userId: string, dto: CreateRoomDto) {
    this.validateVoteSettings(dto);
    this.validateLocationSettings(dto);
    await this.requirePlaylistEntitlement(userId, dto.kind);

    return this.prisma.$transaction(async (tx) => {
      const room = await tx.room.create({
        data: {
          name: dto.name,
          description: dto.description,
          kind: dto.kind,
          visibility: dto.visibility ?? 'PUBLIC',
          ownerId: userId,
          editAccess: dto.editAccess ?? 'EVERYONE',
          voteAccess: dto.voteAccess ?? 'EVERYONE',
          voteWindow: dto.voteWindow ?? 'ALWAYS',
          voteStartsAt: dto.voteStartsAt ? new Date(dto.voteStartsAt) : null,
          voteEndsAt: dto.voteEndsAt ? new Date(dto.voteEndsAt) : null,
          voteLocationLat: dto.voteLocationLat ?? null,
          voteLocationLng: dto.voteLocationLng ?? null,
          voteLocationRadiusM: dto.voteLocationRadiusM ?? null,
        },
      });
      await tx.roomMember.create({
        data: { roomId: room.id, userId, role: 'OWNER' },
      });
      return room;
    });
  }

  async findOne(roomId: string, userId: string) {
    const room = await this.prisma.room.findUnique({ where: { id: roomId } });
    if (!room) throw new NotFoundException('Room not found');

    if (room.visibility === 'PRIVATE') {
      const isOwner = room.ownerId === userId;
      const member = isOwner
        ? null
        : await this.prisma.roomMember.findUnique({
            where: { roomId_userId: { roomId, userId } },
          });
      if (!isOwner && !member) {
        throw new NotFoundException('Room not found');
      }
    }
    return room;
  }

  async list(userId: string) {
    return this.prisma.room.findMany({
      where: {
        OR: [
          { visibility: 'PUBLIC' },
          { ownerId: userId },
          { members: { some: { userId } } },
        ],
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async update(roomId: string, userId: string, dto: UpdateRoomDto) {
    const room = await this.requireEditableRoom(roomId, userId);

    this.validateVoteSettings({ ...room, ...dto } as CreateRoomDto);
    this.validateLocationSettings({ ...room, ...dto } as CreateRoomDto);

    const goingPrivate =
      room.visibility === 'PUBLIC' && dto.visibility === 'PRIVATE';

    const updated = await this.prisma.room.update({
      where: { id: roomId },
      data: {
        name: dto.name,
        description: dto.description,
        visibility: dto.visibility,
        editAccess: dto.editAccess,
        voteAccess: dto.voteAccess,
        voteWindow: dto.voteWindow,
        voteStartsAt: dto.voteStartsAt
          ? new Date(dto.voteStartsAt)
          : undefined,
        voteEndsAt: dto.voteEndsAt ? new Date(dto.voteEndsAt) : undefined,
        voteLocationLat: dto.voteLocationLat,
        voteLocationLng: dto.voteLocationLng,
        voteLocationRadiusM: dto.voteLocationRadiusM,
      },
    });

    if (goingPrivate) {
      await this.evictNonInvitedMembers(
        roomId,
        updated.name,
        room.ownerId,
      );
    }
    return updated;
  }

  /**
   * When a room flips PUBLIC → PRIVATE, members who joined freely (without
   * an invitation) lose their place: a private room may only contain
   * invited users (V.2.1/V.2.3 — "only invited users can access"). They
   * are removed and notified; the owner and invited users are kept.
   */
  private async evictNonInvitedMembers(
    roomId: string,
    roomName: string,
    ownerId: string,
  ): Promise<void> {
    const invitations = await this.prisma.roomInvitation.findMany({
      where: { roomId, status: { in: ['PENDING', 'ACCEPTED'] } },
      select: { inviteeId: true },
    });
    const allowed = new Set(invitations.map((i) => i.inviteeId));
    allowed.add(ownerId);

    const members = await this.prisma.roomMember.findMany({
      where: { roomId },
      select: { userId: true },
    });
    const toEvict = members
      .map((m) => m.userId)
      .filter((id) => !allowed.has(id));
    if (toEvict.length === 0) return;

    await this.prisma.roomMember.deleteMany({
      where: { roomId, userId: { in: toEvict } },
    });
    for (const userId of toEvict) {
      this.realtime?.emitToUser(userId, 'room:kicked', { roomId, roomName });
    }
  }

  async remove(roomId: string, userId: string) {
    const room = await this.prisma.room.findUnique({ where: { id: roomId } });
    if (!room) throw new NotFoundException('Room not found');
    if (room.ownerId !== userId) {
      throw new ForbiddenException('Only the owner can delete this room');
    }
    await this.prisma.room.delete({ where: { id: roomId } });
  }

  private async requireEditableRoom(roomId: string, userId: string) {
    const room = await this.prisma.room.findUnique({ where: { id: roomId } });
    if (!room) throw new NotFoundException('Room not found');

    if (room.ownerId === userId) return room;

    const member = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId, userId } },
    });

    if (!member) {
      // Don't leak existence of a private room to non-members
      if (room.visibility === 'PRIVATE') {
        throw new NotFoundException('Room not found');
      }
      throw new ForbiddenException('You are not a member of this room');
    }

    if (!EDIT_ROLES.has(member.role)) {
      throw new ForbiddenException('Insufficient role for this action');
    }
    return room;
  }

  // VI.3 — the Music Playlist Editor is a premium feature: only PREMIUM
  // accounts may create (host) playlist rooms. Free accounts keep VOTE
  // rooms and delegation. Editing playlist items is gated the same way in
  // PlaylistService. Downgrading never deletes existing playlist rooms.
  private async requirePlaylistEntitlement(
    userId: string,
    kind: RoomKind,
  ): Promise<void> {
    if (kind === RoomKind.PLAYLIST) {
      await this.subscription.assertPremium(userId);
    }
  }

  private validateVoteSettings(dto: Partial<CreateRoomDto>) {
    if (dto.voteWindow !== VoteWindow.SCHEDULED) return;
    if (!dto.voteStartsAt || !dto.voteEndsAt) {
      throw new BadRequestException(
        'voteStartsAt and voteEndsAt are required for SCHEDULED windows',
      );
    }
    const start = new Date(dto.voteStartsAt).getTime();
    const end = new Date(dto.voteEndsAt).getTime();
    if (!(end > start)) {
      throw new BadRequestException('voteEndsAt must be after voteStartsAt');
    }
  }

  private validateLocationSettings(dto: Partial<CreateRoomDto>) {
    const fields = [
      dto.voteLocationLat,
      dto.voteLocationLng,
      dto.voteLocationRadiusM,
    ];
    const provided = fields.filter((v) => v !== undefined && v !== null).length;
    if (provided !== 0 && provided !== 3) {
      throw new BadRequestException(
        'voteLocation requires lat, lng and radius together',
      );
    }
  }
}
