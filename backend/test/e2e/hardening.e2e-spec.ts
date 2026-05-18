import { Test, TestingModule } from '@nestjs/testing';
import {
  FastifyAdapter,
  NestFastifyApplication,
} from '@nestjs/platform-fastify';
import helmet from '@fastify/helmet';
import { PrismaService } from '@/prisma/prisma.service';
import { RedisService } from '@/redis/redis.service';
import { createMockPrismaService } from '@test/helpers/prisma-test.helper';
import { createMockRedisService } from '@test/helpers/redis-test.helper';

describe('Hardening (e2e)', () => {
  let app: NestFastifyApplication;

  beforeAll(async () => {
    const prismaService = createMockPrismaService();
    const redisService = createMockRedisService();
    (prismaService.isHealthy as ReturnType<typeof vi.fn>).mockResolvedValue(
      true,
    );
    (redisService.isHealthy as ReturnType<typeof vi.fn>).mockResolvedValue(
      true,
    );

    const module: TestingModule = await Test.createTestingModule({
      controllers: [
        (await import('@/health/health.controller')).HealthController,
      ],
      providers: [
        { provide: PrismaService, useValue: prismaService },
        { provide: RedisService, useValue: redisService },
      ],
    }).compile();

    app = module.createNestApplication<NestFastifyApplication>(
      new FastifyAdapter(),
    );
    await app.register(helmet, {
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'", "'unsafe-inline'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          imgSrc: ["'self'", 'data:', 'https:'],
          connectSrc: ["'self'"],
        },
      },
      crossOriginEmbedderPolicy: false,
    });
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
  });

  afterAll(async () => {
    await app.close();
  });

  it('sets the core security headers from Helmet', async () => {
    const res = await app.inject({ method: 'GET', url: '/health' });

    expect(res.statusCode).toBe(200);
    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['x-frame-options']).toBe('SAMEORIGIN');
    expect(res.headers['strict-transport-security']).toContain('max-age=');
    expect(res.headers['referrer-policy']).toBeDefined();
    expect(res.headers['x-dns-prefetch-control']).toBeDefined();
  });

  it('sets a restrictive Content-Security-Policy', async () => {
    const res = await app.inject({ method: 'GET', url: '/health' });

    const csp = res.headers['content-security-policy'] as string;
    expect(csp).toBeDefined();
    expect(csp).toContain("default-src 'self'");
    expect(csp).toContain("connect-src 'self'");
    expect(csp).toContain("img-src 'self' data: https:");
  });

  it('hides the X-Powered-By banner', async () => {
    const res = await app.inject({ method: 'GET', url: '/health' });
    expect(res.headers['x-powered-by']).toBeUndefined();
  });
});
