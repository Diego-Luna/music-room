import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import { Public } from '../common/decorators/public.decorator';

interface HealthStatus {
  status: 'ok' | 'error';
  db: 'connected' | 'disconnected';
  redis: 'connected' | 'disconnected';
  uptime: number;
}

@ApiTags('Health')
@Controller('health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  @Public()
  @Get()
  @ApiOperation({ summary: 'Health check' })
  @ApiResponse({ status: 200, description: 'Service is healthy' })
  @ApiResponse({ status: 503, description: 'Service is unhealthy' })
  async check(): Promise<HealthStatus> {
    const [dbHealthy, redisHealthy] = await Promise.all([
      this.prisma.isHealthy(),
      this.redis.isHealthy(),
    ]);

    const status = dbHealthy && redisHealthy ? 'ok' : 'error';

    return {
      status,
      db: dbHealthy ? 'connected' : 'disconnected',
      redis: redisHealthy ? 'connected' : 'disconnected',
      uptime: process.uptime(),
    };
  }
}
