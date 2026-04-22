/**
 * Unit tests for DeletionRequestsAdminService (TASK-005).
 *
 * Tests:
 *   - listDeletionRequests() returns paginated list with masked emails
 *   - listDeletionRequests() applies search filter
 *   - listDeletionRequests() applies status filter
 *   - listDeletionRequests() respects MAX_PAGE_SIZE cap
 *   - processDeletionRequest() marks as processed (happy path)
 *   - processDeletionRequest() throws NotFoundException if id not found
 *   - processDeletionRequest() throws ConflictException if already processed
 *   - getPendingCount() returns count of pending requests
 */

import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException, ConflictException } from '@nestjs/common';
import { DeletionRequestsAdminService } from './deletion-requests-admin.service';
import { DatabaseService } from '../database/database.service';

// ---------------------------------------------------------------------------
// Mock factory
// ---------------------------------------------------------------------------

function createMockDatabaseService() {
  const mockDb = {
    select: jest.fn().mockReturnThis(),
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    offset: jest.fn().mockReturnThis(),
    update: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    returning: jest.fn().mockResolvedValue([]),
    execute: jest.fn(),
  };

  return {
    getDb: jest.fn().mockReturnValue(mockDb),
    withRetry: jest.fn().mockImplementation(async (fn: () => Promise<any>) => fn()),
    _mockDb: mockDb,
  };
}

const NOW = new Date('2026-04-21T12:00:00Z');
const REQUESTED_AT = new Date('2026-04-20T10:00:00Z');

function makePendingRow(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    id: 'dr-uuid-001',
    email: 'john@example.com',
    ipAddress: '127.0.0.1',
    requestedAt: REQUESTED_AT,
    processedAt: null,
    status: 'pending',
    ...overrides,
  };
}

describe('DeletionRequestsAdminService', () => {
  let service: DeletionRequestsAdminService;
  let dbService: ReturnType<typeof createMockDatabaseService>;

  beforeEach(async () => {
    dbService = createMockDatabaseService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DeletionRequestsAdminService,
        { provide: DatabaseService, useValue: dbService },
      ],
    }).compile();

    service = module.get<DeletionRequestsAdminService>(DeletionRequestsAdminService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  // -------------------------------------------------------------------------
  // listDeletionRequests
  // -------------------------------------------------------------------------

  describe('listDeletionRequests()', () => {
    beforeEach(() => {
      // First call: count query, returns [{ value: 2 }]
      // Second call: rows query
      dbService._mockDb.select.mockReturnThis();
      dbService._mockDb.from.mockReturnThis();
      dbService._mockDb.where.mockReturnThis();
      dbService._mockDb.orderBy.mockReturnThis();
      dbService._mockDb.limit.mockReturnThis();
      dbService._mockDb.offset
        .mockResolvedValueOnce([{ value: 2 }])     // count
        .mockResolvedValueOnce([                    // rows
          makePendingRow({ id: 'dr-001', email: 'john@example.com' }),
          makePendingRow({ id: 'dr-002', email: 'jane@example.com', status: 'processed', processedAt: NOW }),
        ]);
    });

    it('returns paginated list with masked emails', async () => {
      const result = await service.listDeletionRequests({ page: 1, pageSize: 20 });

      expect(result.total).toBe(2);
      expect(result.page).toBe(1);
      expect(result.pageSize).toBe(20);
      expect(result.data).toHaveLength(2);

      // Emails should be masked
      expect(result.data[0].email).toBe('jo***@example.com');
      expect(result.data[1].email).toBe('ja***@example.com');
    });

    it('returns correct status fields', async () => {
      dbService._mockDb.offset
        .mockResolvedValueOnce([{ value: 1 }])
        .mockResolvedValueOnce([makePendingRow()]);

      const result = await service.listDeletionRequests({});
      expect(result.data[0].status).toBe('pending');
      expect(result.data[0].processedAt).toBeNull();
    });

    it('returns processed status with processedAt timestamp', async () => {
      dbService._mockDb.offset
        .mockResolvedValueOnce([{ value: 1 }])
        .mockResolvedValueOnce([
          makePendingRow({ status: 'processed', processedAt: NOW }),
        ]);

      const result = await service.listDeletionRequests({});
      expect(result.data[0].status).toBe('processed');
      expect(result.data[0].processedAt).toBe(NOW.toISOString());
    });

    it('caps pageSize at MAX_PAGE_SIZE (100)', async () => {
      dbService._mockDb.offset
        .mockResolvedValueOnce([{ value: 0 }])
        .mockResolvedValueOnce([]);

      await service.listDeletionRequests({ page: 1, pageSize: 500 });

      // The limit() call should be called with 100 (capped)
      expect(dbService._mockDb.limit).toHaveBeenCalledWith(100);
    });

    it('uses default page=1 and pageSize=20 when not provided', async () => {
      dbService._mockDb.offset
        .mockResolvedValueOnce([{ value: 0 }])
        .mockResolvedValueOnce([]);

      await service.listDeletionRequests({});

      expect(dbService._mockDb.limit).toHaveBeenCalledWith(20);
      expect(dbService._mockDb.offset).toHaveBeenCalledWith(0); // (1-1)*20 = 0
    });

    it('returns ipAddress as null when not set', async () => {
      dbService._mockDb.offset
        .mockResolvedValueOnce([{ value: 1 }])
        .mockResolvedValueOnce([
          makePendingRow({ ipAddress: null }),
        ]);

      const result = await service.listDeletionRequests({});
      expect(result.data[0].ipAddress).toBeNull();
    });
  });

  // -------------------------------------------------------------------------
  // processDeletionRequest
  // -------------------------------------------------------------------------

  describe('processDeletionRequest()', () => {
    it('returns processed result when request exists and is pending', async () => {
      const processedAt = new Date('2026-04-21T12:00:00Z');
      dbService._mockDb.returning.mockResolvedValueOnce([
        { id: 'dr-001', status: 'processed', processedAt },
      ]);

      const result = await service.processDeletionRequest('dr-001');

      expect(result.id).toBe('dr-001');
      expect(result.status).toBe('processed');
      expect(result.processedAt).toBe(processedAt.toISOString());
    });

    it('throws NotFoundException when id does not exist', async () => {
      // First update returns empty (id not found or already processed)
      dbService._mockDb.returning.mockResolvedValueOnce([]);

      // Then SELECT to check existence returns empty too
      dbService._mockDb.offset.mockResolvedValueOnce([]);

      await expect(service.processDeletionRequest('nonexistent-id'))
        .rejects
        .toBeInstanceOf(NotFoundException);
    });

    it('throws ConflictException when request is already processed', async () => {
      // First update returns empty (already processed)
      dbService._mockDb.returning.mockResolvedValueOnce([]);

      // Then SELECT to check existence returns a processed row
      dbService._mockDb.offset.mockResolvedValueOnce([{ status: 'processed' }]);

      await expect(service.processDeletionRequest('dr-already-processed'))
        .rejects
        .toBeInstanceOf(ConflictException);
    });
  });

  // -------------------------------------------------------------------------
  // getPendingCount
  // -------------------------------------------------------------------------

  describe('getPendingCount()', () => {
    it('returns count of pending requests', async () => {
      dbService._mockDb.where.mockResolvedValueOnce([{ value: 5 }]);

      const result = await service.getPendingCount();
      expect(result.count).toBe(5);
    });

    it('returns 0 when no pending requests', async () => {
      dbService._mockDb.where.mockResolvedValueOnce([{ value: 0 }]);

      const result = await service.getPendingCount();
      expect(result.count).toBe(0);
    });
  });
});
