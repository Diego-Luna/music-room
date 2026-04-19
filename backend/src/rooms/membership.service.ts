import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  InviteMemberDto,
  MemberRole,
  UpdateMemberRoleDto,
} from './dto/invite-member.dto';

const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days
const ADMIN_ROLES = new Set(['OWNER', 'ADMIN']);

@Injectable()
export class RoomMembershipService {
  constructor(private readonly prisma: PrismaService) {}

  async listMembers(roomId: string, userId: string) {
    await this.requireVisibleRoom(roomId, userId);
    return this.prisma.roomMember.findMany({
      where: { roomId },
      orderBy: { joinedAt: 'asc' },
      include: {
        user: { select: { id: true, displayName: true, avatarUrl: true } },
      },
    });
  }

  async join(roomId: string, userId: string) {
    const room = await this.requireRoom(roomId);

    const existing = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId, userId } },
    });
    if (existing) {
      throw new ConflictException('Already a member of this room');
    }

    if (room.visibility === 'PRIVATE' && room.ownerId !== userId) {
      const invite = await this.prisma.roomInvitation.findFirst({
        where: {
          roomId,
          inviteeId: userId,
          status: 'PENDING',
          expiresAt: { gt: new Date() },
        },
      });
      if (!invite) {
        throw new ForbiddenException(
          'This room is private; you need an invitation',
        );
      }
      await this.prisma.roomInvitation.update({
        where: { id: invite.id },
        data: { status: 'ACCEPTED', respondedAt: new Date() },
      });
    }

    return this.prisma.roomMember.create({
      data: { roomId, userId, role: 'MEMBER' },
    });
  }

  async leave(roomId: string, userId: string) {
    const room = await this.requireRoom(roomId);
    if (room.ownerId === userId) {
      throw new BadRequestException(
        'Owner cannot leave; transfer ownership or delete the room',
      );
    }
    const member = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId, userId } },
    });
    if (!member) {
      throw new NotFoundException('You are not a member of this room');
    }
    await this.prisma.roomMember.delete({
      where: { roomId_userId: { roomId, userId } },
    });
  }

  async invite(roomId: string, inviterId: string, dto: InviteMemberDto) {
    const room = await this.requireRoom(roomId);
    await this.requireAdmin(roomId, room, inviterId);

    const invitee = await this.prisma.user.findUnique({
      where: { id: dto.userId },
    });
    if (!invitee) throw new NotFoundException('Invitee not found');

    const alreadyMember = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId, userId: dto.userId } },
    });
    if (alreadyMember) {
      throw new ConflictException('User is already a member');
    }

    return this.prisma.roomInvitation.create({
      data: {
        roomId,
        inviterId,
        inviteeId: dto.userId,
        status: 'PENDING',
        expiresAt: new Date(Date.now() + INVITE_TTL_MS),
      },
    });
  }

  async updateRole(
    roomId: string,
    actingUserId: string,
    targetUserId: string,
    dto: UpdateMemberRoleDto,
  ) {
    const room = await this.requireRoom(roomId);
    if (room.ownerId !== actingUserId) {
      throw new ForbiddenException('Only the owner can change member roles');
    }
    if (targetUserId === room.ownerId) {
      throw new BadRequestException('Cannot change the owner role');
    }

    const target = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId, userId: targetUserId } },
    });
    if (!target) throw new NotFoundException('Member not found');

    return this.prisma.roomMember.update({
      where: { roomId_userId: { roomId, userId: targetUserId } },
      data: { role: dto.role },
    });
  }

  async removeMember(
    roomId: string,
    actingUserId: string,
    targetUserId: string,
  ) {
    const room = await this.requireRoom(roomId);
    if (targetUserId === room.ownerId) {
      throw new BadRequestException('Cannot remove the room owner');
    }
    await this.requireAdmin(roomId, room, actingUserId);

    const target = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId, userId: targetUserId } },
    });
    if (!target) throw new NotFoundException('Member not found');

    await this.prisma.roomMember.delete({
      where: { roomId_userId: { roomId, userId: targetUserId } },
    });
  }

  // ── helpers ─────────────────────────────────────────────────────
  private async requireRoom(roomId: string) {
    const room = await this.prisma.room.findUnique({ where: { id: roomId } });
    if (!room) throw new NotFoundException('Room not found');
    return room;
  }

  private async requireVisibleRoom(roomId: string, userId: string) {
    const room = await this.requireRoom(roomId);
    if (room.visibility === 'PUBLIC' || room.ownerId === userId) return room;
    const member = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId, userId } },
    });
    if (!member) throw new NotFoundException('Room not found');
    return room;
  }

  private async requireAdmin(
    roomId: string,
    room: { ownerId: string },
    userId: string,
  ): Promise<void> {
    if (room.ownerId === userId) return;
    const member = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId, userId } },
    });
    if (!member || !ADMIN_ROLES.has(member.role)) {
      throw new ForbiddenException('Owner or admin role required');
    }
  }
}

export { MemberRole };
