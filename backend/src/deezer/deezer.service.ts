import {
  Injectable,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';

export const DEEZER_PROVIDER = 'deezer';
const DEEZER_API_BASE = 'https://api.deezer.com';

export interface DeezerSearchResult {
  /** Deezer track id, stored as our `providerId`. */
  providerId: string;
  title: string;
  artist: string;
  durationMs: number;
  artworkUrl: string | null;
  /** 30-second MP3 preview URL — what the in-app player actually plays. */
  previewUrl: string | null;
}

/**
 * Track search/metadata via the public Deezer API.
 *
 * Deezer's search endpoint needs **no authentication** (no per-user account,
 * no app token), which is why it replaced the per-user Spotify OAuth model.
 * Playback uses the 30s `preview` MP3 each result carries; the request is a
 * hand-written REST call (no SDK) to satisfy subject III.
 */
@Injectable()
export class DeezerService {
  private readonly logger = new Logger(DeezerService.name);

  async search(query: string, limit = 10): Promise<DeezerSearchResult[]> {
    const q = query?.trim();
    if (!q) return [];
    const params = new URLSearchParams({
      q,
      limit: String(Math.min(Math.max(limit, 1), 50)),
    });
    const res = await fetch(`${DEEZER_API_BASE}/search?${params.toString()}`);
    if (!res.ok) {
      this.logger.warn(`Deezer search ${res.status}`);
      throw new InternalServerErrorException(
        `Deezer search failed (${res.status})`,
      );
    }
    const body = (await res.json()) as {
      data?: Array<{
        id: number;
        title: string;
        duration: number; // seconds
        preview: string | null;
        artist?: { name?: string };
        album?: { cover_medium?: string | null };
      }>;
    };
    const items = body.data ?? [];
    return items.map<DeezerSearchResult>((t) => ({
      providerId: String(t.id),
      title: t.title,
      artist: t.artist?.name ?? 'Unknown',
      durationMs: (t.duration ?? 0) * 1000,
      artworkUrl: t.album?.cover_medium ?? null,
      previewUrl: t.preview ?? null,
    }));
  }
}
