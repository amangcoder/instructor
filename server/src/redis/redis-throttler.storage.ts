import { Injectable } from '@nestjs/common';
import { ThrottlerStorage } from '@nestjs/throttler';
import { RedisService } from './redis.service';

interface StorageRecord {
  totalHits: number;
  timeToExpire: number;
  isBlocked: boolean;
  timeToBlockExpire: number;
}

/**
 * Redis-backed storage for @nestjs/throttler, replacing the default
 * in-memory store so rate limits are shared across all server instances.
 */
@Injectable()
export class RedisThrottlerStorage implements ThrottlerStorage {
  constructor(private readonly redis: RedisService) {}

  async increment(
    key: string,
    ttl: number,
    limit: number,
    blockDuration: number,
    throttlerName: string,
  ): Promise<StorageRecord> {
    const redisKey = `throttle:${throttlerName}:${key}`;
    const blockKey = `throttle:${throttlerName}:${key}:blocked`;

    // Check if currently blocked.
    const blocked = await this.redis.client.get(blockKey);
    if (blocked) {
      const blockTtl = await this.redis.client.ttl(blockKey);
      return {
        totalHits: limit + 1,
        timeToExpire: 0,
        isBlocked: true,
        timeToBlockExpire: Math.max(blockTtl, 0) * 1000,
      };
    }

    // Atomic increment + set TTL on first hit.
    // TTL is in milliseconds from @nestjs/throttler.
    const ttlSec = Math.ceil(ttl / 1000);
    const totalHits = await this.redis.client.incr(redisKey);
    if (totalHits === 1) {
      await this.redis.client.expire(redisKey, ttlSec);
    }

    const currentTtl = await this.redis.client.ttl(redisKey);
    const timeToExpire = Math.max(currentTtl, 0) * 1000;

    // If over limit and blockDuration is set, create a block key.
    if (totalHits > limit && blockDuration > 0) {
      const blockSec = Math.ceil(blockDuration / 1000);
      await this.redis.client.set(blockKey, '1', 'EX', blockSec);
      return {
        totalHits,
        timeToExpire,
        isBlocked: true,
        timeToBlockExpire: blockDuration,
      };
    }

    return {
      totalHits,
      timeToExpire,
      isBlocked: false,
      timeToBlockExpire: 0,
    };
  }
}
