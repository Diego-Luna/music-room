import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';
import { PushService } from '../notifications/push.service';

type Room = {
  id: string;
  kind: string;
  ownerId: string;
  visibility: string;
  delegateUserId: string | null;
  delegateGrantedAt: Date | null;
};

@Injectable()
export class DelegationService {
  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly realtime?: RealtimeService,
    @Optional() private readonly push?: PushService,
  ) {}

  async grant(roomId: string, ownerId: string, delegateUserId: string) {
    const room = await this.requireDelegateRoom(roomId);
    if (room.ownerId !== ownerId) {
      throw new ForbiddenException('Only the room owner can grant control');
    }
    if (delegateUserId === ownerId) {
      throw new BadRequestException(
        'Owner already has control; grant to a different user',
      );
    }
    const isMember = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId, userId: delegateUserId } },
    });
    if (!isMember) {
      throw new BadRequestException('Delegate must be a room member');
    }
    const connected = await this.prisma.socialAccount.findUnique({
      where: {
        provider_userId: { provider: 'spotify', userId: delegateUserId },
      },
    });
    if (!connected) {
      throw new BadRequestException('Delegate has no Spotify account linked');
    }

    const updated = await this.prisma.room.update({
      where: { id: roomId },
      data: {
        delegateUserId,
        delegateGrantedAt: new Date(),
      },
    });
    this.realtime?.emitToRoom(roomId, 'delegate:granted', {
      roomId,
      delegateUserId,
      grantedById: ownerId,
    });
    this.realtime?.emitToUser(delegateUserId, 'delegate:you-are-dj', {
      roomId,
    });
    void this.push?.sendToUser(delegateUserId, {
      title: "You're the DJ",
      body: 'A room just handed you music control.',
      data: { type: 'delegate:granted', roomId },
    });
    return this.project(updated);
  }

  async revoke(roomId: string, userId: string) {
    const room = await this.requireDelegateRoom(roomId);
    const isOwner = room.ownerId === userId;
    const isSelf = room.delegateUserId === userId;
    if (!isOwner && !isSelf) {
      throw new ForbiddenException(
        'Only the owner or the current delegate can revoke',
      );
    }
    if (!room.delegateUserId) return this.project(room);
    const previous = room.delegateUserId;
    const updated = await this.prisma.room.update({
      where: { id: roomId },
      data: { delegateUserId: null, delegateGrantedAt: null },
    });
    this.realtime?.emitToRoom(roomId, 'delegate:revoked', {
      roomId,
      previousDelegateId: previous,
      revokedById: userId,
    });
    return this.project(updated);
  }

  async getCurrent(roomId: string, userId: string) {
    const room = await this.requireDelegateRoom(roomId);
    await this.requireMember(room, userId);
    return this.project(room);
  }

  async requireDelegateOrOwner(roomId: string, userId: string): Promise<Room> {
    const room = await this.requireDelegateRoom(roomId);
    const isOwner = room.ownerId === userId;
    const isDelegate = room.delegateUserId === userId;
    if (!isOwner && !isDelegate) {
      throw new ForbiddenException('Not the DJ for this room');
    }
    return room;
  }

  private project(room: Room) {
    return {
      roomId: room.id,
      delegateUserId: room.delegateUserId,
      delegateGrantedAt: room.delegateGrantedAt,
    };
  }

  private async requireDelegateRoom(roomId: string): Promise<Room> {
    const room = (await this.prisma.room.findUnique({
      where: { id: roomId },
    })) as Room | null;
    if (!room) throw new NotFoundException('Room not found');
    if (room.kind !== 'DELEGATE') {
      throw new BadRequestException('Room is not a DELEGATE room');
    }
    return room;
  }

  private async requireMember(room: Room, userId: string) {
    if (room.ownerId === userId) return;
    const member = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId: room.id, userId } },
    });
    if (!member) {
      if (room.visibility === 'PRIVATE') {
        throw new NotFoundException('Room not found');
      }
      throw new ForbiddenException('Not a member of this room');
    }
  }
}
