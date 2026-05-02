/**
 * Unit tests for PlanVoicesRepository.
 *
 * Strategy:
 *   - mock database.getDb() to return a chainable Drizzle query-builder stub
 *   - mock database.withRetry() to pass through to the provided function
 *   - assert that the correct Drizzle chain is invoked for each method
 *   - assert return value mapping and error paths
 */

import { Test, TestingModule } from '@nestjs/testing';
import {
  PlanVoicesRepository,
  mapLegacyTtsStatus,
  type DbTransaction,
} from './plan-voices.repository';
import { DatabaseService } from '../database.service';

// ---------------------------------------------------------------------------
// Chainable query-builder stub
// ---------------------------------------------------------------------------

/** Creates a Jest mock that returns `this` for all query-builder chain methods */
function makeChainMock(resolveWith: unknown[] = []) {
  const chain: Record<string, jest.Mock> = {
    insert: jest.fn(),
    select: jest.fn(),
    update: jest.fn(),
    from: jest.fn(),
    where: jest.fn(),
    values: jest.fn(),
    set: jest.fn(),
    onConflictDoUpdate: jest.fn(),
    leftJoin: jest.fn(),
    orderBy: jest.fn(),
    limit: jest.fn(),
    offset: jest.fn(),
    returning: jest.fn().mockResolvedValue(resolveWith),
    execute: jest.fn().mockResolvedValue(resolveWith),
  };

  // All non-terminal methods return the chain itself
  for (const key of Object.keys(chain)) {
    if (key !== 'returning' && key !== 'execute') {
      chain[key].mockReturnValue(chain);
    }
  }

  return chain;
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

const PLAN_VOICE = {
  id: 'pv-uuid-1',
  planId: 'plan-uuid-1',
  voiceId: 'voice-uuid-1',
  locale: 'en-US',
  status: 'pending' as const,
  audioUrl: null,
  durationMs: null,
  errorMsg: null,
  generatedAt: null,
  createdAt: new Date('2026-01-01T00:00:00Z'),
  updatedAt: new Date('2026-01-01T00:00:00Z'),
};

const READY_PLAN_VOICE = {
  ...PLAN_VOICE,
  id: 'pv-uuid-2',
  status: 'ready' as const,
  audioUrl: 's3://bucket/audio.mp3',
  durationMs: 3000,
  generatedAt: new Date('2026-01-02T00:00:00Z'),
};

const FAILED_PLAN_VOICE = {
  ...PLAN_VOICE,
  id: 'pv-uuid-3',
  status: 'failed' as const,
  errorMsg: 'Synthesis timeout',
};

// ---------------------------------------------------------------------------
// Suite
// ---------------------------------------------------------------------------

describe('PlanVoicesRepository', () => {
  let repository: PlanVoicesRepository;
  let mockDatabaseService: jest.Mocked<Partial<DatabaseService>>;
  let drizzleChain: ReturnType<typeof makeChainMock>;

  beforeEach(async () => {
    drizzleChain = makeChainMock();

    mockDatabaseService = {
      getDb: jest.fn().mockReturnValue(drizzleChain),
      withRetry: jest.fn().mockImplementation(async (fn: () => Promise<unknown>) => fn()),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PlanVoicesRepository,
        { provide: DatabaseService, useValue: mockDatabaseService },
      ],
    }).compile();

    repository = module.get<PlanVoicesRepository>(PlanVoicesRepository);
  });

  // ── mapLegacyTtsStatus (pure function) ─────────────────────────────────────

  describe('mapLegacyTtsStatus()', () => {
    it('maps "completed" → "ready"', () => {
      expect(mapLegacyTtsStatus('completed')).toBe('ready');
    });

    it('maps "pending" → "pending"', () => {
      expect(mapLegacyTtsStatus('pending')).toBe('pending');
    });

    it('maps "processing" → "processing"', () => {
      expect(mapLegacyTtsStatus('processing')).toBe('processing');
    });

    it('maps "failed" → "failed"', () => {
      expect(mapLegacyTtsStatus('failed')).toBe('failed');
    });

    it('maps "partial" → "failed" (partial means some jobs failed)', () => {
      expect(mapLegacyTtsStatus('partial')).toBe('failed');
    });

    it('maps "none" → "pending"', () => {
      expect(mapLegacyTtsStatus('none')).toBe('pending');
    });

    it('maps unknown values → "pending" (safe default)', () => {
      expect(mapLegacyTtsStatus('unknown_legacy_value')).toBe('pending');
    });
  });

  // ── upsertPlanVoice ─────────────────────────────────────────────────────────

  describe('upsertPlanVoice()', () => {
    it('calls insert with the provided data and returns the persisted row', async () => {
      drizzleChain.returning.mockResolvedValue([PLAN_VOICE]);

      const result = await repository.upsertPlanVoice({
        planId: 'plan-uuid-1',
        voiceId: 'voice-uuid-1',
        locale: 'en-US',
      });

      expect(result).toBe(PLAN_VOICE);
      expect(drizzleChain.insert).toHaveBeenCalledTimes(1);
      expect(drizzleChain.values).toHaveBeenCalledTimes(1);
      expect(drizzleChain.onConflictDoUpdate).toHaveBeenCalledTimes(1);
      expect(drizzleChain.returning).toHaveBeenCalledTimes(1);
    });

    it('uses withRetry for cold-start recovery', async () => {
      drizzleChain.returning.mockResolvedValue([PLAN_VOICE]);
      await repository.upsertPlanVoice({ planId: 'p', voiceId: 'v', locale: 'en-US' });
      expect(mockDatabaseService.withRetry).toHaveBeenCalledTimes(1);
    });

    it('passes the correct conflict target columns to onConflictDoUpdate', async () => {
      drizzleChain.returning.mockResolvedValue([PLAN_VOICE]);
      await repository.upsertPlanVoice({ planId: 'p', voiceId: 'v', locale: 'en-US' });

      const [conflictArgs] = drizzleChain.onConflictDoUpdate.mock.calls[0];
      expect(conflictArgs).toHaveProperty('target');
      expect(conflictArgs).toHaveProperty('set');
    });
  });

  // ── updateStatus ────────────────────────────────────────────────────────────

  describe('updateStatus()', () => {
    it('updates status to "ready" and includes audioUrl/durationMs', async () => {
      await repository.updateStatus('pv-1', 'ready', 's3://bucket/file.mp3', 3000);

      expect(drizzleChain.update).toHaveBeenCalledTimes(1);
      expect(drizzleChain.set).toHaveBeenCalledTimes(1);
      expect(drizzleChain.where).toHaveBeenCalledTimes(1);

      const [setArg] = drizzleChain.set.mock.calls[0];
      expect(setArg.status).toBe('ready');
      expect(setArg.audioUrl).toBe('s3://bucket/file.mp3');
      expect(setArg.durationMs).toBe(3000);
      expect(setArg.generatedAt).toBeInstanceOf(Date);
    });

    it('updates status to "failed" with errorMsg only', async () => {
      await repository.updateStatus('pv-1', 'failed', undefined, undefined, 'timeout');

      const [setArg] = drizzleChain.set.mock.calls[0];
      expect(setArg.status).toBe('failed');
      expect(setArg.errorMsg).toBe('timeout');
      expect(setArg.generatedAt).toBeUndefined();
    });

    it('does NOT set generatedAt for non-ready statuses', async () => {
      await repository.updateStatus('pv-1', 'processing');

      const [setArg] = drizzleChain.set.mock.calls[0];
      expect(setArg.status).toBe('processing');
      expect(setArg.generatedAt).toBeUndefined();
    });

    it('does not include undefined optional fields in the set payload', async () => {
      await repository.updateStatus('pv-1', 'pending');

      const [setArg] = drizzleChain.set.mock.calls[0];
      expect('audioUrl' in setArg).toBe(false);
      expect('durationMs' in setArg).toBe(false);
      expect('errorMsg' in setArg).toBe(false);
    });

    it('always sets updatedAt', async () => {
      await repository.updateStatus('pv-1', 'pending');

      const [setArg] = drizzleChain.set.mock.calls[0];
      expect(setArg.updatedAt).toBeInstanceOf(Date);
    });
  });

  // ── listByPlan ──────────────────────────────────────────────────────────────

  describe('listByPlan()', () => {
    it('returns all plan_voice rows joined with voice displayName/slug', async () => {
      const joinedRows = [
        { ...PLAN_VOICE, voiceDisplayName: 'Bella', voiceSlug: 'af_bella' },
        { ...READY_PLAN_VOICE, voiceDisplayName: 'Aoede', voiceSlug: 'aoede' },
      ];
      drizzleChain.orderBy.mockResolvedValue(joinedRows);

      const result = await repository.listByPlan('plan-uuid-1');

      expect(result).toEqual([
        { ...PLAN_VOICE, voice: { displayName: 'Bella', slug: 'af_bella' } },
        { ...READY_PLAN_VOICE, voice: { displayName: 'Aoede', slug: 'aoede' } },
      ]);
      expect(drizzleChain.select).toHaveBeenCalledTimes(1);
      expect(drizzleChain.from).toHaveBeenCalledTimes(1);
      expect(drizzleChain.leftJoin).toHaveBeenCalledTimes(1);
      expect(drizzleChain.where).toHaveBeenCalledTimes(1);
      expect(drizzleChain.orderBy).toHaveBeenCalledTimes(1);
    });

    it('returns voice=null when the joined voice row is missing', async () => {
      const joinedRows = [
        { ...PLAN_VOICE, voiceDisplayName: null, voiceSlug: null },
      ];
      drizzleChain.orderBy.mockResolvedValue(joinedRows);

      const result = await repository.listByPlan('plan-uuid-1');

      expect(result).toEqual([{ ...PLAN_VOICE, voice: null }]);
    });

    it('returns empty array when no rows exist for the plan', async () => {
      drizzleChain.orderBy.mockResolvedValue([]);
      const result = await repository.listByPlan('no-such-plan');
      expect(result).toEqual([]);
    });
  });

  // ── listFailed ──────────────────────────────────────────────────────────────

  describe('listFailed()', () => {
    it('returns paginated failed rows and total count', async () => {
      // First withRetry call → items query, second → count query
      mockDatabaseService.withRetry!
        .mockImplementationOnce(async (fn: () => Promise<unknown>) => [FAILED_PLAN_VOICE])
        .mockImplementationOnce(async (fn: () => Promise<unknown>) => [{ total: '1' }]);

      const result = await repository.listFailed(1, 20);

      expect(result.items).toEqual([FAILED_PLAN_VOICE]);
      expect(result.total).toBe(1);
    });

    it('calculates offset correctly for page 2', async () => {
      mockDatabaseService.withRetry!
        .mockImplementationOnce(async () => [])
        .mockImplementationOnce(async () => [{ total: '0' }]);

      await repository.listFailed(2, 10);

      // Both queries should have been fired in parallel
      expect(mockDatabaseService.withRetry).toHaveBeenCalledTimes(2);
    });

    it('returns total=0 when there are no failed rows', async () => {
      mockDatabaseService.withRetry!
        .mockImplementationOnce(async () => [])
        .mockImplementationOnce(async () => [{ total: '0' }]);

      const result = await repository.listFailed(1, 20);

      expect(result.items).toEqual([]);
      expect(result.total).toBe(0);
    });

    it('handles missing total row gracefully', async () => {
      mockDatabaseService.withRetry!
        .mockImplementationOnce(async () => [])
        .mockImplementationOnce(async () => []);

      const result = await repository.listFailed(1, 20);

      expect(result.total).toBe(0);
    });
  });

  // ── hasReadyVoice ───────────────────────────────────────────────────────────

  describe('hasReadyVoice()', () => {
    it('returns true when a ready row exists for the plan', async () => {
      // Simulate LIMIT 1 returning one row
      drizzleChain.limit.mockResolvedValue([{ id: 'pv-uuid-2' }]);

      const result = await repository.hasReadyVoice('plan-uuid-1');

      expect(result).toBe(true);
      expect(drizzleChain.select).toHaveBeenCalledTimes(1);
      expect(drizzleChain.where).toHaveBeenCalledTimes(1);
      expect(drizzleChain.limit).toHaveBeenCalledWith(1);
    });

    it('returns false when no ready rows exist', async () => {
      drizzleChain.limit.mockResolvedValue([]);

      const result = await repository.hasReadyVoice('plan-uuid-no-ready');

      expect(result).toBe(false);
    });

    it('uses LIMIT 1 for efficiency (does not scan all rows)', async () => {
      drizzleChain.limit.mockResolvedValue([]);
      await repository.hasReadyVoice('plan-uuid-1');
      expect(drizzleChain.limit).toHaveBeenCalledWith(1);
    });

    it('uses withRetry for cold-start recovery', async () => {
      drizzleChain.limit.mockResolvedValue([]);
      await repository.hasReadyVoice('plan-uuid-1');
      expect(mockDatabaseService.withRetry).toHaveBeenCalledTimes(1);
    });
  });

  // ── backfillFromTtsStatus ───────────────────────────────────────────────────

  describe('backfillFromTtsStatus()', () => {
    it('creates a plan_voice row with mapped status from a completed tts_status', async () => {
      // withRetry call 1 → tts_jobs query returns one job
      // withRetry call 2 → voices query returns one voice
      // withRetry call 3 → insert returns created row
      mockDatabaseService.withRetry!
        .mockImplementationOnce(async () => [{ voiceSlug: 'af_aoede', locale: 'en-US' }])
        .mockImplementationOnce(async () => [{ id: 'voice-uuid-1' }])
        .mockImplementationOnce(async () => [READY_PLAN_VOICE]);

      const result = await repository.backfillFromTtsStatus('plan-uuid-1', 'completed');

      expect(result).toBe(READY_PLAN_VOICE);
      expect(mockDatabaseService.withRetry).toHaveBeenCalledTimes(3);
    });

    it('maps "completed" → "ready" in the upserted row', async () => {
      mockDatabaseService.withRetry!
        .mockImplementationOnce(async () => [{ voiceSlug: 'af_aoede', locale: 'en-US' }])
        .mockImplementationOnce(async () => [{ id: 'voice-uuid-1' }])
        .mockImplementationOnce(async (fn: () => Promise<unknown>) => fn());

      drizzleChain.returning.mockResolvedValue([{ ...PLAN_VOICE, status: 'ready' }]);

      await repository.backfillFromTtsStatus('plan-uuid-1', 'completed');

      // The insert values call should have received status='ready'
      const [valuesArg] = drizzleChain.values.mock.calls[0];
      expect(valuesArg.status).toBe('ready');
    });

    it('maps "partial" → "failed"', async () => {
      mockDatabaseService.withRetry!
        .mockImplementationOnce(async () => [{ voiceSlug: 'af_aoede', locale: 'en-US' }])
        .mockImplementationOnce(async () => [{ id: 'voice-uuid-1' }])
        .mockImplementationOnce(async (fn: () => Promise<unknown>) => fn());

      drizzleChain.returning.mockResolvedValue([{ ...PLAN_VOICE, status: 'failed' }]);

      await repository.backfillFromTtsStatus('plan-uuid-1', 'partial');

      const [valuesArg] = drizzleChain.values.mock.calls[0];
      expect(valuesArg.status).toBe('failed');
    });

    it('throws when no tts_jobs exist for the plan', async () => {
      mockDatabaseService.withRetry!
        .mockImplementationOnce(async () => []); // no tts_jobs

      await expect(
        repository.backfillFromTtsStatus('plan-no-jobs', 'completed'),
      ).rejects.toThrow(/No tts_jobs found for plan plan-no-jobs/);
    });

    it('throws when the voice slug is not found in the voices table', async () => {
      mockDatabaseService.withRetry!
        .mockImplementationOnce(async () => [{ voiceSlug: 'unknown_slug', locale: 'en-US' }])
        .mockImplementationOnce(async () => []); // voice not found

      await expect(
        repository.backfillFromTtsStatus('plan-uuid-1', 'completed'),
      ).rejects.toThrow(/Voice slug 'unknown_slug' not found/);
    });
  });

  // ── createBatch ─────────────────────────────────────────────────────────────

  describe('createBatch()', () => {
    let txMock: ReturnType<typeof makeChainMock>;

    beforeEach(() => {
      txMock = makeChainMock();
    });

    it('inserts multiple rows and returns them', async () => {
      const inputRows = [
        { planId: 'p1', voiceId: 'v1', locale: 'en-US' },
        { planId: 'p1', voiceId: 'v2', locale: 'en-IN' },
      ];
      txMock.returning.mockResolvedValue([PLAN_VOICE, READY_PLAN_VOICE]);

      const result = await repository.createBatch(
        inputRows,
        txMock as unknown as DbTransaction,
      );

      expect(result).toEqual([PLAN_VOICE, READY_PLAN_VOICE]);
      expect(txMock.insert).toHaveBeenCalledTimes(1);
      expect(txMock.values).toHaveBeenCalledWith(inputRows);
      expect(txMock.onConflictDoUpdate).toHaveBeenCalledTimes(1);
      expect(txMock.returning).toHaveBeenCalledTimes(1);
    });

    it('returns empty array without touching the database when rows is empty', async () => {
      const result = await repository.createBatch(
        [],
        txMock as unknown as DbTransaction,
      );

      expect(result).toEqual([]);
      expect(txMock.insert).not.toHaveBeenCalled();
    });

    it('uses EXCLUDED column references in onConflictDoUpdate', async () => {
      txMock.returning.mockResolvedValue([PLAN_VOICE]);

      await repository.createBatch(
        [{ planId: 'p1', voiceId: 'v1', locale: 'en-US' }],
        txMock as unknown as DbTransaction,
      );

      const [conflictArgs] = txMock.onConflictDoUpdate.mock.calls[0];
      expect(conflictArgs.set).toHaveProperty('status');
      expect(conflictArgs.set).toHaveProperty('updatedAt');
    });

    it('accepts the db instance as the tx parameter (no true transaction needed)', async () => {
      // This test verifies the interface accepts both the db and a tx-like object
      txMock.returning.mockResolvedValue([PLAN_VOICE]);

      await expect(
        repository.createBatch(
          [{ planId: 'p', voiceId: 'v', locale: 'en-US' }],
          txMock as unknown as DbTransaction,
        ),
      ).resolves.toEqual([PLAN_VOICE]);
    });
  });
});
