import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { FriendsService } from '../users/friends.service';
import { RealtimeService } from '../realtime/realtime.service';
import { PushService } from '../notifications/push.service';

const USER_PROJECTION = {
  select: { id: true, displayName: true, avatarUrl: true },
};

@Injectable()
export class DelegationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly friends: FriendsService,
    @Optional() private readonly realtime?: RealtimeService,
    @Optional() private readonly push?: PushService,
  ) {}

  async grant(ownerId: string, deviceId: string, delegateUserId: string) {
    if (delegateUserId === ownerId) {
      throw new BadRequestException('Cannot delegate control to yourself');
    }
    const delegate = await this.prisma.user.findUnique({
      where: { id: delegateUserId },
    });
    if (!delegate) throw new NotFoundException('Delegate user not found');

    const areFriends = await this.friends.areFriends(ownerId, delegateUserId);
    if (!areFriends) {
      throw new ForbiddenException(
        'You can only delegate control to a friend',
      );
    }

    const previous = await this.prisma.musicControlDelegation.findUnique({
      where: { ownerId_deviceId: { ownerId, deviceId } },
    });

    const delegation = await this.prisma.musicControlDelegation.upsert({
      where: { ownerId_deviceId: { ownerId, deviceId } },
      update: { delegateUserId, grantedAt: new Date() },
      create: { ownerId, deviceId, delegateUserId },
    });

    // Control moved away from a different delegate → tell the old one.
    if (previous && previous.delegateUserId !== delegateUserId) {
      this.realtime?.emitToUser(
        previous.delegateUserId,
        'device:delegation:revoked',
        { deviceId, ownerId },
      );
    }

    // ownerId is intentionally included: granting is a mutual friend
    // interaction, and the delegate must know whose device they control.
    this.realtime?.emitToUser(delegateUserId, 'device:delegation:granted', {
      deviceId,
      ownerId,
    });
    void this.push?.sendToUser(delegateUserId, {
      title: 'Music control granted',
      body: 'A friend gave you control of one of their devices',
      data: { type: 'device:delegation:granted', deviceId, ownerId },
    });
    return delegation;
  }

  async revoke(ownerId: string, deviceId: string) {
    const existing = await this.prisma.musicControlDelegation.findUnique({
      where: { ownerId_deviceId: { ownerId, deviceId } },
    });
    if (!existing) {
      throw new NotFoundException('No delegation for this device');
    }
    await this.prisma.musicControlDelegation.delete({
      where: { ownerId_deviceId: { ownerId, deviceId } },
    });
    this.realtime?.emitToUser(
      existing.delegateUserId,
      'device:delegation:revoked',
      { deviceId, ownerId },
    );
    return { revoked: true };
  }

  async listControlledDevices(delegateUserId: string) {
    return this.prisma.musicControlDelegation.findMany({
      where: { delegateUserId },
      orderBy: { grantedAt: 'desc' },
      include: { owner: USER_PROJECTION },
    });
  }

  /**
   * Lists the devices attached to the account — derived from the user's
   * active sessions (`RefreshToken.deviceId`) — each annotated with its
   * current delegation, if any. This is what the owner browses to pick a
   * device to delegate. A device that still has a delegation but no active
   * session is kept in the list so a stale delegation stays visible.
   */
  async listMyDevices(userId: string) {
    const sessions = await this.prisma.refreshToken.findMany({
      where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
      select: { deviceId: true, userAgent: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
    });
    const delegations = await this.prisma.musicControlDelegation.findMany({
      where: { ownerId: userId },
      include: { delegate: USER_PROJECTION },
    });
    const delegationByDevice = new Map(
      delegations.map((d) => [d.deviceId, d]),
    );

    const devices = new Map<
      string,
      { deviceId: string; userAgent: string | null; lastSeenAt: Date | null }
    >();
    for (const s of sessions) {
      if (!s.deviceId || devices.has(s.deviceId)) continue;
      devices.set(s.deviceId, {
        deviceId: s.deviceId,
        userAgent: s.userAgent ?? null,
        lastSeenAt: s.createdAt,
      });
    }
    for (const d of delegations) {
      if (devices.has(d.deviceId)) continue;
      devices.set(d.deviceId, {
        deviceId: d.deviceId,
        userAgent: null,
        lastSeenAt: null,
      });
    }

    return [...devices.values()].map((dev) => ({
      ...dev,
      delegation: delegationByDevice.get(dev.deviceId) ?? null,
    }));
  }
}
