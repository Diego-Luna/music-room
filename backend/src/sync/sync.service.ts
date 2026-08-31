import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { scrubUser } from '../users/users.service';

// VI.4 — backend support for offline mode. The mobile client owns the
// hard parts (local cache, action queue, UX of "you are offline"); the
// backend provides a single endpoint that returns a snapshot of all
// data relevant to the user, used on reconnect to refresh the cache.
//
// Replay safety: most mutations are naturally idempotent thanks to
// unique constraints — (roomId, provider, providerId) on tracks and
// (trackId, userId) on votes — so re-running a queued offline action is
// safe (a duplicate add returns 409; a re-vote upserts). Non-idempotent
// operations (move, role change) surface conflicts via the existing
// 4xx error codes, which the client must handle.
@Injectable()
export class SyncService {
  constructor(private readonly prisma: PrismaService) {}

  async snapshot(userId: string) {
    const [me, rooms, invitations, friendships] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: userId } }),
      this.prisma.room.findMany({
        where: {
          OR: [{ ownerId: userId }, { members: { some: { userId } } }],
        },
        orderBy: { updatedAt: 'desc' },
      }),
      this.prisma.roomInvitation.findMany({
        where: {
          inviteeId: userId,
          status: 'PENDING',
          expiresAt: { gt: new Date() },
        },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.friendship.findMany({
        where: {
          OR: [
            { requesterId: userId, status: { in: ['PENDING', 'ACCEPTED'] } },
            { addresseeId: userId, status: { in: ['PENDING', 'ACCEPTED'] } },
          ],
        },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    if (!me) throw new NotFoundException('User not found');

    return {
      serverTime: new Date().toISOString(),
      me: scrubUser(me as unknown as Record<string, unknown>),
      rooms,
      invitations,
      friendships,
    };
  }
}
