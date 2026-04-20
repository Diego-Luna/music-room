import { Test, TestingModule } from '@nestjs/testing';
import {
  FastifyAdapter,
  NestFastifyApplication,
} from '@nestjs/platform-fastify';
import { ValidationPipe } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { AuthModule } from '@/auth/auth.module';
import { PrismaModule } from '@/prisma/prisma.module';
import { PrismaService } from '@/prisma/prisma.service';
import { RedisModule } from '@/redis/redis.module';
import { RedisService } from '@/redis/redis.service';
import { JwtAuthGuard } from '@/common/guards/jwt-auth.guard';
import { createMockRedisService } from '@test/helpers/redis-test.helper';
import {
  TEST_JWT_SECRET,
  TEST_JWT_REFRESH_SECRET,
} from '@test/helpers/auth-test.helper';

/**
 * E2E tests for the auth module.
 * Uses in-memory mocks for Prisma and Redis to avoid external dependencies.
 */
describe('Auth (e2e)', () => {
  let app: NestFastifyApplication;
  let redisService: Partial<RedisService>;

  // In-memory user store for the mock Prisma
  let users: Record<string, Record<string, unknown>>;
  let socialAccounts: Record<string, Record<string, unknown>>;

  const mockPrismaService = () => {
    users = {};
    socialAccounts = {};

    return {
      user: {
        findUnique: vi.fn(({ where }: { where: Record<string, string> }) => {
          if (where.email) {
            return Promise.resolve(
              Object.values(users).find((u) => u.email === where.email) ?? null,
            );
          }
          if (where.id) {
            return Promise.resolve(users[where.id] ?? null);
          }
          return Promise.resolve(null);
        }),
        findFirst: vi.fn(({ where }: { where: Record<string, unknown> }) => {
          if (where.emailVerifyToken) {
            return Promise.resolve(
              Object.values(users).find(
                (u) => u.emailVerifyToken === where.emailVerifyToken,
              ) ?? null,
            );
          }
          if (where.resetPasswordToken) {
            return Promise.resolve(
              Object.values(users).find(
                (u) => u.resetPasswordToken === where.resetPasswordToken,
              ) ?? null,
            );
          }
          return Promise.resolve(null);
        }),
        create: vi.fn(({ data }: { data: Record<string, unknown> }) => {
          const id = `user-${Date.now()}-${Math.random().toString(36).slice(2)}`;
          const user = {
            id,
            ...data,
            emailVerified: data.emailVerified ?? false,
            visibility: 'PUBLIC',
            musicPreferences: [],
            createdAt: new Date(),
            updatedAt: new Date(),
          };
          users[id] = user;
          return Promise.resolve(user);
        }),
        update: vi.fn(
          ({
            where,
            data,
          }: {
            where: Record<string, string>;
            data: Record<string, unknown>;
          }) => {
            const user = users[where.id];
            if (!user) return Promise.resolve(null);
            Object.assign(user, data, { updatedAt: new Date() });
            return Promise.resolve(user);
          },
        ),
      },
      socialAccount: {
        findUnique: vi.fn(() => Promise.resolve(null)),
        create: vi.fn(({ data }: { data: Record<string, unknown> }) => {
          const id = `social-${Date.now()}`;
          const sa = { id, ...data, createdAt: new Date() };
          socialAccounts[id] = sa;
          return Promise.resolve(sa);
        }),
      },
      $connect: vi.fn(),
      $disconnect: vi.fn(),
    };
  };

  beforeAll(async () => {
    redisService = createMockRedisService();

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
        PrismaModule,
        RedisModule,
        AuthModule,
      ],
      providers: [
        {
          provide: APP_GUARD,
          useClass: JwtAuthGuard,
        },
      ],
    })
      .overrideProvider(PrismaService)
      .useFactory({ factory: mockPrismaService })
      .overrideProvider(RedisService)
      .useValue(redisService)
      .compile();

    app = module.createNestApplication<NestFastifyApplication>(
      new FastifyAdapter(),
    );
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('POST /auth/register', () => {
    it('should register a new user and return tokens', async () => {
      const result = await app.inject({
        method: 'POST',
        url: '/auth/register',
        payload: {
          email: 'newuser@example.com',
          password: 'MyP@ssw0rd',
          displayName: 'New User',
        },
      });

      expect(result.statusCode).toBe(201);
      const body = JSON.parse(result.payload);
      expect(body).toHaveProperty('accessToken');
      expect(body).toHaveProperty('refreshToken');
    });

    it('should return 409 for duplicate email', async () => {
      // First registration
      await app.inject({
        method: 'POST',
        url: '/auth/register',
        payload: {
          email: 'duplicate@example.com',
          password: 'MyP@ssw0rd',
          displayName: 'User',
        },
      });

      // Second registration with same email
      const result = await app.inject({
        method: 'POST',
        url: '/auth/register',
        payload: {
          email: 'duplicate@example.com',
          password: 'MyP@ssw0rd',
          displayName: 'User 2',
        },
      });

      expect(result.statusCode).toBe(409);
    });

    it('should return 400 for weak password', async () => {
      const result = await app.inject({
        method: 'POST',
        url: '/auth/register',
        payload: {
          email: 'weak@example.com',
          password: 'weak',
          displayName: 'User',
        },
      });

      expect(result.statusCode).toBe(400);
    });

    it('should return 400 for invalid email', async () => {
      const result = await app.inject({
        method: 'POST',
        url: '/auth/register',
        payload: {
          email: 'not-an-email',
          password: 'MyP@ssw0rd',
          displayName: 'User',
        },
      });

      expect(result.statusCode).toBe(400);
    });
  });

  describe('POST /auth/login', () => {
    it('should login with valid credentials', async () => {
      // Register first
      await app.inject({
        method: 'POST',
        url: '/auth/register',
        payload: {
          email: 'login@example.com',
          password: 'MyP@ssw0rd',
          displayName: 'Login User',
        },
      });

      // Login
      const result = await app.inject({
        method: 'POST',
        url: '/auth/login',
        payload: {
          email: 'login@example.com',
          password: 'MyP@ssw0rd',
        },
      });

      expect(result.statusCode).toBe(200);
      const body = JSON.parse(result.payload);
      expect(body).toHaveProperty('accessToken');
      expect(body).toHaveProperty('refreshToken');
    });

    it('should return 401 for wrong password', async () => {
      const result = await app.inject({
        method: 'POST',
        url: '/auth/login',
        payload: {
          email: 'login@example.com',
          password: 'WrongP@ss1',
        },
      });

      expect(result.statusCode).toBe(401);
    });

    it('should return 401 for non-existent user', async () => {
      const result = await app.inject({
        method: 'POST',
        url: '/auth/login',
        payload: {
          email: 'nonexistent@example.com',
          password: 'MyP@ssw0rd',
        },
      });

      expect(result.statusCode).toBe(401);
    });
  });

  describe('POST /auth/verify-email', () => {
    it('should verify email with valid token', async () => {
      // Register to get user with verify token
      await app.inject({
        method: 'POST',
        url: '/auth/register',
        payload: {
          email: 'verify@example.com',
          password: 'MyP@ssw0rd',
          displayName: 'Verify User',
        },
      });

      // Find the verify token from our in-memory store
      const user = Object.values(users).find(
        (u) => u.email === 'verify@example.com',
      );

      const result = await app.inject({
        method: 'POST',
        url: '/auth/verify-email',
        payload: { token: user!.emailVerifyToken },
      });

      expect(result.statusCode).toBe(200);
    });

    it('should return 400 for invalid token', async () => {
      const result = await app.inject({
        method: 'POST',
        url: '/auth/verify-email',
        payload: { token: 'invalid-token' },
      });

      expect(result.statusCode).toBe(400);
    });
  });

  describe('POST /auth/forgot-password', () => {
    it('should always return 200 (prevent email enumeration)', async () => {
      const result = await app.inject({
        method: 'POST',
        url: '/auth/forgot-password',
        payload: { email: 'unknown@example.com' },
      });

      expect(result.statusCode).toBe(200);
    });
  });

  describe('POST /auth/reset-password', () => {
    it('should reset password with valid token', async () => {
      // Register and trigger forgot-password
      await app.inject({
        method: 'POST',
        url: '/auth/register',
        payload: {
          email: 'reset@example.com',
          password: 'OldP@ssw0rd',
          displayName: 'Reset User',
        },
      });

      await app.inject({
        method: 'POST',
        url: '/auth/forgot-password',
        payload: { email: 'reset@example.com' },
      });

      const user = Object.values(users).find(
        (u) => u.email === 'reset@example.com',
      );

      const result = await app.inject({
        method: 'POST',
        url: '/auth/reset-password',
        payload: {
          token: user!.resetPasswordToken,
          newPassword: 'NewP@ssw0rd',
        },
      });

      expect(result.statusCode).toBe(200);
    });

    it('should return 400 for invalid reset token', async () => {
      const result = await app.inject({
        method: 'POST',
        url: '/auth/reset-password',
        payload: {
          token: 'bad-token',
          newPassword: 'NewP@ssw0rd',
        },
      });

      expect(result.statusCode).toBe(400);
    });
  });

  describe('POST /auth/refresh', () => {
    it('should return new tokens for valid refresh token', async () => {
      // Register to get tokens
      const registerResult = await app.inject({
        method: 'POST',
        url: '/auth/register',
        payload: {
          email: 'refresh@example.com',
          password: 'MyP@ssw0rd',
          displayName: 'Refresh User',
        },
      });

      const { refreshToken } = JSON.parse(registerResult.payload);

      const result = await app.inject({
        method: 'POST',
        url: '/auth/refresh',
        payload: { refreshToken },
      });

      expect(result.statusCode).toBe(200);
      const body = JSON.parse(result.payload);
      expect(body).toHaveProperty('accessToken');
      expect(body).toHaveProperty('refreshToken');
    });

    it('should return 401 for invalid refresh token', async () => {
      const result = await app.inject({
        method: 'POST',
        url: '/auth/refresh',
        payload: { refreshToken: 'invalid-token' },
      });

      expect(result.statusCode).toBe(401);
    });
  });

  describe('POST /auth/logout', () => {
    it('should logout with valid access token', async () => {
      // Register to get tokens
      const registerResult = await app.inject({
        method: 'POST',
        url: '/auth/register',
        payload: {
          email: 'logout@example.com',
          password: 'MyP@ssw0rd',
          displayName: 'Logout User',
        },
      });

      const { accessToken, refreshToken } = JSON.parse(
        registerResult.payload,
      );

      const result = await app.inject({
        method: 'POST',
        url: '/auth/logout',
        headers: {
          authorization: `Bearer ${accessToken}`,
        },
        payload: { refreshToken },
      });

      expect(result.statusCode).toBe(200);
      expect(redisService.set).toHaveBeenCalled();
    });

    it('should return 401 without auth token', async () => {
      const result = await app.inject({
        method: 'POST',
        url: '/auth/logout',
        payload: {},
      });

      expect(result.statusCode).toBe(401);
    });
  });

  describe('POST /auth/link-social', () => {
    it('should return 401 without auth token', async () => {
      const result = await app.inject({
        method: 'POST',
        url: '/auth/link-social',
        payload: {
          provider: 'google',
          accessToken: 'some-token',
        },
      });

      expect(result.statusCode).toBe(401);
    });
  });
});
