import { Test, TestingModule } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { ConflictException, UnauthorizedException, BadRequestException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { AuthService } from './auth.service';
import { JwtBlacklistService } from './jwt-blacklist.service';
import { PrismaService } from '../prisma/prisma.service';

vi.mock('bcrypt', () => ({
  hash: vi.fn().mockResolvedValue('hashed-password'),
  compare: vi.fn(),
}));

// Minimal mock for global fetch
const mockFetch = vi.fn();
vi.stubGlobal('fetch', mockFetch);

describe('AuthService', () => {
  let service: AuthService;
  let prismaService: Record<string, unknown>;
  let jwtService: Partial<JwtService>;
  let jwtBlacklist: Partial<JwtBlacklistService>;
  let configService: Partial<ConfigService>;

  const mockUser = {
    id: 'user-1',
    email: 'test@example.com',
    passwordHash: 'hashed-password',
    displayName: 'Test User',
    emailVerified: false,
    emailVerifyToken: 'verify-token',
    resetPasswordToken: null,
    resetPasswordExpires: null,
    visibility: 'PUBLIC',
    musicPreferences: [],
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  beforeEach(async () => {
    prismaService = {
      user: {
        findUnique: vi.fn(),
        findFirst: vi.fn(),
        create: vi.fn().mockResolvedValue(mockUser),
        update: vi.fn().mockResolvedValue(mockUser),
      },
      socialAccount: {
        findUnique: vi.fn(),
        create: vi.fn(),
      },
    };

    jwtService = {
      sign: vi.fn().mockReturnValue('jwt-token'),
      verify: vi.fn().mockReturnValue({ sub: 'user-1', email: 'test@example.com' }),
      decode: vi.fn().mockReturnValue({ sub: 'user-1', email: 'test@example.com', exp: Math.floor(Date.now() / 1000) + 900 }),
    };

    jwtBlacklist = {
      blacklist: vi.fn().mockResolvedValue(undefined),
      isBlacklisted: vi.fn().mockResolvedValue(false),
    };

    configService = {
      get: vi.fn((key: string, defaultValue?: unknown) => {
        const map: Record<string, unknown> = {
          JWT_SECRET: 'test-secret',
          JWT_REFRESH_SECRET: 'test-refresh-secret',
          JWT_EXPIRES_IN_SECONDS: 900,
          JWT_REFRESH_EXPIRES_IN_SECONDS: 604800,
        };
        return map[key] ?? defaultValue;
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prismaService },
        { provide: JwtService, useValue: jwtService },
        { provide: ConfigService, useValue: configService },
        { provide: JwtBlacklistService, useValue: jwtBlacklist },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  describe('register', () => {
    it('should register a new user and return tokens', async () => {
      (prismaService.user as Record<string, ReturnType<typeof vi.fn>>).findUnique.mockResolvedValue(null);

      const result = await service.register({
        email: 'new@example.com',
        password: 'MyP@ssw0rd',
        displayName: 'New User',
      });

      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
      expect(bcrypt.hash).toHaveBeenCalledWith('MyP@ssw0rd', 12);
    });

    it('should throw ConflictException if email already exists', async () => {
      (prismaService.user as Record<string, ReturnType<typeof vi.fn>>).findUnique.mockResolvedValue(mockUser);

      await expect(
        service.register({
          email: 'test@example.com',
          password: 'MyP@ssw0rd',
          displayName: 'Test',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('validateUser', () => {
    it('should return user data when credentials are valid', async () => {
      (prismaService.user as Record<string, ReturnType<typeof vi.fn>>).findUnique.mockResolvedValue(mockUser);
      (bcrypt.compare as ReturnType<typeof vi.fn>).mockResolvedValue(true);

      const result = await service.validateUser('test@example.com', 'password');
      expect(result).toEqual({ id: 'user-1', email: 'test@example.com' });
    });

    it('should throw UnauthorizedException when user not found', async () => {
      (prismaService.user as Record<string, ReturnType<typeof vi.fn>>).findUnique.mockResolvedValue(null);

      await expect(
        service.validateUser('wrong@example.com', 'password'),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('should throw UnauthorizedException when password is wrong', async () => {
      (prismaService.user as Record<string, ReturnType<typeof vi.fn>>).findUnique.mockResolvedValue(mockUser);
      (bcrypt.compare as ReturnType<typeof vi.fn>).mockResolvedValue(false);

      await expect(
        service.validateUser('test@example.com', 'wrong'),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('should throw UnauthorizedException when user has no password (social only)', async () => {
      (prismaService.user as Record<string, ReturnType<typeof vi.fn>>).findUnique.mockResolvedValue({
        ...mockUser,
        passwordHash: null,
      });

      await expect(
        service.validateUser('test@example.com', 'password'),
      ).rejects.toThrow(UnauthorizedException);
    });
  });

  describe('login', () => {
    it('should return tokens when credentials are valid', async () => {
      (prismaService.user as Record<string, ReturnType<typeof vi.fn>>).findUnique.mockResolvedValue(mockUser);
      (bcrypt.compare as ReturnType<typeof vi.fn>).mockResolvedValue(true);

      const result = await service.login('test@example.com', 'password');
      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
    });
  });

  describe('socialLogin', () => {
    it('should return tokens for existing social account', async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ id: 'google-123', email: 'test@example.com', name: 'Test' }),
      });
      (prismaService.socialAccount as Record<string, ReturnType<typeof vi.fn>>).findUnique.mockResolvedValue({
        user: mockUser,
      });

      const result = await service.socialLogin({
        provider: 'google',
        accessToken: 'valid-token',
      });

      expect(result).toHaveProperty('accessToken');
    });

    it('should create new user for new social account with new email', async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ id: 'google-456', email: 'new@example.com', name: 'New User' }),
      });
      (prismaService.socialAccount as Record<string, ReturnType<typeof vi.fn>>).findUnique.mockResolvedValue(null);
      (prismaService.user as Record<string, ReturnType<typeof vi.fn>>).findUnique.mockResolvedValue(null);

      const result = await service.socialLogin({
        provider: 'google',
        accessToken: 'valid-token',
      });

      expect(result).toHaveProperty('accessToken');
      expect((prismaService.user as Record<string, ReturnType<typeof vi.fn>>).create).toHaveBeenCalled();
    });

    it('should throw UnauthorizedException for invalid social token', async () => {
      mockFetch.mockResolvedValue({
        ok: false,
        status: 401,
      });

      await expect(
        service.socialLogin({ provider: 'google', accessToken: 'invalid' }),
      ).rejects.toThrow(UnauthorizedException);
    });
  });

  describe('linkSocial', () => {
    it('should link social account to user', async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ id: 'fb-123', email: 'test@example.com', name: 'Test' }),
      });
      (prismaService.socialAccount as Record<string, ReturnType<typeof vi.fn>>).findUnique.mockResolvedValue(null);

      await service.linkSocial('user-1', {
        provider: 'facebook',
        accessToken: 'valid-token',
      });

      expect((prismaService.socialAccount as Record<string, ReturnType<typeof vi.fn>>).create).toHaveBeenCalled();
    });

    it('should throw ConflictException if social account already linked to another user', async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ id: 'fb-123', email: 'other@example.com', name: 'Other' }),
      });
      (prismaService.socialAccount as Record<string, ReturnType<typeof vi.fn>>).findUnique
        .mockResolvedValueOnce({ userId: 'other-user' }); // provider_providerId lookup

      await expect(
        service.linkSocial('user-1', {
          provider: 'facebook',
          accessToken: 'valid-token',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('verifyEmail', () => {
    it('should verify email with valid token', async () => {
      (prismaService.user as Record<string, ReturnType<typeof vi.fn>>).findFirst.mockResolvedValue(mockUser);

      await service.verifyEmail('verify-token');

      expect((prismaService.user as Record<string, ReturnType<typeof vi.fn>>).update).toHaveBeenCalledWith({
        where: { id: 'user-1' },
        data: { emailVerified: true, emailVerifyToken: null },
      });
    });

    it('should throw BadRequestException for invalid token', async () => {
      (prismaService.user as Record<string, ReturnType<typeof vi.fn>>).findFirst.mockResolvedValue(null);

      await expect(service.verifyEmail('bad-token')).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('forgotPassword', () => {
    it('should set reset token for existing user', async () => {
      (prismaService.user as Record<string, ReturnType<typeof vi.fn>>).findUnique.mockResolvedValue(mockUser);

      await service.forgotPassword('test@example.com');

      expect((prismaService.user as Record<string, ReturnType<typeof vi.fn>>).update).toHaveBeenCalled();
    });

    it('should not throw for non-existing user (prevent enumeration)', async () => {
      (prismaService.user as Record<string, ReturnType<typeof vi.fn>>).findUnique.mockResolvedValue(null);

      await expect(
        service.forgotPassword('unknown@example.com'),
      ).resolves.not.toThrow();
    });
  });

  describe('resetPassword', () => {
    it('should reset password with valid token', async () => {
      (prismaService.user as Record<string, ReturnType<typeof vi.fn>>).findFirst.mockResolvedValue(mockUser);

      await service.resetPassword('reset-token', 'NewP@ssw0rd');

      expect(bcrypt.hash).toHaveBeenCalledWith('NewP@ssw0rd', 12);
      expect((prismaService.user as Record<string, ReturnType<typeof vi.fn>>).update).toHaveBeenCalled();
    });

    it('should throw BadRequestException for invalid/expired token', async () => {
      (prismaService.user as Record<string, ReturnType<typeof vi.fn>>).findFirst.mockResolvedValue(null);

      await expect(
        service.resetPassword('bad-token', 'NewP@ssw0rd'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('refresh', () => {
    it('should return new token pair for valid refresh token', async () => {
      const result = await service.refresh('valid-refresh-token');

      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
      expect(jwtBlacklist.blacklist).toHaveBeenCalled();
    });

    it('should throw UnauthorizedException for blacklisted refresh token', async () => {
      (jwtBlacklist.isBlacklisted as ReturnType<typeof vi.fn>).mockResolvedValue(true);

      await expect(service.refresh('blacklisted-token')).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('should throw UnauthorizedException for invalid refresh token', async () => {
      (jwtService.verify as ReturnType<typeof vi.fn>).mockImplementation(() => {
        throw new Error('invalid token');
      });

      await expect(service.refresh('invalid-token')).rejects.toThrow(
        UnauthorizedException,
      );
    });
  });

  describe('logout', () => {
    it('should blacklist access token', async () => {
      await service.logout('access-token');

      expect(jwtBlacklist.blacklist).toHaveBeenCalled();
    });

    it('should blacklist both tokens when refresh token provided', async () => {
      await service.logout('access-token', 'refresh-token');

      expect(jwtBlacklist.blacklist).toHaveBeenCalledTimes(2);
    });
  });

  describe('verifySocialToken', () => {
    it('should return profile for valid google token', async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: () =>
          Promise.resolve({
            id: 'g-123',
            email: 'user@gmail.com',
            name: 'Google User',
            picture: 'https://photo.url',
          }),
      });

      const profile = await service.verifySocialToken('google', 'token');
      expect(profile.id).toBe('g-123');
      expect(profile.email).toBe('user@gmail.com');
    });

    it('should return profile for valid facebook token', async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: () =>
          Promise.resolve({
            id: 'fb-123',
            email: 'user@fb.com',
            name: 'FB User',
            picture: { data: { url: 'https://photo.url' } },
          }),
      });

      const profile = await service.verifySocialToken('facebook', 'token');
      expect(profile.id).toBe('fb-123');
    });

    it('should throw BadRequestException for unsupported provider', async () => {
      await expect(
        service.verifySocialToken('twitter', 'token'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw UnauthorizedException for invalid token', async () => {
      mockFetch.mockResolvedValue({ ok: false, status: 401 });

      await expect(
        service.verifySocialToken('google', 'bad-token'),
      ).rejects.toThrow(UnauthorizedException);
    });
  });
});
