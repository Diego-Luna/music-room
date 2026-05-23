import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { DelegationPlaybackService } from './delegation-playback.service';
import { PrismaService } from '../prisma/prisma.service';
import { SpotifyService } from '../spotify/spotify.service';

describe('DelegationPlaybackService', () => {
  let service: DelegationPlaybackService;
  let prisma: {
    musicControlDelegation: { findUnique: ReturnType<typeof vi.fn> };
  };
  let spotify: Record<string, ReturnType<typeof vi.fn>>;

  const delegation = {
    id: 'del-1',
    ownerId: 'owner-1',
    deviceId: 'device-A',
    delegateUserId: 'friend-1',
  };

  beforeEach(async () => {
    prisma = { musicControlDelegation: { findUnique: vi.fn() } };
    spotify = {
      play: vi.fn(),
      pause: vi.fn(),
      next: vi.fn(),
      previous: vi.fn(),
      setVolume: vi.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DelegationPlaybackService,
        { provide: PrismaService, useValue: prisma },
        { provide: SpotifyService, useValue: spotify },
      ],
    }).compile();

    service = module.get(DelegationPlaybackService);
  });

  it('throws 404 when the delegation does not exist', async () => {
    prisma.musicControlDelegation.findUnique.mockResolvedValue(null);
    await expect(service.play('del-x', 'user-1', {})).rejects.toThrow(
      NotFoundException,
    );
  });

  it('throws 403 when the caller is neither owner nor delegate', async () => {
    prisma.musicControlDelegation.findUnique.mockResolvedValue(delegation);
    await expect(service.play('del-1', 'stranger', {})).rejects.toThrow(
      ForbiddenException,
    );
  });

  it('lets the delegate drive playback against the owner Spotify token', async () => {
    prisma.musicControlDelegation.findUnique.mockResolvedValue(delegation);

    await service.play('del-1', 'friend-1', { uris: ['spotify:track:x'] });

    expect(spotify.play).toHaveBeenCalledWith(
      'owner-1',
      ['spotify:track:x'],
      undefined,
    );
  });

  it('lets the owner drive playback on their own device', async () => {
    prisma.musicControlDelegation.findUnique.mockResolvedValue(delegation);

    await service.pause('del-1', 'owner-1');

    expect(spotify.pause).toHaveBeenCalledWith('owner-1');
  });

  it('routes next/previous/volume to the owner token', async () => {
    prisma.musicControlDelegation.findUnique.mockResolvedValue(delegation);

    await service.next('del-1', 'friend-1');
    await service.previous('del-1', 'friend-1');
    await service.setVolume('del-1', 'friend-1', 50);

    expect(spotify.next).toHaveBeenCalledWith('owner-1');
    expect(spotify.previous).toHaveBeenCalledWith('owner-1');
    expect(spotify.setVolume).toHaveBeenCalledWith('owner-1', 50);
  });
});
