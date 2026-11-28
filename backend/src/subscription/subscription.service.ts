import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export type SubscriptionTier = 'FREE' | 'PREMIUM';

export interface SubscriptionPlan {
  tier: SubscriptionTier;
  label: string;
  price: string;
  features: string[];
}

// VI.3 — the two offers, established beforehand. Creating and hosting
// playlist rooms is the premium-only functionality; editing an existing
// playlist follows its own edit license (V.2.3: everyone by default).
const PLANS: SubscriptionPlan[] = [
  {
    tier: 'FREE',
    label: 'Free',
    price: '0',
    features: [
      'Music Track Vote rooms',
      'Music Control Delegation',
      'Join and edit playlists you have access to',
      'Up to 3 rooms of your own',
    ],
  },
  {
    tier: 'PREMIUM',
    label: 'Premium',
    price: '9.99',
    features: [
      'Everything in Free',
      'Music Playlist Editor — create and host your own playlist rooms',
    ],
  },
];

@Injectable()
export class SubscriptionService {
  constructor(private readonly prisma: PrismaService) {}

  getPlans(): SubscriptionPlan[] {
    return PLANS;
  }

  async getMine(userId: string): Promise<{ tier: SubscriptionTier }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { subscriptionTier: true },
    });
    if (!user) throw new NotFoundException('User not found');
    return { tier: user.subscriptionTier as SubscriptionTier };
  }

  async switchTo(
    userId: string,
    tier: SubscriptionTier,
  ): Promise<{ tier: SubscriptionTier }> {
    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: { subscriptionTier: tier },
      select: { subscriptionTier: true },
    });
    return { tier: updated.subscriptionTier as SubscriptionTier };
  }

  // VI.3 — entitlement check for the premium-only feature: creating a
  // playlist room.
  async assertPremium(userId: string): Promise<void> {
    const { tier } = await this.getMine(userId);
    if (tier !== 'PREMIUM') {
      throw new ForbiddenException(
        'Creating a playlist requires a premium subscription',
      );
    }
  }
}
