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
import { DelegationModule } from '@/delegation/delegation.module';
import { PrismaModule } from '@/prisma/prisma.module';
import { PrismaService } from '@/prisma/prisma.service';
import { RedisModule } from '@/redis/redis.module';
import { RedisService } from '@/redis/redis.service';
import { MailService } from '@/mail/mail.service';
import { SpotifyService } from '@/spotify/spotify.service';
import { JwtAuthGuard } from '@/common/guards/jwt-auth.guard';
import { createMockRedisService } from '@test/helpers/redis-test.helper';
import {
  generateTestTokens,
  TEST_JWT_SECRET,
  TEST_JWT_REFRESH_SECRET,
} from '@test/helpers/auth-test.helper';

/**
 * E2E for V.2.2 Music Control Delegation — full grant → playback → revoke
 * flow. Prisma is an in-memory mock; Spotify is mocked so playback commands
 * are observed, not sent to the real API.
 */
describe('Delegation (e2e)', () => {
  let app: NestFastifyApplication;
  let spotify: Record<string, ReturnType<typeof vi.fn>>;

  const ownerId = randomUUID();
  const friendId = randomUUID();
  const strangerId = randomUUID();

  const ownerToken = generateTestTokens(ownerId, 'owner@example.com')
    .accessToken;
  const friendToken = generateTestTokens(friendId, 'friend@example.com')
    .accessToken;
  const strangerToken = generateTestTokens(strangerId, 'stranger@example.com')
    .accessToken;

  const mockPrismaService = () => {
    const users: Record<string, Record<string, unknown>> = {
      [ownerId]: { id: ownerId, displayName: 'Owner' },
      [friendId]: { id: friendId, displayName: 'Friend' },
      [strangerId]: { id: strangerId, displayName: 'Stranger' },
    };
    // owner and friend are accepted friends; stranger is not
    const friendships = [
      {
        id: randomUUID(),
        requesterId: ownerId,
        addresseeId: friendId,
        status: 'ACCEPTED',
      },
    ];
    const delegations: Record<string, Record<string, unknown>> = {};

    return {
      user: {
        findUnique: vi.fn(({ where }: { where: { id: string } }) =>
          Promise.resolve(users[where.id] ?? null),
        ),
      },
      friendship: {
        findFirst: vi.fn(
          ({
            where,
          }: {
            where: {
              status: string;
              OR: Array<{ requesterId: string; addresseeId: string }>;
            };
          }) => {
            const found = friendships.find(
              (f) =>
                f.status === where.status &&
                where.OR.some(
                  (c) =>
                    f.requesterId === c.requesterId &&
                    f.addresseeId === c.addresseeId,
                ),
            );
            return Promise.resolve(found ?? null);
          },
        ),
      },
      musicControlDelegation: {
        findUnique: vi.fn(({ where }: { where: Record<string, unknown> }) => {
          if (where.id) {
            return Promise.resolve(
              delegations[where.id as string] ?? null,
            );
          }
          const c = where.ownerId_deviceId as
            | { ownerId: string; deviceId: string }
            | undefined;
          if (c) {
            return Promise.resolve(
              Object.values(delegations).find(
                (d) => d.ownerId === c.ownerId && d.deviceId === c.deviceId,
              ) ?? null,
            );
          }
          return Promise.resolve(null);
        }),
        findMany: vi.fn(
          ({ where }: { where?: Record<string, string> }) => {
            let rows = Object.values(delegations);
            if (where?.ownerId) {
              rows = rows.filter((d) => d.ownerId === where.ownerId);
            }
            if (where?.delegateUserId) {
              rows = rows.filter(
                (d) => d.delegateUserId === where.delegateUserId,
              );
            }
            return Promise.resolve(rows);
          },
        ),
        upsert: vi.fn(
          ({
            where,
            update,
            create,
          }: {
            where: { ownerId_deviceId: { ownerId: string; deviceId: string } };
            update: Record<string, unknown>;
            create: Record<string, unknown>;
          }) => {
            const c = where.ownerId_deviceId;
            const existing = Object.values(delegations).find(
              (d) => d.ownerId === c.ownerId && d.deviceId === c.deviceId,
            );
            if (existing) {
              Object.assign(existing, update);
              return Promise.resolve(existing);
            }
            const id = randomUUID();
            const row = { id, ...create, grantedAt: new Date() };
            delegations[id] = row;
            return Promise.resolve(row);
          },
        ),
        delete: vi.fn(
          ({
            where,
          }: {
            where: { ownerId_deviceId: { ownerId: string; deviceId: string } };
          }) => {
            const c = where.ownerId_deviceId;
            const entry = Object.entries(delegations).find(
              ([, d]) => d.ownerId === c.ownerId && d.deviceId === c.deviceId,
            );
            if (entry) delete delegations[entry[0]];
            return Promise.resolve(entry?.[1] ?? null);
          },
        ),
      },
      $connect: vi.fn(),
      $disconnect: vi.fn(),
    };
  };

  beforeAll(async () => {
    spotify = {
      play: vi.fn().mockResolvedValue(undefined),
      pause: vi.fn().mockResolvedValue(undefined),
      next: vi.fn().mockResolvedValue(undefined),
      previous: vi.fn().mockResolvedValue(undefined),
      setVolume: vi.fn().mockResolvedValue(undefined),
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
        DelegationModule,
      ],
      providers: [{ provide: APP_GUARD, useClass: JwtAuthGuard }],
    })
      .overrideProvider(PrismaService)
      .useFactory({ factory: mockPrismaService })
      .overrideProvider(RedisService)
      .useValue(createMockRedisService())
      .overrideProvider(MailService)
      .useValue({
        sendVerificationEmail: vi.fn(),
        sendPasswordResetEmail: vi.fn(),
      })
      .overrideProvider(SpotifyService)
      .useValue(spotify)
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

  it('rejects unauthenticated requests (401)', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/users/me/delegations',
    });
    expect(res.statusCode).toBe(401);
  });

  it('owner cannot delegate control to a non-friend (403)', async () => {
    const res = await app.inject({
      method: 'PUT',
      url: '/users/me/devices/device-A/delegate',
      headers: { authorization: `Bearer ${ownerToken}` },
      payload: { delegateUserId: strangerId },
    });
    expect(res.statusCode).toBe(403);
  });

  it('grant → playback → revoke full flow', async () => {
    // owner grants control of device-A to their friend
    const grant = await app.inject({
      method: 'PUT',
      url: '/users/me/devices/device-A/delegate',
      headers: { authorization: `Bearer ${ownerToken}` },
      payload: { delegateUserId: friendId },
    });
    expect(grant.statusCode).toBe(200);
    const delegation = JSON.parse(grant.payload);
    expect(delegation.delegateUserId).toBe(friendId);
    const delegationId = delegation.id as string;

    // the friend sees the device in their controlled-devices list
    const controlled = await app.inject({
      method: 'GET',
      url: '/users/me/controlled-devices',
      headers: { authorization: `Bearer ${friendToken}` },
    });
    expect(controlled.statusCode).toBe(200);
    expect(JSON.parse(controlled.payload)).toHaveLength(1);

    // the friend drives playback — Spotify is called with the OWNER's id
    const play = await app.inject({
      method: 'POST',
      url: `/delegations/${delegationId}/playback/play`,
      headers: { authorization: `Bearer ${friendToken}` },
      payload: { uris: ['spotify:track:abc'] },
    });
    expect(play.statusCode).toBe(200);
    expect(spotify.play).toHaveBeenCalledWith(
      ownerId,
      ['spotify:track:abc'],
      undefined,
    );

    // a stranger cannot drive playback on that device
    const strangerPlay = await app.inject({
      method: 'POST',
      url: `/delegations/${delegationId}/playback/pause`,
      headers: { authorization: `Bearer ${strangerToken}` },
    });
    expect(strangerPlay.statusCode).toBe(403);

    // owner revokes the delegation
    const revoke = await app.inject({
      method: 'DELETE',
      url: '/users/me/devices/device-A/delegate',
      headers: { authorization: `Bearer ${ownerToken}` },
    });
    expect(revoke.statusCode).toBe(200);

    // after revoke, the friend can no longer control the device
    const playAfter = await app.inject({
      method: 'POST',
      url: `/delegations/${delegationId}/playback/play`,
      headers: { authorization: `Bearer ${friendToken}` },
      payload: {},
    });
    expect(playAfter.statusCode).toBe(404);
  });
});
