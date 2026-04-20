import { Test, TestingModule } from '@nestjs/testing';
import { JwtBlacklistService } from './jwt-blacklist.service';
import { RedisService } from '../redis/redis.service';
import { createMockRedisService } from '@test/helpers/redis-test.helper';

describe('JwtBlacklistService', () => {
  let service: JwtBlacklistService;
  let redisService: Partial<RedisService>;

  beforeEach(async () => {
    redisService = createMockRedisService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        JwtBlacklistService,
        { provide: RedisService, useValue: redisService },
      ],
    }).compile();

    service = module.get<JwtBlacklistService>(JwtBlacklistService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('blacklist', () => {
    it('should store token in Redis with TTL', async () => {
      await service.blacklist('test-token', 300);

      expect(redisService.set).toHaveBeenCalledWith(
        'jwt:blacklist:test-token',
        '1',
        300,
      );
    });
  });

  describe('isBlacklisted', () => {
    it('should return true when token is blacklisted', async () => {
      (redisService.exists as ReturnType<typeof vi.fn>).mockResolvedValue(true);

      const result = await service.isBlacklisted('blacklisted-token');
      expect(result).toBe(true);
      expect(redisService.exists).toHaveBeenCalledWith(
        'jwt:blacklist:blacklisted-token',
      );
    });

    it('should return false when token is not blacklisted', async () => {
      (redisService.exists as ReturnType<typeof vi.fn>).mockResolvedValue(
        false,
      );

      const result = await service.isBlacklisted('valid-token');
      expect(result).toBe(false);
    });
  });
});
