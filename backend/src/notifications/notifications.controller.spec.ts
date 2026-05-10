import { Test, TestingModule } from '@nestjs/testing';
import { NotificationsController } from './notifications.controller';
import { PushService } from './push.service';

describe('NotificationsController', () => {
  let controller: NotificationsController;
  let push: Partial<PushService>;

  const user = { sub: 'user-1', email: 'u@example.com' };

  beforeEach(async () => {
    push = {
      register: vi.fn().mockResolvedValue({ id: 'token-1' }),
      unregister: vi.fn().mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [NotificationsController],
      providers: [{ provide: PushService, useValue: push }],
    }).compile();

    controller = module.get(NotificationsController);
  });

  it('POST /notifications/register registers a device token', async () => {
    const res = await controller.register(user, {
      token: 'fcm-abc',
      platform: 'android',
    } as any);
    expect(res).toEqual({ id: 'token-1', registered: true });
    expect(push.register).toHaveBeenCalledWith('user-1', {
      token: 'fcm-abc',
      platform: 'android',
    });
  });

  it('DELETE /notifications/register unregisters a device token', async () => {
    const res = await controller.unregister(user, { token: 'fcm-abc' } as any);
    expect(res).toEqual({ unregistered: true });
    expect(push.unregister).toHaveBeenCalledWith('user-1', 'fcm-abc');
  });
});
