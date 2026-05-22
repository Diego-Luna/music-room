import { Test, TestingModule } from '@nestjs/testing';
import { DelegationController } from './delegation.controller';
import { DelegationService } from './delegation.service';

describe('DelegationController', () => {
  let controller: DelegationController;
  let delegation: Partial<DelegationService>;

  const user = { sub: 'owner-1', email: 'o@example.com' };

  beforeEach(async () => {
    delegation = {
      listMyDevices: vi.fn().mockResolvedValue([{ deviceId: 'phone' }]),
      listMyDelegations: vi.fn().mockResolvedValue([{ id: 'del-1' }]),
      listControlledDevices: vi.fn().mockResolvedValue([{ id: 'del-2' }]),
      getCurrent: vi.fn().mockResolvedValue({ id: 'del-1' }),
      grant: vi.fn().mockResolvedValue({ id: 'del-1' }),
      revoke: vi.fn().mockResolvedValue({ revoked: true }),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [DelegationController],
      providers: [{ provide: DelegationService, useValue: delegation }],
    }).compile();

    controller = module.get(DelegationController);
  });

  it('GET /users/me/devices lists my account devices', async () => {
    const res = await controller.listDevices(user);
    expect(res).toEqual([{ deviceId: 'phone' }]);
    expect(delegation.listMyDevices).toHaveBeenCalledWith('owner-1');
  });

  it('GET /users/me/delegations lists my delegations', async () => {
    const res = await controller.listMine(user);
    expect(res).toEqual([{ id: 'del-1' }]);
    expect(delegation.listMyDelegations).toHaveBeenCalledWith('owner-1');
  });

  it('GET /users/me/controlled-devices lists devices I control', async () => {
    const res = await controller.listControlled(user);
    expect(res).toEqual([{ id: 'del-2' }]);
    expect(delegation.listControlledDevices).toHaveBeenCalledWith('owner-1');
  });

  it('GET /users/me/devices/:deviceId/delegate gets the current delegate', async () => {
    const res = await controller.getCurrent(user, 'device-A');
    expect(res).toEqual({ id: 'del-1' });
    expect(delegation.getCurrent).toHaveBeenCalledWith('owner-1', 'device-A');
  });

  it('PUT /users/me/devices/:deviceId/delegate grants control', async () => {
    const res = await controller.grant(user, 'device-A', {
      delegateUserId: 'friend-1',
    });
    expect(res).toEqual({ id: 'del-1' });
    expect(delegation.grant).toHaveBeenCalledWith(
      'owner-1',
      'device-A',
      'friend-1',
    );
  });

  it('DELETE /users/me/devices/:deviceId/delegate revokes control', async () => {
    const res = await controller.revoke(user, 'device-A');
    expect(res).toEqual({ revoked: true });
    expect(delegation.revoke).toHaveBeenCalledWith('owner-1', 'device-A');
  });
});
