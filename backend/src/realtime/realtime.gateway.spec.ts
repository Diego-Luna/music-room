import { Test } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { NotFoundException } from '@nestjs/common';
import { RealtimeGateway } from './realtime.gateway';
import { RealtimeService, roomChannel, userChannel } from './realtime.service';
import { JwtBlacklistService } from '../auth/jwt-blacklist.service';
import { RoomsService } from '../rooms/rooms.service';

describe('RealtimeGateway', () => {
  let gateway: RealtimeGateway;
  let realtime: RealtimeService;
  let jwtService: { verify: ReturnType<typeof vi.fn> };
  let blacklist: { isBlacklisted: ReturnType<typeof vi.fn> };
  let roomsService: { findOne: ReturnType<typeof vi.fn> };
  let config: { get: ReturnType<typeof vi.fn> };

  const makeSocket = (opts?: Partial<Record<string, unknown>>) => {
    const socket: Record<string, unknown> = {
      id: 'sock-1',
      data: {},
      handshake: {
        auth: {},
        headers: {},
        query: {},
        ...(opts?.handshake as object),
      },
      join: vi.fn(() => Promise.resolve()),
      leave: vi.fn(() => Promise.resolve()),
      emit: vi.fn(),
      disconnect: vi.fn(),
      ...opts,
    };
    return socket as never;
  };

  beforeEach(async () => {
    jwtService = { verify: vi.fn() };
    blacklist = { isBlacklisted: vi.fn().mockResolvedValue(false) };
    roomsService = { findOne: vi.fn() };
    config = { get: vi.fn().mockReturnValue('test-secret') };

    const module = await Test.createTestingModule({
      providers: [
        RealtimeGateway,
        RealtimeService,
        { provide: JwtService, useValue: jwtService },
        { provide: ConfigService, useValue: config },
        { provide: JwtBlacklistService, useValue: blacklist },
        { provide: RoomsService, useValue: roomsService },
      ],
    }).compile();

    gateway = module.get(RealtimeGateway);
    realtime = module.get(RealtimeService);
  });

  describe('handleConnection', () => {
    it('authenticates a socket with a bearer token in auth handshake', async () => {
      jwtService.verify.mockReturnValue({ sub: 'u1', email: 'a@b.c' });
      const socket = makeSocket({
        handshake: { auth: { token: 't' }, headers: {}, query: {} },
      });

      await gateway.handleConnection(socket);

      expect(jwtService.verify).toHaveBeenCalledWith('t', {
        secret: 'test-secret',
      });
      expect(socket.data).toEqual({ userId: 'u1', email: 'a@b.c' });
      expect(socket.join).toHaveBeenCalledWith(userChannel('u1'));
    });

    it('disconnects when no token is supplied', async () => {
      const socket = makeSocket();
      await gateway.handleConnection(socket);
      expect(socket.disconnect).toHaveBeenCalledWith(true);
      expect(socket.emit).toHaveBeenCalledWith(
        'auth:error',
        expect.any(Object),
      );
    });

    it('disconnects when the token is blacklisted', async () => {
      jwtService.verify.mockReturnValue({ sub: 'u1', email: 'a@b.c' });
      blacklist.isBlacklisted.mockResolvedValue(true);
      const socket = makeSocket({
        handshake: { auth: { token: 'revoked' }, headers: {}, query: {} },
      });
      await gateway.handleConnection(socket);
      expect(socket.disconnect).toHaveBeenCalledWith(true);
    });

    it('disconnects when jwt.verify throws', async () => {
      jwtService.verify.mockImplementation(() => {
        throw new Error('bad sig');
      });
      const socket = makeSocket({
        handshake: { auth: { token: 'bad' }, headers: {}, query: {} },
      });
      await gateway.handleConnection(socket);
      expect(socket.disconnect).toHaveBeenCalledWith(true);
    });

    it('extracts the token from the Authorization header', async () => {
      jwtService.verify.mockReturnValue({ sub: 'u1', email: 'a@b.c' });
      const socket = makeSocket({
        handshake: {
          auth: {},
          headers: { authorization: 'Bearer hdr-token' },
          query: {},
        },
      });
      await gateway.handleConnection(socket);
      expect(jwtService.verify).toHaveBeenCalledWith(
        'hdr-token',
        expect.any(Object),
      );
    });
  });

  describe('room:join', () => {
    it('rejects when roomId is missing', async () => {
      const socket = makeSocket({ data: { userId: 'u1', email: 'a' } });
      const res = await gateway.onRoomJoin(socket, {});
      expect(res.ok).toBe(false);
    });

    it('rejects when the user is unauthorized (no data.userId)', async () => {
      const socket = makeSocket();
      const res = await gateway.onRoomJoin(socket, { roomId: 'r' });
      expect(res.ok).toBe(false);
    });

    it('rejects when the user has no access to the room', async () => {
      roomsService.findOne.mockRejectedValue(new NotFoundException());
      const socket = makeSocket({ data: { userId: 'u1', email: 'a' } });
      const res = await gateway.onRoomJoin(socket, { roomId: 'r' });
      expect(res.ok).toBe(false);
      expect(res.error).toBe('not allowed');
    });

    it('joins the channel and broadcasts presence:joined', async () => {
      roomsService.findOne.mockResolvedValue({ id: 'r' });
      const socket = makeSocket({ data: { userId: 'u1', email: 'a' } });
      const emit = vi.fn();
      const to = vi.fn(() => ({ emit }));
      realtime.setServer({ to } as never);

      const res = await gateway.onRoomJoin(socket, { roomId: 'r' });

      expect(res.ok).toBe(true);
      expect(socket.join).toHaveBeenCalledWith(roomChannel('r'));
      expect(to).toHaveBeenCalledWith(roomChannel('r'));
      expect(emit).toHaveBeenCalledWith(
        'presence:joined',
        expect.objectContaining({ userId: 'u1' }),
      );
    });
  });

  describe('room:leave', () => {
    it('leaves the channel and broadcasts presence:left', async () => {
      const socket = makeSocket({ data: { userId: 'u1', email: 'a' } });
      const emit = vi.fn();
      const to = vi.fn(() => ({ emit }));
      realtime.setServer({ to } as never);

      const res = await gateway.onRoomLeave(socket, { roomId: 'r' });

      expect(res.ok).toBe(true);
      expect(socket.leave).toHaveBeenCalledWith(roomChannel('r'));
      expect(emit).toHaveBeenCalledWith(
        'presence:left',
        expect.objectContaining({ userId: 'u1' }),
      );
    });

    it('rejects on missing roomId / missing auth', async () => {
      const socket = makeSocket({ data: { userId: 'u1', email: 'a' } });
      const r1 = await gateway.onRoomLeave(socket, {});
      const socket2 = makeSocket();
      const r2 = await gateway.onRoomLeave(socket2, { roomId: 'r' });
      expect(r1.ok).toBe(false);
      expect(r2.ok).toBe(false);
    });
  });

  describe('onModuleInit', () => {
    it('registers the server with RealtimeService when available', () => {
      const setServer = vi.spyOn(realtime, 'setServer');
      const server = { to: vi.fn() } as never;
      (gateway as unknown as { server: unknown }).server = server;
      gateway.onModuleInit();
      expect(setServer).toHaveBeenCalledWith(server);
    });
  });
});
