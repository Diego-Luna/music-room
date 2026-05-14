import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateRoomDto, VoteWindow } from './dto/create-room.dto';
import { UpdateRoomDto } from './dto/update-room.dto';

const EDIT_ROLES = new Set(['OWNER', 'ADMIN']);

@Injectable()
export class RoomsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, dto: CreateRoomDto) {
    this.validateVoteSettings(dto);
    this.validateLocationSettings(dto);

    return this.prisma.$transaction(async (tx) => {
      const room = await tx.room.create({
        data: {
          name: dto.name,
          description: dto.description,
          kind: dto.kind,
          visibility: dto.visibility ?? 'PUBLIC',
          ownerId: userId,
          allowMembersEdit: dto.allowMembersEdit ?? true,
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

    return this.prisma.room.update({
      where: { id: roomId },
      data: {
        name: dto.name,
        description: dto.description,
        visibility: dto.visibility,
        allowMembersEdit: dto.allowMembersEdit,
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
