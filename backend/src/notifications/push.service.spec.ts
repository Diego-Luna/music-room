import { Test, TestingModule } from '@nestjs/testing';
import { PushService } from './push.service';
import { PushTransport } from './push-transport';
import { PrismaService } from '../prisma/prisma.service';

type Fn = ReturnType<typeof vi.fn>;

describe('PushService', () => {
  let service: PushService;
  let prisma: {
    deviceToken: {
      upsert: Fn;
      deleteMany: Fn;
      findMany: Fn;
      delete: Fn;
    };
  };
  let transport: { send: Fn };

  beforeEach(async () => {
    prisma = {
      deviceToken: {
        upsert: vi.fn(),
        deleteMany: vi.fn(),
        findMany: vi.fn(),
        delete: vi.fn(),
      },
    };
    transport = { send: vi.fn().mockResolvedValue({ ok: true }) };
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PushService,
        { provide: PrismaService, useValue: prisma },
        { provide: PushTransport, useValue: transport },
      ],
    }).compile();
    service = module.get(PushService);
  });

  describe('register', () => {
    it('upserts by (platform, token) and binds the user', async () => {
      prisma.deviceToken.upsert.mockResolvedValue({ id: 'dt1' });
      const res = await service.register('u1', {
        token: 'apns-token',
        platform: 'IOS',
      });
      expect(prisma.deviceToken.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            platform_token: { platform: 'IOS', token: 'apns-token' },
          },
          update: expect.objectContaining({ userId: 'u1' }),
          create: expect.objectContaining({
            userId: 'u1',
            token: 'apns-token',
            platform: 'IOS',
          }),
        }),
      );
      expect(res.id).toBe('dt1');
    });
  });

  describe('unregister', () => {
    it('deletes only the caller user token', async () => {
      await service.unregister('u1', 'apns-token');
      expect(prisma.deviceToken.deleteMany).toHaveBeenCalledWith({
        where: { userId: 'u1', token: 'apns-token' },
      });
    });
  });

  describe('sendToUser', () => {
    it('returns 0 when the user has no tokens', async () => {
      prisma.deviceToken.findMany.mockResolvedValue([]);
      const n = await service.sendToUser('u1', { title: 't', body: 'b' });
      expect(n).toBe(0);
      expect(transport.send).not.toHaveBeenCalled();
    });

    it('fans out to every registered token', async () => {
      prisma.deviceToken.findMany.mockResolvedValue([
        { id: 'd1', token: 'a', platform: 'IOS' },
        { id: 'd2', token: 'b', platform: 'ANDROID' },
      ]);
      const n = await service.sendToUser('u1', { title: 't', body: 'b' });
      expect(transport.send).toHaveBeenCalledTimes(2);
      expect(n).toBe(2);
    });

    it('removes invalid tokens flagged by the transport', async () => {
      prisma.deviceToken.findMany.mockResolvedValue([
        { id: 'd1', token: 'stale', platform: 'IOS' },
      ]);
      transport.send.mockResolvedValue({ ok: false, invalidToken: true });
      const n = await service.sendToUser('u1', { title: 't', body: 'b' });
      expect(n).toBe(0);
      expect(prisma.deviceToken.delete).toHaveBeenCalledWith({
        where: { id: 'd1' },
      });
    });

    it('swallows transport errors without throwing to the caller', async () => {
      prisma.deviceToken.findMany.mockResolvedValue([
        { id: 'd1', token: 'a', platform: 'IOS' },
      ]);
      transport.send.mockRejectedValue(new Error('boom'));
      await expect(
        service.sendToUser('u1', { title: 't', body: 'b' }),
      ).resolves.toBe(0);
    });
  });
});
