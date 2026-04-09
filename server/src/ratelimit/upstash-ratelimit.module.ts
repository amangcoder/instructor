/**
 * UpstashRateLimiterModule — global module providing UpstashRateLimitService.
 *
 * Import once in AppModule. Replaces DynamoDBRateLimiterModule for
 * custom per-key rate limiting (OTP requests, plan generation quota).
 *
 * Declared @Global() so importing modules do not need to add it to their
 * own imports array — the service is available application-wide.
 */

import { Global, Module } from '@nestjs/common';
import { UpstashRateLimitService } from './upstash-ratelimit.service';

@Global()
@Module({
  providers: [UpstashRateLimitService],
  exports: [UpstashRateLimitService],
})
export class UpstashRateLimiterModule {}
