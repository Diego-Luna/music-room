import { Test, TestingModule } from '@nestjs/testing';
import {
  FastifyAdapter,
  NestFastifyApplication,
} from '@nestjs/platform-fastify';
import { ValidationPipe } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { AuthModule } from '@/auth/auth.module';
import { PrismaModule } from '@/prisma/prisma.module';
import { PrismaService } from '@/prisma/prisma.service';
import { RedisModule } from '@/redis/redis.module';
import { RedisService } from '@/redis/redis.service';
import { MailService } from '@/mail/mail.service';
import { JwtAuthGuard } from '@/common/guards/jwt-auth.guard';
import { createMockRedisService } from '@test/helpers/redis-test.helper';
import {
  TEST_JWT_SECRET,
  TEST_JWT_REFRESH_SECRET,
} from '@test/helpers/auth-test.helper';

describe('Rate limit (e2e)', () => {
  let app: NestFastifyApplication;
  const AUTH_LIMIT = 3;

  beforeAll(async () => {
    const users: Record<string, Record<string, unknown>> = {};
    const prisma = {
      user: {
        findUnique: vi.fn(({ where }: { where: Record<string, string> }) =>
          Promise.resolve(
            Object.values(users).find((u) => u.email === where.email) ?? null,
          ),
        ),
        findFirst: vi.fn(() => Promise.resolve(null)),
        create: vi.fn(({ data }) => {
          const id = `u-${Object.keys(users).length + 1}`;
          users[id] = { id, ...data };
          return Promise.resolve(users[id]);
        }),
        update: vi.fn(() => Promise.resolve(null)),
      },
      socialAccount: { findUnique: vi.fn(() => Promise.resolve(null)) },
      verificationToken: {
        create: vi.fn(() => Promise.resolve({})),
        findUnique: vi.fn(() => Promise.resolve(null)),
        delete: vi.fn(() => Promise.resolve({})),
        deleteMany: vi.fn(() => Promise.resolve({ count: 0 })),
      },
      passwordResetToken: {
        create: vi.fn(() => Promise.resolve({})),
        findUnique: vi.fn(() => Promise.resolve(null)),
        delete: vi.fn(() => Promise.resolve({})),
        deleteMany: vi.fn(() => Promise.resolve({ count: 0 })),
      },
      refreshToken: {
        create: vi.fn(() => Promise.resolve({})),
        findUnique: vi.fn(() => Promise.resolve(null)),
        findFirst: vi.fn(() => Promise.resolve(null)),
        findMany: vi.fn(() => Promise.resolve([])),
        update: vi.fn(() => Promise.resolve({})),
        delete: vi.fn(() => Promise.resolve({})),
        deleteMany: vi.fn(() => Promise.resolve({ count: 0 })),
      },
      $transaction: vi.fn(async (cb: unknown) =>
        typeof cb === 'function' ? (cb as (p: unknown) => unknown)(prisma) : cb,
      ),
    };
    const redis = createMockRedisService();
    const mail = {
      sendVerificationEmail: vi.fn(() => Promise.resolve()),
      sendPasswordResetEmail: vi.fn(() => Promise.resolve()),
      sendEmail: vi.fn(() => Promise.resolve()),
    };

    const module: TestingModule = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          load: [
            () => ({
              JWT_SECRET: TEST_JWT_SECRET,
              JWT_REFRESH_SECRET: TEST_JWT_REFRESH_SECRET,
              JWT_EXPIRES_IN_SECONDS: 900,
              JWT_REFRESH_EXPIRES_IN_SECONDS: 604800,
            }),
          ],
        }),
        ThrottlerModule.forRoot([
          { name: 'default', ttl: 60000, limit: 100 },
          { name: 'auth', ttl: 60000, limit: AUTH_LIMIT },
        ]),
        PrismaModule,
        RedisModule,
        AuthModule,
      ],
      providers: [
        { provide: APP_GUARD, useClass: ThrottlerGuard },
        { provide: APP_GUARD, useClass: JwtAuthGuard },
      ],
    })
      .overrideProvider(PrismaService)
      .useValue(prisma)
      .overrideProvider(RedisService)
      .useValue(redis)
      .overrideProvider(MailService)
      .useValue(mail)
      .compile();

    app = module.createNestApplication<NestFastifyApplication>(
      new FastifyAdapter({ trustProxy: true }),
    );
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true }),
    );
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
  });

  afterAll(async () => {
    await app.close();
  });

  it('returns 429 after the auth bucket is exhausted on /auth/login', async () => {
    const payload = { email: 'brute@example.com', password: 'WrongP@ss123' };
    const statuses: number[] = [];

    for (let i = 0; i < AUTH_LIMIT + 2; i++) {
      const res = await app.inject({
        method: 'POST',
        url: '/auth/login',
        headers: { 'x-forwarded-for': '10.0.0.99' },
        payload,
      });
      statuses.push(res.statusCode);
    }

    // First AUTH_LIMIT requests pass through the limiter (return 401 — bad creds),
    // the ones after are 429.
    expect(statuses.slice(0, AUTH_LIMIT).every((s) => s === 401)).toBe(true);
    expect(statuses.slice(AUTH_LIMIT).every((s) => s === 429)).toBe(true);
  });
});
