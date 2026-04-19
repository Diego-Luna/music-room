import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { UsersService } from './users.service';
import { PrismaService } from '../prisma/prisma.service';
import { Visibility } from './dto/update-user.dto';

describe('UsersService', () => {
  let service: UsersService;
  let prisma: {
    user: {
      findUnique: ReturnType<typeof vi.fn>;
      update: ReturnType<typeof vi.fn>;
    };
  };

  const existingUser = {
    id: 'user-1',
    email: 'user@example.com',
    displayName: 'Alice',
    avatarUrl: null,
    emailVerified: true,
    visibility: 'PUBLIC',
    musicPreferences: ['rock', 'jazz'],
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-02'),
    passwordHash: 'secret-hash',
  };

  beforeEach(async () => {
    prisma = {
      user: {
        findUnique: vi.fn(),
        update: vi.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: PrismaService, useValue: prisma },
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
});
