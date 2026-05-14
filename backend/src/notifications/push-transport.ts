import { Injectable, Logger } from '@nestjs/common';

export type DevicePlatform = 'IOS' | 'ANDROID' | 'WEB';

export interface PushEnvelope {
  token: string;
  platform: DevicePlatform;
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface PushSendResult {
  ok: boolean;
  invalidToken?: boolean;
}

export abstract class PushTransport {
  abstract send(envelope: PushEnvelope): Promise<PushSendResult>;
}

@Injectable()
export class LogPushTransport extends PushTransport {
  private readonly logger = new Logger(LogPushTransport.name);

  send(envelope: PushEnvelope): Promise<PushSendResult> {
    this.logger.log(
      `push[${envelope.platform}] ${envelope.title} → ${envelope.token.slice(0, 8)}…`,
    );
    return Promise.resolve({ ok: true });
  }
}
