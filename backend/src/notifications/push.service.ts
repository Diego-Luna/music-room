import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  DevicePlatform,
  PushEnvelope,
  PushTransport,
} from './push-transport';

export interface PushMessage {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface RegisterTokenInput {
  token: string;
  platform: DevicePlatform;
}

@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly transport: PushTransport,
  ) {}

  async register(userId: string, dto: RegisterTokenInput) {
    return this.prisma.deviceToken.upsert({
      where: { platform_token: { platform: dto.platform, token: dto.token } },
      update: { userId, lastSeenAt: new Date() },
      create: { userId, token: dto.token, platform: dto.platform },
    });
  }

  async unregister(userId: string, token: string) {
    await this.prisma.deviceToken.deleteMany({
      where: { userId, token },
    });
  }

  async sendToUser(userId: string, msg: PushMessage): Promise<number> {
    const tokens = await this.prisma.deviceToken.findMany({
      where: { userId },
    });
    if (!tokens.length) return 0;
    let sent = 0;
    for (const t of tokens) {
      const envelope: PushEnvelope = {
        token: t.token,
        platform: t.platform as DevicePlatform,
        title: msg.title,
        body: msg.body,
        data: msg.data,
      };
      try {
        const res = await this.transport.send(envelope);
        if (res.invalidToken) {
          await this.prisma.deviceToken.delete({ where: { id: t.id } });
          continue;
        }
        if (res.ok) sent += 1;
      } catch (err) {
        this.logger.warn(
          `push failed for ${t.id}: ${(err as Error).message ?? err}`,
        );
      }
    }
    return sent;
  }
}
