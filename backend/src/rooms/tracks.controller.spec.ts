import { Test, TestingModule } from '@nestjs/testing';
import { TracksController } from './tracks.controller';
import { TracksService } from './tracks.service';

describe('TracksController', () => {
  let controller: TracksController;
  let tracks: Partial<TracksService>;

  const user = { sub: 'user-1', email: 'u@example.com' };
  const roomId = 'room-1';
  const trackId = 'track-1';

  beforeEach(async () => {
    tracks = {
      listRanked: vi.fn().mockResolvedValue([{ id: trackId, score: 5 }]),
      addTrack: vi.fn().mockResolvedValue({ id: trackId }),
      vote: vi.fn().mockResolvedValue({ id: trackId, score: 6 }),
      removeTrack: vi.fn().mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [TracksController],
      providers: [{ provide: TracksService, useValue: tracks }],
    }).compile();

    controller = module.get(TracksController);
  });

  it('GET /rooms/:id/tracks lists tracks ranked by score', async () => {
    const res = await controller.list(user, roomId);
    expect(res).toEqual([{ id: trackId, score: 5 }]);
    expect(tracks.listRanked).toHaveBeenCalledWith(roomId, 'user-1');
  });

  it('POST /rooms/:id/tracks adds a track suggestion', async () => {
    const dto = { spotifyId: 'sp-1', title: 'Test' } as any;
    const res = await controller.add(user, roomId, dto);
    expect(res).toEqual({ id: trackId });
    expect(tracks.addTrack).toHaveBeenCalledWith(roomId, 'user-1', dto);
  });

  it('POST /rooms/:id/tracks/:trackId/vote records a vote', async () => {
    const dto = { value: 1 } as any;
    const res = await controller.vote(user, roomId, trackId, dto);
    expect(res).toEqual({ id: trackId, score: 6 });
    expect(tracks.vote).toHaveBeenCalledWith(roomId, trackId, 'user-1', dto);
  });

  it('DELETE /rooms/:id/tracks/:trackId removes a track', async () => {
    const res = await controller.remove(user, roomId, trackId);
    expect(res).toEqual({ message: 'Track removed' });
    expect(tracks.removeTrack).toHaveBeenCalledWith(roomId, trackId, 'user-1');
  });
});
