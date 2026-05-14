import { Test, TestingModule } from '@nestjs/testing';
import { RoomMembershipController } from './membership.controller';
import { RoomMembershipService } from './membership.service';

describe('RoomMembershipController', () => {
  let controller: RoomMembershipController;
  let membership: Partial<RoomMembershipService>;

  const user = { sub: 'user-1', email: 'u@example.com' };
  const roomId = 'room-1';

  beforeEach(async () => {
    membership = {
      listMembers: vi.fn().mockResolvedValue([{ userId: 'user-1', role: 'OWNER' }]),
      join: vi.fn().mockResolvedValue(undefined),
      leave: vi.fn().mockResolvedValue(undefined),
      invite: vi.fn().mockResolvedValue({ id: 'inv-1' }),
      updateRole: vi.fn().mockResolvedValue({ userId: 'user-2', role: 'ADMIN' }),
      removeMember: vi.fn().mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [RoomMembershipController],
      providers: [{ provide: RoomMembershipService, useValue: membership }],
    }).compile();

    controller = module.get(RoomMembershipController);
  });

  it('GET /rooms/:id/members lists members', async () => {
    const res = await controller.list(user, roomId);
    expect(res).toEqual([{ userId: 'user-1', role: 'OWNER' }]);
    expect(membership.listMembers).toHaveBeenCalledWith(roomId, 'user-1');
  });

  it('POST /rooms/:id/join joins a room', async () => {
    const res = await controller.join(user, roomId);
    expect(res).toEqual({ message: 'Joined' });
    expect(membership.join).toHaveBeenCalledWith(roomId, 'user-1');
  });

  it('POST /rooms/:id/leave leaves a room', async () => {
    const res = await controller.leave(user, roomId);
    expect(res).toEqual({ message: 'Left' });
    expect(membership.leave).toHaveBeenCalledWith(roomId, 'user-1');
  });

  it('POST /rooms/:id/invitations invites a user', async () => {
    const dto = { userId: 'user-2', role: 'MEMBER' } as any;
    const res = await controller.invite(user, roomId, dto);
    expect(res).toEqual({ id: 'inv-1' });
    expect(membership.invite).toHaveBeenCalledWith(roomId, 'user-1', dto);
  });

  it('PATCH /rooms/:id/members/:userId/role updates a role', async () => {
    const dto = { role: 'ADMIN' } as any;
    const res = await controller.updateRole(user, roomId, 'user-2', dto);
    expect(res).toEqual({ userId: 'user-2', role: 'ADMIN' });
    expect(membership.updateRole).toHaveBeenCalledWith(
      roomId,
      'user-1',
      'user-2',
      dto,
    );
  });

  it('DELETE /rooms/:id/members/:userId removes a member', async () => {
    const res = await controller.removeMember(user, roomId, 'user-2');
    expect(res).toEqual({ message: 'Member removed' });
    expect(membership.removeMember).toHaveBeenCalledWith(
      roomId,
      'user-1',
      'user-2',
    );
  });
});
