import { Injectable, NestMiddleware, Logger } from '@nestjs/common';
import { FastifyRequest, FastifyReply } from 'fastify';

export interface RequestLogData {
  method: string;
  path: string;
  statusCode: number;
  duration: number;
  platform: string | undefined;
  device: string | undefined;
  appVersion: string | undefined;
  ip: string | undefined;
  userAgent: string | undefined;
}

@Injectable()
export class RequestLoggerMiddleware implements NestMiddleware {
  private readonly logger = new Logger('HTTP');

  use(req: FastifyRequest['raw'], res: FastifyReply['raw'], next: () => void) {
    const startTime = Date.now();

    const method = req.method ?? 'UNKNOWN';
    const url = req.url ?? '/';
    const platform = this.getHeader(req, 'x-platform');
    const device = this.getHeader(req, 'x-device');
    const appVersion = this.getHeader(req, 'x-app-version');
    const ip =
      this.getHeader(req, 'x-forwarded-for') ?? req.socket?.remoteAddress;
    const userAgent = this.getHeader(req, 'user-agent');

    res.on('finish', () => {
      const duration = Date.now() - startTime;
      const statusCode = res.statusCode;

      const logData: RequestLogData = {
        method,
        path: url,
        statusCode,
        duration,
        platform,
        device,
        appVersion,
        ip,
        userAgent,
      };

      const message = `${method} ${url} ${statusCode} ${duration}ms`;

      if (platform || device || appVersion) {
        this.logger.log(
          `${message} [platform=${platform ?? 'N/A'} device=${device ?? 'N/A'} version=${appVersion ?? 'N/A'}]`,
        );
      } else {
        this.logger.log(message);
      }

      // Attach log data to response for potential persistence
      (res as unknown as Record<string, unknown>).__logData = logData;
    });

    next();
  }

  private getHeader(
    req: FastifyRequest['raw'],
    name: string,
  ): string | undefined {
    const value = req.headers[name];
    if (Array.isArray(value)) return value[0];
    return value;
  }
}
