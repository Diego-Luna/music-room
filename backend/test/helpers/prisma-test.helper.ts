import { PrismaService } from '@/prisma/prisma.service';

export function createMockPrismaService(): Partial<PrismaService> {
  return {
    $connect: vi.fn(),
    $disconnect: vi.fn(),
    $queryRaw: vi.fn(),
    isHealthy: vi.fn().mockResolvedValue(true),
  };
}
