import { Test, TestingModule } from '@nestjs/testing';
import {
  FastifyAdapter,
  NestFastifyApplication,
} from '@nestjs/platform-fastify';
import { HealthModule } from '@/health/health.module';
import { PrismaService } from '@/prisma/prisma.service';
import { RedisService } from '@/redis/redis.service';
import { createMockPrismaService } from '@test/helpers/prisma-test.helper';
import { createMockRedisService } from '@test/helpers/redis-test.helper';

describe('Health (e2e)', () => {
  let app: NestFastifyApplication;
  let prismaService: Partial<PrismaService>;
  let redisService: Partial<RedisService>;

  beforeAll(async () => {
    prismaService = createMockPrismaService();
    redisService = createMockRedisService();

    const module: TestingModule = await Test.createTestingModule({
      controllers: [(await import('@/health/health.controller')).HealthController],
      providers: [
        { provide: PrismaService, useValue: prismaService },
        { provide: RedisService, useValue: redisService },
      ],
    }).compile();

    app = module.createNestApplication<NestFastifyApplication>(
      new FastifyAdapter(),
    );
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /health should return 200 with status ok', async () => {
    (prismaService.isHealthy as ReturnType<typeof vi.fn>).mockResolvedValue(
      true,
    );
    (redisService.isHealthy as ReturnType<typeof vi.fn>).mockResolvedValue(
      true,
    );

    const result = await app.inject({
      method: 'GET',
      url: '/health',
    });

    expect(result.statusCode).toBe(200);
    const body = JSON.parse(result.payload);
    expect(body.status).toBe('ok');
    expect(body.db).toBe('connected');
    expect(body.redis).toBe('connected');
    expect(body.uptime).toBeDefined();
  });

  it('GET /health should return status error when DB is down', async () => {
    (prismaService.isHealthy as ReturnType<typeof vi.fn>).mockResolvedValue(
      false,
    );
    (redisService.isHealthy as ReturnType<typeof vi.fn>).mockResolvedValue(
      true,
    );

    const result = await app.inject({
      method: 'GET',
      url: '/health',
    });

    expect(result.statusCode).toBe(200);
    const body = JSON.parse(result.payload);
    expect(body.status).toBe('error');
    expect(body.db).toBe('disconnected');
  });
});
