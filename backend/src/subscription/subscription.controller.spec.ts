import { Test, TestingModule } from '@nestjs/testing';
import { SubscriptionController } from './subscription.controller';
import { SubscriptionService } from './subscription.service';

describe('SubscriptionController', () => {
  let controller: SubscriptionController;
  let service: Partial<SubscriptionService>;

  const user = { sub: 'user-1', email: 'a@b.c' };

  beforeEach(async () => {
    service = {
      getPlans: vi.fn().mockReturnValue([
        { tier: 'FREE', label: 'Free', price: '0', features: [] },
        { tier: 'PREMIUM', label: 'Premium', price: '9.99', features: [] },
      ]),
      getMine: vi.fn().mockResolvedValue({ tier: 'FREE' }),
      switchTo: vi.fn().mockResolvedValue({ tier: 'PREMIUM' }),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [SubscriptionController],
      providers: [{ provide: SubscriptionService, useValue: service }],
    }).compile();

    controller = module.get<SubscriptionController>(SubscriptionController);
  });

  it('GET /subscription/plans returns the offers', () => {
    expect(controller.getPlans()).toHaveLength(2);
  });

  it('GET /subscription/me returns my tier', async () => {
    await expect(controller.getMine(user)).resolves.toEqual({ tier: 'FREE' });
    expect(service.getMine).toHaveBeenCalledWith('user-1');
  });

  it('PUT /subscription/me switches my tier', async () => {
    await expect(
      controller.switchMine(user, { tier: 'PREMIUM' }),
    ).resolves.toEqual({ tier: 'PREMIUM' });
    expect(service.switchTo).toHaveBeenCalledWith('user-1', 'PREMIUM');
  });
});
