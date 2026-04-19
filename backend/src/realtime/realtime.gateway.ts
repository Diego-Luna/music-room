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
  data: { userId: string; email: string };
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
      };
      await socket.join(userChannel(payload.sub));
      this.logger.log(`socket ${socket.id} authed as ${payload.sub}`);
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
      return { ok: false, error: 'not allowed' };
    }

    await socket.join(roomChannel(roomId));
    this.realtime.emitToRoom(roomId, 'presence:joined', {
      userId: socket.data.userId,
      at: new Date().toISOString(),
    });
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
    this.realtime.emitToRoom(roomId, 'presence:left', {
      userId: socket.data.userId,
      at: new Date().toISOString(),
    });
    return { ok: true };
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
