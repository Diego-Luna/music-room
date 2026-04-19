import { Test, TestingModule } from '@nestjs/testing';
import {
  FastifyAdapter,
  NestFastifyApplication,
} from '@nestjs/platform-fastify';
import { ConfigModule } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { io as ioClient, type Socket as ClientSocket } from 'socket.io-client';
import { AddressInfo } from 'node:net';
import { randomUUID } from 'node:crypto';
import { AuthModule } from '@/auth/auth.module';
import { RealtimeCoreModule } from '@/realtime/realtime-core.module';
import { RealtimeModule } from '@/realtime/realtime.module';
import { RoomsModule } from '@/rooms/rooms.module';
import { PrismaModule } from '@/prisma/prisma.module';
import { PrismaService } from '@/prisma/prisma.service';
import { RedisModule } from '@/redis/redis.module';
import { RedisService } from '@/redis/redis.service';
import { MailService } from '@/mail/mail.service';
import { createMockRedisService } from '@test/helpers/redis-test.helper';
import {
  TEST_JWT_SECRET,
  TEST_JWT_REFRESH_SECRET,
} from '@test/helpers/auth-test.helper';

describe('Realtime (e2e)', () => {
  let app: NestFastifyApplication;
  let url: string;
  let jwtService: JwtService;

  const rooms: Record<string, Record<string, unknown>> = {};
  const members: Record<string, Record<string, unknown>> = {};
  const memberKey = (r: string, u: string) => `${r}::${u}`;

  const prisma = {
    user: {
      findUnique: vi.fn(({ where }: { where: Record<string, string> }) =>
        Promise.resolve({ id: where.id ?? 'u' }),
      ),
    },
    room: {
      findUnique: vi.fn(({ where }: { where: Record<string, string> }) =>
        Promise.resolve(rooms[where.id] ?? null),
      ),
      findMany: vi.fn(() => Promise.resolve([])),
      create: vi.fn(({ data }: { data: Record<string, unknown> }) => {
        const id = randomUUID();
        rooms[id] = { id, ...data };
        return Promise.resolve(rooms[id]);
      }),
      update: vi.fn(() => Promise.resolve({})),
      delete: vi.fn(() => Promise.resolve({})),
    },
    roomMember: {
      create: vi.fn(({ data }: { data: Record<string, unknown> }) => {
        const key = memberKey(data.roomId as string, data.userId as string);
        members[key] = { ...data, joinedAt: new Date() };
        return Promise.resolve(members[key]);
      }),
      findUnique: vi.fn(
        ({ where }: { where: { roomId_userId: Record<string, string> } }) =>
          Promise.resolve(
            members[memberKey(where.roomId_userId.roomId, where.roomId_userId.userId)] ??
              null,
          ),
      ),
      findMany: vi.fn(() => Promise.resolve([])),
      delete: vi.fn(() => Promise.resolve({})),
      update: vi.fn(() => Promise.resolve({})),
    },
    roomInvitation: {
      create: vi.fn(({ data }: { data: Record<string, unknown> }) =>
        Promise.resolve({ id: randomUUID(), ...data }),
      ),
      findFirst: vi.fn(() => Promise.resolve(null)),
      update: vi.fn(() => Promise.resolve({})),
    },
    $transaction: vi.fn(async (cb: unknown) =>
      typeof cb === 'function' ? (cb as (p: unknown) => unknown)(prisma) : cb,
    ),
  };

  beforeAll(async () => {
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
        PrismaModule,
        RedisModule,
        RealtimeCoreModule,
        AuthModule,
        RoomsModule,
        RealtimeModule,
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
      new FastifyAdapter(),
    );
    app.useWebSocketAdapter(new IoAdapter(app));
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
    await app.listen(0, '127.0.0.1');

    const httpServer = app.getHttpServer() as unknown as {
      address(): AddressInfo;
    };
    const addr = httpServer.address();
    url = `http://127.0.0.1:${addr.port}`;

    jwtService = module.get(JwtService);
  });

  afterAll(async () => {
    await app.close();
  });

  const connect = (token: string): Promise<ClientSocket> =>
    new Promise((resolve, reject) => {
      const socket = ioClient(url, {
        auth: { token },
        transports: ['websocket'],
        reconnection: false,
      });
      socket.on('connect', () => resolve(socket));
      socket.on('connect_error', (e) => reject(e));
      setTimeout(() => reject(new Error('connect timeout')), 2000);
    });

  const token = (sub: string) =>
    jwtService.sign({ sub, email: `${sub}@x.io` }, { secret: TEST_JWT_SECRET });

  it('rejects sockets without a token (server-side disconnect)', async () => {
    const disconnected = await new Promise<boolean>((resolve) => {
      const s = ioClient(url, {
        transports: ['websocket'],
        reconnection: false,
      });
      s.on('disconnect', () => {
        resolve(true);
        s.close();
      });
      setTimeout(() => {
        s.close();
        resolve(false);
      }, 2000);
    });
    expect(disconnected).toBe(true);
  });

  it('broadcasts presence:joined to the room', async () => {
    const ownerId = randomUUID();
    const room = (await prisma.room.create({
      data: {
        name: 'RT',
        kind: 'VOTE',
        visibility: 'PUBLIC',
        ownerId,
      },
    })) as { id: string };
    await prisma.roomMember.create({
      data: { roomId: room.id, userId: ownerId, role: 'OWNER' },
    });

    const socketA = await connect(token(ownerId));
    const joinerId = randomUUID();
    await prisma.roomMember.create({
      data: { roomId: room.id, userId: joinerId, role: 'MEMBER' },
    });
    const socketB = await connect(token(joinerId));

    // A subscribes first so it receives broadcasts for the channel
    await new Promise<void>((resolve) =>
      socketA.emit('room:join', { roomId: room.id }, () => resolve()),
    );

    // wait specifically for the joiner's presence event
    const received = new Promise<{ userId: string }>((resolve) => {
      socketA.on('presence:joined', (p: { userId: string }) => {
        if (p.userId === joinerId) resolve(p);
      });
    });

    // then B joins — this triggers the broadcast we are waiting for
    await new Promise<void>((resolve) =>
      socketB.emit('room:join', { roomId: room.id }, () => resolve()),
    );

    const payload = await Promise.race([
      received,
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error('no broadcast')), 2000),
      ),
    ]);
    expect(payload.userId).toBe(joinerId);

    socketA.disconnect();
    socketB.disconnect();
  });
});
