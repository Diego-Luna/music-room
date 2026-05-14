import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateUserDto, Visibility } from './dto/update-user.dto';
import { FriendsService } from './friends.service';

export interface UserProfile {
  id: string;
  email: string;
  displayName: string;
  avatarUrl: string | null;
  emailVerified: boolean;
  visibility: Visibility;
  musicPreferences: string[];
  createdAt: Date;
  updatedAt: Date;
}

export interface PublicUserProfile {
  id: string;
  displayName: string;
  avatarUrl: string | null;
  visibility: Visibility;
  musicPreferences: string[];
}

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly friends: FriendsService,
  ) {}

  async findOne(userId: string): Promise<UserProfile> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return this.scrub(user);
  }

  async update(userId: string, dto: UpdateUserDto): Promise<UserProfile> {
    const data: Record<string, unknown> = {};
    if (dto.displayName !== undefined) data.displayName = dto.displayName;
    if (dto.avatarUrl !== undefined) data.avatarUrl = dto.avatarUrl;
    if (dto.visibility !== undefined) data.visibility = dto.visibility;
    if (dto.musicPreferences !== undefined) {
      data.musicPreferences = dto.musicPreferences;
    }

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data,
    });
    return this.scrub(updated);
  }

  /**
   * Read another user's profile, enforcing the target's visibility:
   *  - PUBLIC       → anyone gets the public-safe view
   *  - FRIENDS_ONLY → only accepted friends get the view; otherwise 404
   *  - PRIVATE      → only self gets it (here: callerId !== targetId → 404)
   *
   * 404 (not 403) is returned for non-visible profiles to avoid leaking the
   * existence of a user with a hidden profile.
   */
  async findOnePublic(
    callerId: string,
    targetId: string,
  ): Promise<PublicUserProfile> {
    if (callerId === targetId) {
      const self = await this.findOne(targetId);
      return this.toPublic(self);
    }
    const target = await this.prisma.user.findUnique({
      where: { id: targetId },
    });
    if (!target) throw new NotFoundException('User not found');

    const visibility = target.visibility as Visibility;
    if (visibility === Visibility.PRIVATE) {
      throw new NotFoundException('User not found');
    }
    if (visibility === Visibility.FRIENDS_ONLY) {
      const ok = await this.friends.areFriends(callerId, targetId);
      if (!ok) throw new NotFoundException('User not found');
    }
    return this.toPublic(this.scrub(target));
  }

  private toPublic(p: UserProfile): PublicUserProfile {
    return {
      id: p.id,
      displayName: p.displayName,
      avatarUrl: p.avatarUrl,
      visibility: p.visibility,
      musicPreferences: p.musicPreferences,
    };
  }

  private scrub(user: Record<string, unknown>): UserProfile {
    return {
      id: user.id as string,
      email: user.email as string,
      displayName: user.displayName as string,
      avatarUrl: (user.avatarUrl as string | null) ?? null,
      emailVerified: user.emailVerified as boolean,
      visibility: user.visibility as Visibility,
      musicPreferences: (user.musicPreferences as string[]) ?? [],
      createdAt: user.createdAt as Date,
      updatedAt: user.updatedAt as Date,
    };
  }
}
