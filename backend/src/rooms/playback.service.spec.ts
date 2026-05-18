import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { PlaybackService } from './playback.service';
import { DelegationService } from './delegation.service';
import { SpotifyService } from '../spotify/spotify.service';
import { RealtimeService } from '../realtime/realtime.service';

type Fn = ReturnType<typeof vi.fn>;

describe('PlaybackService', () => {
  let service: PlaybackService;
  let delegation: {
    requireDelegateOrOwner: Fn;
  };
  let spotify: {
    play: Fn;
    pause: Fn;
    next: Fn;
    previous: Fn;
    setVolume: Fn;
  };
  let realtime: { emitToRoom: Fn; emitToUser: Fn };

  beforeEach(async () => {
    delegation = { requireDelegateOrOwner: vi.fn() };
    spotify = {
      play: vi.fn(),
      pause: vi.fn(),
      next: vi.fn(),
      previous: vi.fn(),
      setVolume: vi.fn(),
    };
    realtime = { emitToRoom: vi.fn(), emitToUser: vi.fn() };
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PlaybackService,
        { provide: DelegationService, useValue: delegation },
        { provide: SpotifyService, useValue: spotify },
        { provide: RealtimeService, useValue: realtime },
      ],
    }).compile();
    service = module.get(PlaybackService);
  });

  it('proxies play to the delegate account', async () => {
    delegation.requireDelegateOrOwner.mockResolvedValue({
      id: 'r1',
      ownerId: 'owner',
      delegateUserId: 'dj',
    });
    await service.play('r1', 'owner', { uris: ['spotify:track:x'] });
    expect(spotify.play).toHaveBeenCalledWith('dj', ['spotify:track:x'], undefined);
    expect(realtime.emitToRoom).toHaveBeenCalledWith(
      'r1',
      'playback:played',
      expect.objectContaining({ roomId: 'r1', byUserId: 'owner' }),
    );
  });

  it('falls back to the owner when no delegate is set', async () => {
    delegation.requireDelegateOrOwner.mockResolvedValue({
      id: 'r1',
      ownerId: 'owner',
      delegateUserId: null,
    });
    await service.pause('r1', 'owner');
    expect(spotify.pause).toHaveBeenCalledWith('owner');
  });

  it('rejects when caller is neither owner nor delegate', async () => {
    delegation.requireDelegateOrOwner.mockRejectedValue(
      new ForbiddenException('Not the DJ for this room'),
    );
    await expect(service.pause('r1', 'stranger')).rejects.toThrow(
      ForbiddenException,
    );
  });

  it('next broadcasts direction=next', async () => {
    delegation.requireDelegateOrOwner.mockResolvedValue({
      id: 'r1',
      ownerId: 'owner',
      delegateUserId: 'dj',
    });
    await service.next('r1', 'dj');
    expect(realtime.emitToRoom).toHaveBeenCalledWith(
      'r1',
      'playback:skipped',
      expect.objectContaining({ direction: 'next' }),
    );
  });

  it('previous broadcasts direction=previous', async () => {
    delegation.requireDelegateOrOwner.mockResolvedValue({
      id: 'r1',
      ownerId: 'owner',
      delegateUserId: 'dj',
    });
    await service.previous('r1', 'dj');
    expect(realtime.emitToRoom).toHaveBeenCalledWith(
      'r1',
      'playback:skipped',
      expect.objectContaining({ direction: 'previous' }),
    );
  });

  it('setVolume clamps to 0-100 and broadcasts', async () => {
    delegation.requireDelegateOrOwner.mockResolvedValue({
      id: 'r1',
      ownerId: 'owner',
      delegateUserId: 'dj',
    });
    await service.setVolume('r1', 'dj', 50);
    expect(spotify.setVolume).toHaveBeenCalledWith('dj', 50);
  });

  it('setVolume rejects out-of-range values', async () => {
    await expect(service.setVolume('r1', 'dj', 120)).rejects.toThrow(
      BadRequestException,
    );
    await expect(service.setVolume('r1', 'dj', -1)).rejects.toThrow(
      BadRequestException,
    );
  });
});
