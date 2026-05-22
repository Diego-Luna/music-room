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

export type FriendshipStatus =
  | 'PENDING'
  | 'ACCEPTED'
  | 'DECLINED'
  | 'CANCELED';

export interface FriendshipView {
  id: string;
  requesterId: string;
  addresseeId: string;
  status: FriendshipStatus;
  createdAt: Date;
  respondedAt: Date | null;
}

@Injectable()
export class FriendsService {
  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly realtime?: RealtimeService,
    @Optional() private readonly push?: PushService,
  ) {}

  async request(
    requesterId: string,
    targetUserId: string,
  ): Promise<FriendshipView> {
    if (requesterId === targetUserId) {
      throw new BadRequestException('Cannot send a friend request to yourself');
    }
    const target = await this.prisma.user.findUnique({
      where: { id: targetUserId },
    });
    if (!target) throw new NotFoundException('User not found');

    // Reuse an existing pair (in either direction) instead of creating a duplicate
    const existing = await this.prisma.friendship.findFirst({
      where: {
        OR: [
          { requesterId, addresseeId: targetUserId },
          { requesterId: targetUserId, addresseeId: requesterId },
        ],
      },
    });
    if (existing) {
      if (existing.status === 'ACCEPTED') {
        throw new ConflictException('Already friends');
      }
      if (existing.status === 'PENDING') {
        throw new ConflictException('A friend request is already pending');
      }
      // DECLINED or CANCELED → re-open as a fresh PENDING from the requester
      const reopened = await this.prisma.friendship.update({
        where: { id: existing.id },
        data: {
          requesterId,
          addresseeId: targetUserId,
          status: 'PENDING',
          respondedAt: null,
        },
      });
      this.notifyNewRequest(targetUserId, reopened.id, requesterId);
      return reopened as unknown as FriendshipView;
    }
    const created = await this.prisma.friendship.create({
      data: { requesterId, addresseeId: targetUserId, status: 'PENDING' },
    });
    this.notifyNewRequest(targetUserId, created.id, requesterId);
    return created as unknown as FriendshipView;
  }

  private notifyNewRequest(
    addresseeId: string,
    friendshipId: string,
    requesterId: string,
  ) {
    this.realtime?.emitToUser(addresseeId, 'friend:request:new', {
      friendshipId,
      requesterId,
    });
    void this.push?.sendToUser(addresseeId, {
      title: 'New friend request',
      body: 'Someone wants to be your friend',
      data: { type: 'friend:request:new', friendshipId, requesterId },
    });
  }

  async accept(addresseeId: string, friendshipId: string) {
    const f = await this.requireFriendship(friendshipId);
    if (f.addresseeId !== addresseeId) {
      throw new ForbiddenException(
        'Only the addressee can accept this request',
      );
    }
    if (f.status !== 'PENDING') {
      throw new BadRequestException(`Friendship is ${f.status}, not PENDING`);
    }
    const updated = await this.prisma.friendship.update({
      where: { id: friendshipId },
      data: { status: 'ACCEPTED', respondedAt: new Date() },
    });
    this.realtime?.emitToUser(f.requesterId, 'friend:request:accepted', {
      friendshipId,
      addresseeId,
    });
    return updated;
  }

  async decline(addresseeId: string, friendshipId: string) {
    const f = await this.requireFriendship(friendshipId);
    if (f.addresseeId !== addresseeId) {
      throw new ForbiddenException(
        'Only the addressee can decline this request',
      );
    }
    if (f.status !== 'PENDING') {
      throw new BadRequestException(`Friendship is ${f.status}, not PENDING`);
    }
    const updated = await this.prisma.friendship.update({
      where: { id: friendshipId },
      data: { status: 'DECLINED', respondedAt: new Date() },
    });
    this.realtime?.emitToUser(f.requesterId, 'friend:request:declined', {
      friendshipId,
      addresseeId,
    });
    return updated;
  }

  async cancel(userId: string, friendshipId: string) {
    const f = await this.requireFriendship(friendshipId);
    const isRequester = f.requesterId === userId;
    const isAddressee = f.addresseeId === userId;
    if (!isRequester && !isAddressee) {
      throw new ForbiddenException('Not your friendship');
    }
    if (f.status === 'ACCEPTED') {
      // unfriend → fully delete
      await this.prisma.friendship.delete({ where: { id: friendshipId } });
      const otherUserId = isRequester ? f.addresseeId : f.requesterId;
      this.realtime?.emitToUser(otherUserId, 'friend:removed', {
        friendshipId,
        byUserId: userId,
      });
      return { id: friendshipId, removed: true };
    }
    if (f.status === 'PENDING' && isRequester) {
      const updated = await this.prisma.friendship.update({
        where: { id: friendshipId },
        data: { status: 'CANCELED', respondedAt: new Date() },
      });
      this.realtime?.emitToUser(f.addresseeId, 'friend:request:canceled', {
        friendshipId,
        requesterId: userId,
      });
      return updated;
    }
    throw new BadRequestException(
      `Cannot cancel a friendship in state ${f.status}`,
    );
  }

  async listAccepted(userId: string) {
    const rows = await this.prisma.friendship.findMany({
      where: {
        status: 'ACCEPTED',
        OR: [{ requesterId: userId }, { addresseeId: userId }],
      },
      orderBy: { respondedAt: 'desc' },
    });
    return rows.map((f) => ({
      friendshipId: f.id,
      friendId: f.requesterId === userId ? f.addresseeId : f.requesterId,
      since: f.respondedAt,
    }));
  }

  async listIncoming(userId: string) {
    return this.prisma.friendship.findMany({
      where: { addresseeId: userId, status: 'PENDING' },
      orderBy: { createdAt: 'desc' },
    });
  }

  async listOutgoing(userId: string) {
    return this.prisma.friendship.findMany({
      where: { requesterId: userId, status: 'PENDING' },
      orderBy: { createdAt: 'desc' },
    });
  }

  async areFriends(userIdA: string, userIdB: string): Promise<boolean> {
    if (userIdA === userIdB) return true;
    const f = await this.prisma.friendship.findFirst({
      where: {
        status: 'ACCEPTED',
        OR: [
          { requesterId: userIdA, addresseeId: userIdB },
          { requesterId: userIdB, addresseeId: userIdA },
        ],
      },
      select: { id: true },
    });
    return f !== null;
  }

  private async requireFriendship(id: string) {
    const f = await this.prisma.friendship.findUnique({ where: { id } });
    if (!f) throw new NotFoundException('Friendship not found');
    return f;
  }
}
