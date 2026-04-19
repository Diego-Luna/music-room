import { randomUUID } from 'node:crypto';
import { Test, TestingModule } from '@nestjs/testing';
import {
  FastifyAdapter,
  NestFastifyApplication,
} from '@nestjs/platform-fastify';
import { ValidationPipe } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { AuthModule } from '@/auth/auth.module';
import { UsersModule } from '@/users/users.module';
import { RoomsModule } from '@/rooms/rooms.module';
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

/**
 * E2E tests for the auth module.
 * Uses in-memory mocks for Prisma, Redis and Mail to avoid external dependencies.
 */
describe('Auth (e2e)', () => {
  let app: NestFastifyApplication;
  let redisService: Partial<RedisService>;
  let mailService: {
    sendVerificationEmail: ReturnType<typeof vi.fn>;
    sendPasswordResetEmail: ReturnType<typeof vi.fn>;
  };

  // In-memory stores
  let users: Record<string, Record<string, unknown>>;
  let socialAccounts: Record<string, Record<string, unknown>>;
  let refreshTokens: Record<string, Record<string, unknown>>;
  let emailVerifications: Record<string, Record<string, unknown>>;
  let passwordResets: Record<string, Record<string, unknown>>;
  let rooms: Record<string, Record<string, unknown>>;
  let roomMembers: Record<string, Record<string, unknown>>;
  let roomInvitations: Record<string, Record<string, unknown>>;

  const mockPrismaService = () => {
    users = {};
    socialAccounts = {};
    refreshTokens = {};
    emailVerifications = {};
    passwordResets = {};
    rooms = {};
    roomMembers = {};
    roomInvitations = {};

    const id = (_prefix: string) => randomUUID();

    const prismaInstance: Record<string, unknown> = {};
    Object.assign(prismaInstance, {
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
        findFirst: vi.fn(() => Promise.resolve(null)),
        create: vi.fn(({ data }: { data: Record<string, unknown> }) => {
          const userId = id('user');
          const user = {
            id: userId,
            ...data,
            emailVerified: data.emailVerified ?? false,
            visibility: 'PUBLIC',
            musicPreferences: [],
            createdAt: new Date(),
            updatedAt: new Date(),
          };
          users[userId] = user;
          // handle nested socialAccounts.create
          const nested = data.socialAccounts as
            | { create?: Record<string, unknown> }
            | undefined;
          if (nested?.create) {
            const saId = id('social');
            socialAccounts[saId] = {
              id: saId,
              ...nested.create,
              userId,
              createdAt: new Date(),
            };
          }
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
        findUnique: vi.fn(({ where }: { where: Record<string, unknown> }) => {
          const ppId = where.provider_providerId as
            | { provider: string; providerId: string }
            | undefined;
          if (ppId) {
            return Promise.resolve(
              Object.values(socialAccounts).find(
                (sa) =>
                  sa.provider === ppId.provider &&
                  sa.providerId === ppId.providerId,
              ) ?? null,
            );
          }
          const pUid = where.provider_userId as
            | { provider: string; userId: string }
            | undefined;
          if (pUid) {
            return Promise.resolve(
              Object.values(socialAccounts).find(
                (sa) =>
                  sa.provider === pUid.provider && sa.userId === pUid.userId,
              ) ?? null,
            );
          }
          return Promise.resolve(null);
        }),
        create: vi.fn(({ data }: { data: Record<string, unknown> }) => {
          const saId = id('social');
          const sa = { id: saId, ...data, createdAt: new Date() };
          socialAccounts[saId] = sa;
          return Promise.resolve(sa);
        }),
      },
      refreshToken: {
        create: vi.fn(({ data }: { data: Record<string, unknown> }) => {
          const rtId = id('rt');
          const rt = { id: rtId, ...data, revokedAt: null, createdAt: new Date() };
          refreshTokens[rtId] = rt;
          return Promise.resolve(rt);
        }),
        findUnique: vi.fn(({ where }: { where: Record<string, string> }) => {
          if (where.tokenHash) {
            return Promise.resolve(
              Object.values(refreshTokens).find(
                (rt) => rt.tokenHash === where.tokenHash,
              ) ?? null,
            );
          }
          if (where.id) {
            return Promise.resolve(refreshTokens[where.id] ?? null);
          }
          return Promise.resolve(null);
        }),
        findMany: vi.fn(
          ({
            where,
            orderBy,
          }: {
            where: Record<string, unknown>;
            orderBy?: Record<string, string>;
          }) => {
            const userId = where.userId as string | undefined;
            const requireActive = where.revokedAt === null;
            const expiresGate = where.expiresAt as
              | { gt?: Date }
              | undefined;
            let rows = Object.values(refreshTokens).filter((rt) => {
              if (userId && rt.userId !== userId) return false;
              if (requireActive && rt.revokedAt) return false;
              if (
                expiresGate?.gt &&
                (rt.expiresAt as Date).getTime() <= expiresGate.gt.getTime()
              ) {
                return false;
              }
              return true;
            });
            if (orderBy?.createdAt === 'desc') {
              rows = rows.sort(
                (a, b) =>
                  (b.createdAt as Date).getTime() -
                  (a.createdAt as Date).getTime(),
              );
            }
            return Promise.resolve(rows);
          },
        ),
        update: vi.fn(
          ({
            where,
            data,
          }: {
            where: Record<string, string>;
            data: Record<string, unknown>;
          }) => {
            const rt = refreshTokens[where.id];
            if (!rt) return Promise.resolve(null);
            Object.assign(rt, data);
            return Promise.resolve(rt);
          },
        ),
        updateMany: vi.fn(
          ({
            where,
            data,
          }: {
            where: Record<string, unknown>;
            data: Record<string, unknown>;
          }) => {
            const userId = where.userId as string | undefined;
            const onlyActive = (where.revokedAt as null) === null;
            let count = 0;
            for (const rt of Object.values(refreshTokens)) {
              if (userId && rt.userId !== userId) continue;
              if (onlyActive && rt.revokedAt) continue;
              Object.assign(rt, data);
              count++;
            }
            return Promise.resolve({ count });
          },
        ),
      },
      emailVerification: {
        create: vi.fn(({ data }: { data: Record<string, unknown> }) => {
          const evId = id('ev');
          const ev = {
            id: evId,
            ...data,
            consumedAt: null,
            createdAt: new Date(),
          };
          emailVerifications[evId] = ev;
          return Promise.resolve(ev);
        }),
        findFirst: vi.fn(({ where }: { where: Record<string, string> }) =>
          Promise.resolve(
            Object.values(emailVerifications).find(
              (ev) => ev.tokenHash === where.tokenHash,
            ) ?? null,
          ),
        ),
        update: vi.fn(
          ({
            where,
            data,
          }: {
            where: Record<string, string>;
            data: Record<string, unknown>;
          }) => {
            const ev = emailVerifications[where.id];
            if (!ev) return Promise.resolve(null);
            Object.assign(ev, data);
            return Promise.resolve(ev);
          },
        ),
      },
      passwordReset: {
        create: vi.fn(({ data }: { data: Record<string, unknown> }) => {
          const prId = id('pr');
          const pr = {
            id: prId,
            ...data,
            consumedAt: null,
            createdAt: new Date(),
          };
          passwordResets[prId] = pr;
          return Promise.resolve(pr);
        }),
        findFirst: vi.fn(({ where }: { where: Record<string, string> }) =>
          Promise.resolve(
            Object.values(passwordResets).find(
              (pr) => pr.tokenHash === where.tokenHash,
            ) ?? null,
          ),
        ),
        update: vi.fn(
          ({
            where,
            data,
          }: {
            where: Record<string, string>;
            data: Record<string, unknown>;
          }) => {
            const pr = passwordResets[where.id];
            if (!pr) return Promise.resolve(null);
            Object.assign(pr, data);
            return Promise.resolve(pr);
          },
        ),
        updateMany: vi.fn(() => Promise.resolve({ count: 0 })),
      },
      room: {
        create: vi.fn(({ data }: { data: Record<string, unknown> }) => {
          const roomId = id('room');
          const room = {
            id: roomId,
            ...data,
            visibility: data.visibility ?? 'PUBLIC',
            licenseTier: data.licenseTier ?? 'FREE',
            allowMembersEdit: data.allowMembersEdit ?? true,
            voteWindow: data.voteWindow ?? 'ALWAYS',
            createdAt: new Date(),
            updatedAt: new Date(),
          };
          rooms[roomId] = room;
          return Promise.resolve(room);
        }),
        findUnique: vi.fn(({ where }: { where: Record<string, string> }) =>
          Promise.resolve(rooms[where.id] ?? null),
        ),
        findMany: vi.fn(
          ({
            where,
            orderBy,
          }: {
            where?: { OR?: Array<Record<string, unknown>> };
            orderBy?: { createdAt?: string };
          }) => {
            let rows = Object.values(rooms);
            if (where?.OR) {
              rows = rows.filter((r) =>
                where.OR!.some((cond) => {
                  if ('visibility' in cond) {
                    return r.visibility === cond.visibility;
                  }
                  if ('ownerId' in cond) return r.ownerId === cond.ownerId;
                  if ('members' in cond) {
                    const userId = (
                      (cond.members as Record<string, unknown>).some as
                        | Record<string, string>
                        | undefined
                    )?.userId;
                    return Object.values(roomMembers).some(
                      (m) => m.roomId === r.id && m.userId === userId,
                    );
                  }
                  return false;
                }),
              );
            }
            if (orderBy?.createdAt === 'desc') {
              rows = rows.sort(
                (a, b) =>
                  (b.createdAt as Date).getTime() -
                  (a.createdAt as Date).getTime(),
              );
            }
            return Promise.resolve(rows);
          },
        ),
        update: vi.fn(
          ({
            where,
            data,
          }: {
            where: Record<string, string>;
            data: Record<string, unknown>;
          }) => {
            const room = rooms[where.id];
            if (!room) return Promise.resolve(null);
            for (const [k, v] of Object.entries(data)) {
              if (v === undefined) continue;
              room[k] = v;
            }
            room.updatedAt = new Date();
            return Promise.resolve(room);
          },
        ),
        delete: vi.fn(({ where }: { where: Record<string, string> }) => {
          const room = rooms[where.id];
          delete rooms[where.id];
          for (const [mid, m] of Object.entries(roomMembers)) {
            if (m.roomId === where.id) delete roomMembers[mid];
          }
          for (const [iid, inv] of Object.entries(roomInvitations)) {
            if (inv.roomId === where.id) delete roomInvitations[iid];
          }
          return Promise.resolve(room ?? null);
        }),
      },
      roomMember: {
        create: vi.fn(({ data }: { data: Record<string, unknown> }) => {
          const memberId = id('rm');
          const member = {
            id: memberId,
            ...data,
            role: data.role ?? 'MEMBER',
            joinedAt: new Date(),
          };
          roomMembers[memberId] = member;
          return Promise.resolve(member);
        }),
        findUnique: vi.fn(({ where }: { where: Record<string, unknown> }) => {
          const compound = where.roomId_userId as
            | { roomId: string; userId: string }
            | undefined;
          if (compound) {
            return Promise.resolve(
              Object.values(roomMembers).find(
                (m) =>
                  m.roomId === compound.roomId && m.userId === compound.userId,
              ) ?? null,
            );
          }
          return Promise.resolve(null);
        }),
        findMany: vi.fn(
          ({
            where,
          }: {
            where: { roomId: string };
          }) => {
            const rows = Object.values(roomMembers).filter(
              (m) => m.roomId === where.roomId,
            );
            return Promise.resolve(
              rows.map((m) => ({
                ...m,
                user: users[m.userId as string]
                  ? {
                      id: users[m.userId as string].id,
                      displayName: users[m.userId as string].displayName,
                      avatarUrl:
                        users[m.userId as string].avatarUrl ?? null,
                    }
                  : null,
              })),
            );
          },
        ),
        update: vi.fn(
          ({
            where,
            data,
          }: {
            where: { roomId_userId: { roomId: string; userId: string } };
            data: Record<string, unknown>;
          }) => {
            const m = Object.values(roomMembers).find(
              (rm) =>
                rm.roomId === where.roomId_userId.roomId &&
                rm.userId === where.roomId_userId.userId,
            );
            if (!m) return Promise.resolve(null);
            Object.assign(m, data);
            return Promise.resolve(m);
          },
        ),
        delete: vi.fn(
          ({
            where,
          }: {
            where: { roomId_userId: { roomId: string; userId: string } };
          }) => {
            const entry = Object.entries(roomMembers).find(
              ([, m]) =>
                m.roomId === where.roomId_userId.roomId &&
                m.userId === where.roomId_userId.userId,
            );
            if (!entry) return Promise.resolve(null);
            delete roomMembers[entry[0]];
            return Promise.resolve(entry[1]);
          },
        ),
      },
      roomInvitation: {
        create: vi.fn(({ data }: { data: Record<string, unknown> }) => {
          const invId = id('inv');
          const inv = {
            id: invId,
            ...data,
            status: data.status ?? 'PENDING',
            createdAt: new Date(),
            respondedAt: null,
          };
          roomInvitations[invId] = inv;
          return Promise.resolve(inv);
        }),
        findUnique: vi.fn(({ where }: { where: Record<string, string> }) =>
          Promise.resolve(roomInvitations[where.id] ?? null),
        ),
        findFirst: vi.fn(
          ({
            where,
          }: {
            where: Record<string, unknown>;
          }) => {
            const expiresGate = where.expiresAt as { gt?: Date } | undefined;
            const found = Object.values(roomInvitations).find((inv) => {
              if (where.roomId && inv.roomId !== where.roomId) return false;
              if (where.inviteeId && inv.inviteeId !== where.inviteeId) {
                return false;
              }
              if (where.status && inv.status !== where.status) return false;
              if (
                expiresGate?.gt &&
                (inv.expiresAt as Date).getTime() <= expiresGate.gt.getTime()
              ) {
                return false;
              }
              return true;
            });
            return Promise.resolve(found ?? null);
          },
        ),
        update: vi.fn(
          ({
            where,
            data,
          }: {
            where: Record<string, string>;
            data: Record<string, unknown>;
          }) => {
            const inv = roomInvitations[where.id];
            if (!inv) return Promise.resolve(null);
            Object.assign(inv, data);
            return Promise.resolve(inv);
          },
        ),
      },
      $transaction: vi.fn(async (fn: (tx: unknown) => Promise<unknown>) => {
        // mocks share the same prisma object → just pass it through
        return fn(prismaInstance);
      }),
      $connect: vi.fn(),
      $disconnect: vi.fn(),
    });
    return prismaInstance;
  };

  beforeAll(async () => {
    redisService = createMockRedisService();
    mailService = {
      sendVerificationEmail: vi.fn().mockResolvedValue(undefined),
      sendPasswordResetEmail: vi.fn().mockResolvedValue(undefined),
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
        PrismaModule,
        RedisModule,
        AuthModule,
        UsersModule,
        RoomsModule,
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
      .overrideProvider(MailService)
      .useValue(mailService)
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
    it('should register a new user, send verification email, return tokens', async () => {
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
      expect(mailService.sendVerificationEmail).toHaveBeenCalled();
    });

    it('should return 409 for duplicate email', async () => {
      await app.inject({
        method: 'POST',
        url: '/auth/register',
        payload: {
          email: 'duplicate@example.com',
          password: 'MyP@ssw0rd',
          displayName: 'User',
        },
      });

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
    beforeAll(async () => {
      await app.inject({
        method: 'POST',
        url: '/auth/register',
        payload: {
          email: 'login@example.com',
          password: 'MyP@ssw0rd',
          displayName: 'Login User',
        },
      });
    });

    it('should login with valid credentials', async () => {
      const result = await app.inject({
        method: 'POST',
        url: '/auth/login',
        payload: { email: 'login@example.com', password: 'MyP@ssw0rd' },
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
        payload: { email: 'login@example.com', password: 'WrongP@ss1' },
      });
      expect(result.statusCode).toBe(401);
    });

    it('should return 401 for non-existent user', async () => {
      const result = await app.inject({
        method: 'POST',
        url: '/auth/login',
        payload: { email: 'nope@example.com', password: 'MyP@ssw0rd' },
      });
      expect(result.statusCode).toBe(401);
    });
  });

  describe('POST /auth/verify-email', () => {
    it('should verify email with the token sent by mail', async () => {
      mailService.sendVerificationEmail.mockClear();

      await app.inject({
        method: 'POST',
        url: '/auth/register',
        payload: {
          email: 'verify@example.com',
          password: 'MyP@ssw0rd',
          displayName: 'Verify User',
        },
      });

      const sentToken = mailService.sendVerificationEmail.mock
        .calls[0][1] as string;
      expect(sentToken).toBeDefined();

      const result = await app.inject({
        method: 'POST',
        url: '/auth/verify-email',
        payload: { token: sentToken },
      });

      expect(result.statusCode).toBe(200);
      const userRow = Object.values(users).find(
        (u) => u.email === 'verify@example.com',
      );
      expect(userRow!.emailVerified).toBe(true);
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

  describe('POST /auth/forgot-password & /auth/reset-password', () => {
    it('should always return 200 for forgot-password (anti-enumeration)', async () => {
      const result = await app.inject({
        method: 'POST',
        url: '/auth/forgot-password',
        payload: { email: 'unknown@example.com' },
      });
      expect(result.statusCode).toBe(200);
    });

    it('should reset password using token from email', async () => {
      mailService.sendPasswordResetEmail.mockClear();

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

      const sentToken = mailService.sendPasswordResetEmail.mock
        .calls[0][1] as string;

      const result = await app.inject({
        method: 'POST',
        url: '/auth/reset-password',
        payload: { token: sentToken, newPassword: 'NewP@ssw0rd' },
      });
      expect(result.statusCode).toBe(200);

      // Old password no longer works
      const oldLogin = await app.inject({
        method: 'POST',
        url: '/auth/login',
        payload: { email: 'reset@example.com', password: 'OldP@ssw0rd' },
      });
      expect(oldLogin.statusCode).toBe(401);

      // New password works
      const newLogin = await app.inject({
        method: 'POST',
        url: '/auth/login',
        payload: { email: 'reset@example.com', password: 'NewP@ssw0rd' },
      });
      expect(newLogin.statusCode).toBe(200);
    });

    it('should return 400 for invalid reset token', async () => {
      const result = await app.inject({
        method: 'POST',
        url: '/auth/reset-password',
        payload: { token: 'bad-token', newPassword: 'NewP@ssw0rd' },
      });
      expect(result.statusCode).toBe(400);
    });
  });

  describe('POST /auth/refresh', () => {
    it('should return new tokens for valid refresh token and revoke the old one', async () => {
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

      // Reuse of revoked token must fail and revoke all family tokens
      const reuse = await app.inject({
        method: 'POST',
        url: '/auth/refresh',
        payload: { refreshToken },
      });
      expect(reuse.statusCode).toBe(401);
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
      const registerResult = await app.inject({
        method: 'POST',
        url: '/auth/register',
        payload: {
          email: 'logout@example.com',
          password: 'MyP@ssw0rd',
          displayName: 'Logout User',
        },
      });
      const { accessToken, refreshToken } = JSON.parse(registerResult.payload);

      const result = await app.inject({
        method: 'POST',
        url: '/auth/logout',
        headers: { authorization: `Bearer ${accessToken}` },
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
        payload: { provider: 'google', accessToken: 'token' },
      });
      expect(result.statusCode).toBe(401);
    });
  });

  describe('Sessions and /users/me', () => {
    const registerAnd = async (email: string) => {
      const res = await app.inject({
        method: 'POST',
        url: '/auth/register',
        payload: {
          email,
          password: 'MyP@ssw0rd',
          displayName: 'Session User',
        },
        headers: {
          'x-device': 'Pixel-8',
          'user-agent': 'MusicRoom/1.0',
          'x-forwarded-for': '10.0.0.7',
        },
      });
      return JSON.parse(res.payload) as {
        accessToken: string;
        refreshToken: string;
      };
    };

    it('GET /users/me returns the authenticated profile', async () => {
      const { accessToken } = await registerAnd('me@example.com');
      const res = await app.inject({
        method: 'GET',
        url: '/users/me',
        headers: { authorization: `Bearer ${accessToken}` },
      });
      expect(res.statusCode).toBe(200);
      const body = JSON.parse(res.payload);
      expect(body.email).toBe('me@example.com');
      expect(body.displayName).toBe('Session User');
      expect(body).not.toHaveProperty('passwordHash');
    });

    it('PATCH /users/me updates the profile', async () => {
      const { accessToken } = await registerAnd('update@example.com');
      const res = await app.inject({
        method: 'PATCH',
        url: '/users/me',
        headers: { authorization: `Bearer ${accessToken}` },
        payload: { displayName: 'Renamed', visibility: 'PRIVATE' },
      });
      expect(res.statusCode).toBe(200);
      const body = JSON.parse(res.payload);
      expect(body.displayName).toBe('Renamed');
      expect(body.visibility).toBe('PRIVATE');
    });

    it('GET /auth/sessions returns the active session and DELETE revokes it', async () => {
      const { accessToken } = await registerAnd('sessions@example.com');

      const list = await app.inject({
        method: 'GET',
        url: '/auth/sessions',
        headers: { authorization: `Bearer ${accessToken}` },
      });
      expect(list.statusCode).toBe(200);
      const sessions = JSON.parse(list.payload) as Array<{
        id: string;
        deviceId: string;
      }>;
      expect(sessions.length).toBeGreaterThanOrEqual(1);
      expect(sessions[0].deviceId).toBe('Pixel-8');

      const revoke = await app.inject({
        method: 'DELETE',
        url: `/auth/sessions/${sessions[0].id}`,
        headers: { authorization: `Bearer ${accessToken}` },
      });
      expect(revoke.statusCode).toBe(200);

      const listAfter = await app.inject({
        method: 'GET',
        url: '/auth/sessions',
        headers: { authorization: `Bearer ${accessToken}` },
      });
      const after = JSON.parse(listAfter.payload) as Array<{ id: string }>;
      expect(after.find((s) => s.id === sessions[0].id)).toBeUndefined();
    });

    it('DELETE /auth/sessions/:id returns 404 for a non-existent session', async () => {
      const { accessToken } = await registerAnd('ghost@example.com');
      const res = await app.inject({
        method: 'DELETE',
        url: '/auth/sessions/does-not-exist',
        headers: { authorization: `Bearer ${accessToken}` },
      });
      expect(res.statusCode).toBe(404);
    });
  });

  describe('Rooms', () => {
    const register = async (email: string) => {
      const res = await app.inject({
        method: 'POST',
        url: '/auth/register',
        payload: {
          email,
          password: 'MyP@ssw0rd',
          displayName: email.split('@')[0],
        },
      });
      const body = JSON.parse(res.payload) as { accessToken: string };
      // user id is created in the in-memory store; look it up by email
      const userRow = Object.values(users).find((u) => u.email === email)!;
      return { accessToken: body.accessToken, userId: userRow.id as string };
    };

    it('POST /rooms creates a room and adds the caller as OWNER', async () => {
      const { accessToken } = await register('owner@example.com');
      const res = await app.inject({
        method: 'POST',
        url: '/rooms',
        headers: { authorization: `Bearer ${accessToken}` },
        payload: { name: 'My Room', kind: 'VOTE' },
      });
      expect(res.statusCode).toBe(201);
      const room = JSON.parse(res.payload);
      expect(room.id).toBeDefined();
      expect(room.kind).toBe('VOTE');
      expect(room.visibility).toBe('PUBLIC');
    });

    it('GET /rooms lists public rooms and rooms owned by the caller', async () => {
      const { accessToken } = await register('lister@example.com');
      await app.inject({
        method: 'POST',
        url: '/rooms',
        headers: { authorization: `Bearer ${accessToken}` },
        payload: { name: 'Mine', kind: 'PLAYLIST' },
      });
      const res = await app.inject({
        method: 'GET',
        url: '/rooms',
        headers: { authorization: `Bearer ${accessToken}` },
      });
      expect(res.statusCode).toBe(200);
      const list = JSON.parse(res.payload);
      expect(list.length).toBeGreaterThanOrEqual(1);
    });

    it('GET /rooms/:id returns 404 for a PRIVATE room non-member', async () => {
      const { accessToken: ownerToken } = await register('priv-o@example.com');
      const created = await app.inject({
        method: 'POST',
        url: '/rooms',
        headers: { authorization: `Bearer ${ownerToken}` },
        payload: { name: 'Private', kind: 'VOTE', visibility: 'PRIVATE' },
      });
      const room = JSON.parse(created.payload);

      const { accessToken: outsider } = await register('priv-out@example.com');
      const res = await app.inject({
        method: 'GET',
        url: `/rooms/${room.id}`,
        headers: { authorization: `Bearer ${outsider}` },
      });
      expect(res.statusCode).toBe(404);
    });

    it('PATCH /rooms/:id rejects a non-owner non-admin', async () => {
      const { accessToken: ownerToken } = await register('upd-o@example.com');
      const created = await app.inject({
        method: 'POST',
        url: '/rooms',
        headers: { authorization: `Bearer ${ownerToken}` },
        payload: { name: 'Edit me', kind: 'PLAYLIST' },
      });
      const room = JSON.parse(created.payload);

      const { accessToken: stranger } = await register('upd-s@example.com');
      const res = await app.inject({
        method: 'PATCH',
        url: `/rooms/${room.id}`,
        headers: { authorization: `Bearer ${stranger}` },
        payload: { name: 'Hijacked' },
      });
      expect(res.statusCode).toBe(403);
    });

    it('POST /rooms/:id/join lets a user join a PUBLIC room and shows up in members', async () => {
      const { accessToken: ownerToken } = await register('join-o@example.com');
      const created = await app.inject({
        method: 'POST',
        url: '/rooms',
        headers: { authorization: `Bearer ${ownerToken}` },
        payload: { name: 'Open', kind: 'VOTE' },
      });
      const room = JSON.parse(created.payload);

      const { accessToken: joiner } = await register('joiner@example.com');
      const join = await app.inject({
        method: 'POST',
        url: `/rooms/${room.id}/join`,
        headers: { authorization: `Bearer ${joiner}` },
      });
      expect(join.statusCode).toBe(200);

      const members = await app.inject({
        method: 'GET',
        url: `/rooms/${room.id}/members`,
        headers: { authorization: `Bearer ${ownerToken}` },
      });
      const list = JSON.parse(members.payload);
      expect(list.length).toBe(2);
    });

    it('PRIVATE room: invite → join flow', async () => {
      const { accessToken: ownerToken } = await register('priv2-o@example.com');
      const { accessToken: inviteeTok, userId: inviteeId } = await register(
        'invitee@example.com',
      );

      const created = await app.inject({
        method: 'POST',
        url: '/rooms',
        headers: { authorization: `Bearer ${ownerToken}` },
        payload: { name: 'VIP', kind: 'VOTE', visibility: 'PRIVATE' },
      });
      const room = JSON.parse(created.payload);

      // Invitee cannot join without invite
      const reject = await app.inject({
        method: 'POST',
        url: `/rooms/${room.id}/join`,
        headers: { authorization: `Bearer ${inviteeTok}` },
      });
      expect(reject.statusCode).toBe(403);

      // Owner invites
      const inv = await app.inject({
        method: 'POST',
        url: `/rooms/${room.id}/invitations`,
        headers: { authorization: `Bearer ${ownerToken}` },
        payload: { userId: inviteeId },
      });
      expect(inv.statusCode).toBe(201);

      // Invitee can now join
      const accept = await app.inject({
        method: 'POST',
        url: `/rooms/${room.id}/join`,
        headers: { authorization: `Bearer ${inviteeTok}` },
      });
      expect(accept.statusCode).toBe(200);
    });

    it('DELETE /rooms/:id only the owner can delete', async () => {
      const { accessToken: ownerToken } = await register('del-o@example.com');
      const created = await app.inject({
        method: 'POST',
        url: '/rooms',
        headers: { authorization: `Bearer ${ownerToken}` },
        payload: { name: 'Doomed', kind: 'VOTE' },
      });
      const room = JSON.parse(created.payload);

      const { accessToken: stranger } = await register('del-s@example.com');
      const blocked = await app.inject({
        method: 'DELETE',
        url: `/rooms/${room.id}`,
        headers: { authorization: `Bearer ${stranger}` },
      });
      expect(blocked.statusCode).toBe(403);

      const ok = await app.inject({
        method: 'DELETE',
        url: `/rooms/${room.id}`,
        headers: { authorization: `Bearer ${ownerToken}` },
      });
      expect(ok.statusCode).toBe(200);
    });
  });
});
