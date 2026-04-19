import { Test, TestingModule } from '@nestjs/testing';
import { RoomsController } from './rooms.controller';
import { RoomsService } from './rooms.service';
import { RoomKind } from './dto/create-room.dto';

describe('RoomsController', () => {
  let controller: RoomsController;
  let service: Partial<RoomsService>;

  const room = {
    id: 'room-1',
    name: 'Chill',
    kind: 'VOTE',
    visibility: 'PUBLIC',
    ownerId: 'user-1',
  };

  beforeEach(async () => {
    service = {
      create: vi.fn().mockResolvedValue(room),
      findOne: vi.fn().mockResolvedValue(room),
      list: vi.fn().mockResolvedValue([room]),
      update: vi.fn().mockResolvedValue(room),
      remove: vi.fn().mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [RoomsController],
      providers: [{ provide: RoomsService, useValue: service }],
    }).compile();

    controller = module.get(RoomsController);
  });

  const user = { sub: 'user-1', email: 'u@example.com' };

  it('POST /rooms creates a room for the current user', async () => {
    await controller.create(user, { name: 'Chill', kind: RoomKind.VOTE });
    expect(service.create).toHaveBeenCalledWith('user-1', {
      name: 'Chill',
      kind: RoomKind.VOTE,
    });
  });

  it('GET /rooms lists rooms visible to the current user', async () => {
    const res = await controller.list(user);
    expect(res).toEqual([room]);
    expect(service.list).toHaveBeenCalledWith('user-1');
  });

  it('GET /rooms/:id returns one room', async () => {
    const res = await controller.findOne(user, 'room-1');
    expect(res).toEqual(room);
    expect(service.findOne).toHaveBeenCalledWith('room-1', 'user-1');
  });

  it('PATCH /rooms/:id updates a room', async () => {
    await controller.update(user, 'room-1', { name: 'New' });
    expect(service.update).toHaveBeenCalledWith('room-1', 'user-1', {
      name: 'New',
    });
  });

  it('DELETE /rooms/:id deletes a room', async () => {
    const res = await controller.remove(user, 'room-1');
    expect(res.message).toContain('deleted');
    expect(service.remove).toHaveBeenCalledWith('room-1', 'user-1');
  });
});
