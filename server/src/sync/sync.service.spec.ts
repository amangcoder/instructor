/**
 * Unit tests for SyncService — session completion sync business logic.
 *
 * Tests:
 *   - uploadCompletions: batch insert, idempotency via client_id, validation
 *   - getCompletions: retrieval with optional since filter
 *   - Error handling: DB errors, invalid data
 *
 * Strategy:
 *   - DatabaseService is fully mocked — no real DB connection needed.
 *   - Tests exercise service methods in isolation.
 */

import { Test, TestingModule } from '@nestjs/testing';
import { SyncService } from './sync.service';
import { DatabaseService } from '../database/database.service';

// ---------------------------------------------------------------------------
// Mock factories
// ---------------------------------------------------------------------------

function createMockDatabaseService() {
  return {
    upsertSessionCompletions: jest.fn().mockResolvedValue(3),
    getSessionCompletions: jest.fn().mockResolvedValue([
      {
        id: 'completion-uuid-1',
        planId: 'plan-uuid-001',
        completedAt: new Date('2026-04-14T12:00:00.000Z'),
        durationMs: 600000,
      },
      {
        id: 'completion-uuid-2',
        planId: 'plan-uuid-001',
        completedAt: new Date('2026-04-15T12:00:00.000Z'),
        durationMs: 900000,
      },
    ]),
    withRetry: jest.fn().mockImplementation((fn: () => Promise<unknown>) => fn()),
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('SyncService', () => {
  let service: SyncService;
  let dbService: ReturnType<typeof createMockDatabaseService>;

  beforeEach(async () => {
    dbService = createMockDatabaseService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SyncService,
        { provide: DatabaseService, useValue: dbService },
      ],
    }).compile();

    service = module.get<SyncService>(SyncService);
  });

  // ─── uploadCompletions ─────────────────────────────────────────────────

  describe('uploadCompletions', () => {
    it('returns syncedCount on successful batch upload', async () => {
      const completions = [
        {
          planId: 'plan-uuid-001',
          completedAt: '2026-04-14T12:00:00.000Z',
          durationMs: 600000,
          clientId: 'client-uuid-1',
        },
        {
          planId: 'plan-uuid-001',
          completedAt: '2026-04-15T12:00:00.000Z',
          durationMs: 900000,
          clientId: 'client-uuid-2',
        },
        {
          planId: 'plan-uuid-002',
          completedAt: '2026-04-13T12:00:00.000Z',
          durationMs: 300000,
          clientId: 'client-uuid-3',
        },
      ];

      const result = await service.uploadCompletions('user-abc', completions);

      expect(result).toHaveProperty('syncedCount');
      expect(result.syncedCount).toBeGreaterThanOrEqual(0);
    });

    it('calls DatabaseService.upsertSessionCompletions with userId', async () => {
      const completions = [
        {
          planId: 'plan-uuid-001',
          completedAt: '2026-04-15T12:00:00.000Z',
          durationMs: 600000,
          clientId: 'client-uuid-1',
        },
      ];

      await service.uploadCompletions('user-abc', completions);

      expect(dbService.upsertSessionCompletions).toHaveBeenCalledWith(
        'user-abc',
        expect.any(Array),
      );
    });

    it('handles empty completions array gracefully', async () => {
      const result = await service.uploadCompletions('user-abc', []);

      expect(result.syncedCount).toBe(0);
    });

    it('handles duplicate client_ids via ON CONFLICT DO NOTHING', async () => {
      // Simulate DB returning lower count due to duplicates
      dbService.upsertSessionCompletions.mockResolvedValueOnce(1);

      const completions = [
        {
          planId: 'plan-uuid-001',
          completedAt: '2026-04-15T12:00:00.000Z',
          durationMs: 600000,
          clientId: 'duplicate-client-id',
        },
        {
          planId: 'plan-uuid-001',
          completedAt: '2026-04-15T12:00:00.000Z',
          durationMs: 600000,
          clientId: 'duplicate-client-id', // same client_id
        },
      ];

      const result = await service.uploadCompletions('user-abc', completions);

      // syncedCount reflects what the DB returned
      expect(result.syncedCount).toBeGreaterThanOrEqual(0);
    });

    it('propagates database errors', async () => {
      dbService.upsertSessionCompletions.mockRejectedValueOnce(
        new Error('DB connection failed'),
      );

      await expect(
        service.uploadCompletions('user-abc', [
          {
            planId: 'plan-uuid-001',
            completedAt: '2026-04-15T12:00:00.000Z',
            durationMs: 600000,
            clientId: 'client-uuid-1',
          },
        ]),
      ).rejects.toThrow('DB connection failed');
    });
  });

  // ─── getCompletions ────────────────────────────────────────────────────

  describe('getCompletions', () => {
    it('returns completions array for a user', async () => {
      const result = await service.getCompletions('user-abc');

      expect(result).toHaveProperty('completions');
      expect(result.completions).toBeInstanceOf(Array);
      expect(result.completions.length).toBe(2);
    });

    it('each completion has id, planId, completedAt, durationMs', async () => {
      const result = await service.getCompletions('user-abc');

      const completion = result.completions[0];
      expect(completion).toHaveProperty('id');
      expect(completion).toHaveProperty('planId');
      expect(completion).toHaveProperty('completedAt');
      expect(completion).toHaveProperty('durationMs');
    });

    it('passes since parameter to DatabaseService', async () => {
      const since = new Date('2026-04-14T00:00:00.000Z');

      await service.getCompletions('user-abc', { since });

      expect(dbService.getSessionCompletions).toHaveBeenCalledWith(
        'user-abc',
        since,
      );
    });

    it('returns empty array when no completions exist', async () => {
      dbService.getSessionCompletions.mockResolvedValueOnce([]);

      const result = await service.getCompletions('user-abc', {
        since: new Date('2027-01-01T00:00:00.000Z'),
      });

      expect(result.completions).toEqual([]);
    });

    it('excludes internal fields (userId, clientId) from response', async () => {
      const result = await service.getCompletions('user-abc');

      for (const completion of result.completions) {
        expect(completion).not.toHaveProperty('userId');
        expect(completion).not.toHaveProperty('clientId');
      }
    });

    it('handles missing since parameter (returns all)', async () => {
      await service.getCompletions('user-abc');

      expect(dbService.getSessionCompletions).toHaveBeenCalledWith(
        'user-abc',
        undefined,
      );
    });
  });
});
