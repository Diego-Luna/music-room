import { Test, TestingModule } from '@nestjs/testing';
import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { DelegationService } from './delegation.service';
import { PrismaService } from '../prisma/prisma.service';
import { FriendsService } from '../users/friends.service';
import { RealtimeService } from '../realtime/realtime.service';
import { PushService } from '../notifications/push.service';

describe('DelegationService', () => {
  let service: DelegationService;
  let prisma: Record<string, Record<string, ReturnType<typeof vi.fn>>>;
  let friends: { areFriends: ReturnType<typeof vi.fn> };
  let realtime: { emitToUser: ReturnType<typeof vi.fn> };
  let push: { sendToUser: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    prisma = {
      user: { findUnique: vi.fn() },
      refreshToken: { findMany: vi.fn() },
      musicControlDelegation: {
        findUnique: vi.fn(),
        findMany: vi.fn(),
        upsert: vi.fn(),
        delete: vi.fn(),
      },
    };
    friends = { areFriends: vi.fn() };
    realtime = { emitToUser: vi.fn() };
    push = { sendToUser: vi.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DelegationService,
        { provide: PrismaService, useValue: prisma },
        { provide: FriendsService, useValue: friends },
        { provide: RealtimeService, useValue: realtime },
        { provide: PushService, useValue: push },
      ],
    }).compile();

    service = module.get(DelegationService);
  });

  describe('grant', () => {
    it('rejects delegating control to yourself', async () => {
      await expect(
        service.grant('owner-1', 'device-A', 'owner-1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects when the delegate user does not exist', async () => {
      prisma.user.findUnique.mockResolvedValue(null);
      await expect(
        service.grant('owner-1', 'device-A', 'ghost'),
      ).rejects.toThrow(NotFoundException);
    });

    it('rejects when the delegate is not a friend', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'stranger' });
      friends.areFriends.mockResolvedValue(false);
      await expect(
        service.grant('owner-1', 'device-A', 'stranger'),
      ).rejects.toThrow(ForbiddenException);
    });

    it('creates the delegation and notifies the delegate when friends', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'friend-1' });
      friends.areFriends.mockResolvedValue(true);
      prisma.musicControlDelegation.findUnique.mockResolvedValue(null);
      prisma.musicControlDelegation.upsert.mockResolvedValue({
        id: 'del-1',
        ownerId: 'owner-1',
        deviceId: 'device-A',
        delegateUserId: 'friend-1',
      });

      await service.grant('owner-1', 'device-A', 'friend-1');

      expect(prisma.musicControlDelegation.upsert).toHaveBeenCalledWith({
        where: { ownerId_deviceId: { ownerId: 'owner-1', deviceId: 'device-A' } },
        update: { delegateUserId: 'friend-1', grantedAt: expect.any(Date) },
        create: {
          ownerId: 'owner-1',
          deviceId: 'device-A',
          delegateUserId: 'friend-1',
        },
      });
      expect(realtime.emitToUser).toHaveBeenCalledWith(
        'friend-1',
        'device:delegation:granted',
        { deviceId: 'device-A', ownerId: 'owner-1' },
      );
    });

    it('notifies the previous delegate when control moves to someone else', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'friend-2' });
      friends.areFriends.mockResolvedValue(true);
      prisma.musicControlDelegation.findUnique.mockResolvedValue({
        delegateUserId: 'friend-1',
      });
      prisma.musicControlDelegation.upsert.mockResolvedValue({ id: 'del-1' });

      await service.grant('owner-1', 'device-A', 'friend-2');

      expect(realtime.emitToUser).toHaveBeenCalledWith(
        'friend-1',
        'device:delegation:revoked',
        { deviceId: 'device-A', ownerId: 'owner-1' },
      );
    });

    it('does NOT emit a revoke when re-granting to the same delegate', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'friend-1' });
      friends.areFriends.mockResolvedValue(true);
      prisma.musicControlDelegation.findUnique.mockResolvedValue({
        delegateUserId: 'friend-1',
      });
      prisma.musicControlDelegation.upsert.mockResolvedValue({ id: 'del-1' });

      await service.grant('owner-1', 'device-A', 'friend-1');

      const revokeCall = realtime.emitToUser.mock.calls.find(
        (c: unknown[]) => c[1] === 'device:delegation:revoked',
      );
      expect(revokeCall).toBeUndefined();
    });
  });

  describe('revoke', () => {
    it('throws 404 when there is no delegation for the device', async () => {
      prisma.musicControlDelegation.findUnique.mockResolvedValue(null);
      await expect(service.revoke('owner-1', 'device-A')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('deletes the delegation and notifies the delegate', async () => {
      prisma.musicControlDelegation.findUnique.mockResolvedValue({
        delegateUserId: 'friend-1',
      });

      await service.revoke('owner-1', 'device-A');

      expect(prisma.musicControlDelegation.delete).toHaveBeenCalledWith({
        where: { ownerId_deviceId: { ownerId: 'owner-1', deviceId: 'device-A' } },
      });
      expect(realtime.emitToUser).toHaveBeenCalledWith(
        'friend-1',
        'device:delegation:revoked',
        { deviceId: 'device-A', ownerId: 'owner-1' },
      );
    });
  });

  describe('listing', () => {
    it('listMyDelegations filters by ownerId', async () => {
      prisma.musicControlDelegation.findMany.mockResolvedValue([]);
      await service.listMyDelegations('owner-1');
      expect(prisma.musicControlDelegation.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { ownerId: 'owner-1' } }),
      );
    });

    it('listControlledDevices filters by delegateUserId', async () => {
      prisma.musicControlDelegation.findMany.mockResolvedValue([]);
      await service.listControlledDevices('friend-1');
      expect(prisma.musicControlDelegation.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { delegateUserId: 'friend-1' } }),
      );
    });
  });

  describe('listMyDevices', () => {
    it('lists account devices from sessions, dedup, annotated with delegations', async () => {
      prisma.refreshToken.findMany.mockResolvedValue([
        { deviceId: 'phone', userAgent: 'iOS', createdAt: new Date(2_000) },
        { deviceId: 'phone', userAgent: 'iOS', createdAt: new Date(1_000) },
        { deviceId: 'tablet', userAgent: 'iPadOS', createdAt: new Date(500) },
        { deviceId: null, userAgent: 'web', createdAt: new Date(100) },
      ]);
      prisma.musicControlDelegation.findMany.mockResolvedValue([
        { id: 'del-1', deviceId: 'phone', delegateUserId: 'friend-1' },
      ]);

      const devices = await service.listMyDevices('owner-1');

      expect(devices).toHaveLength(2); // null skipped, phone deduped
      const phone = devices.find((d) => d.deviceId === 'phone');
      expect(phone?.delegation).toBeTruthy();
      expect(devices.find((d) => d.deviceId === 'tablet')?.delegation).toBeNull();
    });

    it('keeps a delegated device that has no active session', async () => {
      prisma.refreshToken.findMany.mockResolvedValue([]);
      prisma.musicControlDelegation.findMany.mockResolvedValue([
        { id: 'del-1', deviceId: 'old-phone', delegateUserId: 'friend-1' },
      ]);

      const devices = await service.listMyDevices('owner-1');

      expect(devices).toHaveLength(1);
      expect(devices[0].deviceId).toBe('old-phone');
      expect(devices[0].lastSeenAt).toBeNull();
    });
  });
});
