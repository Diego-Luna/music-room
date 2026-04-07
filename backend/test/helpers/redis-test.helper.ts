import { RedisService } from '@/redis/redis.service';

export function createMockRedisService(): Partial<RedisService> {
  return {
    isHealthy: vi.fn().mockResolvedValue(true),
    set: vi.fn(),
    get: vi.fn(),
    del: vi.fn(),
    exists: vi.fn(),
    getClient: vi.fn(),
  };
}
