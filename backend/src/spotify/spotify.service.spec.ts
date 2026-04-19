import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import {
  BadRequestException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { SpotifyService, SPOTIFY_PROVIDER } from './spotify.service';
import { PrismaService } from '../prisma/prisma.service';

type Fn = ReturnType<typeof vi.fn>;

describe('SpotifyService', () => {
  let service: SpotifyService;
  let prisma: {
    socialAccount: {
      findUnique: Fn;
      upsert: Fn;
      update: Fn;
      deleteMany: Fn;
    };
  };
  let fetchMock: Fn;

  const env: Record<string, string> = {
    SPOTIFY_CLIENT_ID: 'client-id',
    SPOTIFY_CLIENT_SECRET: 'client-secret',
    SPOTIFY_REDIRECT_URI: 'http://localhost:3000/auth/spotify/callback',
  };

  const jsonResponse = (status: number, body: unknown) =>
    ({
      ok: status >= 200 && status < 300,
      status,
      json: async () => body,
      text: async () => JSON.stringify(body),
    }) as Response;

  beforeEach(async () => {
    prisma = {
      socialAccount: {
        findUnique: vi.fn(),
        upsert: vi.fn(),
        update: vi.fn(),
        deleteMany: vi.fn(),
      },
    };
    fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    const config: Partial<ConfigService> = {
      get: vi.fn((key: string) => env[key]),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SpotifyService,
        { provide: PrismaService, useValue: prisma },
        { provide: ConfigService, useValue: config },
      ],
    }).compile();

    service = module.get(SpotifyService);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  describe('buildAuthorizeUrl', () => {
    it('includes client_id, redirect_uri, scope and state', () => {
      const { url, state } = service.buildAuthorizeUrl('abc');
      expect(url).toContain('client_id=client-id');
      expect(url).toContain(
        'redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fauth%2Fspotify%2Fcallback',
      );
      expect(url).toContain('state=abc');
      expect(url).toContain('response_type=code');
      expect(state).toBe('abc');
    });

    it('generates a random state when none is provided', () => {
      const a = service.buildAuthorizeUrl();
      const b = service.buildAuthorizeUrl();
      expect(a.state).not.toBe(b.state);
      expect(a.state.length).toBeGreaterThanOrEqual(16);
    });
  });

  describe('exchangeCode', () => {
    it('exchanges code, fetches profile, upserts the account', async () => {
      fetchMock
        .mockResolvedValueOnce(
          jsonResponse(200, {
            access_token: 'at',
            refresh_token: 'rt',
            expires_in: 3600,
            scope: 'user-read-email',
          }),
        )
        .mockResolvedValueOnce(
          jsonResponse(200, {
            id: 'spotify-user-1',
            display_name: 'Alice',
            email: 'a@example.com',
          }),
        );

      const tokens = await service.exchangeCode('u1', 'the-code');

      expect(tokens.accessToken).toBe('at');
      expect(tokens.refreshToken).toBe('rt');
      expect(fetchMock).toHaveBeenNthCalledWith(
        1,
        'https://accounts.spotify.com/api/token',
        expect.objectContaining({ method: 'POST' }),
      );
      expect(prisma.socialAccount.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            provider_providerId: {
              provider: SPOTIFY_PROVIDER,
              providerId: 'spotify-user-1',
            },
          },
          create: expect.objectContaining({
            userId: 'u1',
            accessToken: 'at',
            refreshToken: 'rt',
          }),
        }),
      );
    });

    it('raises 400 when Spotify rejects the code', async () => {
      fetchMock.mockResolvedValueOnce(
        jsonResponse(400, { error: 'invalid_grant' }),
      );
      await expect(service.exchangeCode('u1', 'bad')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('sends Authorization: Basic with base64(id:secret)', async () => {
      fetchMock
        .mockResolvedValueOnce(
          jsonResponse(200, {
            access_token: 'at',
            refresh_token: 'rt',
            expires_in: 3600,
          }),
        )
        .mockResolvedValueOnce(
          jsonResponse(200, { id: 'p1', display_name: null, email: null }),
        );

      await service.exchangeCode('u1', 'c');
      const [, init] = fetchMock.mock.calls[0];
      const expected = Buffer.from('client-id:client-secret').toString(
        'base64',
      );
      expect(init.headers.Authorization).toBe(`Basic ${expected}`);
    });
  });

  describe('getAccessTokenForUser', () => {
    it('404 when no social account is connected', async () => {
      prisma.socialAccount.findUnique.mockResolvedValue(null);
      await expect(service.getAccessTokenForUser('u1')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('returns the stored token when still valid', async () => {
      prisma.socialAccount.findUnique.mockResolvedValue({
        id: 'sa1',
        accessToken: 'valid',
        refreshToken: 'r',
        tokenExpiresAt: new Date(Date.now() + 10 * 60 * 1000),
        scope: null,
      });
      const t = await service.getAccessTokenForUser('u1');
      expect(t).toBe('valid');
      expect(fetchMock).not.toHaveBeenCalled();
    });

    it('refreshes when the stored token is near expiry', async () => {
      prisma.socialAccount.findUnique.mockResolvedValue({
        id: 'sa1',
        accessToken: 'stale',
        refreshToken: 'r',
        tokenExpiresAt: new Date(Date.now() - 1000),
        scope: null,
      });
      fetchMock.mockResolvedValueOnce(
        jsonResponse(200, {
          access_token: 'fresh',
          expires_in: 3600,
        }),
      );

      const t = await service.getAccessTokenForUser('u1');
      expect(t).toBe('fresh');
      expect(prisma.socialAccount.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'sa1' },
          data: expect.objectContaining({ accessToken: 'fresh' }),
        }),
      );
    });

    it('rejects refresh when the account has no refresh token', async () => {
      prisma.socialAccount.findUnique.mockResolvedValue({
        id: 'sa1',
        accessToken: 'stale',
        refreshToken: null,
        tokenExpiresAt: new Date(Date.now() - 1000),
        scope: null,
      });
      await expect(service.getAccessTokenForUser('u1')).rejects.toThrow(
        UnauthorizedException,
      );
    });
  });

  describe('search', () => {
    it('calls the search endpoint with a bearer token and maps tracks', async () => {
      prisma.socialAccount.findUnique.mockResolvedValue({
        id: 'sa1',
        accessToken: 'valid',
        refreshToken: null,
        tokenExpiresAt: new Date(Date.now() + 10 * 60 * 1000),
        scope: null,
      });
      fetchMock.mockResolvedValueOnce(
        jsonResponse(200, {
          tracks: {
            items: [
              {
                id: 'spot-1',
                name: 'Song',
                artists: [{ name: 'Alice' }],
                duration_ms: 200_000,
                album: { images: [{ url: 'https://img' }] },
                uri: 'spotify:track:spot-1',
              },
            ],
          },
        }),
      );

      const res = await service.search('u1', 'hello', 5);
      expect(res).toHaveLength(1);
      expect(res[0].artists).toEqual(['Alice']);
      const [url, init] = fetchMock.mock.calls[0];
      expect(url).toContain('https://api.spotify.com/v1/search');
      expect(url).toContain('q=hello');
      expect(url).toContain('limit=5');
      expect(init.headers.Authorization).toBe('Bearer valid');
    });
  });

  describe('getStatus', () => {
    it('returns connected=false when no account', async () => {
      prisma.socialAccount.findUnique.mockResolvedValue(null);
      const s = await service.getStatus('u1');
      expect(s).toEqual({ connected: false });
    });

    it('returns connected=true with expiresAt', async () => {
      const expiresAt = new Date(Date.now() + 3600 * 1000);
      prisma.socialAccount.findUnique.mockResolvedValue({
        providerId: 'spot-1',
        tokenExpiresAt: expiresAt,
        scope: 'user-read-email',
      });
      const s = await service.getStatus('u1');
      expect(s.connected).toBe(true);
    });
  });

  describe('disconnect', () => {
    it('deletes the spotify social account for the user', async () => {
      await service.disconnect('u1');
      expect(prisma.socialAccount.deleteMany).toHaveBeenCalledWith({
        where: { provider: SPOTIFY_PROVIDER, userId: 'u1' },
      });
    });
  });
});
