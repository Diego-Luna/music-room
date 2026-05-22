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
import { PushService } from '../notifications/push.service';
import {
  InviteMemberDto,
  MemberRole,
  UpdateMemberRoleDto,
} from './dto/invite-member.dto';

const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days
const ADMIN_ROLES = new Set(['OWNER', 'ADMIN']);

@Injectable()
export class RoomMembershipService {
  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly realtime?: RealtimeService,
    @Optional() private readonly push?: PushService,
  ) {}

  private emit(roomId: string, event: string, payload: unknown) {
    this.realtime?.emitToRoom(roomId, event, payload);
  }
  private emitUser(userId: string, event: string, payload: unknown) {
    this.realtime?.emitToUser(userId, event, payload);
  }

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

    const member = await this.prisma.roomMember.create({
      data: { roomId, userId, role: 'MEMBER' },
    });
    this.emit(roomId, 'member:joined', { roomId, userId, role: 'MEMBER' });
    return member;
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
    this.emit(roomId, 'member:left', { roomId, userId });
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

    const invitation = await this.prisma.roomInvitation.create({
      data: {
        roomId,
        inviterId,
        inviteeId: dto.userId,
        status: 'PENDING',
        expiresAt: new Date(Date.now() + INVITE_TTL_MS),
      },
    });
    this.emitUser(dto.userId, 'invitation:new', {
      invitationId: invitation.id,
      roomId,
      roomName: room.name,
      inviterId,
    });
    void this.push?.sendToUser(dto.userId, {
      title: 'New room invitation',
      body: `You were invited to join ${room.name}`,
      data: {
        type: 'invitation:new',
        roomId,
        roomName: room.name,
        invitationId: invitation.id,
      },
    });
    return invitation;
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

    const updated = await this.prisma.roomMember.update({
      where: { roomId_userId: { roomId, userId: targetUserId } },
      data: { role: dto.role },
    });
    this.emit(roomId, 'member:role-changed', {
      roomId,
      userId: targetUserId,
      role: dto.role,
    });
    return updated;
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
    // Kick is anonymous — neither the room broadcast nor the targeted
    // user's toast reveals the acting admin's identity (privacy).
    this.emit(roomId, 'member:removed', {
      roomId,
      userId: targetUserId,
    });
    this.emitUser(targetUserId, 'room:kicked', {
      roomId,
      roomName: room.name,
    });
  }

  // ── invitations management (both sides) ─────────────────────────
  async listMyInvitations(userId: string) {
    return this.prisma.roomInvitation.findMany({
      where: {
        inviteeId: userId,
        status: 'PENDING',
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
      include: {
        room: {
          select: { id: true, name: true, kind: true, visibility: true },
        },
        inviter: {
          select: { id: true, displayName: true, avatarUrl: true },
        },
      },
    });
  }

  async listSentInvitations(userId: string) {
    return this.prisma.roomInvitation.findMany({
      where: {
        inviterId: userId,
        status: 'PENDING',
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
      include: {
        room: {
          select: { id: true, name: true, kind: true, visibility: true },
        },
        invitee: {
          select: { id: true, displayName: true, avatarUrl: true },
        },
      },
    });
  }

  async acceptInvitation(userId: string, invitationId: string) {
    const invitation = await this.requireOwnPendingInvitation(
      userId,
      invitationId,
    );
    if (invitation.expiresAt <= new Date()) {
      throw new BadRequestException('Invitation has expired');
    }
    // Reuse join(): it flips the matching PENDING invite to ACCEPTED,
    // creates the membership and emits member:joined. No duplication.
    await this.join(invitation.roomId, userId);
    return { message: 'Joined', roomId: invitation.roomId };
  }

  async declineInvitation(userId: string, invitationId: string) {
    const invitation = await this.requireOwnPendingInvitation(
      userId,
      invitationId,
    );
    const updated = await this.prisma.roomInvitation.update({
      where: { id: invitationId },
      data: { status: 'DECLINED', respondedAt: new Date() },
    });
    this.emitUser(invitation.inviterId, 'invitation:declined', {
      invitationId,
      roomId: invitation.roomId,
      inviteeId: userId,
    });
    return updated;
  }

  async revokeInvitation(actingUserId: string, invitationId: string) {
    const invitation = await this.prisma.roomInvitation.findUnique({
      where: { id: invitationId },
      include: { room: { select: { name: true } } },
    });
    if (!invitation) throw new NotFoundException('Invitation not found');
    if (invitation.status !== 'PENDING') {
      throw new ConflictException('Invitation is no longer pending');
    }
    // The original inviter can always revoke their own invite.
    // Any current owner/admin of the room can also revoke (symmetric
    // with the create-side authorization in `invite()`).
    if (invitation.inviterId !== actingUserId) {
      const room = await this.requireRoom(invitation.roomId);
      await this.requireAdmin(invitation.roomId, room, actingUserId);
    }
    const updated = await this.prisma.roomInvitation.update({
      where: { id: invitationId },
      data: { status: 'REVOKED', respondedAt: new Date() },
    });
    // Toast payload: only the contextual info the invitee needs.
    // The acting admin's identity is intentionally NOT leaked (privacy).
    this.emitUser(invitation.inviteeId, 'invitation:revoked', {
      invitationId,
      roomId: invitation.roomId,
      roomName: invitation.room.name,
    });
    return updated;
  }

  private async requireOwnPendingInvitation(
    userId: string,
    invitationId: string,
  ) {
    const invitation = await this.prisma.roomInvitation.findUnique({
      where: { id: invitationId },
    });
    if (!invitation || invitation.inviteeId !== userId) {
      throw new NotFoundException('Invitation not found');
    }
    if (invitation.status !== 'PENDING') {
      throw new ConflictException('Invitation is no longer pending');
    }
    return invitation;
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
