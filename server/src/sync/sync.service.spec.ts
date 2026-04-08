/**
 * Unit tests for SyncService (migrated to DynamoDBService for metadata storage).
 *
 * DynamoDBService is mocked with per-method jest.fn() instances.
 * AWS S3 SDK is mocked via jest.mock() — no real AWS calls in CI.
 */

import { Test, TestingModule } from '@nestjs/testing';
import { ServiceUnavailableException } from '@nestjs/common';
import { SyncService } from './sync.service';
import { DynamoDBService } from '../dynamodb/dynamodb.service';

// ---------------------------------------------------------------------------
// Mock S3 client
// ---------------------------------------------------------------------------

const mockGetSignedUrl = jest.fn();

jest.mock('@aws-sdk/s3-request-presigner', () => ({
  getSignedUrl: (...args: unknown[]) => mockGetSignedUrl(...args),
}));

jest.mock('@aws-sdk/client-s3', () => ({
  S3Client: jest.fn().mockImplementation(() => ({})),
  GetObjectCommand: jest.fn().mockImplementation((params) => ({ _type: 'GetObject', ...params })),
  PutObjectCommand: jest.fn().mockImplementation((params) => ({ _type: 'PutObject', ...params })),
}));

// ---------------------------------------------------------------------------
// Mock DynamoDBService factory
// ---------------------------------------------------------------------------

function createMockDynamoDBService() {
  return {
    getUserById: jest.fn().mockResolvedValue(null),
    getUserByEmail: jest.fn().mockResolvedValue(null),
    createUser: jest.fn().mockResolvedValue(undefined),
    createOtp: jest.fn().mockResolvedValue(undefined),
    getActiveOtps: jest.fn().mockResolvedValue([]),
    markOtpUsed: jest.fn().mockResolvedValue(undefined),
    incrementOtpAttempts: jest.fn().mockResolvedValue(undefined),
    invalidateOtpsForEmail: jest.fn().mockResolvedValue(undefined),
    createRefreshToken: jest.fn().mockResolvedValue(undefined),
    getRefreshToken: jest.fn().mockResolvedValue(null),
    revokeRefreshToken: jest.fn().mockResolvedValue(undefined),
    revokeAllRefreshTokens: jest.fn().mockResolvedValue(undefined),
    getSyncMetadata: jest.fn().mockResolvedValue(null),
    upsertSyncMetadata: jest.fn().mockResolvedValue(undefined),
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('SyncService', () => {
  let service: SyncService;
  let mockDynamo: ReturnType<typeof createMockDynamoDBService>;

  const TEST_BUCKET = 'test-sync-bucket';
  const USER_ID = 'user-abc-123';

  const makePresignedUrl = (key: string, method: 'GET' | 'PUT') =>
    `https://${TEST_BUCKET}.s3.ap-south-1.amazonaws.com/${key}?X-Amz-Signature=abc123&method=${method}`;

  beforeEach(async () => {
    mockDynamo = createMockDynamoDBService();
    process.env.AWS_S3_BUCKET = TEST_BUCKET;
    process.env.AWS_REGION = 'ap-south-1';

    mockGetSignedUrl.mockImplementation(
      async (_client: unknown, command: { Key?: string; _type?: string }) => {
        const method = command._type === 'GetObject' ? 'GET' : 'PUT';
        return makePresignedUrl(command.Key ?? '', method);
      },
    );

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SyncService,
        { provide: DynamoDBService, useValue: mockDynamo },
      ],
    }).compile();

    service = module.get<SyncService>(SyncService);
  });

  afterEach(() => {
    jest.restoreAllMocks();
    delete process.env.AWS_S3_BUCKET;
    delete process.env.AWS_REGION;
  });

  // ── getUploadUrl ────────────────────────────────────────────────────────────

  describe('getUploadUrl', () => {
    it('returns an uploadUrl and expiresIn', async () => {
      const result = await service.getUploadUrl(USER_ID);
      expect(result).toMatchObject({
        uploadUrl: expect.any(String),
        expiresIn: expect.any(Number),
      });
    });

    it('uploadUrl is a valid HTTPS URL', async () => {
      const result = await service.getUploadUrl(USER_ID);
      expect(result.uploadUrl).toMatch(/^https:\/\//);
    });

    it('expiresIn is 300 seconds (5 minutes)', async () => {
      const result = await service.getUploadUrl(USER_ID);
      expect(result.expiresIn).toBe(300);
    });

    it('upload URL S3 key is scoped to the user ID', async () => {
      await service.getUploadUrl(USER_ID);
      const [, command] = mockGetSignedUrl.mock.calls[0] as [unknown, { Key: string }];
      expect(command.Key).toContain(USER_ID);
    });

    it('upload URL S3 key ends with instructor.db', async () => {
      await service.getUploadUrl(USER_ID);
      const [, command] = mockGetSignedUrl.mock.calls[0] as [unknown, { Key: string }];
      expect(command.Key).toMatch(/instructor\.db$/);
    });

    it('uses PutObjectCommand (not GetObjectCommand)', async () => {
      await service.getUploadUrl(USER_ID);
      const [, command] = mockGetSignedUrl.mock.calls[0] as [unknown, { _type: string }];
      expect(command._type).toBe('PutObject');
    });

    it('generates different URLs for different users', async () => {
      const [r1, r2] = await Promise.all([
        service.getUploadUrl('user-1'),
        service.getUploadUrl('user-2'),
      ]);
      expect(r1.uploadUrl).not.toBe(r2.uploadUrl);
    });

    it('throws ServiceUnavailableException when AWS_S3_BUCKET is not configured', async () => {
      delete process.env.AWS_S3_BUCKET;

      const module = await Test.createTestingModule({
        providers: [
          SyncService,
          { provide: DynamoDBService, useValue: mockDynamo },
        ],
      }).compile();
      const noBucketService = module.get<SyncService>(SyncService);

      await expect(noBucketService.getUploadUrl(USER_ID)).rejects.toThrow(
        ServiceUnavailableException,
      );
    });
  });

  // ── getDownloadUrl ──────────────────────────────────────────────────────────

  describe('getDownloadUrl', () => {
    it('returns a downloadUrl and expiresIn', async () => {
      const result = await service.getDownloadUrl(USER_ID);
      expect(result).toMatchObject({
        downloadUrl: expect.any(String),
        expiresIn: expect.any(Number),
      });
    });

    it('downloadUrl is a valid HTTPS URL', async () => {
      const result = await service.getDownloadUrl(USER_ID);
      expect(result.downloadUrl).toMatch(/^https:\/\//);
    });

    it('expiresIn is 300 seconds (5 minutes)', async () => {
      const result = await service.getDownloadUrl(USER_ID);
      expect(result.expiresIn).toBe(300);
    });

    it('download URL S3 key matches upload URL S3 key for the same user', async () => {
      await service.getUploadUrl(USER_ID);
      const uploadKey = (mockGetSignedUrl.mock.calls[0] as [unknown, { Key: string }])[1].Key;

      mockGetSignedUrl.mockClear();
      await service.getDownloadUrl(USER_ID);
      const downloadKey = (mockGetSignedUrl.mock.calls[0] as [unknown, { Key: string }])[1].Key;

      expect(uploadKey).toBe(downloadKey);
    });

    it('uses GetObjectCommand (not PutObjectCommand)', async () => {
      await service.getDownloadUrl(USER_ID);
      const [, command] = mockGetSignedUrl.mock.calls[0] as [unknown, { _type: string }];
      expect(command._type).toBe('GetObject');
    });

    it('S3 path follows backups/{userId}/instructor.db convention', async () => {
      await service.getDownloadUrl(USER_ID);
      const [, command] = mockGetSignedUrl.mock.calls[0] as [unknown, { Key: string }];
      expect(command.Key).toBe(`backups/${USER_ID}/instructor.db`);
    });

    it('throws ServiceUnavailableException when S3 is not configured', async () => {
      delete process.env.AWS_S3_BUCKET;

      const module = await Test.createTestingModule({
        providers: [
          SyncService,
          { provide: DynamoDBService, useValue: mockDynamo },
        ],
      }).compile();
      const noBucketService = module.get<SyncService>(SyncService);

      await expect(noBucketService.getDownloadUrl(USER_ID)).rejects.toThrow(
        ServiceUnavailableException,
      );
    });
  });

  // ── getSyncStatus ───────────────────────────────────────────────────────────

  describe('getSyncStatus', () => {
    it('returns null lastSyncAt and null sizeBytes when never synced', async () => {
      mockDynamo.getSyncMetadata.mockResolvedValueOnce(null);
      const result = await service.getSyncStatus(USER_ID);
      expect(result).toEqual({ lastSyncAt: null, sizeBytes: null });
    });

    it('returns lastSyncAt as ISO string and sizeBytes when a record exists', async () => {
      const lastSyncDate = new Date('2026-04-06T12:00:00Z');
      mockDynamo.getSyncMetadata.mockResolvedValueOnce({
        userId: USER_ID,
        lastSyncAt: lastSyncDate,
        sizeBytes: 5_242_880,
      });
      const result = await service.getSyncStatus(USER_ID);
      expect(result).toEqual({
        lastSyncAt: '2026-04-06T12:00:00.000Z',
        sizeBytes: 5_242_880,
      });
    });

    it('returns sizeBytes as null when size is not recorded', async () => {
      mockDynamo.getSyncMetadata.mockResolvedValueOnce({
        userId: USER_ID,
        lastSyncAt: new Date(),
        sizeBytes: null,
      });
      const result = await service.getSyncStatus(USER_ID);
      expect(result.sizeBytes).toBeNull();
    });

    it('returns status independently per user', async () => {
      mockDynamo.getSyncMetadata
        .mockResolvedValueOnce({ userId: USER_ID, lastSyncAt: new Date(), sizeBytes: 1024 })
        .mockResolvedValueOnce(null);

      const [r1, r2] = await Promise.all([
        service.getSyncStatus(USER_ID),
        service.getSyncStatus('other-user'),
      ]);

      expect(r1.lastSyncAt).not.toBeNull();
      expect(r2.lastSyncAt).toBeNull();
    });

    it('calls DynamoDBService.getSyncMetadata with the userId', async () => {
      mockDynamo.getSyncMetadata.mockResolvedValueOnce(null);
      await service.getSyncStatus(USER_ID);
      expect(mockDynamo.getSyncMetadata).toHaveBeenCalledWith(USER_ID);
    });
  });

  // ── confirmSync ─────────────────────────────────────────────────────────────

  describe('confirmSync', () => {
    it('resolves without throwing on a successful confirm', async () => {
      await expect(service.confirmSync(USER_ID, 1024)).resolves.toBeUndefined();
    });

    it('calls DynamoDBService.upsertSyncMetadata with userId and sizeBytes', async () => {
      await service.confirmSync(USER_ID, 2048);
      expect(mockDynamo.upsertSyncMetadata).toHaveBeenCalledWith(
        USER_ID,
        expect.any(Date),
        2048,
      );
    });

    it('upserts even when sizeBytes is omitted', async () => {
      await service.confirmSync(USER_ID);
      expect(mockDynamo.upsertSyncMetadata).toHaveBeenCalledWith(
        USER_ID,
        expect.any(Date),
        undefined,
      );
    });

    it('calls upsertSyncMetadata with a recent lastSyncAt timestamp', async () => {
      const before = new Date();
      await service.confirmSync(USER_ID, 512);
      const after = new Date();

      const [, lastSyncAt] = mockDynamo.upsertSyncMetadata.mock.calls[0] as [string, Date, number];
      expect(lastSyncAt.getTime()).toBeGreaterThanOrEqual(before.getTime());
      expect(lastSyncAt.getTime()).toBeLessThanOrEqual(after.getTime());
    });
  });

  // ── S3 key format ────────────────────────────────────────────────────────────

  describe('S3 key format', () => {
    it('key format is "backups/{userId}/instructor.db"', async () => {
      await service.getUploadUrl('specific-user-id');
      const [, command] = mockGetSignedUrl.mock.calls[0] as [unknown, { Key: string }];
      expect(command.Key).toBe('backups/specific-user-id/instructor.db');
    });

    it('URL contains the bucket name in the host', async () => {
      const result = await service.getUploadUrl(USER_ID);
      expect(result.uploadUrl).toContain(TEST_BUCKET);
    });
  });
});
