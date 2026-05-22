import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SpotifyService } from '../spotify/spotify.service';
import { PlayPlaybackDto } from './dto/delegation.dto';

/**
 * V.2.2 playback control. The caller drives playback on a delegated device;
 * commands always execute against the device **owner's** Spotify token — the
 * delegate is a remote control, not the audio source. Both the owner and the
 * current delegate of a delegation may issue commands.
 */
@Injectable()
export class DelegationPlaybackService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly spotify: SpotifyService,
  ) {}

  async play(delegationId: string, callerId: string, dto: PlayPlaybackDto) {
    const ownerId = await this.requireControl(delegationId, callerId);
    await this.spotify.play(ownerId, dto.uris, dto.contextUri);
    return { ok: true };
  }

  async pause(delegationId: string, callerId: string) {
    const ownerId = await this.requireControl(delegationId, callerId);
    await this.spotify.pause(ownerId);
    return { ok: true };
  }

  async next(delegationId: string, callerId: string) {
    const ownerId = await this.requireControl(delegationId, callerId);
    await this.spotify.next(ownerId);
    return { ok: true };
  }

  async previous(delegationId: string, callerId: string) {
    const ownerId = await this.requireControl(delegationId, callerId);
    await this.spotify.previous(ownerId);
    return { ok: true };
  }

  async setVolume(delegationId: string, callerId: string, percent: number) {
    const ownerId = await this.requireControl(delegationId, callerId);
    await this.spotify.setVolume(ownerId, percent);
    return { ok: true };
  }

  /** Resolves the device owner id, or throws if the caller may not control it. */
  private async requireControl(
    delegationId: string,
    callerId: string,
  ): Promise<string> {
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
    return delegation.ownerId;
  }
}
