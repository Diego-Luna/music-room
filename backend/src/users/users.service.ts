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
  subscriptionTier: string;
  musicPreferences: string[];
  publicInfo: string | null;
  friendsInfo: string | null;
  privateInfo: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface PublicUserProfile {
  id: string;
  displayName: string;
  avatarUrl: string | null;
  visibility: Visibility;
  musicPreferences: string[];
  publicInfo: string | null;
  // Only present when the caller is a friend (or self).
  friendsInfo?: string | null;
  // Only present when the caller is the profile owner.
  privateInfo?: string | null;
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
    if (dto.publicInfo !== undefined) data.publicInfo = dto.publicInfo;
    if (dto.friendsInfo !== undefined) data.friendsInfo = dto.friendsInfo;
    if (dto.privateInfo !== undefined) data.privateInfo = dto.privateInfo;

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
    const isSelf = callerId === targetId;
    const target = await this.prisma.user.findUnique({
      where: { id: targetId },
    });
    if (!target) throw new NotFoundException('User not found');

    // Self always sees the friend tier; otherwise resolve the friendship once.
    const isFriend = isSelf
      ? true
      : await this.friends.areFriends(callerId, targetId);

    if (!isSelf) {
      const visibility = target.visibility as Visibility;
      if (visibility === Visibility.PRIVATE) {
        throw new NotFoundException('User not found');
      }
      if (visibility === Visibility.FRIENDS_ONLY && !isFriend) {
        throw new NotFoundException('User not found');
      }
    }
    return this.toPublic(this.scrub(target), isSelf, isFriend);
  }

  /**
   * Builds the visibility-filtered profile per the V.1 audience tiers:
   *  - publicInfo  → everyone who can see the profile
   *  - friendsInfo → friends (and self) only
   *  - privateInfo → self only
   */
  private toPublic(
    p: UserProfile,
    isSelf = false,
    isFriend = false,
  ): PublicUserProfile {
    return {
      id: p.id,
      displayName: p.displayName,
      avatarUrl: p.avatarUrl,
      visibility: p.visibility,
      musicPreferences: p.musicPreferences,
      publicInfo: p.publicInfo,
      friendsInfo: isSelf || isFriend ? p.friendsInfo : undefined,
      privateInfo: isSelf ? p.privateInfo : undefined,
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
      subscriptionTier: user.subscriptionTier as string,
      musicPreferences: (user.musicPreferences as string[]) ?? [],
      publicInfo: (user.publicInfo as string | null) ?? null,
      friendsInfo: (user.friendsInfo as string | null) ?? null,
      privateInfo: (user.privateInfo as string | null) ?? null,
      createdAt: user.createdAt as Date,
      updatedAt: user.updatedAt as Date,
    };
  }
}
