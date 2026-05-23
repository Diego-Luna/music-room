import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { SubscriptionService } from './subscription.service';
import { PrismaService } from '../prisma/prisma.service';

describe('SubscriptionService', () => {
  let service: SubscriptionService;
  let prisma: {
    user: {
      findUnique: ReturnType<typeof vi.fn>;
      update: ReturnType<typeof vi.fn>;
    };
  };

  beforeEach(async () => {
    prisma = { user: { findUnique: vi.fn(), update: vi.fn() } };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SubscriptionService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<SubscriptionService>(SubscriptionService);
  });

  describe('getPlans', () => {
    it('returns the two offers (FREE then PREMIUM)', () => {
      const plans = service.getPlans();
      expect(plans).toHaveLength(2);
      expect(plans.map((p) => p.tier)).toEqual(['FREE', 'PREMIUM']);
    });
  });

  describe('getMine', () => {
    it('returns the current tier', async () => {
      prisma.user.findUnique.mockResolvedValue({
        subscriptionTier: 'PREMIUM',
      });
      await expect(service.getMine('user-1')).resolves.toEqual({
        tier: 'PREMIUM',
      });
    });

    it('throws NotFound for an unknown user', async () => {
      prisma.user.findUnique.mockResolvedValue(null);
      await expect(service.getMine('ghost')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('switchTo', () => {
    it('updates the user tier and returns it', async () => {
      prisma.user.update.mockResolvedValue({ subscriptionTier: 'PREMIUM' });

      const result = await service.switchTo('user-1', 'PREMIUM');

      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 'user-1' },
        data: { subscriptionTier: 'PREMIUM' },
        select: { subscriptionTier: true },
      });
      expect(result).toEqual({ tier: 'PREMIUM' });
    });
  });
});
