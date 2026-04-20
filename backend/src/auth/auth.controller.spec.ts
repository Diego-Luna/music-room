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

  describe('register', () => {
    it('should register and return tokens', async () => {
      const result = await controller.register({
        email: 'user@example.com',
        password: 'MyP@ssw0rd',
        displayName: 'User',
      });

      expect(result).toEqual(mockTokens);
      expect(authService.register).toHaveBeenCalled();
    });
  });

  describe('login', () => {
    it('should login and return tokens', async () => {
      const result = await controller.login({
        email: 'user@example.com',
        password: 'MyP@ssw0rd',
      });

      expect(result).toEqual(mockTokens);
      expect(authService.login).toHaveBeenCalledWith(
        'user@example.com',
        'MyP@ssw0rd',
      );
    });
  });

  describe('socialLogin', () => {
    it('should login via social and return tokens', async () => {
      const result = await controller.socialLogin({
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
      const result = await controller.refresh({
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
  });
});
