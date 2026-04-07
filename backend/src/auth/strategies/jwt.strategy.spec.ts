import { UnauthorizedException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { JwtStrategy } from './jwt.strategy';
import { JwtBlacklistService } from '../jwt-blacklist.service';

describe('JwtStrategy', () => {
  let strategy: JwtStrategy;
  let jwtBlacklist: Partial<JwtBlacklistService>;

  beforeEach(async () => {
    jwtBlacklist = {
      isBlacklisted: vi.fn().mockResolvedValue(false),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        JwtStrategy,
        {
          provide: ConfigService,
          useValue: {
            get: vi.fn().mockReturnValue('test-secret'),
          },
        },
        { provide: JwtBlacklistService, useValue: jwtBlacklist },
      ],
    }).compile();

    strategy = module.get<JwtStrategy>(JwtStrategy);
  });

  it('should be defined', () => {
    expect(strategy).toBeDefined();
  });

  describe('validate', () => {
    it('should return payload for valid non-blacklisted token', async () => {
      const mockReq = {
        headers: { authorization: 'Bearer valid-token' },
      };

      const result = await strategy.validate(mockReq, {
        sub: 'user-1',
        email: 'test@example.com',
      });

      expect(result).toEqual({ sub: 'user-1', email: 'test@example.com' });
    });

    it('should throw UnauthorizedException for blacklisted token', async () => {
      (jwtBlacklist.isBlacklisted as ReturnType<typeof vi.fn>).mockResolvedValue(true);

      const mockReq = {
        headers: { authorization: 'Bearer blacklisted-token' },
      };

      await expect(
        strategy.validate(mockReq, {
          sub: 'user-1',
          email: 'test@example.com',
        }),
      ).rejects.toThrow(UnauthorizedException);
    });
  });
});
