import { Test, TestingModule } from '@nestjs/testing';
import { FriendsController } from './friends.controller';
import { FriendsService } from './friends.service';

describe('FriendsController', () => {
  let controller: FriendsController;
  let friends: Partial<FriendsService>;

  const user = { sub: 'user-1', email: 'u@example.com' };

  beforeEach(async () => {
    friends = {
      listAccepted: vi.fn().mockResolvedValue([{ friendshipId: 'f1' }]),
      listIncoming: vi.fn().mockResolvedValue([{ id: 'f-in' }]),
      listOutgoing: vi.fn().mockResolvedValue([{ id: 'f-out' }]),
      request: vi.fn().mockResolvedValue({ id: 'f-new' }),
      accept: vi.fn().mockResolvedValue({ id: 'f-acc' }),
      decline: vi.fn().mockResolvedValue({ id: 'f-dec' }),
      cancel: vi.fn().mockResolvedValue({ id: 'f-can' }),
    };

    const mod: TestingModule = await Test.createTestingModule({
      controllers: [FriendsController],
      providers: [{ provide: FriendsService, useValue: friends }],
    }).compile();
    controller = mod.get(FriendsController);
  });

  it('GET /users/me/friends lists accepted friends', async () => {
    const res = await controller.list(user);
    expect(res).toEqual([{ friendshipId: 'f1' }]);
    expect(friends.listAccepted).toHaveBeenCalledWith('user-1');
  });

  it('GET /users/me/friends/incoming lists incoming PENDING', async () => {
    const res = await controller.incoming(user);
    expect(res).toEqual([{ id: 'f-in' }]);
    expect(friends.listIncoming).toHaveBeenCalledWith('user-1');
  });

  it('GET /users/me/friends/outgoing lists outgoing PENDING', async () => {
    const res = await controller.outgoing(user);
    expect(res).toEqual([{ id: 'f-out' }]);
    expect(friends.listOutgoing).toHaveBeenCalledWith('user-1');
  });

  it('POST /users/me/friends/request creates a request', async () => {
    const res = await controller.request(user, { userId: 'user-2' });
    expect(res).toEqual({ id: 'f-new' });
    expect(friends.request).toHaveBeenCalledWith('user-1', 'user-2');
  });

  it('POST /users/me/friends/:id/accept', async () => {
    const res = await controller.accept(user, 'f-x');
    expect(res).toEqual({ id: 'f-acc' });
    expect(friends.accept).toHaveBeenCalledWith('user-1', 'f-x');
  });

  it('POST /users/me/friends/:id/decline', async () => {
    const res = await controller.decline(user, 'f-x');
    expect(res).toEqual({ id: 'f-dec' });
    expect(friends.decline).toHaveBeenCalledWith('user-1', 'f-x');
  });

  it('DELETE /users/me/friends/:id', async () => {
    const res = await controller.cancel(user, 'f-x');
    expect(res).toEqual({ id: 'f-can' });
    expect(friends.cancel).toHaveBeenCalledWith('user-1', 'f-x');
  });
});
