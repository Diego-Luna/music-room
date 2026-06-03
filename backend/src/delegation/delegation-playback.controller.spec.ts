import { Test, TestingModule } from '@nestjs/testing';
import { DelegationPlaybackController } from './delegation-playback.controller';
import { DelegationPlaybackService } from './delegation-playback.service';

describe('DelegationPlaybackController', () => {
  let controller: DelegationPlaybackController;
  let playback: Partial<DelegationPlaybackService>;

  const user = { sub: 'friend-1', email: 'f@example.com' };
  const delegationId = 'del-1';

  beforeEach(async () => {
    playback = {
      play: vi.fn().mockResolvedValue({ ok: true }),
      pause: vi.fn().mockResolvedValue({ ok: true }),
      next: vi.fn().mockResolvedValue({ ok: true }),
      previous: vi.fn().mockResolvedValue({ ok: true }),
      setVolume: vi.fn().mockResolvedValue({ ok: true }),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [DelegationPlaybackController],
      providers: [
        { provide: DelegationPlaybackService, useValue: playback },
      ],
    }).compile();

    controller = module.get(DelegationPlaybackController);
  });

  it('POST /delegations/:id/playback/play forwards to the service', async () => {
    const dto = { trackId: 'track-9' };
    const res = await controller.play(user, delegationId, dto);
    expect(res).toEqual({ ok: true });
    expect(playback.play).toHaveBeenCalledWith(delegationId, 'friend-1', dto);
  });

  it('POST /delegations/:id/playback/pause forwards to the service', async () => {
    await controller.pause(user, delegationId);
    expect(playback.pause).toHaveBeenCalledWith(delegationId, 'friend-1');
  });

  it('POST /delegations/:id/playback/next forwards to the service', async () => {
    await controller.next(user, delegationId);
    expect(playback.next).toHaveBeenCalledWith(delegationId, 'friend-1');
  });

  it('POST /delegations/:id/playback/previous forwards to the service', async () => {
    await controller.previous(user, delegationId);
    expect(playback.previous).toHaveBeenCalledWith(delegationId, 'friend-1');
  });

  it('PUT /delegations/:id/playback/volume forwards the percent', async () => {
    await controller.volume(user, delegationId, { percent: 42 });
    expect(playback.setVolume).toHaveBeenCalledWith(
      delegationId,
      'friend-1',
      42,
    );
  });
});
