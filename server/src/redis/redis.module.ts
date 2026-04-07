import { Global, Module } from '@nestjs/common';
import { RedisService } from './redis.service';
import { RateLimitService } from './rate-limit.service';
import { RedisThrottlerStorage } from './redis-throttler.storage';

/**
 * Global RedisModule — imported once in AppModule and available everywhere.
 */
@Global()
@Module({
  providers: [RedisService, RateLimitService, RedisThrottlerStorage],
  exports: [RedisService, RateLimitService, RedisThrottlerStorage],
})
export class RedisModule {}
