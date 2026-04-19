import { Test, TestingModule } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import {
  ConflictException,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { AuthService } from './auth.service';
import { JwtBlacklistService } from './jwt-blacklist.service';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from '../mail/mail.service';

vi.mock('bcrypt', () => ({
  hash: vi.fn().mockResolvedValue('hashed-password'),
  compare: vi.fn(),
}));

const mockFetch = vi.fn();
vi.stubGlobal('fetch', mockFetch);

describe('AuthService', () => {
  let service: AuthService;
  let prismaService: Record<string, unknown>;
  let jwtService: Partial<JwtService>;
  let jwtBlacklist: Partial<JwtBlacklistService>;
  let mailService: Partial<MailService>;
  let configService: Partial<ConfigService>;

  const mockUser = {
    id: 'user-1',
    email: 'test@example.com',
    passwordHash: 'hashed-password',
    displayName: 'Test User',
    emailVerified: false,
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
      refreshToken: {
        create: vi.fn().mockResolvedValue({ id: 'rt-1' }),
        findFirst: vi.fn(),
        findUnique: vi.fn(),
        findMany: vi.fn(),
        update: vi.fn(),
        updateMany: vi.fn(),
      },
      emailVerification: {
        create: vi.fn().mockResolvedValue({ id: 'ev-1' }),
        findFirst: vi.fn(),
        update: vi.fn(),
      },
      passwordReset: {
        create: vi.fn().mockResolvedValue({ id: 'pr-1' }),
        findFirst: vi.fn(),
        update: vi.fn(),
        updateMany: vi.fn(),
      },
    };

    jwtService = {
      sign: vi.fn().mockReturnValue('jwt-token'),
      verify: vi
        .fn()
        .mockReturnValue({ sub: 'user-1', email: 'test@example.com' }),
      decode: vi.fn().mockReturnValue({
        sub: 'user-1',
        email: 'test@example.com',
        exp: Math.floor(Date.now() / 1000) + 900,
      }),
    };

    jwtBlacklist = {
      blacklist: vi.fn().mockResolvedValue(undefined),
      isBlacklisted: vi.fn().mockResolvedValue(false),
    };

    mailService = {
      sendVerificationEmail: vi.fn().mockResolvedValue(undefined),
      sendPasswordResetEmail: vi.fn().mockResolvedValue(undefined),
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
        { provide: MailService, useValue: mailService },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  const userTable = () =>
    prismaService.user as Record<string, ReturnType<typeof vi.fn>>;
  const refreshTable = () =>
    prismaService.refreshToken as Record<string, ReturnType<typeof vi.fn>>;
  const emailVerifTable = () =>
    prismaService.emailVerification as Record<string, ReturnType<typeof vi.fn>>;
  const passwordResetTable = () =>
    prismaService.passwordReset as Record<string, ReturnType<typeof vi.fn>>;
  const socialTable = () =>
    prismaService.socialAccount as Record<string, ReturnType<typeof vi.fn>>;

  describe('register', () => {
    it('should register, send verification email, and return tokens', async () => {
      userTable().findUnique.mockResolvedValue(null);

      const result = await service.register({
        email: 'new@example.com',
        password: 'MyP@ssw0rd',
        displayName: 'New User',
      });

      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
      expect(bcrypt.hash).toHaveBeenCalledWith('MyP@ssw0rd', 12);
      expect(emailVerifTable().create).toHaveBeenCalledTimes(1);
      expect(mailService.sendVerificationEmail).toHaveBeenCalledTimes(1);
      const mailArgs = (mailService.sendVerificationEmail as ReturnType<
        typeof vi.fn
      >).mock.calls[0];
      expect(mailArgs[0]).toBe('test@example.com');
      expect(typeof mailArgs[1]).toBe('string');
      expect(mailArgs[1].length).toBeGreaterThan(20);
      expect(refreshTable().create).toHaveBeenCalledTimes(1);
    });

    it('should throw ConflictException on duplicate email', async () => {
      userTable().findUnique.mockResolvedValue(mockUser);

      await expect(
        service.register({
          email: 'test@example.com',
          password: 'MyP@ssw0rd',
          displayName: 'Test',
        }),
      ).rejects.toThrow(ConflictException);
      expect(mailService.sendVerificationEmail).not.toHaveBeenCalled();
    });
  });

  describe('validateUser', () => {
    it('should return user data for valid credentials', async () => {
      userTable().findUnique.mockResolvedValue(mockUser);
      (bcrypt.compare as ReturnType<typeof vi.fn>).mockResolvedValue(true);

      const result = await service.validateUser(
        'test@example.com',
        'password',
      );
      expect(result).toEqual({ id: 'user-1', email: 'test@example.com' });
    });

    it('should throw UnauthorizedException when user missing', async () => {
      userTable().findUnique.mockResolvedValue(null);
      await expect(
        service.validateUser('wrong@example.com', 'password'),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('should throw UnauthorizedException for wrong password', async () => {
      userTable().findUnique.mockResolvedValue(mockUser);
      (bcrypt.compare as ReturnType<typeof vi.fn>).mockResolvedValue(false);
      await expect(
        service.validateUser('test@example.com', 'wrong'),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('should throw UnauthorizedException for social-only user', async () => {
      userTable().findUnique.mockResolvedValue({
        ...mockUser,
        passwordHash: null,
      });
      await expect(
        service.validateUser('test@example.com', 'password'),
      ).rejects.toThrow(UnauthorizedException);
    });
  });

  describe('login', () => {
    it('should return tokens and persist a refresh token row', async () => {
      userTable().findUnique.mockResolvedValue(mockUser);
      (bcrypt.compare as ReturnType<typeof vi.fn>).mockResolvedValue(true);

      const result = await service.login('test@example.com', 'password');

      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
      expect(refreshTable().create).toHaveBeenCalledTimes(1);
      const created = refreshTable().create.mock.calls[0][0];
      expect(created.data.userId).toBe('user-1');
      expect(typeof created.data.tokenHash).toBe('string');
      expect(created.data.tokenHash).toHaveLength(64);
    });

    it('should record device metadata when provided', async () => {
      userTable().findUnique.mockResolvedValue(mockUser);
      (bcrypt.compare as ReturnType<typeof vi.fn>).mockResolvedValue(true);

      await service.login('test@example.com', 'password', {
        deviceId: 'dev-42',
        userAgent: 'iPhone',
        ip: '1.2.3.4',
      });

      const created = refreshTable().create.mock.calls[0][0];
      expect(created.data.deviceId).toBe('dev-42');
      expect(created.data.userAgent).toBe('iPhone');
      expect(created.data.ip).toBe('1.2.3.4');
    });
  });

  describe('socialLogin', () => {
    it('should return tokens for existing social account', async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: () =>
          Promise.resolve({
            id: 'google-123',
            email: 'test@example.com',
            name: 'Test',
          }),
      });
      socialTable().findUnique.mockResolvedValue({ user: mockUser });

      const result = await service.socialLogin({
        provider: 'google',
        accessToken: 'valid-token',
      });
      expect(result).toHaveProperty('accessToken');
      expect(refreshTable().create).toHaveBeenCalledTimes(1);
    });

    it('should create new user (email verified) for new social account', async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: () =>
          Promise.resolve({
            id: 'google-456',
            email: 'new@example.com',
            name: 'New User',
          }),
      });
      socialTable().findUnique.mockResolvedValue(null);
      userTable().findUnique.mockResolvedValue(null);

      const result = await service.socialLogin({
        provider: 'google',
        accessToken: 'valid-token',
      });

      expect(result).toHaveProperty('accessToken');
      expect(userTable().create).toHaveBeenCalled();
      expect(mailService.sendVerificationEmail).not.toHaveBeenCalled();
    });

    it('should link social account to existing user with same email', async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: () =>
          Promise.resolve({
            id: 'fb-789',
            email: 'test@example.com',
            name: 'Test',
          }),
      });
      socialTable().findUnique.mockResolvedValue(null);
      userTable().findUnique.mockResolvedValue(mockUser);

      await service.socialLogin({
        provider: 'facebook',
        accessToken: 'valid-token',
      });
      expect(socialTable().create).toHaveBeenCalled();
    });

    it('should throw UnauthorizedException for invalid social token', async () => {
      mockFetch.mockResolvedValue({ ok: false, status: 401 });
      await expect(
        service.socialLogin({ provider: 'google', accessToken: 'bad' }),
      ).rejects.toThrow(UnauthorizedException);
    });
  });

  describe('linkSocial', () => {
    it('should link a fresh social account to user', async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: () =>
          Promise.resolve({
            id: 'fb-123',
            email: 'test@example.com',
            name: 'Test',
          }),
      });
      socialTable().findUnique.mockResolvedValue(null);

      await service.linkSocial('user-1', {
        provider: 'facebook',
        accessToken: 'valid',
      });

      expect(socialTable().create).toHaveBeenCalled();
    });

    it('should throw ConflictException if social account already linked elsewhere', async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: () =>
          Promise.resolve({
            id: 'fb-123',
            email: 'other@example.com',
            name: 'Other',
          }),
      });
      socialTable().findUnique.mockResolvedValueOnce({ userId: 'other' });

      await expect(
        service.linkSocial('user-1', {
          provider: 'facebook',
          accessToken: 'valid',
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('should throw ConflictException if user already has same provider linked', async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: () =>
          Promise.resolve({
            id: 'fb-999',
            email: 'test@example.com',
            name: 'Test',
          }),
      });
      socialTable().findUnique
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({ userId: 'user-1' });

      await expect(
        service.linkSocial('user-1', {
          provider: 'facebook',
          accessToken: 'valid',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('verifyEmail', () => {
    it('should consume verification token and mark email verified', async () => {
      emailVerifTable().findFirst.mockResolvedValue({
        id: 'ev-1',
        userId: 'user-1',
        tokenHash: 'hash',
        expiresAt: new Date(Date.now() + 60_000),
        consumedAt: null,
        user: mockUser,
      });

      await service.verifyEmail('raw-token');

      expect(userTable().update).toHaveBeenCalledWith({
        where: { id: 'user-1' },
        data: { emailVerified: true },
      });
      expect(emailVerifTable().update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'ev-1' },
          data: expect.objectContaining({ consumedAt: expect.any(Date) }),
        }),
      );
    });

    it('should throw BadRequestException for unknown token', async () => {
      emailVerifTable().findFirst.mockResolvedValue(null);
      await expect(service.verifyEmail('bad')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should throw BadRequestException for expired token', async () => {
      emailVerifTable().findFirst.mockResolvedValue({
        id: 'ev-1',
        userId: 'user-1',
        tokenHash: 'hash',
        expiresAt: new Date(Date.now() - 1000),
        consumedAt: null,
      });
      await expect(service.verifyEmail('expired')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should throw BadRequestException for already consumed token', async () => {
      emailVerifTable().findFirst.mockResolvedValue({
        id: 'ev-1',
        userId: 'user-1',
        tokenHash: 'hash',
        expiresAt: new Date(Date.now() + 60_000),
        consumedAt: new Date(),
      });
      await expect(service.verifyEmail('used')).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('forgotPassword', () => {
    it('should create reset row + send mail for known user', async () => {
      userTable().findUnique.mockResolvedValue(mockUser);

      await service.forgotPassword('test@example.com');

      expect(passwordResetTable().create).toHaveBeenCalledTimes(1);
      expect(mailService.sendPasswordResetEmail).toHaveBeenCalledTimes(1);
    });

    it('should silently no-op for unknown user (anti-enumeration)', async () => {
      userTable().findUnique.mockResolvedValue(null);

      await service.forgotPassword('nope@example.com');

      expect(passwordResetTable().create).not.toHaveBeenCalled();
      expect(mailService.sendPasswordResetEmail).not.toHaveBeenCalled();
    });
  });

  describe('resetPassword', () => {
    it('should reset password with valid token', async () => {
      passwordResetTable().findFirst.mockResolvedValue({
        id: 'pr-1',
        userId: 'user-1',
        tokenHash: 'hash',
        expiresAt: new Date(Date.now() + 3_600_000),
        consumedAt: null,
      });

      await service.resetPassword('raw-token', 'NewP@ssw0rd');

      expect(bcrypt.hash).toHaveBeenCalledWith('NewP@ssw0rd', 12);
      expect(userTable().update).toHaveBeenCalledWith({
        where: { id: 'user-1' },
        data: { passwordHash: 'hashed-password' },
      });
      expect(passwordResetTable().update).toHaveBeenCalled();
      expect(refreshTable().updateMany).toHaveBeenCalled();
    });

    it('should throw BadRequestException for unknown token', async () => {
      passwordResetTable().findFirst.mockResolvedValue(null);
      await expect(
        service.resetPassword('bad', 'NewP@ssw0rd'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException for expired token', async () => {
      passwordResetTable().findFirst.mockResolvedValue({
        id: 'pr-1',
        userId: 'user-1',
        tokenHash: 'hash',
        expiresAt: new Date(Date.now() - 1000),
        consumedAt: null,
      });
      await expect(
        service.resetPassword('expired', 'NewP@ssw0rd'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException for consumed token', async () => {
      passwordResetTable().findFirst.mockResolvedValue({
        id: 'pr-1',
        userId: 'user-1',
        tokenHash: 'hash',
        expiresAt: new Date(Date.now() + 3_600_000),
        consumedAt: new Date(),
      });
      await expect(
        service.resetPassword('used', 'NewP@ssw0rd'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('refresh', () => {
    it('should rotate refresh token: revoke old + create new', async () => {
      refreshTable().findUnique.mockResolvedValue({
        id: 'rt-old',
        userId: 'user-1',
        tokenHash: 'hash',
        expiresAt: new Date(Date.now() + 1_000_000),
        revokedAt: null,
      });

      const result = await service.refresh('valid-refresh');

      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
      expect(refreshTable().update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'rt-old' },
          data: expect.objectContaining({
            revokedAt: expect.any(Date),
            replacedBy: expect.any(String),
          }),
        }),
      );
      expect(refreshTable().create).toHaveBeenCalled();
    });

    it('should throw UnauthorizedException for revoked token (theft signal: revoke all)', async () => {
      refreshTable().findUnique.mockResolvedValue({
        id: 'rt-old',
        userId: 'user-1',
        tokenHash: 'hash',
        expiresAt: new Date(Date.now() + 1_000_000),
        revokedAt: new Date(),
      });

      await expect(service.refresh('revoked')).rejects.toThrow(
        UnauthorizedException,
      );
      expect(refreshTable().updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ userId: 'user-1' }),
        }),
      );
    });

    it('should throw UnauthorizedException for unknown token', async () => {
      refreshTable().findUnique.mockResolvedValue(null);
      await expect(service.refresh('unknown')).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('should throw UnauthorizedException for invalid JWT', async () => {
      (jwtService.verify as ReturnType<typeof vi.fn>).mockImplementation(() => {
        throw new Error('bad');
      });
      await expect(service.refresh('not-a-jwt')).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('should throw UnauthorizedException for expired DB row', async () => {
      refreshTable().findUnique.mockResolvedValue({
        id: 'rt-old',
        userId: 'user-1',
        tokenHash: 'hash',
        expiresAt: new Date(Date.now() - 1000),
        revokedAt: null,
      });
      await expect(service.refresh('expired')).rejects.toThrow(
        UnauthorizedException,
      );
    });
  });

  describe('logout', () => {
    it('should blacklist access token', async () => {
      await service.logout('access-token');
      expect(jwtBlacklist.blacklist).toHaveBeenCalled();
    });

    it('should also revoke refresh token row when refresh provided', async () => {
      refreshTable().findUnique.mockResolvedValue({
        id: 'rt-1',
        userId: 'user-1',
        tokenHash: 'hash',
        expiresAt: new Date(Date.now() + 1_000_000),
        revokedAt: null,
      });

      await service.logout('access-token', 'refresh-token');
      expect(refreshTable().update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'rt-1' },
          data: expect.objectContaining({ revokedAt: expect.any(Date) }),
        }),
      );
    });

    it('should not throw when refresh token unknown', async () => {
      refreshTable().findUnique.mockResolvedValue(null);
      await expect(
        service.logout('access-token', 'unknown-refresh'),
      ).resolves.not.toThrow();
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
      expect(profile.picture).toBe('https://photo.url');
    });

    it('should throw BadRequestException for unsupported provider', async () => {
      await expect(
        service.verifySocialToken('twitter', 'token'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw UnauthorizedException for invalid token', async () => {
      mockFetch.mockResolvedValue({ ok: false, status: 401 });
      await expect(
        service.verifySocialToken('google', 'bad'),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('should verify Google audience when GOOGLE_CLIENT_ID is configured', async () => {
      (configService.get as ReturnType<typeof vi.fn>).mockImplementation(
        (k: string, d?: unknown) =>
          k === 'GOOGLE_CLIENT_ID' ? 'our-client-id.apps.googleusercontent.com' : d,
      );
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: () =>
            Promise.resolve({
              aud: 'our-client-id.apps.googleusercontent.com',
              exp: String(Math.floor(Date.now() / 1000) + 600),
            }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: () =>
            Promise.resolve({
              id: 'g-1',
              email: 'u@gmail.com',
              name: 'U',
            }),
        });
      const profile = await service.verifySocialToken('google', 'tok');
      expect(profile.id).toBe('g-1');
      expect(mockFetch).toHaveBeenCalledTimes(2);
      expect(mockFetch.mock.calls[0][0]).toContain(
        'oauth2.googleapis.com/tokeninfo',
      );
    });

  });

  describe('sessions', () => {
    it('should list active sessions ordered by createdAt desc', async () => {
      const rows = [
        {
          id: 'rt-2',
          deviceId: 'iPhone',
          userAgent: 'iOS-App/1.0',
          ip: '1.2.3.4',
          expiresAt: new Date(Date.now() + 3600_000),
          createdAt: new Date('2026-04-17'),
        },
        {
          id: 'rt-1',
          deviceId: 'Web',
          userAgent: 'Chrome',
          ip: '5.6.7.8',
          expiresAt: new Date(Date.now() + 3600_000),
          createdAt: new Date('2026-04-10'),
        },
      ];
      refreshTable().findMany.mockResolvedValue(rows);

      const list = await service.listSessions('user-1');

      expect(refreshTable().findMany).toHaveBeenCalledWith({
        where: {
          userId: 'user-1',
          revokedAt: null,
          expiresAt: { gt: expect.any(Date) },
        },
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          deviceId: true,
          userAgent: true,
          ip: true,
          expiresAt: true,
          createdAt: true,
        },
      });
      expect(list).toHaveLength(2);
      expect(list[0].id).toBe('rt-2');
    });

    it('should revoke a session owned by the user', async () => {
      refreshTable().findUnique.mockResolvedValue({
        id: 'rt-9',
        userId: 'user-1',
        revokedAt: null,
      });
      await service.revokeSession('user-1', 'rt-9');
      expect(refreshTable().update).toHaveBeenCalledWith({
        where: { id: 'rt-9' },
        data: { revokedAt: expect.any(Date) },
      });
    });

    it('should throw NotFound when the session does not belong to the user', async () => {
      refreshTable().findUnique.mockResolvedValue({
        id: 'rt-9',
        userId: 'someone-else',
        revokedAt: null,
      });
      await expect(
        service.revokeSession('user-1', 'rt-9'),
      ).rejects.toThrow(/not found/i);
    });

    it('should throw NotFound when the session does not exist', async () => {
      refreshTable().findUnique.mockResolvedValue(null);
      await expect(
        service.revokeSession('user-1', 'missing'),
      ).rejects.toThrow(/not found/i);
    });

    it('should be idempotent when the session is already revoked', async () => {
      refreshTable().findUnique.mockResolvedValue({
        id: 'rt-9',
        userId: 'user-1',
        revokedAt: new Date(),
      });
      await service.revokeSession('user-1', 'rt-9');
      expect(refreshTable().update).not.toHaveBeenCalled();
    });
  });

  describe('verifySocialToken audience mismatch', () => {
    it('should reject a Google token when audience does not match', async () => {
      (configService.get as ReturnType<typeof vi.fn>).mockImplementation(
        (k: string, d?: unknown) =>
          k === 'GOOGLE_CLIENT_ID' ? 'our-client-id.apps.googleusercontent.com' : d,
      );
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () =>
          Promise.resolve({
            aud: 'someone-else.apps.googleusercontent.com',
            exp: String(Math.floor(Date.now() / 1000) + 600),
          }),
      });
      await expect(
        service.verifySocialToken('google', 'tok'),
      ).rejects.toThrow(UnauthorizedException);
    });
  });
});
