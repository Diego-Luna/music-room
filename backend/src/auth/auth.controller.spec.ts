import { Test, TestingModule } from '@nestjs/testing';
import { AuthController } from './auth.controller';
import { AuthService, TokenPair } from './auth.service';

describe('AuthController', () => {
  let controller: AuthController;
  let authService: Partial<AuthService>;

  const mockTokens: TokenPair = {
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  };

  beforeEach(async () => {
    authService = {
      register: vi.fn().mockResolvedValue(mockTokens),
      login: vi.fn().mockResolvedValue(mockTokens),
      socialLogin: vi.fn().mockResolvedValue(mockTokens),
      linkSocial: vi.fn().mockResolvedValue(undefined),
      verifyEmail: vi.fn().mockResolvedValue(undefined),
      forgotPassword: vi.fn().mockResolvedValue(undefined),
      resetPassword: vi.fn().mockResolvedValue(undefined),
      refresh: vi.fn().mockResolvedValue(mockTokens),
      logout: vi.fn().mockResolvedValue(undefined),
      listSessions: vi.fn().mockResolvedValue([
        {
          id: 'rt-1',
          deviceId: 'iPhone',
          userAgent: 'iOS-App/1.0',
          ip: '1.2.3.4',
          expiresAt: new Date(Date.now() + 3600_000),
          createdAt: new Date('2026-04-15'),
        },
      ]),
      revokeSession: vi.fn().mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [{ provide: AuthService, useValue: authService }],
    }).compile();

    controller = module.get<AuthController>(AuthController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  const fakeReq = {
    headers: {
      'x-device': 'iPhone-15',
      'user-agent': 'TestAgent/1.0',
      'x-forwarded-for': '1.2.3.4',
    },
    ip: '127.0.0.1',
  } as never;

  describe('register', () => {
    it('should register and return tokens with device context', async () => {
      const result = await controller.register(fakeReq, {
        email: 'user@example.com',
        password: 'MyP@ssw0rd',
        displayName: 'User',
      });

      expect(result).toEqual(mockTokens);
      expect(authService.register).toHaveBeenCalledWith(
        expect.objectContaining({ email: 'user@example.com' }),
        expect.objectContaining({
          deviceId: 'iPhone-15',
          userAgent: 'TestAgent/1.0',
          ip: '1.2.3.4',
        }),
      );
    });
  });

  describe('login', () => {
    it('should login and return tokens with device context', async () => {
      const result = await controller.login(fakeReq, {
        email: 'user@example.com',
        password: 'MyP@ssw0rd',
      });

      expect(result).toEqual(mockTokens);
      expect(authService.login).toHaveBeenCalledWith(
        'user@example.com',
        'MyP@ssw0rd',
        expect.objectContaining({ deviceId: 'iPhone-15' }),
      );
    });
  });

  describe('socialLogin', () => {
    it('should login via social and return tokens', async () => {
      const result = await controller.socialLogin(fakeReq, {
        provider: 'google',
        accessToken: 'google-token',
      });

      expect(result).toEqual(mockTokens);
    });
  });

  describe('linkSocial', () => {
    it('should link social account', async () => {
      const result = await controller.linkSocial(
        { sub: 'user-1', email: 'test@example.com' },
        { provider: 'facebook', accessToken: 'fb-token' },
      );

      expect(result.message).toBe('Social account linked successfully');
      expect(authService.linkSocial).toHaveBeenCalledWith('user-1', {
        provider: 'facebook',
        accessToken: 'fb-token',
      });
    });
  });

  describe('verifyEmail', () => {
    it('should verify email', async () => {
      const result = await controller.verifyEmail({ token: 'verify-token' });
      expect(result.message).toBe('Email verified successfully');
    });
  });

  describe('forgotPassword', () => {
    it('should send reset email', async () => {
      const result = await controller.forgotPassword({
        email: 'user@example.com',
      });
      expect(result.message).toContain('reset link');
    });
  });

  describe('resetPassword', () => {
    it('should reset password', async () => {
      const result = await controller.resetPassword({
        token: 'reset-token',
        newPassword: 'NewP@ssw0rd',
      });
      expect(result.message).toBe('Password reset successfully');
    });
  });

  describe('refresh', () => {
    it('should refresh tokens', async () => {
      const result = await controller.refresh(fakeReq, {
        refreshToken: 'old-refresh',
      });
      expect(result).toEqual(mockTokens);
    });
  });

  describe('logout', () => {
    it('should logout', async () => {
      const mockReq = {
        headers: { authorization: 'Bearer access-token' },
      } as never;

      const result = await controller.logout(mockReq, {
        refreshToken: 'refresh-token',
      });

      expect(result.message).toBe('Logged out successfully');
      expect(authService.logout).toHaveBeenCalledWith(
        'access-token',
        'refresh-token',
      );
    });

    it('should logout with empty access token when authorization header is missing', async () => {
      const mockReq = { headers: {} } as never;

      const result = await controller.logout(mockReq, {});

      expect(result.message).toBe('Logged out successfully');
      expect(authService.logout).toHaveBeenCalledWith('', undefined);
    });
  });

  describe('sessions', () => {
    it('GET /auth/sessions returns the current user sessions', async () => {
      const res = await controller.listSessions({
        sub: 'user-1',
        email: 'test@example.com',
      });
      expect(res).toHaveLength(1);
      expect(res[0].id).toBe('rt-1');
      expect(authService.listSessions).toHaveBeenCalledWith('user-1');
    });

    it('DELETE /auth/sessions/:id revokes a session', async () => {
      const res = await controller.revokeSession(
        { sub: 'user-1', email: 'test@example.com' },
        'rt-2',
      );
      expect(res.message).toBe('Session revoked');
      expect(authService.revokeSession).toHaveBeenCalledWith('user-1', 'rt-2');
    });
  });

  describe('deviceContext edge cases', () => {
    it('should take the first value when headers are arrays and fall back to req.ip', async () => {
      const arrayHeaderReq = {
        headers: {
          'x-device': ['Pixel-8', 'Pixel-9'],
          'user-agent': ['Agent/1', 'Agent/2'],
        },
        ip: '10.0.0.42',
      } as never;

      await controller.login(arrayHeaderReq, {
        email: 'user@example.com',
        password: 'MyP@ssw0rd',
      });

      expect(authService.login).toHaveBeenCalledWith(
        'user@example.com',
        'MyP@ssw0rd',
        expect.objectContaining({
          deviceId: 'Pixel-8',
          userAgent: 'Agent/1',
          ip: '10.0.0.42',
        }),
      );
    });
  });
});
