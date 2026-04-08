/**
 * DynamoDBRateLimiterModule — global module providing DynamoDBRateLimitService.
 *
 * Import once in AppModule. Replaces RedisModule + @nestjs/throttler for
 * custom per-key rate limiting (OTP requests, plan generation quota).
 */

import { Global, Module } from '@nestjs/common';
import { DynamoDBRateLimitService } from './dynamodb-ratelimit.service';

@Global()
@Module({
  providers: [DynamoDBRateLimitService],
  exports: [DynamoDBRateLimitService],
})
export class DynamoDBRateLimiterModule {}
