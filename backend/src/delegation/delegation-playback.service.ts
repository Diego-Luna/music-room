import {
  ForbiddenException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';
import { PlayPlaybackDto } from './dto/delegation.dto';

export type PlaybackAction =
  | 'play'
  | 'pause'
  | 'next'
  | 'previous'
  | 'volume';

/**
 * V.2.2 playback control. The caller drives playback on a delegated device.
 * There is no provider playback API to call (Deezer = 30s preview MP3 played
 * in-app), so the command is **relayed over Socket.io to the device owner**:
 * the owner's app plays/pauses/skips its own player. The delegate is a pure
 * remote control. Both the owner and the current delegate may issue commands.
 */
@Injectable()
export class DelegationPlaybackService {
  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly realtime?: RealtimeService,
  ) {}

  async play(delegationId: string, callerId: string, dto: PlayPlaybackDto) {
    return this.command(delegationId, callerId, 'play', {
      trackId: dto.trackId ?? null,
    });
  }

  async pause(delegationId: string, callerId: string) {
    return this.command(delegationId, callerId, 'pause');
  }

  async next(delegationId: string, callerId: string) {
    return this.command(delegationId, callerId, 'next');
  }

  async previous(delegationId: string, callerId: string) {
    return this.command(delegationId, callerId, 'previous');
  }

  async setVolume(delegationId: string, callerId: string, percent: number) {
    return this.command(delegationId, callerId, 'volume', { percent });
  }

  private async command(
    delegationId: string,
    callerId: string,
    action: PlaybackAction,
    extra: Record<string, unknown> = {},
  ) {
    const { ownerId, deviceId } = await this.requireControl(
      delegationId,
      callerId,
    );
    this.realtime?.emitToUser(ownerId, 'playback:command', {
      delegationId,
      deviceId,
      action,
      by: callerId,
      ...extra,
    });
    return { ok: true };
  }

  /** Resolves the controlled device, or throws if the caller may not control it. */
  private async requireControl(
    delegationId: string,
    callerId: string,
  ): Promise<{ ownerId: string; deviceId: string }> {
    const delegation = await this.prisma.musicControlDelegation.findUnique({
      where: { id: delegationId },
    });
    if (!delegation) throw new NotFoundException('Delegation not found');
    if (
      delegation.ownerId !== callerId &&
      delegation.delegateUserId !== callerId
    ) {
      throw new ForbiddenException('You do not control this device');
    }
    return { ownerId: delegation.ownerId, deviceId: delegation.deviceId };
  }
}
