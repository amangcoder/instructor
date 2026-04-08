/**
 * Unit tests for DynamoDBRateLimitService.
 *
 * All DynamoDB SDK calls are intercepted via mocked DocumentClient.send().
 * No real AWS calls are made in CI.
 *
 * Scenarios covered:
 *   consume():
 *     - allowed=true when counter < limit
 *     - allowed=true on exactly the limit-th request
 *     - allowed=false when ConditionalCheckFailedException fires (counter at limit)
 *     - retryAfterSec is positive when rate-limited
 *     - uses pk=RATELIMIT#<namespace>#<identifier> key pattern
 *   peek():
 *     - allowed=true when no counter exists
 *     - allowed=true when count is below limit
 *     - allowed=false when count equals the limit
 *     - does NOT increment the counter (read-only)
 *   increment():
 *     - resolves without throwing
 *     - sends exactly one DynamoDB request
 */

import { Test, TestingModule } from '@nestjs/testing';
import { DynamoDBRateLimitService } from './dynamodb-ratelimit.service';

// ---------------------------------------------------------------------------
// Mock @aws-sdk/client-dynamodb and @aws-sdk/lib-dynamodb
// ---------------------------------------------------------------------------

const mockSend = jest.fn();

class ConditionalCheckFailedException extends Error {
  readonly name = 'ConditionalCheckFailedException';
  constructor() {
    super('The conditional request failed');
    this.name = 'ConditionalCheckFailedException';
  }
}

jest.mock('@aws-sdk/client-dynamodb', () => ({
  DynamoDBClient: jest.fn().mockImplementation(() => ({})),
  ConditionalCheckFailedException,
}));

jest.mock('@aws-sdk/lib-dynamodb', () => ({
  DynamoDBDocumentClient: {
    from: jest.fn().mockReturnValue({ send: mockSend }),
  },
  GetCommand: jest.fn().mockImplementation((input) => ({ _type: 'Get', ...input })),
  PutCommand: jest.fn().mockImplementation((input) => ({ _type: 'Put', ...input })),
  UpdateCommand: jest.fn().mockImplementation((input) => ({ _type: 'Update', ...input })),
}));

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeCounterItem(count: number, windowSec = 300) {
  const ttl = Math.floor(Date.now() / 1000) + windowSec;
  return {
    pk: 'RATELIMIT#otp#test@example.com',
    sk: 'COUNTER',
    count,
    ttl,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('DynamoDBRateLimitService', () => {
  let service: DynamoDBRateLimitService;

  beforeEach(async () => {
    process.env.DYNAMODB_TABLE = 'instructor-test-table';
    process.env.AWS_REGION = 'us-east-1';

    mockSend.mockResolvedValue({});

    const module: TestingModule = await Test.createTestingModule({
      providers: [DynamoDBRateLimitService],
    }).compile();

    service = module.get<DynamoDBRateLimitService>(DynamoDBRateLimitService);
  });

  afterEach(() => {
    jest.clearAllMocks();
    delete process.env.DYNAMODB_TABLE;
    delete process.env.AWS_REGION;
  });

  // ── consume ─────────────────────────────────────────────────────────────────

  describe('consume', () => {
    it('returns { allowed: true } when counter is below the limit (first request)', async () => {
      mockSend.mockResolvedValueOnce({
        Attributes: makeCounterItem(1),
      });

      const result = await service.consume('otp', 'test@example.com', 3, 300);
      expect(result.allowed).toBe(true);
    });

    it('returns { allowed: true } on exactly the 3rd request (at-limit request)', async () => {
      mockSend.mockResolvedValueOnce({
        Attributes: makeCounterItem(3),
      });

      const result = await service.consume('otp', 'test@example.com', 3, 300);
      expect(result.allowed).toBe(true);
    });

    it('returns { allowed: false } when ConditionalCheckFailedException is thrown', async () => {
      // First call: UpdateItem fails (counter already at limit)
      mockSend.mockRejectedValueOnce(new ConditionalCheckFailedException());
      // Second call: GetItem returns current counter
      mockSend.mockResolvedValueOnce({
        Item: makeCounterItem(3),
      });

      const result = await service.consume('otp', 'test@example.com', 3, 300);
      expect(result.allowed).toBe(false);
    });

    it('retryAfterSec is positive when rate-limited', async () => {
      const futureTtl = Math.floor(Date.now() / 1000) + 120;
      mockSend.mockRejectedValueOnce(new ConditionalCheckFailedException());
      mockSend.mockResolvedValueOnce({
        Item: { ...makeCounterItem(3), ttl: futureTtl },
      });

      const result = await service.consume('otp', 'test@example.com', 3, 300);
      expect(result.retryAfterSec).toBeGreaterThan(0);
    });

    it('retryAfterSec is 0 when not rate-limited', async () => {
      mockSend.mockResolvedValueOnce({
        Attributes: makeCounterItem(1),
      });

      const result = await service.consume('otp', 'test@example.com', 3, 300);
      expect(result.retryAfterSec).toBe(0);
    });

    it('uses pk=RATELIMIT#<namespace>#<identifier> key pattern', async () => {
      mockSend.mockResolvedValueOnce({ Attributes: makeCounterItem(1) });
      await service.consume('otp', 'user@example.com', 3, 300);

      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain('RATELIMIT#otp#user@example.com');
    });

    it('uses RATELIMIT#plan#<userId> for plan rate limiting namespace', async () => {
      mockSend.mockResolvedValueOnce({ Attributes: makeCounterItem(1) });
      await service.consume('plan', 'user-123', 10, 3600);

      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain('RATELIMIT#plan#user-123');
    });

    it('propagates non-ConditionalCheck DynamoDB errors', async () => {
      mockSend.mockRejectedValueOnce(new Error('DynamoDB provisioned throughput exceeded'));
      await expect(service.consume('otp', 'test@example.com', 3, 300)).rejects.toThrow(
        /provisioned throughput/i,
      );
    });

    it('result.current reflects the new counter value on success', async () => {
      mockSend.mockResolvedValueOnce({ Attributes: makeCounterItem(2) });

      const result = await service.consume('otp', 'email@example.com', 3, 300);
      expect(result.current).toBe(2);
    });
  });

  // ── peek ────────────────────────────────────────────────────────────────────

  describe('peek', () => {
    it('returns { allowed: true, current: 0 } when no counter record exists', async () => {
      mockSend.mockResolvedValueOnce({ Item: undefined });
      const result = await service.peek('otp', 'test@example.com', 3);
      expect(result.allowed).toBe(true);
      expect(result.current).toBe(0);
    });

    it('returns { allowed: true } when current count is below the limit', async () => {
      mockSend.mockResolvedValueOnce({ Item: makeCounterItem(2) });
      const result = await service.peek('otp', 'test@example.com', 3);
      expect(result.allowed).toBe(true);
    });

    it('returns { allowed: false } when current count equals the limit', async () => {
      mockSend.mockResolvedValueOnce({ Item: makeCounterItem(3) });
      const result = await service.peek('otp', 'test@example.com', 3);
      expect(result.allowed).toBe(false);
    });

    it('returns { allowed: false } when current count exceeds the limit', async () => {
      mockSend.mockResolvedValueOnce({ Item: makeCounterItem(5) });
      const result = await service.peek('otp', 'test@example.com', 3);
      expect(result.allowed).toBe(false);
    });

    it('does NOT increment the counter — exactly one DynamoDB call (Get)', async () => {
      mockSend.mockResolvedValueOnce({ Item: makeCounterItem(1) });
      await service.peek('otp', 'test@example.com', 3);
      // Only 1 DynamoDB send (Get), not 2 (Get + Update)
      expect(mockSend).toHaveBeenCalledTimes(1);
    });

    it('retryAfterSec is positive when peek indicates rate-limited', async () => {
      const futureTtl = Math.floor(Date.now() / 1000) + 200;
      mockSend.mockResolvedValueOnce({
        Item: { ...makeCounterItem(3), ttl: futureTtl },
      });

      const result = await service.peek('otp', 'test@example.com', 3);
      expect(result.retryAfterSec).toBeGreaterThan(0);
    });

    it('retryAfterSec is 0 when peek is within limit', async () => {
      mockSend.mockResolvedValueOnce({ Item: makeCounterItem(1) });
      const result = await service.peek('otp', 'test@example.com', 3);
      expect(result.retryAfterSec).toBe(0);
    });
  });

  // ── increment ───────────────────────────────────────────────────────────────

  describe('increment', () => {
    it('resolves without throwing', async () => {
      mockSend.mockResolvedValueOnce({ Attributes: makeCounterItem(1) });
      await expect(service.increment('plan', 'user-abc', 3600)).resolves.toBeUndefined();
    });

    it('sends exactly one DynamoDB request', async () => {
      mockSend.mockResolvedValueOnce({ Attributes: makeCounterItem(1) });
      await service.increment('plan', 'user-abc', 3600);
      expect(mockSend).toHaveBeenCalledTimes(1);
    });

    it('uses the correct RATELIMIT key pattern', async () => {
      mockSend.mockResolvedValueOnce({ Attributes: makeCounterItem(1) });
      await service.increment('plan', 'user-xyz', 3600);

      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain('RATELIMIT#plan#user-xyz');
    });
  });

  // ── Key construction ────────────────────────────────────────────────────────

  describe('rate-limit key construction', () => {
    it('scopes OTP rate limits to the email address as identifier', async () => {
      mockSend.mockResolvedValueOnce({ Attributes: makeCounterItem(1) });
      await service.consume('otp', 'alice@example.com', 3, 300);

      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain('alice@example.com');
    });

    it('scopes plan rate limits to the userId as identifier', async () => {
      mockSend.mockResolvedValueOnce({ Attributes: makeCounterItem(1) });
      await service.consume('plan', 'user-alice-id', 10, 3600);

      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain('user-alice-id');
    });

    it('two different emails have independent rate-limit keys', async () => {
      mockSend.mockResolvedValueOnce({ Attributes: makeCounterItem(1) });
      mockSend.mockResolvedValueOnce({ Attributes: makeCounterItem(1) });

      await service.consume('otp', 'alice@example.com', 3, 300);
      await service.consume('otp', 'bob@example.com', 3, 300);

      const firstKey = JSON.stringify(mockSend.mock.calls[0][0]);
      const secondKey = JSON.stringify(mockSend.mock.calls[1][0]);

      expect(firstKey).toContain('alice@example.com');
      expect(secondKey).toContain('bob@example.com');
      expect(firstKey).not.toContain('bob@example.com');
    });
  });
});
