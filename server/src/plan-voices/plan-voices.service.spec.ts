/**
 * Unit tests for PlanVoicesService (AC-020).
 *
 * Tests service-layer business logic in isolation — all dependencies
 * (DatabaseService, PlanVoicesRepository, VoiceRepository,
 * TtsBatchPregenService) are fully mocked.
 *
 * Public methods under test:
 *   - regenerateVoice(planId, voiceId)
 *   - listFailed(page?, pageSize?)
 */

import { NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { PlanVoicesService } from './plan-voices.service';
import { PlanVoicesRepository } from '../database/repositories/plan-voices.repository';
import { VoiceRepository } from '../database/repositories/voice.repository';
import { TtsBatchPregenService } from '../tts/tts-batch-pregen.service';
import { TtsService } from '../tts/tts.service';
import { DatabaseService } from '../database/database.service';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const PLAN_ID = 'plan-uuid-001';
const VOICE_ID = 'voice-uuid-001';

const PLAN_VOICE_FIXTURE = {
  id: 'pv-uuid-001',
  planId: PLAN_ID,
  voiceId: VOICE_ID,
  locale: 'en-US',
  status: 'failed' as const,
  audioUrl: null,
  durationMs: null,
  errorMsg: 'Synthesis timeout',
  generatedAt: null,
  createdAt: new Date('2026-01-01T00:00:00.000Z'),
  updatedAt: new Date('2026-01-02T00:00:00.000Z'),
};

const VOICE_FIXTURE = {
  id: VOICE_ID,
  name: 'Aria',
  slug: 'aria',
  provider: 'kokoro' as const,
  locale: 'en-US',
  gender: 'female' as const,
  isActive: true,
  createdAt: new Date('2026-01-01T00:00:00.000Z'),
  updatedAt: new Date('2026-01-01T00:00:00.000Z'),
};

const PLAN_JSON = JSON.stringify({ steps: [{ title: 'Step 1', duration: 60 }] });

// ---------------------------------------------------------------------------
// Mock factories
// ---------------------------------------------------------------------------

function createMockPlanVoicesRepo(): jest.Mocked<PlanVoicesRepository> {
  return {
    listByPlan: jest.fn().mockResolvedValue([PLAN_VOICE_FIXTURE]),
    listFailed: jest.fn().mockResolvedValue({ items: [PLAN_VOICE_FIXTURE], total: 1 }),
    upsertPlanVoice: jest.fn(),
    updateStatus: jest.fn(),
    hasReadyVoice: jest.fn(),
    backfillFromTtsStatus: jest.fn(),
    createBatch: jest.fn(),
    noop: false,
  } as unknown as jest.Mocked<PlanVoicesRepository>;
}

function createMockVoiceRepo(): jest.Mocked<VoiceRepository> {
  return {
    findById: jest.fn().mockResolvedValue(VOICE_FIXTURE),
    findAll: jest.fn(),
    findBySlug: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  } as unknown as jest.Mocked<VoiceRepository>;
}

function createMockTtsBatchPregen(): jest.Mocked<TtsBatchPregenService> {
  return {
    regenerateVoice: jest.fn().mockResolvedValue(undefined),
    enqueueBatch: jest.fn(),
    writePlanVoiceStatus: jest.fn(),
  } as unknown as jest.Mocked<TtsBatchPregenService>;
}

function createMockTtsService(): jest.Mocked<TtsService> {
  return {
    synthesize: jest.fn().mockResolvedValue(Buffer.from('')),
  } as unknown as jest.Mocked<TtsService>;
}

function createMockDb(planRows: Array<{ planJson: string | null }> = [{ planJson: PLAN_JSON }]) {
  const selectResult = {
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    limit: jest.fn().mockResolvedValue(planRows),
  };
  const dbInstance = { select: jest.fn().mockReturnValue(selectResult) };

  return {
    getDb: jest.fn().mockReturnValue(dbInstance),
    withRetry: jest.fn().mockImplementation((fn: () => Promise<unknown>) => fn()),
    noop: false,
  } as unknown as jest.Mocked<DatabaseService>;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('PlanVoicesService', () => {
  let service: PlanVoicesService;
  let planVoicesRepo: jest.Mocked<PlanVoicesRepository>;
  let voiceRepo: jest.Mocked<VoiceRepository>;
  let ttsBatchPregen: jest.Mocked<TtsBatchPregenService>;
  let ttsService: jest.Mocked<TtsService>;
  let db: jest.Mocked<DatabaseService>;

  async function buildService(
    dbOverride?: jest.Mocked<DatabaseService>,
    planVoicesRepoOverride?: jest.Mocked<PlanVoicesRepository>,
  ) {
    planVoicesRepo = planVoicesRepoOverride ?? createMockPlanVoicesRepo();
    voiceRepo = createMockVoiceRepo();
    ttsBatchPregen = createMockTtsBatchPregen();
    ttsService = createMockTtsService();
    db = dbOverride ?? createMockDb();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PlanVoicesService,
        { provide: DatabaseService, useValue: db },
        { provide: PlanVoicesRepository, useValue: planVoicesRepo },
        { provide: VoiceRepository, useValue: voiceRepo },
        { provide: TtsBatchPregenService, useValue: ttsBatchPregen },
        { provide: TtsService, useValue: ttsService },
      ],
    }).compile();

    service = module.get<PlanVoicesService>(PlanVoicesService);
  }

  // ── regenerateVoice ─────────────────────────────────────────────────────────

  describe('regenerateVoice()', () => {
    beforeEach(async () => {
      await buildService();
    });

    it('returns a regeneration response with planId, voiceId and status=pending', async () => {
      const result = await service.regenerateVoice(PLAN_ID, VOICE_ID);

      expect(result).toMatchObject({
        planId: PLAN_ID,
        voiceId: VOICE_ID,
        status: 'pending',
      });
      expect(typeof result.jobId).toBe('string');
      expect(result.jobId.length).toBeGreaterThan(0);
    });

    it('looks up the plan_voice row by planId', async () => {
      await service.regenerateVoice(PLAN_ID, VOICE_ID);
      expect(planVoicesRepo.listByPlan).toHaveBeenCalledWith(PLAN_ID);
    });

    it('looks up the voice row by voiceId', async () => {
      await service.regenerateVoice(PLAN_ID, VOICE_ID);
      expect(voiceRepo.findById).toHaveBeenCalledWith(VOICE_ID);
    });

    it('calls ttsBatchPregen.regenerateVoice with correct arguments', async () => {
      await service.regenerateVoice(PLAN_ID, VOICE_ID);

      expect(ttsBatchPregen.regenerateVoice).toHaveBeenCalledWith(
        PLAN_ID,
        VOICE_FIXTURE.slug,
        PLAN_VOICE_FIXTURE.locale,
        PLAN_JSON,
        VOICE_FIXTURE.provider,
      );
    });

    it('throws NotFoundException when no plan_voice row exists for the pair', async () => {
      // Return a plan_voices list that does NOT contain the requested voiceId
      planVoicesRepo.listByPlan.mockResolvedValue([]);

      await expect(service.regenerateVoice(PLAN_ID, VOICE_ID)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('throws NotFoundException when the voice does not exist', async () => {
      voiceRepo.findById.mockResolvedValue(null);

      await expect(service.regenerateVoice(PLAN_ID, VOICE_ID)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('throws NotFoundException when the plan does not exist', async () => {
      // Plan not found → empty planRows from db query
      const dbNoPlan = createMockDb([]); // returns empty array → plan not found
      await buildService(dbNoPlan);

      await expect(service.regenerateVoice(PLAN_ID, VOICE_ID)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('returns synthetic jobId in database noop mode (no DATABASE_URL)', async () => {
      const dbNoop = {
        getDb: jest.fn().mockReturnValue(null), // noop: getDb() returns null
        withRetry: jest.fn(),
        noop: true,
      } as unknown as jest.Mocked<DatabaseService>;

      await buildService(dbNoop);

      const result = await service.regenerateVoice(PLAN_ID, VOICE_ID);

      // Should still return a response without calling ttsBatchPregen
      expect(result).toMatchObject({ planId: PLAN_ID, voiceId: VOICE_ID, status: 'pending' });
      expect(ttsBatchPregen.regenerateVoice).not.toHaveBeenCalled();
    });
  });

  // ── listFailed ──────────────────────────────────────────────────────────────

  describe('listFailed()', () => {
    beforeEach(async () => {
      await buildService();
    });

    it('returns paginated list of failed plan-voices', async () => {
      const result = await service.listFailed(1, 20);

      expect(result).toMatchObject({
        items: expect.arrayContaining([expect.objectContaining({ id: PLAN_VOICE_FIXTURE.id })]),
        total: 1,
        page: 1,
        pageSize: 20,
      });
    });

    it('calls repo.listFailed with page and pageSize', async () => {
      await service.listFailed(2, 10);
      expect(planVoicesRepo.listFailed).toHaveBeenCalledWith(2, 10);
    });

    it('defaults to page=1 and pageSize=20 when called with no args', async () => {
      await service.listFailed();
      expect(planVoicesRepo.listFailed).toHaveBeenCalledWith(1, 20);
    });

    it('clamps page to minimum of 1 when page < 1', async () => {
      await service.listFailed(0, 20);
      expect(planVoicesRepo.listFailed).toHaveBeenCalledWith(1, 20);
    });

    it('clamps page to minimum of 1 when page is negative', async () => {
      await service.listFailed(-5, 20);
      expect(planVoicesRepo.listFailed).toHaveBeenCalledWith(1, 20);
    });

    it('clamps pageSize to maximum of 100', async () => {
      await service.listFailed(1, 999);
      expect(planVoicesRepo.listFailed).toHaveBeenCalledWith(1, 100);
    });

    it('clamps pageSize to minimum of 1', async () => {
      await service.listFailed(1, 0);
      expect(planVoicesRepo.listFailed).toHaveBeenCalledWith(1, 1);
    });

    it('returns correct page and pageSize in the response envelope', async () => {
      const result = await service.listFailed(3, 5);
      expect(result.page).toBe(3);
      expect(result.pageSize).toBe(5);
    });
  });
});
