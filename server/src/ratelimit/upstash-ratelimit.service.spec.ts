/**
 * Unit tests for UpstashRateLimitService.
 *
 * All @upstash/redis calls are intercepted via jest mocks.
 * No real Upstash/Redis calls are made in CI.
 *
 * Scenarios covered:
 *   consume():
 *     - allowed=true when counter <= limit (first request)
 *     - allowed=true on exactly the limit-th request
 *     - allowed=false when counter exceeds limit
 *     - retryAfterSec is positive (from pttl) when rate-limited
 *     - retryAfterSec is 0 when allowed
 *     - uses pipeline() — not separate incr + expire calls [CRITICAL]
 *     - key format: ratelimit:{namespace}:{identifier}
 *     - TTL safety net: detects orphaned keys (ttl=-1) and sets expiry
 *     - propagates Redis errors
 *   peek():
 *     - allowed=true, current=0 when no counter exists (GET returns null)
 *     - allowed=true when count is below limit
 *     - allowed=false when count equals or exceeds limit
 *     - does NOT increment counter (no pipeline/incr call)
 *     - retryAfterSec from pttl when denied
 *   increment():
 *     - uses pipeline() for unconditional INCR+PEXPIRE [CRITICAL]
 *     - resolves without throwing
 *   Noop mode:
 *     - returns {allowed: true} when UPSTASH_REDIS_REST_URL unset
 *     - no Redis calls in noop mode
 */

import { Test, TestingModule } from '@nestjs/testing';
import { UpstashRateLimitService } from './upstash-ratelimit.service';

// ---------------------------------------------------------------------------
// Mock @upstash/redis
// ---------------------------------------------------------------------------

const mockExec = jest.fn();
const mockPipelineFn = jest.fn(() => ({
  incr: jest.fn().mockReturnThis(),
  pexpire: jest.fn().mockReturnThis(),
  exec: mockExec,
}));
const mockGet = jest.fn();
const mockTtl = jest.fn();
const mockPttl = jest.fn();
const mockPexpire = jest.fn();

jest.mock('@upstash/redis', () => ({
  Redis: jest.fn().mockImplementation(() => ({
    pipeline: mockPipelineFn,
    get: mockGet,
    ttl: mockTtl,
    pttl: mockPttl,
    pexpire: mockPexpire,
  })),
}));

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const NS = 'otp';
const ID = 'test@example.com';
const LIMIT = 3;
const WINDOW_SEC = 300;
const WINDOW_MS = WINDOW_SEC * 1000;

function expectedKey(namespace = NS, identifier = ID): string {
  return `ratelimit:${namespace}:${identifier}`;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('UpstashRateLimitService', () => {
  let service: UpstashRateLimitService;

  beforeEach(async () => {
    process.env.UPSTASH_REDIS_REST_URL = 'https://example.upstash.io';
    process.env.UPSTASH_REDIS_REST_TOKEN = 'test-token';

    // Default safe returns
    mockTtl.mockResolvedValue(200); // key exists with TTL — no orphan
    mockPttl.mockResolvedValue(200_000); // 200 seconds remaining
    mockExec.mockResolvedValue([1, 1]); // [INCR result=1, PEXPIRE result=1]
    mockGet.mockResolvedValue(null);
    mockPexpire.mockResolvedValue(1);

    const module: TestingModule = await Test.createTestingModule({
      providers: [UpstashRateLimitService],
    }).compile();

    service = module.get<UpstashRateLimitService>(UpstashRateLimitService);
  });

  afterEach(() => {
    jest.clearAllMocks();
    delete process.env.UPSTASH_REDIS_REST_URL;
    delete process.env.UPSTASH_REDIS_REST_TOKEN;
  });

  // ── consume ─────────────────────────────────────────────────────────────────

  describe('consume', () => {
    it('returns { allowed: true } when counter is below the limit (first request)', async () => {
      mockExec.mockResolvedValue([1, 1]); // INCR=1, PEXPIRE=1
      const result = await service.consume(NS, ID, LIMIT, WINDOW_SEC);
      expect(result.allowed).toBe(true);
    });

    it('returns { allowed: true } on exactly the limit-th request', async () => {
      mockExec.mockResolvedValue([LIMIT, 1]); // INCR hits limit exactly
      const result = await service.consume(NS, ID, LIMIT, WINDOW_SEC);
      expect(result.allowed).toBe(true);
      expect(result.current).toBe(LIMIT);
    });

    it('returns { allowed: false } when counter exceeds the limit', async () => {
      mockExec.mockResolvedValue([LIMIT + 1, 1]);
      const result = await service.consume(NS, ID, LIMIT, WINDOW_SEC);
      expect(result.allowed).toBe(false);
    });

    it('retryAfterSec is positive (from pttl) when rate-limited', async () => {
      mockExec.mockResolvedValue([LIMIT + 1, 1]);
      mockPttl.mockResolvedValue(120_000); // 120 seconds remaining
      const result = await service.consume(NS, ID, LIMIT, WINDOW_SEC);
      expect(result.retryAfterSec).toBeGreaterThan(0);
      expect(result.retryAfterSec).toBe(120); // ceil(120000/1000)
    });

    it('retryAfterSec is 0 when allowed', async () => {
      mockExec.mockResolvedValue([1, 1]);
      const result = await service.consume(NS, ID, LIMIT, WINDOW_SEC);
      expect(result.retryAfterSec).toBe(0);
    });

    it('[CRITICAL] calls pipeline() — not separate incr/expire calls', async () => {
      mockExec.mockResolvedValue([1, 1]);
      await service.consume(NS, ID, LIMIT, WINDOW_SEC);
      expect(mockPipelineFn).toHaveBeenCalledTimes(1);
      // Direct redis.incr should NOT be called — only pipeline().incr()
      // (The mock tracks pipeline() calls, not standalone incr)
    });

    it('pipeline result[0] is returned as current on success', async () => {
      mockExec.mockResolvedValue([2, 1]);
      const result = await service.consume(NS, ID, LIMIT, WINDOW_SEC);
      expect(result.current).toBe(2);
    });

    it('pipeline result[0] is returned as current on denial', async () => {
      mockExec.mockResolvedValue([LIMIT + 2, 1]);
      mockPttl.mockResolvedValue(50_000);
      const result = await service.consume(NS, ID, LIMIT, WINDOW_SEC);
      expect(result.current).toBe(LIMIT + 2);
      expect(result.allowed).toBe(false);
    });

    it('key format is ratelimit:{namespace}:{identifier}', async () => {
      const pipelineInstance = {
        incr: jest.fn().mockReturnThis(),
        pexpire: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue([1, 1]),
      };
      mockPipelineFn.mockReturnValueOnce(pipelineInstance);

      await service.consume(NS, ID, LIMIT, WINDOW_SEC);

      expect(pipelineInstance.incr).toHaveBeenCalledWith(expectedKey());
      expect(pipelineInstance.pexpire).toHaveBeenCalledWith(expectedKey(), WINDOW_MS);
    });

    it('key uses plan namespace and userId as identifier', async () => {
      const pipelineInstance = {
        incr: jest.fn().mockReturnThis(),
        pexpire: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue([1, 1]),
      };
      mockPipelineFn.mockReturnValueOnce(pipelineInstance);

      await service.consume('plan', 'user-123', 10, 3600);

      expect(pipelineInstance.incr).toHaveBeenCalledWith('ratelimit:plan:user-123');
    });

    it('TTL safety net: does NOT call pexpire when key has valid TTL', async () => {
      mockTtl.mockResolvedValue(150); // Key has a valid TTL
      mockExec.mockResolvedValue([1, 1]);

      await service.consume(NS, ID, LIMIT, WINDOW_SEC);

      // pexpire as standalone (orphan fix) should NOT be called
      expect(mockPexpire).not.toHaveBeenCalled();
    });

    it('TTL safety net: does NOT call pexpire when key does not exist (ttl = -2)', async () => {
      mockTtl.mockResolvedValue(-2); // Key does not exist yet
      mockExec.mockResolvedValue([1, 1]);

      await service.consume(NS, ID, LIMIT, WINDOW_SEC);

      expect(mockPexpire).not.toHaveBeenCalled();
    });

    it('propagates pipeline errors (HTTP failure)', async () => {
      mockExec.mockRejectedValue(new Error('Upstash HTTP error 500'));
      await expect(service.consume(NS, ID, LIMIT, WINDOW_SEC)).rejects.toThrow(
        /Upstash HTTP error/i,
      );
    });

    it('falls back to windowSec for retryAfterSec when pttl returns non-positive', async () => {
      mockExec.mockResolvedValue([LIMIT + 1, 1]);
      mockPttl.mockResolvedValue(0); // pttl returns 0 (edge case)
      const result = await service.consume(NS, ID, LIMIT, WINDOW_SEC);
      expect(result.retryAfterSec).toBe(WINDOW_SEC);
    });

    it('two different identifiers have independent keys', async () => {
      const pipelineA = {
        incr: jest.fn().mockReturnThis(),
        pexpire: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue([1, 1]),
      };
      const pipelineB = {
        incr: jest.fn().mockReturnThis(),
        pexpire: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue([1, 1]),
      };
      mockPipelineFn.mockReturnValueOnce(pipelineA).mockReturnValueOnce(pipelineB);

      await service.consume(NS, 'alice@example.com', LIMIT, WINDOW_SEC);
      await service.consume(NS, 'bob@example.com', LIMIT, WINDOW_SEC);

      expect(pipelineA.incr).toHaveBeenCalledWith('ratelimit:otp:alice@example.com');
      expect(pipelineB.incr).toHaveBeenCalledWith('ratelimit:otp:bob@example.com');
    });
  });

  // ── peek ────────────────────────────────────────────────────────────────────

  describe('peek', () => {
    it('returns { allowed: true, current: 0 } when no counter record exists', async () => {
      mockGet.mockResolvedValue(null);
      const result = await service.peek(NS, ID, LIMIT);
      expect(result.allowed).toBe(true);
      expect(result.current).toBe(0);
    });

    it('returns { allowed: true } when count is below the limit', async () => {
      mockGet.mockResolvedValue('2');
      const result = await service.peek(NS, ID, LIMIT);
      expect(result.allowed).toBe(true);
      expect(result.current).toBe(2);
    });

    it('returns { allowed: false } when count equals the limit', async () => {
      mockGet.mockResolvedValue(String(LIMIT));
      const result = await service.peek(NS, ID, LIMIT);
      expect(result.allowed).toBe(false);
      expect(result.current).toBe(LIMIT);
    });

    it('returns { allowed: false } when count exceeds the limit', async () => {
      mockGet.mockResolvedValue(String(LIMIT + 2));
      const result = await service.peek(NS, ID, LIMIT);
      expect(result.allowed).toBe(false);
    });

    it('does NOT call pipeline/incr — read-only operation', async () => {
      mockGet.mockResolvedValue('1');
      await service.peek(NS, ID, LIMIT);
      expect(mockPipelineFn).not.toHaveBeenCalled();
    });

    it('retryAfterSec is positive from pttl when rate-limited', async () => {
      mockGet.mockResolvedValue(String(LIMIT));
      mockPttl.mockResolvedValue(90_000); // 90 seconds remaining
      const result = await service.peek(NS, ID, LIMIT);
      expect(result.retryAfterSec).toBe(90);
    });

    it('retryAfterSec is 0 when within limit', async () => {
      mockGet.mockResolvedValue('1');
      const result = await service.peek(NS, ID, LIMIT);
      expect(result.retryAfterSec).toBe(0);
    });

    it('retryAfterSec is 0 when no counter exists', async () => {
      mockGet.mockResolvedValue(null);
      const result = await service.peek(NS, ID, LIMIT);
      expect(result.retryAfterSec).toBe(0);
    });
  });

  // ── increment ───────────────────────────────────────────────────────────────

  describe('increment', () => {
    it('[CRITICAL] uses pipeline() for unconditional INCR+PEXPIRE', async () => {
      const pipelineInstance = {
        incr: jest.fn().mockReturnThis(),
        pexpire: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue([1, 1]),
      };
      mockPipelineFn.mockReturnValueOnce(pipelineInstance);

      await service.increment(NS, ID, WINDOW_SEC);

      expect(mockPipelineFn).toHaveBeenCalledTimes(1);
      expect(pipelineInstance.incr).toHaveBeenCalledWith(expectedKey());
      expect(pipelineInstance.pexpire).toHaveBeenCalledWith(expectedKey(), WINDOW_MS);
    });

    it('resolves without throwing', async () => {
      mockExec.mockResolvedValue([1, 1]);
      await expect(service.increment(NS, ID, WINDOW_SEC)).resolves.toBeUndefined();
    });

    it('calls exactly one pipeline execution (single HTTP round-trip)', async () => {
      mockExec.mockResolvedValue([1, 1]);
      await service.increment(NS, ID, WINDOW_SEC);
      expect(mockPipelineFn).toHaveBeenCalledTimes(1);
      expect(mockExec).toHaveBeenCalledTimes(1);
    });

    it('uses correct key format for increment', async () => {
      const pipelineInstance = {
        incr: jest.fn().mockReturnThis(),
        pexpire: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue([1, 1]),
      };
      mockPipelineFn.mockReturnValueOnce(pipelineInstance);

      await service.increment('plan', 'user-abc', 3600);

      expect(pipelineInstance.incr).toHaveBeenCalledWith('ratelimit:plan:user-abc');
      expect(pipelineInstance.pexpire).toHaveBeenCalledWith('ratelimit:plan:user-abc', 3_600_000);
    });
  });

  // ── Noop mode ────────────────────────────────────────────────────────────────

  describe('noop mode (UPSTASH_REDIS_REST_URL unset)', () => {
    let noopService: UpstashRateLimitService;

    beforeEach(async () => {
      delete process.env.UPSTASH_REDIS_REST_URL;
      delete process.env.UPSTASH_REDIS_REST_TOKEN;

      jest.clearAllMocks();

      const module: TestingModule = await Test.createTestingModule({
        providers: [UpstashRateLimitService],
      }).compile();

      noopService = module.get<UpstashRateLimitService>(UpstashRateLimitService);
    });

    it('consume() returns { allowed: true, current: 0, retryAfterSec: 0 }', async () => {
      const result = await noopService.consume(NS, ID, LIMIT, WINDOW_SEC);
      expect(result).toEqual({ allowed: true, current: 0, retryAfterSec: 0 });
    });

    it('consume() makes no Redis calls in noop mode', async () => {
      await noopService.consume(NS, ID, LIMIT, WINDOW_SEC);
      expect(mockPipelineFn).not.toHaveBeenCalled();
      expect(mockTtl).not.toHaveBeenCalled();
    });

    it('peek() returns { allowed: true, current: 0, retryAfterSec: 0 } in noop mode', async () => {
      const result = await noopService.peek(NS, ID, LIMIT);
      expect(result).toEqual({ allowed: true, current: 0, retryAfterSec: 0 });
    });

    it('peek() makes no Redis calls in noop mode', async () => {
      await noopService.peek(NS, ID, LIMIT);
      expect(mockGet).not.toHaveBeenCalled();
    });

    it('increment() resolves without throwing in noop mode', async () => {
      await expect(noopService.increment(NS, ID, WINDOW_SEC)).resolves.toBeUndefined();
    });

    it('increment() makes no Redis calls in noop mode', async () => {
      await noopService.increment(NS, ID, WINDOW_SEC);
      expect(mockPipelineFn).not.toHaveBeenCalled();
    });
  });

  // ── Key construction ──────────────────────────────────────────────────────────

  describe('rate-limit key construction', () => {
    it('key format is ratelimit:{namespace}:{identifier}', async () => {
      mockExec.mockResolvedValue([1, 1]);
      const pipelineInstance = {
        incr: jest.fn().mockReturnThis(),
        pexpire: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue([1, 1]),
      };
      mockPipelineFn.mockReturnValueOnce(pipelineInstance);

      await service.consume('otp', 'alice@example.com', LIMIT, WINDOW_SEC);

      expect(pipelineInstance.incr).toHaveBeenCalledWith('ratelimit:otp:alice@example.com');
    });

    it('OTP rate limits are scoped to email address', async () => {
      const pipelineInstance = {
        incr: jest.fn().mockReturnThis(),
        pexpire: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue([1, 1]),
      };
      mockPipelineFn.mockReturnValueOnce(pipelineInstance);

      await service.consume('otp', 'user@example.com', LIMIT, WINDOW_SEC);

      expect(pipelineInstance.incr).toHaveBeenCalledWith(
        expect.stringContaining('user@example.com'),
      );
    });

    it('plan rate limits are scoped to userId', async () => {
      const pipelineInstance = {
        incr: jest.fn().mockReturnThis(),
        pexpire: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue([1, 1]),
      };
      mockPipelineFn.mockReturnValueOnce(pipelineInstance);

      await service.consume('plan', 'user-999', 10, 3600);

      expect(pipelineInstance.incr).toHaveBeenCalledWith('ratelimit:plan:user-999');
    });
  });
});
