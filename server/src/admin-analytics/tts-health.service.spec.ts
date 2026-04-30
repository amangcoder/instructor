/**
 * Unit tests for TtsHealthService (TASK-003).
 *
 * Tests:
 *   - Returns health status for both providers
 *   - Classifies 'healthy' when errorRate < 5% and recent success
 *   - Classifies 'degraded' when errorRate > 5% or no recent success
 *   - Classifies 'unknown' when no jobs in last 60 min
 *   - Handles null lastSuccessAt
 */

import { Test, TestingModule } from '@nestjs/testing';
import { TtsHealthService } from './tts-health.service';
import { DatabaseService } from '../database/database.service';
import { createMockDatabaseService } from '../database/testing';

describe('TtsHealthService', () => {
  let service: TtsHealthService;
  let dbService: ReturnType<typeof createMockDatabaseService>;

  beforeEach(async () => {
    dbService = createMockDatabaseService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TtsHealthService,
        { provide: DatabaseService, useValue: dbService },
      ],
    }).compile();

    service = module.get<TtsHealthService>(TtsHealthService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getTtsHealth()', () => {
    it('returns providers array with both kokoro and elevenlabs', async () => {
      const recentSuccess = new Date(Date.now() - 5 * 60 * 1000).toISOString(); // 5 min ago

      // For each provider: 2 parallel queries (counts + lastSuccess)
      // kokoro queries
      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: [{ total: 100, failed: 2 }] })
        .mockResolvedValueOnce({ rows: [{ last_success_at: recentSuccess }] })
        // elevenlabs queries
        .mockResolvedValueOnce({ rows: [{ total: 50, failed: 15 }] })
        .mockResolvedValueOnce({ rows: [{ last_success_at: recentSuccess }] });

      const result = await service.getTtsHealth();

      expect(result.providers).toHaveLength(2);
      expect(result.providers[0].provider).toBe('kokoro');
      expect(result.providers[1].provider).toBe('elevenlabs');
    });

    it('classifies as healthy when errorRate < 5% and recent success', async () => {
      const recentSuccess = new Date(Date.now() - 5 * 60 * 1000).toISOString();

      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: [{ total: 100, failed: 2 }] })  // 2% error rate
        .mockResolvedValueOnce({ rows: [{ last_success_at: recentSuccess }] })
        .mockResolvedValueOnce({ rows: [{ total: 100, failed: 2 }] })
        .mockResolvedValueOnce({ rows: [{ last_success_at: recentSuccess }] });

      const result = await service.getTtsHealth();
      expect(result.providers[0].status).toBe('healthy');
      expect(result.providers[0].errorRateLast60m).toBe(0.02);
    });

    it('classifies as degraded when errorRate >= 5%', async () => {
      const recentSuccess = new Date(Date.now() - 5 * 60 * 1000).toISOString();

      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: [{ total: 100, failed: 10 }] })  // 10% error rate
        .mockResolvedValueOnce({ rows: [{ last_success_at: recentSuccess }] })
        .mockResolvedValueOnce({ rows: [{ total: 100, failed: 2 }] })
        .mockResolvedValueOnce({ rows: [{ last_success_at: recentSuccess }] });

      const result = await service.getTtsHealth();
      expect(result.providers[0].status).toBe('degraded');
    });

    it('classifies as degraded when errorRate > 20%', async () => {
      const recentSuccess = new Date(Date.now() - 5 * 60 * 1000).toISOString();

      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: [{ total: 100, failed: 25 }] })  // 25% error rate
        .mockResolvedValueOnce({ rows: [{ last_success_at: recentSuccess }] })
        .mockResolvedValueOnce({ rows: [{ total: 100, failed: 2 }] })
        .mockResolvedValueOnce({ rows: [{ last_success_at: recentSuccess }] });

      const result = await service.getTtsHealth();
      expect(result.providers[0].status).toBe('degraded');
    });

    it('classifies as unknown when no jobs in last 60min', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: [{ total: 0, failed: 0 }] })
        .mockResolvedValueOnce({ rows: [{ last_success_at: null }] })
        .mockResolvedValueOnce({ rows: [{ total: 0, failed: 0 }] })
        .mockResolvedValueOnce({ rows: [{ last_success_at: null }] });

      const result = await service.getTtsHealth();
      expect(result.providers[0].status).toBe('unknown');
      expect(result.providers[0].errorRateLast60m).toBe(0);
      expect(result.providers[0].lastSuccessAt).toBeNull();
    });

    it('classifies as degraded when no success within 60min', async () => {
      const oldSuccess = new Date(Date.now() - 90 * 60 * 1000).toISOString(); // 90 min ago

      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: [{ total: 10, failed: 0 }] })  // 0% error rate but stale
        .mockResolvedValueOnce({ rows: [{ last_success_at: oldSuccess }] })
        .mockResolvedValueOnce({ rows: [{ total: 10, failed: 0 }] })
        .mockResolvedValueOnce({ rows: [{ last_success_at: oldSuccess }] });

      const result = await service.getTtsHealth();
      expect(result.providers[0].status).toBe('degraded');
    });
  });
});
