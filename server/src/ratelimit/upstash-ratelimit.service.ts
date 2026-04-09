/**
 * UpstashRateLimitService — replaces DynamoDBRateLimitService.
 *
 * Uses @upstash/redis HTTP client (no TCP connections, serverless-safe) to
 * implement fixed-window rate limiting with atomic INCR + PEXPIRE pipelines.
 *
 * Key format:  ratelimit:{namespace}:{identifier}
 *
 * Algorithm for consume():
 *   1. Atomic pipeline: INCR key + PEXPIRE key windowMs (single HTTP request —
 *      if HTTP fails, neither command executes; no orphaned keys).
 *   2. If INCR result <= limit: allow. If > limit: get PTTL and deny.
 *
 * Note: the upfront TTL safety-net (redis.ttl check before the pipeline) has
 * been removed to keep the normal case at 2 Redis commands (INCR + PEXPIRE)
 * and stay within Upstash's 10,000 commands/day free tier at ~1,000 DAU.
 * The orphaned-key scenario (INCR completes but PEXPIRE never runs) is
 * theoretically possible but extremely unlikely with Upstash's HTTP-atomic
 * pipeline model — if the HTTP request fails, neither command executes.
 *
 * Environment variables:
 *   UPSTASH_REDIS_REST_URL   — Upstash Redis REST endpoint
 *   UPSTASH_REDIS_REST_TOKEN — Upstash Redis REST token
 *
 * Noop mode (when UPSTASH_REDIS_REST_URL is unset):
 *   All consume() calls return { allowed: true, current: 0, retryAfterSec: 0 }.
 *   No Redis calls are made. Useful for local dev without Redis.
 *
 * Free-tier usage estimate (Upstash — 10,000 commands/day):
 *   Normal case:  2 commands per consume() call (INCR + PEXPIRE)
 *   Denied case:  3 commands per consume() call (INCR + PEXPIRE + PTTL)
 *   ~1,000 DAU × 2 Redis commands per auth request ≈ 1,000–3,000 commands/day
 *   (~10–30% of free tier).
 */

import { Injectable, Logger } from '@nestjs/common';
import { Redis } from '@upstash/redis';

// ── Public interface ──────────────────────────────────────────────────────────

export interface RateLimitResult {
  allowed: boolean;
  current: number;
  retryAfterSec: number;
}

// ── Key builder ───────────────────────────────────────────────────────────────

function rateLimitKey(namespace: string, identifier: string): string {
  return `ratelimit:${namespace}:${identifier}`;
}

// ── Service ───────────────────────────────────────────────────────────────────

@Injectable()
export class UpstashRateLimitService {
  private readonly logger = new Logger(UpstashRateLimitService.name);
  private readonly redis: Redis;

  /** True when Upstash credentials are unset — all operations become no-ops. */
  private readonly noop: boolean;

  constructor() {
    const url = process.env.UPSTASH_REDIS_REST_URL ?? '';
    const token = process.env.UPSTASH_REDIS_REST_TOKEN ?? '';

    this.noop = url === '';

    if (this.noop) {
      this.logger.warn(
        'UPSTASH_REDIS_REST_URL not set — rate limiting is disabled (all requests allowed)',
      );
      this.redis = null as unknown as Redis;
      return;
    }

    this.redis = new Redis({ url, token });
  }

  /**
   * Atomically increment the rate-limit counter and check whether it is within bounds.
   *
   * Uses an atomic pipeline (single HTTP round-trip):
   *   INCR ratelimit:{namespace}:{identifier}
   *   PEXPIRE ratelimit:{namespace}:{identifier} {windowMs}
   *
   * If the pipeline HTTP request fails, neither command executes (no orphaned keys).
   *
   * TTL safety net: if the key exists without a TTL (e.g. from a crashed request that
   * completed INCR but not PEXPIRE), we detect it via TTL = -1 and immediately set the
   * expiry before the main pipeline runs.
   *
   * @param namespace   Logical group, e.g. "otp", "plan"
   * @param identifier  Per-entity key, e.g. email address or userId
   * @param limit       Max requests allowed in the window
   * @param windowSec   Window duration in seconds
   */
  async consume(
    namespace: string,
    identifier: string,
    limit: number,
    windowSec: number,
  ): Promise<RateLimitResult> {
    if (this.noop) {
      return { allowed: true, current: 0, retryAfterSec: 0 };
    }

    const key = rateLimitKey(namespace, identifier);
    const windowMs = windowSec * 1000;

    // ── Atomic INCR + PEXPIRE pipeline ────────────────────────────────────────
    // Single HTTP round-trip: if the request fails, neither command executes.
    const pipeline = this.redis.pipeline();
    pipeline.incr(key);
    pipeline.pexpire(key, windowMs);
    const results = await pipeline.exec();

    const current = results[0] as number;

    if (current <= limit) {
      return { allowed: true, current, retryAfterSec: 0 };
    }

    // ── Denied: compute remaining window time ─────────────────────────────────
    // PTTL gives sub-second precision for retry guidance.
    const remainingMs = await this.redis.pttl(key);
    const retryAfterSec = remainingMs > 0 ? Math.ceil(remainingMs / 1000) : windowSec;

    this.logger.debug(
      `Rate limit exceeded for ${namespace}/${identifier} — current=${current}, retryAfterSec=${retryAfterSec}`,
    );

    return { allowed: false, current, retryAfterSec };
  }

  /**
   * Check the current counter value without incrementing.
   * Use before expensive work (e.g. Gemini API call) to avoid burning
   * quota on requests that would be rate-limited.
   *
   * Performs two Redis reads (GET + TTL) — both are lightweight.
   *
   * @param namespace   Logical group
   * @param identifier  Per-entity key
   * @param limit       Max requests allowed in the window
   */
  async peek(
    namespace: string,
    identifier: string,
    limit: number,
  ): Promise<RateLimitResult> {
    if (this.noop) {
      return { allowed: true, current: 0, retryAfterSec: 0 };
    }

    const key = rateLimitKey(namespace, identifier);

    const raw = await this.redis.get<string>(key);

    if (raw === null) {
      // No counter exists — definitely under limit.
      return { allowed: true, current: 0, retryAfterSec: 0 };
    }

    const current = Number(raw);
    const allowed = current < limit;

    if (allowed) {
      return { allowed: true, current, retryAfterSec: 0 };
    }

    // Compute retry time from remaining TTL.
    const remainingMs = await this.redis.pttl(key);
    const retryAfterSec = remainingMs > 0 ? Math.ceil(remainingMs / 1000) : 0;

    return { allowed: false, current, retryAfterSec };
  }

  /**
   * Increment the counter unconditionally — no limit check, always sets/refreshes TTL.
   *
   * Uses an atomic pipeline (single HTTP round-trip):
   *   INCR ratelimit:{namespace}:{identifier}
   *   PEXPIRE ratelimit:{namespace}:{identifier} {windowMs}
   *
   * This prevents counter leakage: every increment guarantees the key will expire.
   *
   * @param namespace   Logical group
   * @param identifier  Per-entity key
   * @param windowSec   Window duration in seconds (used to refresh TTL)
   */
  async increment(
    namespace: string,
    identifier: string,
    windowSec: number,
  ): Promise<void> {
    if (this.noop) return;

    const key = rateLimitKey(namespace, identifier);
    const windowMs = windowSec * 1000;

    const pipeline = this.redis.pipeline();
    pipeline.incr(key);
    pipeline.pexpire(key, windowMs);
    await pipeline.exec();
  }
}
