import { Injectable } from '@nestjs/common';
import { RedisService } from '../redis/redis.service';

@Injectable()
export class JwtBlacklistService {
  private readonly PREFIX = 'jwt:blacklist:';

  constructor(private readonly redis: RedisService) {}

  async blacklist(token: string, ttlSeconds: number): Promise<void> {
    await this.redis.set(`${this.PREFIX}${token}`, '1', ttlSeconds);
  }

  async isBlacklisted(token: string): Promise<boolean> {
    return this.redis.exists(`${this.PREFIX}${token}`);
  }
}
