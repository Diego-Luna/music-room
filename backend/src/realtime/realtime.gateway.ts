import {
  Injectable,
  Logger,
  OnModuleInit,
  UnauthorizedException,
} from '@nestjs/common';
import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { JwtBlacklistService } from '../auth/jwt-blacklist.service';
import { JwtPayload } from '../auth/auth.service';
import { RoomsService } from '../rooms/rooms.service';
import { RealtimeService, roomChannel, userChannel } from './realtime.service';

interface AuthedSocket extends Socket {
  data: {
    userId: string;
    email: string;
    platform?: string;
    device?: string;
    appVersion?: string;
  };
}

@Injectable()
@WebSocketGateway({ cors: { origin: true } })
export class RealtimeGateway
  implements OnGatewayConnection, OnGatewayDisconnect, OnModuleInit
{
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(RealtimeGateway.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly jwtBlacklist: JwtBlacklistService,
    private readonly roomsService: RoomsService,
    private readonly realtime: RealtimeService,
  ) {}

  onModuleInit() {
    if (this.server) {
      this.realtime.setServer(this.server);
    }
  }

  async handleConnection(socket: Socket): Promise<void> {
    try {
      const token = this.extractToken(socket);
      if (!token) throw new UnauthorizedException('Missing token');

      const payload = this.jwtService.verify<JwtPayload>(token, {
        secret: this.configService.get<string>('JWT_SECRET'),
      });
      if (await this.jwtBlacklist.isBlacklisted(token)) {
        throw new UnauthorizedException('Token revoked');
      }
      (socket as AuthedSocket).data = {
        userId: payload.sub,
        email: payload.email,
        // * Prefer HTTP headers (native); fall back to handshake.auth (web —
        //   browsers block custom WebSocket headers).
        platform: this.clientTag(socket, 'x-platform', 'platform'),
        device: this.clientTag(socket, 'x-device', 'device'),
        appVersion: this.clientTag(socket, 'x-app-version', 'appVersion'),
      };
      await socket.join(userChannel(payload.sub));
      this.logAction(socket as AuthedSocket, 'connect', `socket=${socket.id}`);
    } catch (err) {
      this.logger.warn(
        `socket ${socket.id} auth failed: ${(err as Error).message}`,
      );
      socket.emit('auth:error', { message: 'unauthorized' });
      socket.disconnect(true);
    }
  }

  handleDisconnect(socket: Socket): void {
    this.logger.debug(`socket ${socket.id} disconnected`);
  }

  @SubscribeMessage('room:join')
  async onRoomJoin(
    socket: AuthedSocket,
    payload: { roomId?: string },
  ): Promise<{ ok: boolean; error?: string }> {
    const roomId = payload?.roomId;
    if (!roomId) return { ok: false, error: 'roomId required' };
    if (!socket.data?.userId) return { ok: false, error: 'unauthorized' };

    try {
      await this.roomsService.findOne(roomId, socket.data.userId);
    } catch {
      this.logAction(socket, 'room:join:denied', `room=${roomId}`);
      return { ok: false, error: 'not allowed' };
    }

    await socket.join(roomChannel(roomId));
    this.logAction(socket, 'room:join', `room=${roomId}`);
    return { ok: true };
  }

  @SubscribeMessage('room:leave')
  async onRoomLeave(
    socket: AuthedSocket,
    payload: { roomId?: string },
  ): Promise<{ ok: boolean; error?: string }> {
    const roomId = payload?.roomId;
    if (!roomId) return { ok: false, error: 'roomId required' };
    if (!socket.data?.userId) return { ok: false, error: 'unauthorized' };

    await socket.leave(roomChannel(roomId));
    this.logAction(socket, 'room:leave', `room=${roomId}`);
    return { ok: true };
  }

  /**
   * Logs a websocket action with the same client tags as the HTTP request
   * logger (V.6: every action from the mobile app must produce a log line
   * carrying Platform / Device / App-Version).
   */
  private logAction(
    socket: AuthedSocket,
    action: string,
    detail: string,
  ): void {
    const d = socket.data;
    this.logger.log(
      `WS ${action} ${detail} user=${d?.userId ?? 'N/A'} ` +
        `[platform=${d?.platform ?? 'N/A'} device=${d?.device ?? 'N/A'} ` +
        `version=${d?.appVersion ?? 'N/A'}]`,
    );
  }

  private header(socket: Socket, name: string): string | undefined {
    const value = socket.handshake.headers[name];
    if (Array.isArray(value)) return value[0];
    return value;
  }

  /** V.6 tag from header or Socket.IO auth map (web-safe). */
  private clientTag(
    socket: Socket,
    headerName: string,
    authKey: string,
  ): string | undefined {
    const fromHeader = this.header(socket, headerName);
    if (fromHeader) return fromHeader;
    const auth = socket.handshake.auth as Record<string, unknown> | undefined;
    const value = auth?.[authKey];
    return typeof value === 'string' && value.length > 0 ? value : undefined;
  }

  private extractToken(socket: Socket): string | null {
    const auth = socket.handshake.auth as Record<string, unknown> | undefined;
    if (auth && typeof auth.token === 'string') return auth.token;
    const header = socket.handshake.headers.authorization;
    if (typeof header === 'string' && header.startsWith('Bearer ')) {
      return header.slice(7);
    }
    const query = socket.handshake.query?.token;
    if (typeof query === 'string') return query;
    return null;
  }
}
