import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from './prisma.service';

describe('PrismaService', () => {
  let service: PrismaService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [PrismaService],
    }).compile();

    service = module.get<PrismaService>(PrismaService);

    // Mock the PrismaClient methods to avoid real DB connections in unit tests
    service.$connect = vi.fn();
    service.$disconnect = vi.fn();
    service.$queryRaw = vi.fn();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('onModuleInit', () => {
    it('should call $connect', async () => {
      await service.onModuleInit();
      expect(service.$connect).toHaveBeenCalledOnce();
    });
  });

  describe('onModuleDestroy', () => {
    it('should call $disconnect', async () => {
      await service.onModuleDestroy();
      expect(service.$disconnect).toHaveBeenCalledOnce();
    });
  });

  describe('isHealthy', () => {
    it('should return true when DB responds', async () => {
      (service.$queryRaw as ReturnType<typeof vi.fn>).mockResolvedValue([
        { '?column?': 1 },
      ]);
      const result = await service.isHealthy();
      expect(result).toBe(true);
    });

    it('should return false when DB throws', async () => {
      (service.$queryRaw as ReturnType<typeof vi.fn>).mockRejectedValue(
        new Error('Connection refused'),
      );
      const result = await service.isHealthy();
      expect(result).toBe(false);
    });
  });
});
