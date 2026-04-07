import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { RedisService } from './redis.service';

// Mock ioredis
vi.mock('ioredis', () => {
  const RedisMock = vi.fn().mockImplementation(() => ({
    connect: vi.fn().mockResolvedValue(undefined),
    quit: vi.fn().mockResolvedValue(undefined),
    ping: vi.fn().mockResolvedValue('PONG'),
    set: vi.fn().mockResolvedValue('OK'),
    get: vi.fn().mockResolvedValue(null),
    del: vi.fn().mockResolvedValue(1),
    exists: vi.fn().mockResolvedValue(0),
  }));
  return { default: RedisMock };
});

describe('RedisService', () => {
  let service: RedisService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RedisService,
        {
          provide: ConfigService,
          useValue: {
            get: vi.fn((key: string, defaultValue: unknown) => defaultValue),
          },
        },
      ],
    }).compile();

    service = module.get<RedisService>(RedisService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('onModuleInit', () => {
    it('should connect to Redis', async () => {
      await service.onModuleInit();
      const client = service.getClient();
      expect(client.connect).toHaveBeenCalled();
    });
  });

  describe('onModuleDestroy', () => {
    it('should disconnect from Redis', async () => {
      await service.onModuleDestroy();
      const client = service.getClient();
      expect(client.quit).toHaveBeenCalled();
    });
  });

  describe('isHealthy', () => {
    it('should return true when Redis responds PONG', async () => {
      const result = await service.isHealthy();
      expect(result).toBe(true);
    });

    it('should return false when Redis throws', async () => {
      const client = service.getClient();
      (client.ping as ReturnType<typeof vi.fn>).mockRejectedValueOnce(
        new Error('Connection refused'),
      );
      const result = await service.isHealthy();
      expect(result).toBe(false);
    });
  });

  describe('set', () => {
    it('should set a value without TTL', async () => {
      await service.set('key', 'value');
      const client = service.getClient();
      expect(client.set).toHaveBeenCalledWith('key', 'value');
    });

    it('should set a value with TTL', async () => {
      await service.set('key', 'value', 60);
      const client = service.getClient();
      expect(client.set).toHaveBeenCalledWith('key', 'value', 'EX', 60);
    });
  });

  describe('get', () => {
    it('should get a value', async () => {
      const client = service.getClient();
      (client.get as ReturnType<typeof vi.fn>).mockResolvedValueOnce(
        'my-value',
      );
      const result = await service.get('key');
      expect(result).toBe('my-value');
    });

    it('should return null for missing key', async () => {
      const result = await service.get('missing');
      expect(result).toBeNull();
    });
  });

  describe('del', () => {
    it('should delete a key', async () => {
      await service.del('key');
      const client = service.getClient();
      expect(client.del).toHaveBeenCalledWith('key');
    });
  });

  describe('exists', () => {
    it('should return false when key does not exist', async () => {
      const result = await service.exists('key');
      expect(result).toBe(false);
    });

    it('should return true when key exists', async () => {
      const client = service.getClient();
      (client.exists as ReturnType<typeof vi.fn>).mockResolvedValueOnce(1);
      const result = await service.exists('key');
      expect(result).toBe(true);
    });
  });
});
