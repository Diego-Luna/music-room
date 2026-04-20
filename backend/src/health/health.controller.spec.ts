import { Test, TestingModule } from '@nestjs/testing';
import { HealthController } from './health.controller';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import { createMockPrismaService } from '@test/helpers/prisma-test.helper';
import { createMockRedisService } from '@test/helpers/redis-test.helper';

describe('HealthController', () => {
  let controller: HealthController;
  let prismaService: Partial<PrismaService>;
  let redisService: Partial<RedisService>;

  beforeEach(async () => {
    prismaService = createMockPrismaService();
    redisService = createMockRedisService();

    const module: TestingModule = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        { provide: PrismaService, useValue: prismaService },
        { provide: RedisService, useValue: redisService },
      ],
    }).compile();

    controller = module.get<HealthController>(HealthController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('check', () => {
    it('should return ok when both services are healthy', async () => {
      (prismaService.isHealthy as ReturnType<typeof vi.fn>).mockResolvedValue(
        true,
      );
      (redisService.isHealthy as ReturnType<typeof vi.fn>).mockResolvedValue(
        true,
      );

      const result = await controller.check();

      expect(result.status).toBe('ok');
      expect(result.db).toBe('connected');
      expect(result.redis).toBe('connected');
      expect(result.uptime).toBeGreaterThan(0);
    });

    it('should return error when DB is unhealthy', async () => {
      (prismaService.isHealthy as ReturnType<typeof vi.fn>).mockResolvedValue(
        false,
      );
      (redisService.isHealthy as ReturnType<typeof vi.fn>).mockResolvedValue(
        true,
      );

      const result = await controller.check();

      expect(result.status).toBe('error');
      expect(result.db).toBe('disconnected');
      expect(result.redis).toBe('connected');
    });

    it('should return error when Redis is unhealthy', async () => {
      (prismaService.isHealthy as ReturnType<typeof vi.fn>).mockResolvedValue(
        true,
      );
      (redisService.isHealthy as ReturnType<typeof vi.fn>).mockResolvedValue(
        false,
      );

      const result = await controller.check();

      expect(result.status).toBe('error');
      expect(result.db).toBe('connected');
      expect(result.redis).toBe('disconnected');
    });

    it('should return error when both services are unhealthy', async () => {
      (prismaService.isHealthy as ReturnType<typeof vi.fn>).mockResolvedValue(
        false,
      );
      (redisService.isHealthy as ReturnType<typeof vi.fn>).mockResolvedValue(
        false,
      );

      const result = await controller.check();

      expect(result.status).toBe('error');
      expect(result.db).toBe('disconnected');
      expect(result.redis).toBe('disconnected');
    });
  });
});
