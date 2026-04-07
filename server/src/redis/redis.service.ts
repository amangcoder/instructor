import {
  Injectable,
  Logger,
  OnModuleInit,
  OnModuleDestroy,
} from '@nestjs/common';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  client!: Redis;

  onModuleInit(): void {
    const url = process.env.REDIS_URL ?? 'redis://127.0.0.1:6379';

    this.client = new Redis(url, {
      maxRetriesPerRequest: 3,
      retryStrategy(times) {
        // Exponential backoff capped at 3 seconds.
        return Math.min(times * 200, 3_000);
      },
      lazyConnect: false,
    });

    this.client.on('connect', () =>
      this.logger.log(`Connected to Redis at ${url}`),
    );
    this.client.on('error', (err) =>
      this.logger.error(`Redis error: ${err.message}`),
    );
  }

  onModuleDestroy(): void {
    this.client?.disconnect();
  }
}
