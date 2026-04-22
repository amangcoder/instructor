/**
 * Unit tests for RetentionAnalyticsService (TASK-002).
 *
 * Tests:
 *   - getRetention() computes D7/D30 rates correctly
 *   - getRetention() handles zero cohort sizes (no division by zero)
 *   - getRetention() handles PostgreSQL query_canceled error (57014) → 504
 *   - getActiveUsers() returns DAU/WAU/MAU arrays
 *   - getActiveUsers() fills date gaps for DAU series
 */

import { Test, TestingModule } from '@nestjs/testing';
import { GatewayTimeoutException } from '@nestjs/common';
import { RetentionAnalyticsService } from './retention-analytics.service';
import { DatabaseService } from '../database/database.service';

// ---------------------------------------------------------------------------
// Mock DatabaseService
// ---------------------------------------------------------------------------

function createMockDatabaseService() {
  const mockDb = {
    execute: jest.fn(),
    select: jest.fn().mockReturnThis(),
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    groupBy: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
  };

  return {
    getDb: jest.fn().mockReturnValue(mockDb),
    withRetry: jest.fn().mockImplementation(async (fn: () => Promise<any>) => fn()),
    _mockDb: mockDb,
  };
}

describe('RetentionAnalyticsService', () => {
  let service: RetentionAnalyticsService;
  let dbService: ReturnType<typeof createMockDatabaseService>;

  beforeEach(async () => {
    dbService = createMockDatabaseService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RetentionAnalyticsService,
        { provide: DatabaseService, useValue: dbService },
      ],
    }).compile();

    service = module.get<RetentionAnalyticsService>(RetentionAnalyticsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getRetention()', () => {
    it('computes D7 and D30 retention rates correctly', async () => {
      // Mock 8 parallel queries: d7 cohort, d7 retained, d7 prev cohort, d7 prev retained,
      //                          d30 cohort, d30 retained, d30 prev cohort, d30 prev retained
      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: [{ cohort_size: 100 }] })   // d7 cohort
        .mockResolvedValueOnce({ rows: [{ retained_count: 15 }] }) // d7 retained
        .mockResolvedValueOnce({ rows: [{ cohort_size: 80 }] })    // d7 prev cohort
        .mockResolvedValueOnce({ rows: [{ retained_count: 10 }] }) // d7 prev retained
        .mockResolvedValueOnce({ rows: [{ cohort_size: 200 }] })   // d30 cohort
        .mockResolvedValueOnce({ rows: [{ retained_count: 20 }] }) // d30 retained
        .mockResolvedValueOnce({ rows: [{ cohort_size: 150 }] })   // d30 prev cohort
        .mockResolvedValueOnce({ rows: [{ retained_count: 12 }] }); // d30 prev retained

      const result = await service.getRetention();

      expect(result.d7).toBeDefined();
      expect(result.d7.rate).toBe(0.15); // 15/100
      expect(result.d7.cohortSize).toBe(100);
      expect(result.d7.retainedCount).toBe(15);
      expect(typeof result.d7.delta).toBe('number');

      expect(result.d30).toBeDefined();
      expect(result.d30.rate).toBe(0.1); // 20/200
      expect(result.d30.cohortSize).toBe(200);
      expect(result.d30.retainedCount).toBe(20);
    });

    it('handles zero cohort size without division error', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: [{ cohort_size: 0 }] })
        .mockResolvedValueOnce({ rows: [{ retained_count: 0 }] })
        .mockResolvedValueOnce({ rows: [{ cohort_size: 0 }] })
        .mockResolvedValueOnce({ rows: [{ retained_count: 0 }] })
        .mockResolvedValueOnce({ rows: [{ cohort_size: 0 }] })
        .mockResolvedValueOnce({ rows: [{ retained_count: 0 }] })
        .mockResolvedValueOnce({ rows: [{ cohort_size: 0 }] })
        .mockResolvedValueOnce({ rows: [{ retained_count: 0 }] });

      const result = await service.getRetention();

      expect(result.d7.rate).toBe(0);
      expect(result.d30.rate).toBe(0);
      expect(result.d7.delta).toBe(0);
      expect(result.d30.delta).toBe(0);
    });

    it('throws GatewayTimeoutException on PostgreSQL 57014 (query_canceled)', async () => {
      const pgError = new Error('query canceled');
      (pgError as any).code = '57014';
      dbService._mockDb.execute.mockRejectedValueOnce(pgError);

      await expect(service.getRetention()).rejects.toBeInstanceOf(GatewayTimeoutException);
    });

    it('re-throws non-timeout errors', async () => {
      const genericError = new Error('connection refused');
      dbService._mockDb.execute.mockRejectedValueOnce(genericError);

      await expect(service.getRetention()).rejects.toThrow('connection refused');
    });
  });

  describe('getActiveUsers()', () => {
    it('returns DAU, WAU, MAU arrays', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce({
          rows: [
            { date: '2026-04-15', value: 10 },
            { date: '2026-04-16', value: 12 },
          ],
        }) // DAU
        .mockResolvedValueOnce({
          rows: [{ date: '2026-04-14', value: 50 }],
        }) // WAU
        .mockResolvedValueOnce({
          rows: [{ date: '2026-04-01', value: 200 }],
        }); // MAU

      const result = await service.getActiveUsers('7d');

      expect(result.dau).toBeDefined();
      expect(Array.isArray(result.dau)).toBe(true);
      expect(result.wau).toBeDefined();
      expect(result.mau).toBeDefined();
      // DAU should have gaps filled (7 days + today)
      expect(result.dau.length).toBeGreaterThanOrEqual(7);
    });

    it('throws GatewayTimeoutException on PostgreSQL 57014', async () => {
      const pgError = new Error('query canceled');
      (pgError as any).code = '57014';
      dbService._mockDb.execute.mockRejectedValueOnce(pgError);

      await expect(service.getActiveUsers('30d')).rejects.toBeInstanceOf(GatewayTimeoutException);
    });
  });
});
