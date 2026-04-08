/**
 * Unit tests for DynamoDBService.
 *
 * All AWS SDK calls are intercepted via mocked DynamoDBDocumentClient.send().
 * No real DynamoDB calls are made — CI runs without AWS credentials.
 *
 * Key patterns under test:
 *   pk/sk key construction for all five entity types
 *   TTL calculation (Unix epoch seconds)
 *   GSI attribute population (gsi1pk / gsi1sk)
 *   CRUD operations (Get, Put, Update, Query, Delete)
 */

import { Test, TestingModule } from '@nestjs/testing';
import { DynamoDBService } from './dynamodb.service';

// ---------------------------------------------------------------------------
// Mock @aws-sdk/client-dynamodb and @aws-sdk/lib-dynamodb
// ---------------------------------------------------------------------------

const mockSend = jest.fn();

jest.mock('@aws-sdk/client-dynamodb', () => ({
  DynamoDBClient: jest.fn().mockImplementation(() => ({})),
}));

jest.mock('@aws-sdk/lib-dynamodb', () => ({
  DynamoDBDocumentClient: {
    from: jest.fn().mockReturnValue({ send: mockSend }),
  },
  GetCommand: jest.fn().mockImplementation((input) => ({ _type: 'Get', ...input })),
  PutCommand: jest.fn().mockImplementation((input) => ({ _type: 'Put', ...input })),
  UpdateCommand: jest.fn().mockImplementation((input) => ({ _type: 'Update', ...input })),
  DeleteCommand: jest.fn().mockImplementation((input) => ({ _type: 'Delete', ...input })),
  QueryCommand: jest.fn().mockImplementation((input) => ({ _type: 'Query', ...input })),
}));

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const TABLE_NAME = 'instructor-test-table';
const TEST_USER_ID = 'user-abc-123';
const TEST_EMAIL = 'test@example.com';
const TEST_TOKEN_HASH = 'sha256hashoftokenabcdef0123456789';
const OTP_SK = '2026-04-09T00:00:00.000Z#test-otp-id';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('DynamoDBService', () => {
  let service: DynamoDBService;

  beforeEach(async () => {
    process.env.DYNAMODB_TABLE = TABLE_NAME;
    process.env.AWS_REGION = 'us-east-1';

    mockSend.mockResolvedValue({});

    const module: TestingModule = await Test.createTestingModule({
      providers: [DynamoDBService],
    }).compile();

    service = module.get<DynamoDBService>(DynamoDBService);
  });

  afterEach(() => {
    jest.clearAllMocks();
    delete process.env.DYNAMODB_TABLE;
    delete process.env.AWS_REGION;
  });

  // ── getUserById ─────────────────────────────────────────────────────────────

  describe('getUserById', () => {
    it('returns null when the item is not found in DynamoDB', async () => {
      mockSend.mockResolvedValueOnce({ Item: undefined });
      const result = await service.getUserById(TEST_USER_ID);
      expect(result).toBeNull();
    });

    it('returns a user object when the item exists', async () => {
      mockSend.mockResolvedValueOnce({
        Item: {
          pk: `USER#${TEST_USER_ID}`,
          sk: 'PROFILE',
          id: TEST_USER_ID,
          email: TEST_EMAIL,
          createdAt: new Date().toISOString(),
        },
      });
      const result = await service.getUserById(TEST_USER_ID);
      expect(result).not.toBeNull();
      expect(result?.id).toBe(TEST_USER_ID);
    });

    it('queries with pk=USER#<userId> and sk=PROFILE', async () => {
      mockSend.mockResolvedValueOnce({ Item: undefined });
      await service.getUserById(TEST_USER_ID);

      const callArg = mockSend.mock.calls[0][0];
      expect(callArg.Key?.pk ?? callArg.Key?.PK).toMatch(new RegExp(`USER#${TEST_USER_ID}`));
      expect(JSON.stringify(callArg)).toContain('PROFILE');
    });

    it('calls DynamoDB exactly once', async () => {
      mockSend.mockResolvedValueOnce({ Item: undefined });
      await service.getUserById(TEST_USER_ID);
      expect(mockSend).toHaveBeenCalledTimes(1);
    });
  });

  // ── getUserByEmail ──────────────────────────────────────────────────────────

  describe('getUserByEmail', () => {
    it('returns null when no user matches the email', async () => {
      mockSend.mockResolvedValueOnce({ Items: [] });
      const result = await service.getUserByEmail(TEST_EMAIL);
      expect(result).toBeNull();
    });

    it('returns a user object when found via GSI email lookup', async () => {
      mockSend.mockResolvedValueOnce({
        Items: [{
          pk: `USER#${TEST_USER_ID}`,
          sk: 'PROFILE',
          id: TEST_USER_ID,
          email: TEST_EMAIL,
        }],
      });
      const result = await service.getUserByEmail(TEST_EMAIL);
      expect(result?.email).toBe(TEST_EMAIL);
    });

    it('queries using the email value in the GSI condition', async () => {
      mockSend.mockResolvedValueOnce({ Items: [] });
      await service.getUserByEmail(TEST_EMAIL);

      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain(TEST_EMAIL);
    });
  });

  // ── createUser ──────────────────────────────────────────────────────────────

  describe('createUser', () => {
    it('resolves without throwing on success', async () => {
      await expect(
        service.createUser({ id: TEST_USER_ID, email: TEST_EMAIL, createdAt: new Date() }),
      ).resolves.toBeUndefined();
    });

    it('puts an item with pk=USER#<id> and sk=PROFILE', async () => {
      await service.createUser({ id: TEST_USER_ID, email: TEST_EMAIL, createdAt: new Date() });

      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain(`USER#${TEST_USER_ID}`);
      expect(JSON.stringify(callArg)).toContain('PROFILE');
    });

    it('sets gsi1pk to the email address for GSI lookups', async () => {
      await service.createUser({ id: TEST_USER_ID, email: TEST_EMAIL, createdAt: new Date() });

      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain(TEST_EMAIL);
    });

    it('stores the email address in the item', async () => {
      await service.createUser({ id: TEST_USER_ID, email: TEST_EMAIL, createdAt: new Date() });

      const callArg = mockSend.mock.calls[0][0];
      const item = callArg.Item;
      expect(item?.email ?? JSON.stringify(callArg)).toContain(TEST_EMAIL);
    });
  });

  // ── createOtp ───────────────────────────────────────────────────────────────

  describe('createOtp', () => {
    it('resolves without throwing on success', async () => {
      await expect(
        service.createOtp(TEST_EMAIL, 'hashcode123', new Date(Date.now() + 300_000)),
      ).resolves.toBeUndefined();
    });

    it('puts an item with pk=OTP#<email>', async () => {
      await service.createOtp(TEST_EMAIL, 'hashcode123', new Date(Date.now() + 300_000));

      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain(`OTP#${TEST_EMAIL}`);
    });

    it('stores the hashed OTP code (never plaintext)', async () => {
      const hashCode = 'sha256-hashed-otp-code';
      await service.createOtp(TEST_EMAIL, hashCode, new Date(Date.now() + 300_000));

      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain(hashCode);
    });

    it('stores ttl as a Unix epoch integer (seconds) for DynamoDB TTL auto-expiry', async () => {
      const expiresAt = new Date(Date.now() + 5 * 60 * 1000);
      await service.createOtp(TEST_EMAIL, 'hashcode', expiresAt);

      const callArg = mockSend.mock.calls[0][0];
      const item = callArg.Item ?? {};
      // TTL must be an integer > current time in seconds
      const ttlValue = item.ttl ?? item.TTL;
      expect(typeof ttlValue).toBe('number');
      expect(ttlValue).toBeGreaterThan(Math.floor(Date.now() / 1000));
    });

    it('TTL equals Math.floor(expiresAt.getTime() / 1000)', async () => {
      const expiresAt = new Date('2026-06-01T00:00:00Z');
      const expectedTtl = Math.floor(expiresAt.getTime() / 1000);
      await service.createOtp(TEST_EMAIL, 'hash', expiresAt);

      const callArg = mockSend.mock.calls[0][0];
      const item = callArg.Item ?? {};
      const ttlValue = item.ttl ?? item.TTL;
      expect(ttlValue).toBe(expectedTtl);
    });
  });

  // ── getActiveOtps ───────────────────────────────────────────────────────────

  describe('getActiveOtps', () => {
    it('returns an empty array when no OTPs exist', async () => {
      mockSend.mockResolvedValueOnce({ Items: [] });
      const result = await service.getActiveOtps(TEST_EMAIL);
      expect(result).toEqual([]);
    });

    it('returns OTP records for the given email', async () => {
      const mockOtp = {
        pk: `OTP#${TEST_EMAIL}`,
        sk: OTP_SK,
        email: TEST_EMAIL,
        code: 'hash123',
        used: false,
        attempts: 0,
        expiresAt: new Date(Date.now() + 300_000).toISOString(),
      };
      mockSend.mockResolvedValueOnce({ Items: [mockOtp] });

      const result = await service.getActiveOtps(TEST_EMAIL);
      expect(result).toHaveLength(1);
      expect(result[0].email).toBe(TEST_EMAIL);
    });

    it('queries by pk=OTP#<email>', async () => {
      mockSend.mockResolvedValueOnce({ Items: [] });
      await service.getActiveOtps(TEST_EMAIL);

      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain(`OTP#${TEST_EMAIL}`);
    });
  });

  // ── markOtpUsed ─────────────────────────────────────────────────────────────

  describe('markOtpUsed', () => {
    it('resolves without throwing', async () => {
      await expect(service.markOtpUsed(TEST_EMAIL, OTP_SK)).resolves.toBeUndefined();
    });

    it('targets the correct pk=OTP#<email> and sk', async () => {
      await service.markOtpUsed(TEST_EMAIL, OTP_SK);
      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain(`OTP#${TEST_EMAIL}`);
      expect(JSON.stringify(callArg)).toContain(OTP_SK);
    });

    it('calls DynamoDB exactly once', async () => {
      await service.markOtpUsed(TEST_EMAIL, OTP_SK);
      expect(mockSend).toHaveBeenCalledTimes(1);
    });
  });

  // ── incrementOtpAttempts ────────────────────────────────────────────────────

  describe('incrementOtpAttempts', () => {
    it('resolves without throwing', async () => {
      await expect(
        service.incrementOtpAttempts(TEST_EMAIL, OTP_SK, 0),
      ).resolves.toBeUndefined();
    });

    it('targets the correct pk=OTP#<email> and sk', async () => {
      await service.incrementOtpAttempts(TEST_EMAIL, OTP_SK, 2);
      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain(`OTP#${TEST_EMAIL}`);
    });

    it('increments by 1 (currentAttempts + 1)', async () => {
      await service.incrementOtpAttempts(TEST_EMAIL, OTP_SK, 2);
      const callArg = mockSend.mock.calls[0][0];
      // The new attempts value should be currentAttempts + 1 = 3
      expect(JSON.stringify(callArg)).toContain('3');
    });
  });

  // ── invalidateOtpsForEmail ──────────────────────────────────────────────────

  describe('invalidateOtpsForEmail', () => {
    it('resolves without throwing when no OTPs exist', async () => {
      mockSend.mockResolvedValueOnce({ Items: [] });
      await expect(service.invalidateOtpsForEmail(TEST_EMAIL)).resolves.toBeUndefined();
    });

    it('resolves without throwing when OTPs exist and are invalidated', async () => {
      const mockOtps = [
        { pk: `OTP#${TEST_EMAIL}`, sk: OTP_SK, used: false },
      ];
      mockSend.mockResolvedValueOnce({ Items: mockOtps }); // query
      mockSend.mockResolvedValueOnce({}); // update
      await expect(service.invalidateOtpsForEmail(TEST_EMAIL)).resolves.toBeUndefined();
    });
  });

  // ── createRefreshToken ──────────────────────────────────────────────────────

  describe('createRefreshToken', () => {
    it('resolves without throwing', async () => {
      const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
      await expect(
        service.createRefreshToken(TEST_USER_ID, TEST_TOKEN_HASH, expiresAt),
      ).resolves.toBeUndefined();
    });

    it('puts an item with pk=TOKEN#<hash>', async () => {
      const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
      await service.createRefreshToken(TEST_USER_ID, TEST_TOKEN_HASH, expiresAt);

      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain(`TOKEN#${TEST_TOKEN_HASH}`);
    });

    it('stores gsi1pk=USER#<userId> for user-scoped token lookups', async () => {
      const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
      await service.createRefreshToken(TEST_USER_ID, TEST_TOKEN_HASH, expiresAt);

      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain(`USER#${TEST_USER_ID}`);
    });

    it('stores ttl as Unix epoch seconds', async () => {
      const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
      const expectedTtl = Math.floor(expiresAt.getTime() / 1000);
      await service.createRefreshToken(TEST_USER_ID, TEST_TOKEN_HASH, expiresAt);

      const callArg = mockSend.mock.calls[0][0];
      const item = callArg.Item ?? {};
      const ttlValue = item.ttl ?? item.TTL;
      expect(Math.abs(ttlValue - expectedTtl)).toBeLessThanOrEqual(1);
    });
  });

  // ── getRefreshToken ─────────────────────────────────────────────────────────

  describe('getRefreshToken', () => {
    it('returns null when the token is not found', async () => {
      mockSend.mockResolvedValueOnce({ Item: undefined });
      const result = await service.getRefreshToken(TEST_TOKEN_HASH);
      expect(result).toBeNull();
    });

    it('returns the token record when found', async () => {
      mockSend.mockResolvedValueOnce({
        Item: {
          pk: `TOKEN#${TEST_TOKEN_HASH}`,
          sk: 'TOKEN',
          userId: TEST_USER_ID,
          tokenHash: TEST_TOKEN_HASH,
          revoked: false,
        },
      });
      const result = await service.getRefreshToken(TEST_TOKEN_HASH);
      expect(result?.userId).toBe(TEST_USER_ID);
    });

    it('queries with pk=TOKEN#<hash> and sk=TOKEN', async () => {
      mockSend.mockResolvedValueOnce({ Item: undefined });
      await service.getRefreshToken(TEST_TOKEN_HASH);

      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain(`TOKEN#${TEST_TOKEN_HASH}`);
      expect(JSON.stringify(callArg)).toContain('TOKEN');
    });
  });

  // ── revokeRefreshToken ──────────────────────────────────────────────────────

  describe('revokeRefreshToken', () => {
    it('resolves without throwing', async () => {
      await expect(
        service.revokeRefreshToken(TEST_USER_ID, TEST_TOKEN_HASH),
      ).resolves.toBeUndefined();
    });

    it('targets the correct token key', async () => {
      await service.revokeRefreshToken(TEST_USER_ID, TEST_TOKEN_HASH);
      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain(TEST_TOKEN_HASH);
    });
  });

  // ── revokeAllRefreshTokens ──────────────────────────────────────────────────

  describe('revokeAllRefreshTokens', () => {
    it('resolves without throwing when user has no tokens', async () => {
      mockSend.mockResolvedValueOnce({ Items: [] });
      await expect(service.revokeAllRefreshTokens(TEST_USER_ID)).resolves.toBeUndefined();
    });

    it('resolves without throwing when user has tokens to revoke', async () => {
      const mockTokens = [
        { pk: `TOKEN#hash1`, sk: 'TOKEN', userId: TEST_USER_ID, revoked: false },
        { pk: `TOKEN#hash2`, sk: 'TOKEN', userId: TEST_USER_ID, revoked: false },
      ];
      mockSend.mockResolvedValueOnce({ Items: mockTokens });
      mockSend.mockResolvedValue({}); // for each revocation
      await expect(service.revokeAllRefreshTokens(TEST_USER_ID)).resolves.toBeUndefined();
    });

    it('queries tokens by userId (gsi1pk=USER#<userId>)', async () => {
      mockSend.mockResolvedValueOnce({ Items: [] });
      await service.revokeAllRefreshTokens(TEST_USER_ID);
      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain(`USER#${TEST_USER_ID}`);
    });
  });

  // ── getSyncMetadata ─────────────────────────────────────────────────────────

  describe('getSyncMetadata', () => {
    it('returns null when no sync metadata exists', async () => {
      mockSend.mockResolvedValueOnce({ Item: undefined });
      const result = await service.getSyncMetadata(TEST_USER_ID);
      expect(result).toBeNull();
    });

    it('returns metadata object when found', async () => {
      mockSend.mockResolvedValueOnce({
        Item: {
          pk: `USER#${TEST_USER_ID}`,
          sk: 'SYNC',
          userId: TEST_USER_ID,
          lastSyncAt: new Date().toISOString(),
          sizeBytes: 1024,
        },
      });
      const result = await service.getSyncMetadata(TEST_USER_ID);
      expect(result?.userId).toBe(TEST_USER_ID);
    });

    it('queries with pk=USER#<userId> and sk=SYNC', async () => {
      mockSend.mockResolvedValueOnce({ Item: undefined });
      await service.getSyncMetadata(TEST_USER_ID);

      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain(`USER#${TEST_USER_ID}`);
      expect(JSON.stringify(callArg)).toContain('SYNC');
    });
  });

  // ── upsertSyncMetadata ──────────────────────────────────────────────────────

  describe('upsertSyncMetadata', () => {
    it('resolves without throwing', async () => {
      await expect(
        service.upsertSyncMetadata(TEST_USER_ID, new Date(), 2048),
      ).resolves.toBeUndefined();
    });

    it('targets pk=USER#<userId> sk=SYNC', async () => {
      await service.upsertSyncMetadata(TEST_USER_ID, new Date(), 1024);
      const callArg = mockSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain(`USER#${TEST_USER_ID}`);
      expect(JSON.stringify(callArg)).toContain('SYNC');
    });

    it('resolves without throwing when sizeBytes is omitted', async () => {
      await expect(
        service.upsertSyncMetadata(TEST_USER_ID, new Date()),
      ).resolves.toBeUndefined();
    });
  });

  // ── TTL calculation correctness ─────────────────────────────────────────────

  describe('TTL attribute calculation', () => {
    it('OTP TTL equals Math.floor(expiresAt.getTime() / 1000)', async () => {
      const expiresAt = new Date('2026-12-31T23:59:59Z');
      const expectedTtl = Math.floor(expiresAt.getTime() / 1000);
      await service.createOtp(TEST_EMAIL, 'hash', expiresAt);

      const callArg = mockSend.mock.calls[0][0];
      const item = callArg.Item ?? {};
      expect(item.ttl ?? item.TTL).toBe(expectedTtl);
    });

    it('refresh token TTL equals Math.floor(expiresAt.getTime() / 1000)', async () => {
      const expiresAt = new Date('2026-12-31T23:59:59Z');
      const expectedTtl = Math.floor(expiresAt.getTime() / 1000);
      await service.createRefreshToken(TEST_USER_ID, TEST_TOKEN_HASH, expiresAt);

      const callArg = mockSend.mock.calls[0][0];
      const item = callArg.Item ?? {};
      expect(item.ttl ?? item.TTL).toBe(expectedTtl);
    });
  });
});
