import { Injectable } from '@nestjs/common';
import { RedisService } from './redis.service';

export interface RateLimitResult {
  allowed: boolean;
  current: number;
  retryAfterSec: number;
}

/**
 * Generic Redis-backed rate limiter using fixed-window counters.
 * Used for custom per-key limits (OTP emails, plan generation) that
 * need to survive restarts and work across multiple server instances.
 */
@Injectable()
export class RateLimitService {
  /** Lua script: atomic check-then-increment (no over-counting on denial). */
  private static readonly CONSUME_SCRIPT = `
    local key = KEYS[1]
    local limit = tonumber(ARGV[1])
    local window = tonumber(ARGV[2])

    local current = tonumber(redis.call('GET', key) or '0')
    if current >= limit then
      local ttl = redis.call('TTL', key)
      return {0, current, ttl}
    end

    local count = redis.call('INCR', key)
    if count == 1 then
      redis.call('EXPIRE', key, window)
    end

    return {1, count, 0}
  `;

  constructor(private readonly redis: RedisService) {}

  /**
   * Check the rate limit and increment the counter atomically.
   * Returns whether the request is allowed.
   *
   * @param namespace  Logical group (e.g. "otp", "plan")
   * @param identifier Per-entity key (e.g. email, userId)
   * @param limit      Max requests allowed in the window
   * @param windowSec  Window duration in seconds
   */
  async consume(
    namespace: string,
    identifier: string,
    limit: number,
    windowSec: number,
  ): Promise<RateLimitResult> {
    const key = `rl:${namespace}:${identifier}`;
    const result = (await this.redis.client.eval(
      RateLimitService.CONSUME_SCRIPT,
      1,
      key,
      limit,
      windowSec,
    )) as number[];

    return {
      allowed: result[0] === 1,
      current: result[1],
      retryAfterSec: result[2],
    };
  }

  /**
   * Check the rate limit WITHOUT incrementing.
   * Use when you need to verify the limit before performing work,
   * then call `increment()` after success (e.g. plan generation).
   */
  async peek(
    namespace: string,
    identifier: string,
    limit: number,
  ): Promise<RateLimitResult> {
    const key = `rl:${namespace}:${identifier}`;
    const [countStr, ttl] = await Promise.all([
      this.redis.client.get(key),
      this.redis.client.ttl(key),
    ]);

    const current = parseInt(countStr ?? '0', 10);
    const allowed = current < limit;

    return {
      allowed,
      current,
      retryAfterSec: allowed ? 0 : Math.max(ttl, 0),
    };
  }

  /**
   * Record one unit of usage (increment without checking).
   * Call after a successful operation that should count against the limit.
   */
  async increment(
    namespace: string,
    identifier: string,
    windowSec: number,
  ): Promise<void> {
    const key = `rl:${namespace}:${identifier}`;
    const count = await this.redis.client.incr(key);
    if (count === 1) {
      await this.redis.client.expire(key, windowSec);
    }
  }
}
