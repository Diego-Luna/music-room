import { Injectable, Logger } from '@nestjs/common';
import type { Server } from 'socket.io';

export const roomChannel = (roomId: string) => `room:${roomId}`;
export const userChannel = (userId: string) => `user:${userId}`;

@Injectable()
export class RealtimeService {
  private server: Server | null = null;
  private readonly logger = new Logger(RealtimeService.name);

  setServer(server: Server): void {
    this.server = server;
  }

  emitToRoom(roomId: string, event: string, payload: unknown): void {
    if (!this.server) {
      this.logger.warn(`emit ${event} dropped — gateway not ready`);
      return;
    }
    this.server.to(roomChannel(roomId)).emit(event, payload);
  }

  emitToUser(userId: string, event: string, payload: unknown): void {
    if (!this.server) {
      this.logger.warn(`emit ${event} dropped — gateway not ready`);
      return;
    }
    this.server.to(userChannel(userId)).emit(event, payload);
  }
}
