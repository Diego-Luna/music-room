import { Logger, INestApplicationContext } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import type { ServerOptions } from 'socket.io';
import Redis from 'ioredis';

export class RedisIoAdapter extends IoAdapter {
  private readonly logger = new Logger(RedisIoAdapter.name);
  private pubClient?: Redis;
  private subClient?: Redis;
  private adapterFactory?: ReturnType<typeof createAdapter>;

  constructor(private readonly app: INestApplicationContext) {
    super(app);
  }

  async connectToRedis(): Promise<void> {
    const config = this.app.get(ConfigService);
    const host = config.get<string>('REDIS_HOST', 'localhost');
    const port = config.get<number>('REDIS_PORT', 6379);

    this.pubClient = new Redis({ host, port });
    this.subClient = this.pubClient.duplicate();
    await Promise.all([
      this.pubClient.connect().catch(() => undefined),
      this.subClient.connect().catch(() => undefined),
    ]);
    this.adapterFactory = createAdapter(this.pubClient, this.subClient);
    this.logger.log(`Socket.IO Redis adapter wired (${host}:${port})`);
  }

  createIOServer(port: number, options?: ServerOptions): unknown {
    const server = super.createIOServer(port, options) as {
      adapter: (f: unknown) => void;
    };
    if (this.adapterFactory) {
      server.adapter(this.adapterFactory);
    }
    return server;
  }
}
