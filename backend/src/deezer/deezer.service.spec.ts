import { DeezerService } from './deezer.service';

describe('DeezerService', () => {
  let service: DeezerService;

  beforeEach(() => {
    service = new DeezerService();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('returns [] for an empty query without hitting the network', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch');
    expect(await service.search('   ')).toEqual([]);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('maps Deezer results to our track shape (duration→ms, preview kept)', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      new Response(
        JSON.stringify({
          data: [
            {
              id: 916424,
              title: 'Lose Yourself',
              duration: 326,
              preview: 'https://cdns-preview.mp3',
              artist: { name: 'Eminem' },
              album: { cover_medium: 'https://cover.jpg' },
            },
          ],
        }),
        { status: 200 },
      ),
    );

    const [track] = await service.search('lose yourself');

    expect(track).toEqual({
      providerId: '916424',
      title: 'Lose Yourself',
      artist: 'Eminem',
      durationMs: 326000,
      artworkUrl: 'https://cover.jpg',
      previewUrl: 'https://cdns-preview.mp3',
    });
  });

  it('throws when Deezer responds non-OK', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      new Response('', { status: 503 }),
    );
    await expect(service.search('x')).rejects.toThrow(/Deezer search failed/);
  });
});
