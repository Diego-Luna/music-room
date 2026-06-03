import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { DelegationPlaybackService } from './delegation-playback.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';

describe('DelegationPlaybackService', () => {
  let service: DelegationPlaybackService;
  let prisma: {
    musicControlDelegation: { findUnique: ReturnType<typeof vi.fn> };
  };
  let realtime: { emitToUser: ReturnType<typeof vi.fn> };

  const delegation = {
    id: 'del-1',
    ownerId: 'owner-1',
    deviceId: 'device-A',
    delegateUserId: 'friend-1',
  };

  beforeEach(async () => {
    prisma = { musicControlDelegation: { findUnique: vi.fn() } };
    realtime = { emitToUser: vi.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DelegationPlaybackService,
        { provide: PrismaService, useValue: prisma },
        { provide: RealtimeService, useValue: realtime },
      ],
    }).compile();

    service = module.get(DelegationPlaybackService);
  });

  it('throws 404 when the delegation does not exist', async () => {
    prisma.musicControlDelegation.findUnique.mockResolvedValue(null);
    await expect(service.play('del-x', 'user-1', {})).rejects.toThrow(
      NotFoundException,
    );
    expect(realtime.emitToUser).not.toHaveBeenCalled();
  });

  it('throws 403 when the caller is neither owner nor delegate', async () => {
    prisma.musicControlDelegation.findUnique.mockResolvedValue(delegation);
    await expect(service.play('del-1', 'stranger', {})).rejects.toThrow(
      ForbiddenException,
    );
    expect(realtime.emitToUser).not.toHaveBeenCalled();
  });

  it('relays a delegate play command to the owner player', async () => {
    prisma.musicControlDelegation.findUnique.mockResolvedValue(delegation);

    await service.play('del-1', 'friend-1', { trackId: 'track-9' });

    expect(realtime.emitToUser).toHaveBeenCalledWith('owner-1', 'playback:command', {
      delegationId: 'del-1',
      deviceId: 'device-A',
      action: 'play',
      by: 'friend-1',
      trackId: 'track-9',
    });
  });

  it('lets the owner drive playback on their own device', async () => {
    prisma.musicControlDelegation.findUnique.mockResolvedValue(delegation);

    await service.pause('del-1', 'owner-1');

    expect(realtime.emitToUser).toHaveBeenCalledWith('owner-1', 'playback:command', {
      delegationId: 'del-1',
      deviceId: 'device-A',
      action: 'pause',
      by: 'owner-1',
    });
  });

  it('relays next/previous/volume to the owner', async () => {
    prisma.musicControlDelegation.findUnique.mockResolvedValue(delegation);

    await service.next('del-1', 'friend-1');
    await service.previous('del-1', 'friend-1');
    await service.setVolume('del-1', 'friend-1', 50);

    const calls = realtime.emitToUser.mock.calls.map(
      (c) => (c[2] as { action: string; percent?: number }),
    );
    expect(calls[0].action).toBe('next');
    expect(calls[1].action).toBe('previous');
    expect(calls[2]).toMatchObject({ action: 'volume', percent: 50 });
  });
});
