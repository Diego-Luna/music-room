import { Test, TestingModule } from '@nestjs/testing';
import { UnauthorizedException } from '@nestjs/common';
import { LocalStrategy } from './local.strategy';
import { AuthService } from '../auth.service';

describe('LocalStrategy', () => {
  let strategy: LocalStrategy;
  let authService: Partial<AuthService>;

  beforeEach(async () => {
    authService = {
      validateUser: vi.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        LocalStrategy,
        { provide: AuthService, useValue: authService },
      ],
    }).compile();

    strategy = module.get<LocalStrategy>(LocalStrategy);
  });

  it('should be defined', () => {
    expect(strategy).toBeDefined();
  });

  describe('validate', () => {
    it('should return user when credentials are valid', async () => {
      const mockUser = { id: 'user-1', email: 'test@example.com' };
      (authService.validateUser as ReturnType<typeof vi.fn>).mockResolvedValue(
        mockUser,
      );

      const result = await strategy.validate('test@example.com', 'password');
      expect(result).toEqual(mockUser);
    });

    it('should throw when credentials are invalid', async () => {
      (authService.validateUser as ReturnType<typeof vi.fn>).mockRejectedValue(
        new UnauthorizedException(),
      );

      await expect(
        strategy.validate('test@example.com', 'wrong'),
      ).rejects.toThrow(UnauthorizedException);
    });
  });
});
