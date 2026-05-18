import { randomBytes } from 'node:crypto';
import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';

export const SPOTIFY_PROVIDER = 'spotify';
const SPOTIFY_AUTH_URL = 'https://accounts.spotify.com/authorize';
const SPOTIFY_TOKEN_URL = 'https://accounts.spotify.com/api/token';
const SPOTIFY_API_BASE = 'https://api.spotify.com/v1';

export const SPOTIFY_SCOPES = [
  'user-read-email',
  'user-read-private',
  'user-read-playback-state',
  'user-modify-playback-state',
  'user-read-currently-playing',
  'streaming',
].join(' ');

export interface SpotifyTokens {
  accessToken: string;
  refreshToken: string | null;
  expiresAt: Date;
  scope: string | null;
}

export interface SpotifyProfile {
  id: string;
  display_name: string | null;
  email: string | null;
}

export interface SpotifySearchResult {
  id: string;
  name: string;
  artists: string[];
  durationMs: number;
  artworkUrl: string | null;
  uri: string;
}

@Injectable()
export class SpotifyService {
  private readonly logger = new Logger(SpotifyService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  buildAuthorizeUrl(stateSeed?: string): { url: string; state: string } {
    const clientId = this.requireConfig('SPOTIFY_CLIENT_ID');
    const redirectUri = this.requireConfig('SPOTIFY_REDIRECT_URI');
    const state = stateSeed ?? randomBytes(16).toString('hex');
    const params = new URLSearchParams({
      client_id: clientId,
      response_type: 'code',
      redirect_uri: redirectUri,
      scope: SPOTIFY_SCOPES,
      state,
    });
    return { url: `${SPOTIFY_AUTH_URL}?${params.toString()}`, state };
  }

  async exchangeCode(userId: string, code: string): Promise<SpotifyTokens> {
    const tokens = await this.postTokenRequest({
      grant_type: 'authorization_code',
      code,
      redirect_uri: this.requireConfig('SPOTIFY_REDIRECT_URI'),
    });
    const profile = await this.fetchProfile(tokens.accessToken);
    await this.prisma.socialAccount.upsert({
      where: {
        provider_providerId: {
          provider: SPOTIFY_PROVIDER,
          providerId: profile.id,
        },
      },
      update: {
        userId,
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        tokenExpiresAt: tokens.expiresAt,
        scope: tokens.scope,
      },
      create: {
        provider: SPOTIFY_PROVIDER,
        providerId: profile.id,
        userId,
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        tokenExpiresAt: tokens.expiresAt,
        scope: tokens.scope,
      },
    });
    return tokens;
  }

  async disconnect(userId: string): Promise<void> {
    await this.prisma.socialAccount.deleteMany({
      where: { provider: SPOTIFY_PROVIDER, userId },
    });
  }

  async getAccessTokenForUser(userId: string): Promise<string> {
    const account = await this.prisma.socialAccount.findUnique({
      where: {
        provider_userId: { provider: SPOTIFY_PROVIDER, userId },
      },
    });
    if (!account) {
      throw new NotFoundException('No Spotify account connected');
    }
    if (!account.accessToken) {
      throw new UnauthorizedException('Spotify connection has no access token');
    }
    const expiresAt = account.tokenExpiresAt;
    const stillValid =
      expiresAt && expiresAt.getTime() - Date.now() > 60_000;
    if (stillValid) return account.accessToken;

    if (!account.refreshToken) {
      throw new UnauthorizedException(
        'Spotify access token expired and no refresh token stored',
      );
    }
    const refreshed = await this.postTokenRequest({
      grant_type: 'refresh_token',
      refresh_token: account.refreshToken,
    });
    await this.prisma.socialAccount.update({
      where: { id: account.id },
      data: {
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken ?? account.refreshToken,
        tokenExpiresAt: refreshed.expiresAt,
        scope: refreshed.scope ?? account.scope,
      },
    });
    return refreshed.accessToken;
  }

  async getStatus(userId: string) {
    const account = await this.prisma.socialAccount.findUnique({
      where: {
        provider_userId: { provider: SPOTIFY_PROVIDER, userId },
      },
    });
    if (!account) return { connected: false as const };
    return {
      connected: true as const,
      providerId: account.providerId,
      expiresAt: account.tokenExpiresAt,
      scope: account.scope,
    };
  }

  async play(userId: string, uris?: string[], contextUri?: string) {
    const body: Record<string, unknown> = {};
    if (uris?.length) body.uris = uris;
    if (contextUri) body.context_uri = contextUri;
    await this.playbackCall(userId, 'PUT', '/me/player/play', body);
  }

  async pause(userId: string) {
    await this.playbackCall(userId, 'PUT', '/me/player/pause');
  }

  async next(userId: string) {
    await this.playbackCall(userId, 'POST', '/me/player/next');
  }

  async previous(userId: string) {
    await this.playbackCall(userId, 'POST', '/me/player/previous');
  }

  async setVolume(userId: string, percent: number) {
    const clamped = Math.max(0, Math.min(100, Math.round(percent)));
    await this.playbackCall(
      userId,
      'PUT',
      `/me/player/volume?volume_percent=${clamped}`,
    );
  }

  private async playbackCall(
    userId: string,
    method: 'PUT' | 'POST',
    path: string,
    body?: Record<string, unknown>,
  ) {
    const token = await this.getAccessTokenForUser(userId);
    const init: RequestInit = {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        ...(body ? { 'Content-Type': 'application/json' } : {}),
      },
    };
    if (body) init.body = JSON.stringify(body);
    const res = await fetch(`${SPOTIFY_API_BASE}${path}`, init);
    if (res.status === 404) {
      throw new NotFoundException('No active Spotify device for the delegate');
    }
    if (!res.ok && res.status !== 204) {
      const text = await res.text().catch(() => '');
      this.logger.warn(`Spotify playback ${method} ${path} ${res.status}: ${text}`);
      throw new InternalServerErrorException(
        `Spotify playback failed (${res.status})`,
      );
    }
  }

  async search(userId: string, query: string, limit = 10) {
    const token = await this.getAccessTokenForUser(userId);
    const params = new URLSearchParams({
      q: query,
      type: 'track',
      limit: String(Math.min(Math.max(limit, 1), 50)),
    });
    const res = await fetch(`${SPOTIFY_API_BASE}/search?${params.toString()}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) {
      throw new InternalServerErrorException(
        `Spotify search failed (${res.status})`,
      );
    }
    const body = (await res.json()) as {
      tracks?: {
        items?: Array<{
          id: string;
          name: string;
          artists: Array<{ name: string }>;
          duration_ms: number;
          album: { images: Array<{ url: string }> };
          uri: string;
        }>;
      };
    };
    const items = body.tracks?.items ?? [];
    return items.map<SpotifySearchResult>((t) => ({
      id: t.id,
      name: t.name,
      artists: t.artists.map((a) => a.name),
      durationMs: t.duration_ms,
      artworkUrl: t.album.images[0]?.url ?? null,
      uri: t.uri,
    }));
  }

  private async fetchProfile(accessToken: string): Promise<SpotifyProfile> {
    const res = await fetch(`${SPOTIFY_API_BASE}/me`, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!res.ok) {
      throw new UnauthorizedException(
        `Spotify profile fetch failed (${res.status})`,
      );
    }
    return (await res.json()) as SpotifyProfile;
  }

  private async postTokenRequest(
    body: Record<string, string>,
  ): Promise<SpotifyTokens> {
    const clientId = this.requireConfig('SPOTIFY_CLIENT_ID');
    const clientSecret = this.requireConfig('SPOTIFY_CLIENT_SECRET');
    const basic = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
    const res = await fetch(SPOTIFY_TOKEN_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: `Basic ${basic}`,
      },
      body: new URLSearchParams(body).toString(),
    });
    if (!res.ok) {
      const text = await res.text().catch(() => '');
      this.logger.warn(`Spotify token endpoint ${res.status}: ${text}`);
      throw new BadRequestException('Spotify token exchange failed');
    }
    const json = (await res.json()) as {
      access_token: string;
      refresh_token?: string;
      expires_in: number;
      scope?: string;
    };
    return {
      accessToken: json.access_token,
      refreshToken: json.refresh_token ?? null,
      expiresAt: new Date(Date.now() + json.expires_in * 1000),
      scope: json.scope ?? null,
    };
  }

  private requireConfig(key: string): string {
    const v = this.config.get<string>(key);
    if (!v) {
      throw new InternalServerErrorException(`${key} is not configured`);
    }
    return v;
  }
}
