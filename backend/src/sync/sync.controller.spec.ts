import { Test, TestingModule } from '@nestjs/testing';
import { SyncController } from './sync.controller';
import { SyncService } from './sync.service';

describe('SyncController', () => {
  let controller: SyncController;
  let service: Partial<SyncService>;

  beforeEach(async () => {
    service = {
      snapshot: vi.fn().mockResolvedValue({
        serverTime: '2026-05-23T12:00:00.000Z',
        me: { id: 'user-1' },
        rooms: [],
        invitations: [],
        friendships: [],
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [SyncController],
      providers: [{ provide: SyncService, useValue: service }],
    }).compile();

    controller = module.get<SyncController>(SyncController);
  });

  it('GET /sync returns a snapshot for the current user', async () => {
    const res = await controller.snapshot({ sub: 'user-1', email: 'a@b.c' });
    expect(res.me).toEqual({ id: 'user-1' });
    expect(service.snapshot).toHaveBeenCalledWith('user-1');
  });
});
