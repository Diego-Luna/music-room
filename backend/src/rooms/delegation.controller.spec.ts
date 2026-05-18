import { Test, TestingModule } from '@nestjs/testing';
import { DelegationController } from './delegation.controller';
import { DelegationService } from './delegation.service';
import { PlaybackService } from './playback.service';

describe('DelegationController', () => {
  let controller: DelegationController;
  let delegation: Partial<DelegationService>;
  let playback: Partial<PlaybackService>;

  const user = { sub: 'user-1', email: 'u@example.com' };
  const roomId = 'room-1';

  beforeEach(async () => {
    delegation = {
      grant: vi.fn().mockResolvedValue({ delegateId: 'user-2' }),
      revoke: vi.fn().mockResolvedValue({ delegateId: null }),
      getCurrent: vi.fn().mockResolvedValue({ delegateId: 'user-2' }),
    };
    playback = {
      play: vi.fn().mockResolvedValue({ ok: true }),
      pause: vi.fn().mockResolvedValue({ ok: true }),
      next: vi.fn().mockResolvedValue({ ok: true }),
      previous: vi.fn().mockResolvedValue({ ok: true }),
      setVolume: vi.fn().mockResolvedValue({ ok: true }),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [DelegationController],
      providers: [
        { provide: DelegationService, useValue: delegation },
        { provide: PlaybackService, useValue: playback },
      ],
    }).compile();

    controller = module.get(DelegationController);
  });

  it('POST /rooms/:id/delegate grants DJ control', async () => {
    const res = await controller.grant(user, roomId, { userId: 'user-2' } as any);
    expect(res).toEqual({ delegateId: 'user-2' });
    expect(delegation.grant).toHaveBeenCalledWith(roomId, 'user-1', 'user-2');
  });

  it('DELETE /rooms/:id/delegate revokes DJ control', async () => {
    const res = await controller.revoke(user, roomId);
    expect(res).toEqual({ delegateId: null });
    expect(delegation.revoke).toHaveBeenCalledWith(roomId, 'user-1');
  });

  it('GET /rooms/:id/delegate returns current DJ', async () => {
    const res = await controller.current(user, roomId);
    expect(res).toEqual({ delegateId: 'user-2' });
    expect(delegation.getCurrent).toHaveBeenCalledWith(roomId, 'user-1');
  });

  it('POST /rooms/:id/playback/play starts playback', async () => {
    const dto = { deviceId: 'dev-1' } as any;
    await controller.play(user, roomId, dto);
    expect(playback.play).toHaveBeenCalledWith(roomId, 'user-1', dto);
  });

  it('POST /rooms/:id/playback/pause pauses playback', async () => {
    await controller.pause(user, roomId);
    expect(playback.pause).toHaveBeenCalledWith(roomId, 'user-1');
  });

  it('POST /rooms/:id/playback/next skips forward', async () => {
    await controller.next(user, roomId);
    expect(playback.next).toHaveBeenCalledWith(roomId, 'user-1');
  });

  it('POST /rooms/:id/playback/previous skips backward', async () => {
    await controller.previous(user, roomId);
    expect(playback.previous).toHaveBeenCalledWith(roomId, 'user-1');
  });

  it('PUT /rooms/:id/playback/volume sets volume', async () => {
    await controller.volume(user, roomId, { percent: 70 } as any);
    expect(playback.setVolume).toHaveBeenCalledWith(roomId, 'user-1', 70);
  });
});
