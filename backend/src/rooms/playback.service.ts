import { BadRequestException, Injectable, Optional } from '@nestjs/common';
import { DelegationService } from './delegation.service';
import { SpotifyService } from '../spotify/spotify.service';
import { RealtimeService } from '../realtime/realtime.service';

export interface PlayDto {
  uris?: string[];
  contextUri?: string;
}

@Injectable()
export class PlaybackService {
  constructor(
    private readonly delegation: DelegationService,
    private readonly spotify: SpotifyService,
    @Optional() private readonly realtime?: RealtimeService,
  ) {}

  async play(roomId: string, userId: string, dto: PlayDto) {
    const { djId } = await this.requireDj(roomId, userId);
    await this.spotify.play(djId, dto.uris, dto.contextUri);
    this.realtime?.emitToRoom(roomId, 'playback:played', {
      roomId,
      byUserId: userId,
      uris: dto.uris ?? null,
    });
    return { ok: true };
  }

  async pause(roomId: string, userId: string) {
    const { djId } = await this.requireDj(roomId, userId);
    await this.spotify.pause(djId);
    this.realtime?.emitToRoom(roomId, 'playback:paused', {
      roomId,
      byUserId: userId,
    });
    return { ok: true };
  }

  async next(roomId: string, userId: string) {
    const { djId } = await this.requireDj(roomId, userId);
    await this.spotify.next(djId);
    this.realtime?.emitToRoom(roomId, 'playback:skipped', {
      roomId,
      byUserId: userId,
      direction: 'next',
    });
    return { ok: true };
  }

  async previous(roomId: string, userId: string) {
    const { djId } = await this.requireDj(roomId, userId);
    await this.spotify.previous(djId);
    this.realtime?.emitToRoom(roomId, 'playback:skipped', {
      roomId,
      byUserId: userId,
      direction: 'previous',
    });
    return { ok: true };
  }

  async setVolume(roomId: string, userId: string, percent: number) {
    if (!Number.isFinite(percent) || percent < 0 || percent > 100) {
      throw new BadRequestException('percent must be between 0 and 100');
    }
    const { djId } = await this.requireDj(roomId, userId);
    await this.spotify.setVolume(djId, percent);
    this.realtime?.emitToRoom(roomId, 'playback:volume-changed', {
      roomId,
      byUserId: userId,
      percent,
    });
    return { ok: true };
  }

  private async requireDj(roomId: string, userId: string) {
    const room = await this.delegation.requireDelegateOrOwner(roomId, userId);
    const djId = room.delegateUserId ?? room.ownerId;
    return { djId };
  }
}
