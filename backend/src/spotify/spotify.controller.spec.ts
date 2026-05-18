import { Test, TestingModule } from '@nestjs/testing';
import { SpotifyController } from './spotify.controller';
import { SpotifyService } from './spotify.service';

describe('SpotifyController', () => {
  let controller: SpotifyController;
  let spotify: Partial<SpotifyService>;

  const user = { sub: 'user-1', email: 'u@example.com' };
  const expiresAt = new Date('2026-06-01T00:00:00Z');

  beforeEach(async () => {
    spotify = {
      buildAuthorizeUrl: vi
        .fn()
        .mockReturnValue({ url: 'https://accounts.spotify.com/authorize?...', state: 'st-1' }),
      exchangeCode: vi.fn().mockResolvedValue({ expiresAt }),
      getStatus: vi.fn().mockResolvedValue({ connected: true }),
      disconnect: vi.fn().mockResolvedValue(undefined),
      search: vi.fn().mockResolvedValue([{ id: 'sp-1', name: 'Test' }]),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [SpotifyController],
      providers: [{ provide: SpotifyService, useValue: spotify }],
    }).compile();

    controller = module.get(SpotifyController);
  });

  it('GET /auth/spotify/authorize-url returns URL + state', () => {
    const res = controller.authorizeUrl();
    expect(res).toEqual({
      url: 'https://accounts.spotify.com/authorize?...',
      state: 'st-1',
    });
    expect(spotify.buildAuthorizeUrl).toHaveBeenCalled();
  });

  it('POST /auth/spotify/callback exchanges the auth code', async () => {
    const res = await controller.callback(user, { code: 'c1', state: 's1' } as any);
    expect(res).toEqual({ connected: true, expiresAt });
    expect(spotify.exchangeCode).toHaveBeenCalledWith('user-1', 'c1');
  });

  it('GET /auth/spotify/status reports connection status', async () => {
    const res = await controller.status(user);
    expect(res).toEqual({ connected: true });
    expect(spotify.getStatus).toHaveBeenCalledWith('user-1');
  });

  it('DELETE /auth/spotify disconnects Spotify', async () => {
    const res = await controller.disconnect(user);
    expect(res).toEqual({ disconnected: true });
    expect(spotify.disconnect).toHaveBeenCalledWith('user-1');
  });

  it('GET /auth/spotify/search uses default limit 10', async () => {
    await controller.search(user, 'queen');
    expect(spotify.search).toHaveBeenCalledWith('user-1', 'queen', 10);
  });

  it('GET /auth/spotify/search clamps limit between 1 and 50', async () => {
    await controller.search(user, 'queen', '999');
    expect(spotify.search).toHaveBeenCalledWith('user-1', 'queen', 50);

    await controller.search(user, 'queen', '-3');
    expect(spotify.search).toHaveBeenCalledWith('user-1', 'queen', 1);
  });

  it('GET /auth/spotify/search falls back to 10 on non-numeric limit', async () => {
    await controller.search(user, 'queen', 'abc');
    expect(spotify.search).toHaveBeenCalledWith('user-1', 'queen', 10);
  });
});
