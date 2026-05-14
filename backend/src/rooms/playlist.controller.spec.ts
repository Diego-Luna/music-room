import { Test, TestingModule } from '@nestjs/testing';
import { PlaylistController } from './playlist.controller';
import { PlaylistService } from './playlist.service';

describe('PlaylistController', () => {
  let controller: PlaylistController;
  let playlist: Partial<PlaylistService>;

  const user = { sub: 'user-1', email: 'u@example.com' };
  const roomId = 'room-1';
  const trackId = 'track-1';

  beforeEach(async () => {
    playlist = {
      listOrdered: vi.fn().mockResolvedValue([{ id: 'item-1', position: 'a0' }]),
      addItem: vi.fn().mockResolvedValue({ id: 'item-1' }),
      moveItem: vi.fn().mockResolvedValue({ id: 'item-1', position: 'b0' }),
      removeItem: vi.fn().mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [PlaylistController],
      providers: [{ provide: PlaylistService, useValue: playlist }],
    }).compile();

    controller = module.get(PlaylistController);
  });

  it('GET /rooms/:id/playlist lists items in order', async () => {
    const res = await controller.list(user, roomId);
    expect(res).toEqual([{ id: 'item-1', position: 'a0' }]);
    expect(playlist.listOrdered).toHaveBeenCalledWith(roomId, 'user-1');
  });

  it('POST /rooms/:id/playlist adds an item', async () => {
    const dto = { trackId } as any;
    const res = await controller.add(user, roomId, dto);
    expect(res).toEqual({ id: 'item-1' });
    expect(playlist.addItem).toHaveBeenCalledWith(roomId, 'user-1', dto);
  });

  it('PATCH /rooms/:id/playlist/:trackId/move reorders an item', async () => {
    const dto = { afterTrackId: 'track-2' } as any;
    const res = await controller.move(user, roomId, trackId, dto);
    expect(res).toEqual({ id: 'item-1', position: 'b0' });
    expect(playlist.moveItem).toHaveBeenCalledWith(
      roomId,
      trackId,
      'user-1',
      dto,
    );
  });

  it('DELETE /rooms/:id/playlist/:trackId removes an item', async () => {
    const res = await controller.remove(user, roomId, trackId);
    expect(res).toEqual({ message: 'Playlist item removed' });
    expect(playlist.removeItem).toHaveBeenCalledWith(roomId, trackId, 'user-1');
  });
});
