import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { UsersService } from './users.service';
import { PrismaService } from '../prisma/prisma.service';
import { FriendsService } from './friends.service';
import { Visibility } from './dto/update-user.dto';

describe('UsersService', () => {
  let service: UsersService;
  let prisma: {
    user: {
      findUnique: ReturnType<typeof vi.fn>;
      update: ReturnType<typeof vi.fn>;
      findMany: ReturnType<typeof vi.fn>;
    };
  };
  let friends: { areFriends: ReturnType<typeof vi.fn> };

  const existingUser = {
    id: 'user-1',
    email: 'user@example.com',
    displayName: 'Alice',
    avatarUrl: null,
    emailVerified: true,
    visibility: 'PUBLIC',
    musicPreferences: ['rock', 'jazz'],
    publicInfo: 'pub',
    friendsInfo: 'fr',
    privateInfo: 'priv',
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-02'),
    passwordHash: 'secret-hash',
  };

  beforeEach(async () => {
    prisma = {
      user: {
        findUnique: vi.fn(),
        update: vi.fn(),
        findMany: vi.fn(),
      },
    };
    friends = { areFriends: vi.fn().mockResolvedValue(false) };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: PrismaService, useValue: prisma },
        { provide: FriendsService, useValue: friends },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
  });

  describe('findOne', () => {
    it('returns a scrubbed profile for an existing user', async () => {
      prisma.user.findUnique.mockResolvedValue(existingUser);

      const profile = await service.findOne('user-1');

      expect(profile).toEqual({
        id: 'user-1',
        email: 'user@example.com',
        displayName: 'Alice',
        avatarUrl: null,
        emailVerified: true,
        visibility: 'PUBLIC',
        musicPreferences: ['rock', 'jazz'],
        publicInfo: 'pub',
        friendsInfo: 'fr',
        privateInfo: 'priv',
        createdAt: existingUser.createdAt,
        updatedAt: existingUser.updatedAt,
      });
      expect(profile).not.toHaveProperty('passwordHash');
    });

    it('throws NotFoundException when user is missing', async () => {
      prisma.user.findUnique.mockResolvedValue(null);
      await expect(service.findOne('ghost')).rejects.toThrow(NotFoundException);
    });
  });

  describe('update', () => {
    it('updates allowed fields and returns a scrubbed profile', async () => {
      const updated = {
        ...existingUser,
        displayName: 'Alicia',
        visibility: 'FRIENDS_ONLY',
        musicPreferences: ['pop'],
      };
      prisma.user.update.mockResolvedValue(updated);

      const profile = await service.update('user-1', {
        displayName: 'Alicia',
        visibility: Visibility.FRIENDS_ONLY,
        musicPreferences: ['pop'],
      });

      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 'user-1' },
        data: {
          displayName: 'Alicia',
          visibility: 'FRIENDS_ONLY',
          musicPreferences: ['pop'],
        },
      });
      expect(profile.displayName).toBe('Alicia');
      expect(profile.visibility).toBe('FRIENDS_ONLY');
      expect(profile).not.toHaveProperty('passwordHash');
    });

    it('silently drops unknown / disallowed fields', async () => {
      prisma.user.update.mockResolvedValue(existingUser);

      await service.update('user-1', {
        displayName: 'Alice',
        // @ts-expect-error testing that unknown fields are dropped
        email: 'hacker@example.com',
        // @ts-expect-error testing that unknown fields are dropped
        passwordHash: 'pwned',
      });

      const payload = prisma.user.update.mock.calls[0][0].data;
      expect(payload).not.toHaveProperty('email');
      expect(payload).not.toHaveProperty('passwordHash');
    });

    it('forwards avatarUrl when provided', async () => {
      prisma.user.update.mockResolvedValue({
        ...existingUser,
        avatarUrl: 'https://cdn/x.png',
      });
      const profile = await service.update('user-1', {
        avatarUrl: 'https://cdn/x.png',
      });
      expect(prisma.user.update.mock.calls[0][0].data).toEqual({
        avatarUrl: 'https://cdn/x.png',
      });
      expect(profile.avatarUrl).toBe('https://cdn/x.png');
    });

    it('defaults musicPreferences to [] when missing on the row', async () => {
      prisma.user.update.mockResolvedValue({
        ...existingUser,
        musicPreferences: undefined,
      });
      const profile = await service.update('user-1', { displayName: 'X' });
      expect(profile.musicPreferences).toEqual([]);
    });
  });

  describe('findOnePublic', () => {
    it('returns the full self-view when caller targets themselves', async () => {
      prisma.user.findUnique.mockResolvedValue(existingUser);
      const profile = await service.findOnePublic('user-1', 'user-1');
      expect(profile).toEqual({
        id: 'user-1',
        displayName: 'Alice',
        avatarUrl: null,
        visibility: 'PUBLIC',
        musicPreferences: ['rock', 'jazz'],
        publicInfo: 'pub',
        friendsInfo: 'fr',
        privateInfo: 'priv',
      });
    });

    it('returns the public profile when target is PUBLIC', async () => {
      prisma.user.findUnique.mockResolvedValue(existingUser);
      const profile = await service.findOnePublic('user-2', 'user-1');
      expect(profile.id).toBe('user-1');
      expect(profile).not.toHaveProperty('email');
      expect(profile).not.toHaveProperty('emailVerified');
      // V.1 tiers: a non-friend sees publicInfo, but NOT friends/private info.
      expect(profile.publicInfo).toBe('pub');
      expect(profile.friendsInfo).toBeUndefined();
      expect(profile.privateInfo).toBeUndefined();
    });

    it('throws NotFoundException when target is PRIVATE and caller is not self', async () => {
      prisma.user.findUnique.mockResolvedValue({
        ...existingUser,
        visibility: 'PRIVATE',
      });
      await expect(
        service.findOnePublic('user-2', 'user-1'),
      ).rejects.toThrow(NotFoundException);
    });

    it('throws NotFoundException when target is FRIENDS_ONLY and caller is not a friend', async () => {
      prisma.user.findUnique.mockResolvedValue({
        ...existingUser,
        visibility: 'FRIENDS_ONLY',
      });
      friends.areFriends.mockResolvedValueOnce(false);
      await expect(
        service.findOnePublic('user-2', 'user-1'),
      ).rejects.toThrow(NotFoundException);
    });

    it('returns the public profile when target is FRIENDS_ONLY and caller is a friend', async () => {
      prisma.user.findUnique.mockResolvedValue({
        ...existingUser,
        visibility: 'FRIENDS_ONLY',
      });
      friends.areFriends.mockResolvedValueOnce(true);
      const profile = await service.findOnePublic('user-2', 'user-1');
      expect(profile.id).toBe('user-1');
      expect(profile.visibility).toBe('FRIENDS_ONLY');
      // V.1 tiers: a friend additionally sees friendsInfo, but never privateInfo.
      expect(profile.publicInfo).toBe('pub');
      expect(profile.friendsInfo).toBe('fr');
      expect(profile.privateInfo).toBeUndefined();
    });

    it('throws NotFoundException when the target user does not exist', async () => {
      prisma.user.findUnique.mockResolvedValue(null);
      await expect(
        service.findOnePublic('user-2', 'ghost'),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('searchByName', () => {
    const row = {
      id: 'user-2',
      displayName: 'Bob',
      avatarUrl: 'https://cdn/b.png',
      visibility: 'PUBLIC',
    };

    it('excludes the caller and PRIVATE profiles, matches displayName case-insensitively', async () => {
      prisma.user.findMany.mockResolvedValue([row]);

      const results = await service.searchByName('user-1', 'bo', 10);

      expect(prisma.user.findMany).toHaveBeenCalledWith({
        where: {
          id: { not: 'user-1' },
          visibility: { not: 'PRIVATE' },
          displayName: { contains: 'bo', mode: 'insensitive' },
        },
        orderBy: { displayName: 'asc' },
        take: 10,
        select: {
          id: true,
          displayName: true,
          avatarUrl: true,
          visibility: true,
        },
      });
      expect(results).toEqual([
        {
          id: 'user-2',
          displayName: 'Bob',
          avatarUrl: 'https://cdn/b.png',
          visibility: 'PUBLIC',
        },
      ]);
    });

    it('defaults the limit to 20 and never leaks info tiers', async () => {
      prisma.user.findMany.mockResolvedValue([row]);

      const results = await service.searchByName('user-1', 'b');

      expect(prisma.user.findMany.mock.calls[0][0].take).toBe(20);
      expect(results[0]).not.toHaveProperty('email');
      expect(results[0]).not.toHaveProperty('publicInfo');
      expect(results[0]).not.toHaveProperty('friendsInfo');
      expect(results[0]).not.toHaveProperty('privateInfo');
    });

    it('normalises a missing avatarUrl to null', async () => {
      prisma.user.findMany.mockResolvedValue([{ ...row, avatarUrl: null }]);
      const results = await service.searchByName('user-1', 'bob');
      expect(results[0].avatarUrl).toBeNull();
    });
  });
});
