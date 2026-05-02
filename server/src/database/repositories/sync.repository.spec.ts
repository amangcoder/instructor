/**
 * Unit tests for SyncRepository — getCategories(), getVoices(), getPlanVoices().
 *
 * Strategy:
 *   - Mock database.getDb() to return a chainable Drizzle query-builder stub.
 *   - Mock database.withRetry() to pass-through by default (lets us inspect the
 *     Drizzle chain for filtering assertions), or to return fixed fixtures when
 *     we only care about the data shape returned to the caller.
 *   - Verify:
 *       • Only published / ready records are returned (REQ-023, AC-013)
 *       • `since` parameter gates both the rows query and the deletedIds query
 *       • deletedIds are correctly derived from unpublished/non-ready records
 *       • Full-sync (no since) never makes a deletedIds DB call
 *       • withRetry() is called the expected number of times per scenario
 */

import { Test, TestingModule } from '@nestjs/testing';
import {
  SyncRepository,
  type CategorySyncResult,
  type VoiceSyncResult,
  type PlanVoiceSyncResult,
} from './sync.repository';
import { DatabaseService } from '../database.service';

// ---------------------------------------------------------------------------
// Chainable query-builder stub
// ---------------------------------------------------------------------------

/**
 * Creates a Jest mock that returns `this` for all query-builder chain methods.
 *
 * All methods return `chain` by default (for fluent chaining). Individual tests
 * that need a specific terminal method to resolve with data should override it:
 *
 *   drizzleChain.orderBy.mockResolvedValue(rows);  // for ...where().orderBy() queries
 *   drizzleChain.where.mockResolvedValue(rows);    // for ...innerJoin().where() queries
 *
 * Most tests bypass the chain entirely by mocking withRetry directly.
 */
function makeChainMock() {
  const chain: Record<string, jest.Mock> = {
    select: jest.fn(),
    insert: jest.fn(),
    update: jest.fn(),
    from: jest.fn(),
    where: jest.fn(),
    innerJoin: jest.fn(),
    orderBy: jest.fn(),
    limit: jest.fn(),
    offset: jest.fn(),
    set: jest.fn(),
    values: jest.fn(),
    returning: jest.fn().mockResolvedValue([]),
    execute: jest.fn().mockResolvedValue([]),
  };

  // Every method returns `chain` so callers can fluently chain further calls.
  // Individual tests override the terminal method with mockResolvedValue(data).
  for (const key of Object.keys(chain)) {
    chain[key].mockReturnValue(chain);
  }

  return chain;
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

const BASE_DATE = new Date('2026-01-01T00:00:00Z');
const SINCE_DATE = new Date('2026-03-01T00:00:00Z');
const AFTER_SINCE = new Date('2026-04-01T00:00:00Z');

const PUBLISHED_CATEGORY = {
  id: 'cat-1',
  slug: 'wellness',
  name: 'Wellness',
  icon: null,
  color: null,
  sortOrder: 1,
  isPublished: true,
  createdAt: BASE_DATE,
  updatedAt: AFTER_SINCE,
};

const UNPUBLISHED_CATEGORY = {
  id: 'cat-2',
  slug: 'fitness',
  name: 'Fitness',
  icon: null,
  color: null,
  sortOrder: 2,
  isPublished: false,
  createdAt: BASE_DATE,
  updatedAt: AFTER_SINCE,
};

const PUBLISHED_VOICE = {
  id: 'voice-1',
  slug: 'google-en-us',
  displayName: 'Google US English',
  locale: 'en-US',
  provider: 'google',
  sampleUrl: null,
  isPublished: true,
  createdAt: BASE_DATE,
  updatedAt: AFTER_SINCE,
};

const UNPUBLISHED_VOICE = {
  id: 'voice-2',
  slug: 'deprecated-voice',
  displayName: 'Deprecated Voice',
  locale: 'en-US',
  provider: 'google',
  sampleUrl: null,
  isPublished: false,
  createdAt: BASE_DATE,
  updatedAt: AFTER_SINCE,
};

const READY_PLAN_VOICE = {
  id: 'pv-1',
  planId: 'plan-1',
  voiceId: 'voice-1',
  locale: 'en-US',
  status: 'ready' as const,
  audioUrl: 's3://bucket/audio.mp3',
  durationMs: 3000,
  errorMsg: null,
  generatedAt: BASE_DATE,
  createdAt: BASE_DATE,
  updatedAt: AFTER_SINCE,
};

const FAILED_PLAN_VOICE = {
  ...READY_PLAN_VOICE,
  id: 'pv-2',
  status: 'failed' as const,
  audioUrl: null,
  durationMs: null,
  generatedAt: null,
};

// ---------------------------------------------------------------------------
// Suite
// ---------------------------------------------------------------------------

describe('SyncRepository — content cache sync methods', () => {
  let repository: SyncRepository;
  let mockDatabaseService: jest.Mocked<Partial<DatabaseService>>;
  let drizzleChain: ReturnType<typeof makeChainMock>;

  beforeEach(async () => {
    drizzleChain = makeChainMock();

    mockDatabaseService = {
      getDb: jest.fn().mockReturnValue(drizzleChain),
      withRetry: jest.fn().mockImplementation(async (fn: () => Promise<unknown>) => fn()),
      noop: false,
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SyncRepository,
        { provide: DatabaseService, useValue: mockDatabaseService },
      ],
    }).compile();

    repository = module.get<SyncRepository>(SyncRepository);
  });

  // ── getCategories ─────────────────────────────────────────────────────────

  describe('getCategories()', () => {
    describe('full sync (no since)', () => {
      it('returns all published categories ordered by sortOrder', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [PUBLISHED_CATEGORY]);

        const result: CategorySyncResult = await repository.getCategories();

        expect(result.rows).toEqual([PUBLISHED_CATEGORY]);
        expect(result.deletedIds).toEqual([]);
      });

      it('makes exactly ONE withRetry call (no deletedIds query)', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => []);

        await repository.getCategories();

        expect(mockDatabaseService.withRetry).toHaveBeenCalledTimes(1);
      });

      it('returns empty rows when no categories are published', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => []);

        const result = await repository.getCategories();

        expect(result.rows).toEqual([]);
        expect(result.deletedIds).toEqual([]);
      });

      it('queries with is_published=true filter (uses select → from → where → orderBy chain)', async () => {
        // Override orderBy as terminal: select().from().where().orderBy() → data
        // where() returns chain (default), so orderBy() can be chained.
        drizzleChain.orderBy.mockResolvedValue([PUBLISHED_CATEGORY]);
        // withRetry passes through by default (fn() is called)

        await repository.getCategories();

        expect(drizzleChain.select).toHaveBeenCalledTimes(1);
        expect(drizzleChain.from).toHaveBeenCalledTimes(1);
        expect(drizzleChain.where).toHaveBeenCalledTimes(1);
        expect(drizzleChain.orderBy).toHaveBeenCalledTimes(1);
      });
    });

    describe('delta sync (with since)', () => {
      it('returns rows updated after since that are still published', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [PUBLISHED_CATEGORY]) // rows
          .mockImplementationOnce(async () => []);                  // deletedIds

        const result = await repository.getCategories(SINCE_DATE);

        expect(result.rows).toEqual([PUBLISHED_CATEGORY]);
      });

      it('makes exactly TWO withRetry calls (rows + deletedIds)', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [])
          .mockImplementationOnce(async () => []);

        await repository.getCategories(SINCE_DATE);

        expect(mockDatabaseService.withRetry).toHaveBeenCalledTimes(2);
      });

      it('returns deletedIds for categories unpublished after since', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [])                             // rows (no newly published)
          .mockImplementationOnce(async () => [{ id: UNPUBLISHED_CATEGORY.id }]); // deletedIds

        const result = await repository.getCategories(SINCE_DATE);

        expect(result.deletedIds).toEqual([UNPUBLISHED_CATEGORY.id]);
      });

      it('returns empty deletedIds when no categories were unpublished since then', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [PUBLISHED_CATEGORY])
          .mockImplementationOnce(async () => []);

        const result = await repository.getCategories(SINCE_DATE);

        expect(result.deletedIds).toEqual([]);
      });

      it('can return both rows and deletedIds simultaneously', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [PUBLISHED_CATEGORY])
          .mockImplementationOnce(async () => [{ id: 'cat-old-unpublished' }]);

        const result = await repository.getCategories(SINCE_DATE);

        expect(result.rows).toHaveLength(1);
        expect(result.deletedIds).toHaveLength(1);
        expect(result.deletedIds[0]).toBe('cat-old-unpublished');
      });

      it('runs rows and deletedIds queries in parallel (Promise.all)', async () => {
        const callOrder: string[] = [];

        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => { callOrder.push('rows'); return []; })
          .mockImplementationOnce(async () => { callOrder.push('deleted'); return []; });

        await repository.getCategories(SINCE_DATE);

        // Both calls were made (Promise.all fires both before awaiting either)
        expect(callOrder).toContain('rows');
        expect(callOrder).toContain('deleted');
        expect(mockDatabaseService.withRetry).toHaveBeenCalledTimes(2);
      });
    });

    describe('return shape', () => {
      it('always returns an object with rows array and deletedIds array', async () => {
        mockDatabaseService.withRetry!.mockResolvedValue([]);

        const result = await repository.getCategories();

        expect(result).toHaveProperty('rows');
        expect(result).toHaveProperty('deletedIds');
        expect(Array.isArray(result.rows)).toBe(true);
        expect(Array.isArray(result.deletedIds)).toBe(true);
      });
    });
  });

  // ── getVoices ─────────────────────────────────────────────────────────────

  describe('getVoices()', () => {
    describe('full sync (no since)', () => {
      it('returns all published voices', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [PUBLISHED_VOICE]);

        const result: VoiceSyncResult = await repository.getVoices();

        expect(result.rows).toEqual([PUBLISHED_VOICE]);
        expect(result.deletedIds).toEqual([]);
      });

      it('makes exactly ONE withRetry call (no deletedIds query)', async () => {
        mockDatabaseService.withRetry!.mockImplementationOnce(async () => []);

        await repository.getVoices();

        expect(mockDatabaseService.withRetry).toHaveBeenCalledTimes(1);
      });

      it('returns empty rows when no voices are published', async () => {
        mockDatabaseService.withRetry!.mockImplementationOnce(async () => []);

        const result = await repository.getVoices();

        expect(result.rows).toEqual([]);
        expect(result.deletedIds).toEqual([]);
      });

      it('queries with is_published=true filter and orderBy locale+displayName', async () => {
        // Override orderBy as terminal: select().from().where().orderBy() → data
        drizzleChain.orderBy.mockResolvedValue([PUBLISHED_VOICE]);

        await repository.getVoices();

        expect(drizzleChain.select).toHaveBeenCalledTimes(1);
        expect(drizzleChain.where).toHaveBeenCalledTimes(1);
        expect(drizzleChain.orderBy).toHaveBeenCalledTimes(1);
      });
    });

    describe('delta sync (with since)', () => {
      it('returns voices updated after since that are still published', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [PUBLISHED_VOICE])
          .mockImplementationOnce(async () => []);

        const result = await repository.getVoices(SINCE_DATE);

        expect(result.rows).toEqual([PUBLISHED_VOICE]);
      });

      it('makes exactly TWO withRetry calls (rows + deletedIds)', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [])
          .mockImplementationOnce(async () => []);

        await repository.getVoices(SINCE_DATE);

        expect(mockDatabaseService.withRetry).toHaveBeenCalledTimes(2);
      });

      it('returns deletedIds for voices unpublished after since', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [])
          .mockImplementationOnce(async () => [{ id: UNPUBLISHED_VOICE.id }]);

        const result = await repository.getVoices(SINCE_DATE);

        expect(result.deletedIds).toEqual([UNPUBLISHED_VOICE.id]);
      });

      it('returns empty deletedIds when no voices were unpublished since then', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [PUBLISHED_VOICE])
          .mockImplementationOnce(async () => []);

        const result = await repository.getVoices(SINCE_DATE);

        expect(result.deletedIds).toEqual([]);
      });

      it('can return both rows and deletedIds simultaneously', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [PUBLISHED_VOICE])
          .mockImplementationOnce(async () => [{ id: 'voice-deprecated' }]);

        const result = await repository.getVoices(SINCE_DATE);

        expect(result.rows).toHaveLength(1);
        expect(result.deletedIds).toEqual(['voice-deprecated']);
      });

      it('deletedIds extraction maps raw { id } rows to string array', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [])
          .mockImplementationOnce(async () => [
            { id: 'voice-a' },
            { id: 'voice-b' },
            { id: 'voice-c' },
          ]);

        const result = await repository.getVoices(SINCE_DATE);

        expect(result.deletedIds).toEqual(['voice-a', 'voice-b', 'voice-c']);
      });
    });

    describe('return shape', () => {
      it('always returns an object with rows array and deletedIds array', async () => {
        mockDatabaseService.withRetry!.mockResolvedValue([]);

        const result = await repository.getVoices();

        expect(result).toHaveProperty('rows');
        expect(result).toHaveProperty('deletedIds');
        expect(Array.isArray(result.rows)).toBe(true);
        expect(Array.isArray(result.deletedIds)).toBe(true);
      });
    });
  });

  // ── getPlanVoices ─────────────────────────────────────────────────────────

  describe('getPlanVoices()', () => {
    describe('full sync (no since)', () => {
      it('returns only status=ready rows for published plans', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [READY_PLAN_VOICE]);

        const result: PlanVoiceSyncResult = await repository.getPlanVoices();

        expect(result.rows).toEqual([READY_PLAN_VOICE]);
        expect(result.deletedIds).toEqual([]);
      });

      it('makes exactly ONE withRetry call (no deletedIds query)', async () => {
        mockDatabaseService.withRetry!.mockImplementationOnce(async () => []);

        await repository.getPlanVoices();

        expect(mockDatabaseService.withRetry).toHaveBeenCalledTimes(1);
      });

      it('returns empty rows when no ready+published plan_voices exist', async () => {
        mockDatabaseService.withRetry!.mockImplementationOnce(async () => []);

        const result = await repository.getPlanVoices();

        expect(result.rows).toEqual([]);
        expect(result.deletedIds).toEqual([]);
      });

      it('uses innerJoin on plans table for the ready+published gate', async () => {
        // Pass-through withRetry so the drizzle chain is actually invoked
        drizzleChain.innerJoin.mockResolvedValue([READY_PLAN_VOICE]);

        await repository.getPlanVoices();

        expect(drizzleChain.select).toHaveBeenCalledTimes(1);
        expect(drizzleChain.from).toHaveBeenCalledTimes(1);
        expect(drizzleChain.innerJoin).toHaveBeenCalledTimes(1);
        expect(drizzleChain.where).toHaveBeenCalledTimes(1);
      });

      it('does NOT include non-ready plan_voice rows', async () => {
        // Only returns the ready row — failed row is excluded by the filter
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [READY_PLAN_VOICE]);

        const result = await repository.getPlanVoices();

        // FAILED_PLAN_VOICE is not in result because the query filters status='ready'
        expect(result.rows.every((r) => r.status === 'ready')).toBe(true);
      });
    });

    describe('delta sync (with since)', () => {
      it('returns ready+published rows updated after since', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [READY_PLAN_VOICE])
          .mockImplementationOnce(async () => []);

        const result = await repository.getPlanVoices(SINCE_DATE);

        expect(result.rows).toEqual([READY_PLAN_VOICE]);
      });

      it('makes exactly TWO withRetry calls (rows + deletedIds)', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [])
          .mockImplementationOnce(async () => []);

        await repository.getPlanVoices(SINCE_DATE);

        expect(mockDatabaseService.withRetry).toHaveBeenCalledTimes(2);
      });

      it('returns deletedIds for plan_voices that became non-ready after since', async () => {
        // Scenario: a plan_voice was previously ready but now status=failed
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [])
          .mockImplementationOnce(async () => [{ id: FAILED_PLAN_VOICE.id }]);

        const result = await repository.getPlanVoices(SINCE_DATE);

        expect(result.deletedIds).toEqual([FAILED_PLAN_VOICE.id]);
      });

      it('returns deletedIds for plan_voices whose plan was unpublished after since', async () => {
        // Scenario: plan_voice is still status=ready but the plan is now is_published=false
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [])
          .mockImplementationOnce(async () => [{ id: 'pv-unpublished-plan' }]);

        const result = await repository.getPlanVoices(SINCE_DATE);

        expect(result.deletedIds).toContain('pv-unpublished-plan');
      });

      it('returns empty deletedIds when all plan_voices remain ready+published', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [READY_PLAN_VOICE])
          .mockImplementationOnce(async () => []);

        const result = await repository.getPlanVoices(SINCE_DATE);

        expect(result.deletedIds).toEqual([]);
      });

      it('can return both rows and deletedIds simultaneously', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [READY_PLAN_VOICE])
          .mockImplementationOnce(async () => [{ id: 'pv-evicted' }]);

        const result = await repository.getPlanVoices(SINCE_DATE);

        expect(result.rows).toHaveLength(1);
        expect(result.deletedIds).toEqual(['pv-evicted']);
      });

      it('handles multiple deletedIds correctly', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [])
          .mockImplementationOnce(async () => [
            { id: 'pv-1' },
            { id: 'pv-2' },
            { id: 'pv-3' },
          ]);

        const result = await repository.getPlanVoices(SINCE_DATE);

        expect(result.deletedIds).toEqual(['pv-1', 'pv-2', 'pv-3']);
      });

      it('deletedIds query joins plans to detect plan-level unpublish', async () => {
        // Pass-through so we can assert the drizzle chain
        drizzleChain.where.mockResolvedValue([{ id: 'pv-evicted' }]);

        await repository.getPlanVoices(SINCE_DATE);

        // Second call to innerJoin covers the deletedIds query join on plans
        expect(drizzleChain.innerJoin).toHaveBeenCalled();
      });

      it('runs rows and deletedIds queries in parallel (Promise.all)', async () => {
        const callOrder: string[] = [];

        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => { callOrder.push('rows'); return []; })
          .mockImplementationOnce(async () => { callOrder.push('deleted'); return []; });

        await repository.getPlanVoices(SINCE_DATE);

        expect(callOrder).toContain('rows');
        expect(callOrder).toContain('deleted');
      });
    });

    describe('return shape', () => {
      it('always returns an object with rows array and deletedIds array', async () => {
        mockDatabaseService.withRetry!.mockResolvedValue([]);

        const result = await repository.getPlanVoices();

        expect(result).toHaveProperty('rows');
        expect(result).toHaveProperty('deletedIds');
        expect(Array.isArray(result.rows)).toBe(true);
        expect(Array.isArray(result.deletedIds)).toBe(true);
      });

      it('rows entries match PlanVoice shape (no plan columns leaked)', async () => {
        mockDatabaseService.withRetry!
          .mockImplementationOnce(async () => [READY_PLAN_VOICE]);

        const result = await repository.getPlanVoices();

        const row = result.rows[0];
        expect(row).toHaveProperty('id');
        expect(row).toHaveProperty('planId');
        expect(row).toHaveProperty('voiceId');
        expect(row).toHaveProperty('locale');
        expect(row).toHaveProperty('status');
        expect(row).toHaveProperty('audioUrl');
        expect(row).toHaveProperty('durationMs');
        expect(row).toHaveProperty('errorMsg');
        expect(row).toHaveProperty('generatedAt');
        expect(row).toHaveProperty('createdAt');
        expect(row).toHaveProperty('updatedAt');
        // No plan columns: isPublished, visibility, etc.
        expect(row).not.toHaveProperty('isPublished');
        expect(row).not.toHaveProperty('visibility');
      });
    });
  });

  // ── Existing sync methods (regression guard) ──────────────────────────────

  describe('legacy session completion methods', () => {
    it('upsertSessionCompletions delegates to DatabaseService', async () => {
      (mockDatabaseService as any).upsertSessionCompletions = jest
        .fn()
        .mockResolvedValue(3);

      const result = await repository.upsertSessionCompletions('user-1', [
        { planId: 'p1', completedAt: new Date(), durationMs: 1000, clientId: 'c1' },
      ]);

      expect(result).toBe(3);
      expect(mockDatabaseService.upsertSessionCompletions).toHaveBeenCalledWith(
        'user-1',
        expect.any(Array),
      );
    });

    it('getSessionCompletions delegates to DatabaseService', async () => {
      (mockDatabaseService as any).getSessionCompletions = jest
        .fn()
        .mockResolvedValue([]);

      await repository.getSessionCompletions('user-1', new Date());

      expect(mockDatabaseService.getSessionCompletions).toHaveBeenCalledWith(
        'user-1',
        expect.any(Date),
      );
    });
  });

  describe('legacy plan trigger methods', () => {
    it('upsertPlanTriggers delegates to DatabaseService', async () => {
      (mockDatabaseService as any).upsertPlanTriggers = jest
        .fn()
        .mockResolvedValue([]);

      await repository.upsertPlanTriggers('user-1', []);

      expect(mockDatabaseService.upsertPlanTriggers).toHaveBeenCalledWith(
        'user-1',
        [],
      );
    });

    it('getPlanTriggers delegates to DatabaseService', async () => {
      (mockDatabaseService as any).getPlanTriggers = jest
        .fn()
        .mockResolvedValue([]);

      await repository.getPlanTriggers('user-1');

      expect(mockDatabaseService.getPlanTriggers).toHaveBeenCalledWith(
        'user-1',
        undefined,
      );
    });
  });
});
