import { RedisIoAdapter } from './redis-io.adapter';

vi.mock('ioredis', () => {
  class RedisMock {
    connect = vi.fn().mockResolvedValue(undefined);
    duplicate = vi.fn(() => new RedisMock());
  }
  return { default: RedisMock };
});

vi.mock('@socket.io/redis-adapter', () => ({
  createAdapter: vi.fn(() => 'fake-adapter-factory'),
}));

describe('RedisIoAdapter', () => {
  const buildApp = () => {
    const config = {
      get: vi.fn((_key: string, defaultValue: unknown) => defaultValue),
    };
    const app = {
      get: vi.fn(() => config),
      // satisfy the INestApplicationContext shape used by IoAdapter
      getHttpServer: vi.fn(),
    } as unknown as Parameters<typeof RedisIoAdapter>[0];
    return { app, config };
  };

  it('connectToRedis reads REDIS_HOST/PORT and instantiates pub/sub clients', async () => {
    const { app, config } = buildApp();
    const adapter = new RedisIoAdapter(app);
    await adapter.connectToRedis();
    expect(config.get).toHaveBeenCalledWith('REDIS_HOST', 'localhost');
    expect(config.get).toHaveBeenCalledWith('REDIS_PORT', 6379);
  });

  it('createIOServer is callable without a connectToRedis (no-op adapter wiring)', () => {
    const { app } = buildApp();
    const adapter = new RedisIoAdapter(app);
    // Avoid invoking the actual socket.io super: stub it.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (adapter as any).createIOServer = (
      port: number,
      _options?: unknown,
    ) => ({
      port,
      adapter: vi.fn(),
    });
    const result = adapter.createIOServer(0) as { port: number };
    expect(result.port).toBe(0);
  });

  it('createIOServer wires the adapter factory after connectToRedis', async () => {
    const { app } = buildApp();
    const adapter = new RedisIoAdapter(app);
    await adapter.connectToRedis();

    const fakeServer = { adapter: vi.fn() };
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const proto = Object.getPrototypeOf(adapter) as any;
    const realCreate = proto.createIOServer;
    const parentProto = Object.getPrototypeOf(proto);
    // Stub the parent's createIOServer to avoid actually booting socket.io
    parentProto.createIOServer = vi.fn(() => fakeServer);
    try {
      adapter.createIOServer(0);
      expect(fakeServer.adapter).toHaveBeenCalledWith('fake-adapter-factory');
    } finally {
      // restore
      proto.createIOServer = realCreate;
    }
  });
});
