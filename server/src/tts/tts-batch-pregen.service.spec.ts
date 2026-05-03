import { Test, TestingModule } from '@nestjs/testing';
import { TtsBatchPregenService } from './tts-batch-pregen.service';
import { DatabaseService } from '../database/database.service';
import { TtsService } from './tts.service';
import { TtsEnumerationService } from './tts-enumeration.service';
import { WorkerDispatchService } from '../worker-dispatch/worker-dispatch.service';
import { PlanVoicesRepository } from '../database/repositories/plan-voices.repository';
import { VoiceRepository } from '../database/repositories/voice.repository';
import { createMockDatabaseService } from '../database/testing/database.service.mock';
import type { TtsBatchPregenWorkerTask } from '../worker-dispatch/worker-task.interface';

// ---------------------------------------------------------------------------
// Module-level mocks
// ---------------------------------------------------------------------------

// Mock S3Client so the constructor does not create a real AWS client.
const mockS3Send = jest.fn();
jest.mock('@aws-sdk/client-s3', () => ({
  S3Client: jest.fn().mockImplementation(() => ({ send: mockS3Send })),
  HeadObjectCommand: jest.fn().mockImplementation((params) => params),
  GetObjectCommand: jest.fn().mockImplementation((params) => params),
}));

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createMockTtsService() {
  return {
    synthesize: jest.fn().mockResolvedValue(Buffer.alloc(64)),
    cacheKey: jest.fn((...args: string[]) => `ck_${args.join('_')}`),
  };
}

function createMockEnumService() {
  return {
    enumerate: jest.fn().mockReturnValue([]),
  };
}

function createMockWorkerDispatch() {
  return {
    dispatchBatchPregen: jest.fn().mockResolvedValue(undefined),
  };
}

/** Create a minimal mock of PlanVoicesRepository for injection. */
function createMockPlanVoicesRepo() {
  return {
    upsertPlanVoice: jest.fn().mockResolvedValue({ id: 'pv-1', status: 'ready' }),
    updateStatus: jest.fn().mockResolvedValue(undefined),
    listByPlan: jest.fn().mockResolvedValue([]),
    hasReadyVoice: jest.fn().mockResolvedValue(false),
    listFailed: jest.fn().mockResolvedValue({ items: [], total: 0 }),
    backfillFromTtsStatus: jest.fn().mockResolvedValue(undefined),
    createBatch: jest.fn().mockResolvedValue([]),
    noop: false,
  } as unknown as jest.Mocked<PlanVoicesRepository>;
}

/**
 * Create a minimal VoiceRepository mock for injection. findBySlug returns a
 * voice whose `id` echoes the input slug so existing test assertions that
 * compare against the slug-style fixture (e.g. `voice-uuid-regen`) still pass
 * after writePlanVoiceStatus resolves slug → UUID.
 */
function createMockVoiceRepo() {
  return {
    noop: false,
    listPublished: jest.fn().mockResolvedValue([]),
    listAll: jest.fn().mockResolvedValue({ rows: [], total: 0 }),
    findById: jest.fn().mockResolvedValue(null),
    findBySlug: jest.fn().mockImplementation(async (slug: string) => ({
      id: slug,
      slug,
      displayName: slug,
      locale: 'enUS',
      provider: 'gemini',
      sampleUrl: null,
      isPublished: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    })),
    create: jest.fn().mockResolvedValue(null),
    update: jest.fn().mockResolvedValue(null),
  } as unknown as jest.Mocked<VoiceRepository>;
}

/** Build a TtsPair-like object for enumeration results. */
function makePair(overrides: Partial<{
  text: string; voiceId: string; locale: string;
  provider: string; speechRate: string; cacheKey: string;
}> = {}) {
  return {
    text: overrides.text ?? 'hello',
    voiceId: overrides.voiceId ?? 'aoede',
    locale: overrides.locale ?? 'enUS',
    provider: overrides.provider ?? 'gemini',
    speechRate: overrides.speechRate ?? '1.0',
    cacheKey: overrides.cacheKey ?? `ck_${Math.random().toString(36).slice(2, 10)}`,
  };
}

/** Build a service via the NestJS test module. */
async function buildService({
  usePlanVoicesGate = false,
  mockDb,
  mockTtsService,
  mockEnumService,
  mockWorkerDispatch,
  mockPlanVoicesRepo,
}: {
  usePlanVoicesGate?: boolean;
  mockDb: jest.Mocked<DatabaseService>;
  mockTtsService: ReturnType<typeof createMockTtsService>;
  mockEnumService: ReturnType<typeof createMockEnumService>;
  mockWorkerDispatch: ReturnType<typeof createMockWorkerDispatch>;
  mockPlanVoicesRepo?: jest.Mocked<PlanVoicesRepository> | null;
}) {
  const providers: any[] = [
    TtsBatchPregenService,
    { provide: DatabaseService, useValue: mockDb },
    { provide: TtsService, useValue: mockTtsService },
    { provide: TtsEnumerationService, useValue: mockEnumService },
    { provide: WorkerDispatchService, useValue: mockWorkerDispatch },
    {
      provide: 'APP_CONFIG',
      useValue: {
        awsS3Bucket: 'test-bucket',
        awsRegion: 'us-east-1',
        usePlanVoicesGate,
      },
    },
  ];

  if (mockPlanVoicesRepo !== null) {
    providers.push({ provide: PlanVoicesRepository, useValue: mockPlanVoicesRepo ?? createMockPlanVoicesRepo() });
  }

  // VoiceRepository is required to resolve voice slugs → UUIDs before writing
  // to plan_voices.voice_id. Always inject the mock; tests use slug fixtures.
  providers.push({ provide: VoiceRepository, useValue: createMockVoiceRepo() });

  const module: TestingModule = await Test.createTestingModule({ providers }).compile();
  return module.get<TtsBatchPregenService>(TtsBatchPregenService);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('TtsBatchPregenService', () => {
  let service: TtsBatchPregenService;
  let mockDb: jest.Mocked<DatabaseService>;
  let mockTtsService: ReturnType<typeof createMockTtsService>;
  let mockEnumService: ReturnType<typeof createMockEnumService>;
  let mockWorkerDispatch: ReturnType<typeof createMockWorkerDispatch>;

  beforeEach(async () => {
    // Reset call counts on module-level mocks (S3).
    // restoreAllMocks in afterEach only restores spies, not factory mocks.
    jest.clearAllMocks();

    // Ensure the S3 client is instantiated by providing a bucket.
    process.env.AWS_S3_BUCKET = 'test-bucket';
    process.env.AWS_REGION = 'us-east-1';

    mockDb = createMockDatabaseService();
    mockTtsService = createMockTtsService();
    mockEnumService = createMockEnumService();
    mockWorkerDispatch = createMockWorkerDispatch();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TtsBatchPregenService,
        { provide: DatabaseService, useValue: mockDb },
        { provide: TtsService, useValue: mockTtsService },
        { provide: TtsEnumerationService, useValue: mockEnumService },
        { provide: WorkerDispatchService, useValue: mockWorkerDispatch },
      ],
    }).compile();

    service = module.get<TtsBatchPregenService>(TtsBatchPregenService);

    // Default: S3 HeadObject throws (i.e. key does not exist / not cached).
    mockS3Send.mockRejectedValue(new Error('NotFound'));
  });

  afterEach(() => {
    jest.restoreAllMocks();
    mockS3Send.mockReset();
    delete process.env.AWS_S3_BUCKET;
    delete process.env.AWS_REGION;
  });

  // =========================================================================
  // startBatchPregen
  // =========================================================================

  describe('startBatchPregen', () => {
    const planId = 'plan-1';
    const planJson = '{"steps":[]}';
    const voiceId = 'aoede';
    const locale = 'enUS';
    const provider = 'gemini';
    const speechRate = '1.0';

    it('marks completed and creates no jobs when all S3 keys are cached', async () => {
      const pairs = [makePair({ cacheKey: 'cached1' }), makePair({ cacheKey: 'cached2' })];
      mockEnumService.enumerate.mockReturnValue(pairs);

      // S3 HeadObject succeeds for all keys = all cached.
      mockS3Send.mockResolvedValue({});

      await service.startBatchPregen(planId, planJson, voiceId, locale, provider, speechRate);

      expect(mockDb.setTtsStatus).toHaveBeenCalledWith(planId, 'completed', 0, 0);
      expect(mockDb.createTtsJobs).not.toHaveBeenCalled();
      expect(mockWorkerDispatch.dispatchBatchPregen).not.toHaveBeenCalled();
    });

    it('creates jobs only for uncached pairs', async () => {
      const cachedPair = makePair({ cacheKey: 'cached1' });
      const uncachedPair = makePair({ cacheKey: 'uncached1' });
      mockEnumService.enumerate.mockReturnValue([cachedPair, uncachedPair]);

      // First call succeeds (cached), second throws (not cached).
      mockS3Send
        .mockResolvedValueOnce({})      // cached1 exists
        .mockRejectedValueOnce(new Error('NotFound')); // uncached1 does not exist

      mockDb.createTtsJobs.mockResolvedValue([
        { id: 'job-1', cacheKey: 'uncached1' },
      ] as any);

      await service.startBatchPregen(planId, planJson, voiceId, locale, provider, speechRate);

      expect(mockDb.createTtsJobs).toHaveBeenCalledWith([
        expect.objectContaining({ cacheKey: 'uncached1', planId }),
      ]);
      expect(mockDb.setTtsStatus).toHaveBeenCalledWith(planId, 'processing', 1, 0);
    });

    it('calls dispatchBatchPregen with correct groups', async () => {
      const pair1 = makePair({ cacheKey: 'ck1', voiceId: 'aoede', locale: 'enUS', provider: 'gemini' });
      const pair2 = makePair({ cacheKey: 'ck2', voiceId: 'aoede', locale: 'enUS', provider: 'gemini' });
      mockEnumService.enumerate.mockReturnValue([pair1, pair2]);

      // None cached.
      mockS3Send.mockRejectedValue(new Error('NotFound'));

      mockDb.createTtsJobs.mockResolvedValue([
        { id: 'job-1', cacheKey: 'ck1' },
        { id: 'job-2', cacheKey: 'ck2' },
      ] as any);

      await service.startBatchPregen(planId, planJson, voiceId, locale, provider, speechRate);

      expect(mockWorkerDispatch.dispatchBatchPregen).toHaveBeenCalledTimes(1);
      const call = mockWorkerDispatch.dispatchBatchPregen.mock.calls[0];
      const task: TtsBatchPregenWorkerTask = call[0];
      expect(task.planId).toBe(planId);
      expect(task.groups.length).toBeGreaterThanOrEqual(1);
      expect(task.groups[0].jobIds).toContain('job-1');
      expect(task.groups[0].jobIds).toContain('job-2');
    });

    it('handles empty pairs list (no TTS pairs)', async () => {
      mockEnumService.enumerate.mockReturnValue([]);

      await service.startBatchPregen(planId, planJson, voiceId, locale, provider, speechRate);

      expect(mockDb.setTtsStatus).toHaveBeenCalledWith(planId, 'completed', 0, 0);
      expect(mockDb.createTtsJobs).not.toHaveBeenCalled();
    });

    it('recovers stale plans before starting', async () => {
      // Set up a stale status so recoverIfStale is triggered.
      const staleDate = new Date(Date.now() - 20 * 60 * 1000); // 20 min ago
      mockDb.getPlanTtsStatus.mockResolvedValue({
        status: 'processing',
        total: 5,
        completed: 2,
        failed: 0,
        ready: false,
        updatedAt: staleDate,
      });

      mockEnumService.enumerate.mockReturnValue([]);

      await service.startBatchPregen(planId, planJson, voiceId, locale, provider, speechRate);

      expect(mockDb.failStalePendingJobs).toHaveBeenCalledWith(planId);
      expect(mockDb.finalizePlanTtsStatus).toHaveBeenCalledWith(planId);
    });
  });

  // =========================================================================
  // processTask
  // =========================================================================

  describe('processTask', () => {
    it('processes groups sequentially', async () => {
      const callOrder: string[] = [];

      const job1 = { id: 'j1', text: 'step 1', cacheKey: 'ck1', voiceId: 'aoede', locale: 'enUS', provider: 'kokoro', speechRate: '1.0' };
      const job2 = { id: 'j2', text: 'step 2', cacheKey: 'ck2', voiceId: 'puck', locale: 'enUS', provider: 'kokoro', speechRate: '1.0' };

      mockDb.getTtsJobsByIds.mockImplementation(async (ids: string[]) => {
        callOrder.push(`getTtsJobsByIds:${ids.join(',')}`);
        if (ids.includes('j1')) return [job1] as any;
        if (ids.includes('j2')) return [job2] as any;
        return [];
      });

      // S3 not cached for individual processing.
      mockS3Send.mockRejectedValue(new Error('NotFound'));

      mockDb.getPlanTtsStatus.mockResolvedValue({
        status: 'processing', total: 2, completed: 2, failed: 0, ready: false, updatedAt: new Date(),
      });

      const task: TtsBatchPregenWorkerTask = {
        task: 'ttsBatchPregen',
        planId: 'plan-1',
        groups: [
          { voiceId: 'aoede', locale: 'enUS', provider: 'kokoro', jobIds: ['j1'] },
          { voiceId: 'puck', locale: 'enUS', provider: 'kokoro', jobIds: ['j2'] },
        ],
      };

      await service.processTask(task);

      // Both groups should be fetched.
      expect(callOrder).toEqual([
        'getTtsJobsByIds:j1',
        'getTtsJobsByIds:j2',
      ]);
    });

    it('finalizes plan status when all jobs are done', async () => {
      mockDb.getTtsJobsByIds.mockResolvedValue([]);
      mockDb.getPlanTtsStatus.mockResolvedValue({
        status: 'processing', total: 5, completed: 3, failed: 2, ready: false, updatedAt: new Date(),
      });

      const task: TtsBatchPregenWorkerTask = {
        task: 'ttsBatchPregen',
        planId: 'plan-1',
        groups: [],
      };

      await service.processTask(task);

      expect(mockDb.finalizePlanTtsStatus).toHaveBeenCalledWith('plan-1');
    });
  });

  // =========================================================================
  // processGroupIndividual (the only group-processing path)
  // =========================================================================

  describe('processGroupIndividual', () => {
    it('marks jobs completed on successful per-step synthesis', async () => {
      const jobs = [
        { id: 'j1', text: 'step 1', cacheKey: 'ck1', voiceId: 'aoede', locale: 'enUS', provider: 'gemini', speechRate: '1.0' },
        { id: 'j2', text: 'step 2', cacheKey: 'ck2', voiceId: 'aoede', locale: 'enUS', provider: 'gemini', speechRate: '1.0' },
      ];
      mockDb.getTtsJobsByIds.mockResolvedValue(jobs as any);

      mockS3Send.mockRejectedValue(new Error('NotFound'));

      mockDb.getPlanTtsStatus.mockResolvedValue({
        status: 'processing', total: 2, completed: 2, failed: 0, ready: false, updatedAt: new Date(),
      });

      const task: TtsBatchPregenWorkerTask = {
        task: 'ttsBatchPregen',
        planId: 'plan-1',
        groups: [{ voiceId: 'aoede', locale: 'enUS', provider: 'gemini', jobIds: ['j1', 'j2'] }],
      };

      await service.processTask(task);

      // One synthesize call per job.
      expect(mockTtsService.synthesize).toHaveBeenCalledTimes(2);
      expect(mockTtsService.synthesize).toHaveBeenCalledWith('step 1', 'aoede', 'enUS', 'gemini', '1.0');
      expect(mockTtsService.synthesize).toHaveBeenCalledWith('step 2', 'aoede', 'enUS', 'gemini', '1.0');

      expect(mockDb.updateTtsJobStatus).toHaveBeenCalledWith('j1', 'completed', 'tts/ck1.wav');
      expect(mockDb.updateTtsJobStatus).toHaveBeenCalledWith('j2', 'completed', 'tts/ck2.wav');
      expect(mockDb.incrementTtsCompleted).toHaveBeenCalledTimes(2);
    });

    it('marks failed jobs in DB after max attempts', async () => {
      const job = {
        id: 'j1', text: 'hello', cacheKey: 'ck1',
        voiceId: 'aoede', locale: 'enUS', provider: 'kokoro', speechRate: '1.0',
      };
      mockDb.getTtsJobsByIds.mockResolvedValue([job] as any);

      // S3 not cached.
      mockS3Send.mockRejectedValue(new Error('NotFound'));

      // Synthesize always fails.
      mockTtsService.synthesize.mockRejectedValue(new Error('TTS down'));

      mockDb.getPlanTtsStatus.mockResolvedValue({
        status: 'processing', total: 1, completed: 0, failed: 1, ready: false, updatedAt: new Date(),
      });

      const task: TtsBatchPregenWorkerTask = {
        task: 'ttsBatchPregen',
        planId: 'plan-1',
        groups: [{ voiceId: 'aoede', locale: 'enUS', provider: 'kokoro', jobIds: ['j1'] }],
      };

      await service.processTask(task);

      // After 3 attempts, job should be marked as failed.
      expect(mockDb.updateTtsJobStatus).toHaveBeenCalledWith(
        'j1', 'failed', undefined, 'TTS down',
      );
      expect(mockTtsService.synthesize).toHaveBeenCalledTimes(3);
    });

    it('skips already-cached jobs', async () => {
      const job = {
        id: 'j1', text: 'hello', cacheKey: 'ck1',
        voiceId: 'aoede', locale: 'enUS', provider: 'kokoro', speechRate: '1.0',
      };
      mockDb.getTtsJobsByIds.mockResolvedValue([job] as any);

      // S3 HeadObject succeeds → job is cached.
      mockS3Send.mockResolvedValue({});

      mockDb.getPlanTtsStatus.mockResolvedValue({
        status: 'processing', total: 1, completed: 1, failed: 0, ready: false, updatedAt: new Date(),
      });

      const task: TtsBatchPregenWorkerTask = {
        task: 'ttsBatchPregen',
        planId: 'plan-1',
        groups: [{ voiceId: 'aoede', locale: 'enUS', provider: 'kokoro', jobIds: ['j1'] }],
      };

      await service.processTask(task);

      // Should not call synthesize — the job was cached.
      expect(mockTtsService.synthesize).not.toHaveBeenCalled();
      // Should mark as completed via filterAndMarkCached.
      expect(mockDb.updateTtsJobStatus).toHaveBeenCalledWith(
        'j1', 'completed', 'tts/ck1.wav',
      );
      expect(mockDb.incrementTtsCompleted).toHaveBeenCalledWith('plan-1');
    });
  });

  // =========================================================================
  // groupPairsByVoiceAndLocale (private, tested via startBatchPregen)
  // =========================================================================

  describe('groupPairsByVoiceAndLocale', () => {
    it('groups pairs by voice+locale+provider', async () => {
      const pair1 = makePair({ cacheKey: 'ck1', voiceId: 'aoede', locale: 'enUS', provider: 'kokoro' });
      const pair2 = makePair({ cacheKey: 'ck2', voiceId: 'aoede', locale: 'enUS', provider: 'kokoro' });
      const pair3 = makePair({ cacheKey: 'ck3', voiceId: 'puck', locale: 'enUS', provider: 'kokoro' });
      mockEnumService.enumerate.mockReturnValue([pair1, pair2, pair3]);

      mockS3Send.mockRejectedValue(new Error('NotFound'));

      mockDb.createTtsJobs.mockResolvedValue([
        { id: 'j1', cacheKey: 'ck1' },
        { id: 'j2', cacheKey: 'ck2' },
        { id: 'j3', cacheKey: 'ck3' },
      ] as any);

      await service.startBatchPregen('plan-1', '{}', 'aoede', 'enUS', 'kokoro', '1.0');

      const task: TtsBatchPregenWorkerTask = mockWorkerDispatch.dispatchBatchPregen.mock.calls[0][0];

      // Should produce 2 groups: one for aoede/enUS/kokoro and one for puck/enUS/kokoro.
      expect(task.groups.length).toBe(2);
      const aoedeGroup = task.groups.find((g) => g.voiceId === 'aoede');
      const puckGroup = task.groups.find((g) => g.voiceId === 'puck');
      expect(aoedeGroup?.jobIds).toEqual(['j1', 'j2']);
      expect(puckGroup?.jobIds).toEqual(['j3']);
    });

    it('remaps Gemini voices for gemini provider', async () => {
      // af_heart maps to 'aoede' in GEMINI_VOICE_MAP
      const pair = makePair({ cacheKey: 'ck1', voiceId: 'af_heart', locale: 'enUS', provider: 'gemini' });
      mockEnumService.enumerate.mockReturnValue([pair]);

      mockS3Send.mockRejectedValue(new Error('NotFound'));

      mockDb.createTtsJobs.mockResolvedValue([
        { id: 'j1', cacheKey: 'ck1' },
      ] as any);

      await service.startBatchPregen('plan-1', '{}', 'af_heart', 'enUS', 'gemini', '1.0');

      const task: TtsBatchPregenWorkerTask = mockWorkerDispatch.dispatchBatchPregen.mock.calls[0][0];

      // The group voiceId should be the remapped Gemini voice 'aoede', not 'af_heart'.
      expect(task.groups[0].voiceId).toBe('aoede');
    });
  });

  // =========================================================================
  // recoverIfStale (via getStatus)
  // =========================================================================

  describe('recoverIfStale', () => {
    it('fails stale pending jobs', async () => {
      const staleDate = new Date(Date.now() - 20 * 60 * 1000); // 20 min ago
      mockDb.getPlanTtsStatus.mockResolvedValue({
        status: 'pending',
        total: 3,
        completed: 0,
        failed: 0,
        ready: false,
        updatedAt: staleDate,
      });

      await service.getStatus('plan-1');

      expect(mockDb.failStalePendingJobs).toHaveBeenCalledWith('plan-1');
      expect(mockDb.finalizePlanTtsStatus).toHaveBeenCalledWith('plan-1');
    });

    it('does nothing if plan is not stale', async () => {
      const recentDate = new Date(); // just now
      mockDb.getPlanTtsStatus.mockResolvedValue({
        status: 'processing',
        total: 3,
        completed: 1,
        failed: 0,
        ready: false,
        updatedAt: recentDate,
      });

      await service.getStatus('plan-1');

      expect(mockDb.failStalePendingJobs).not.toHaveBeenCalled();
      expect(mockDb.finalizePlanTtsStatus).not.toHaveBeenCalled();
    });

    it('does nothing if plan status is completed', async () => {
      mockDb.getPlanTtsStatus.mockResolvedValue({
        status: 'completed',
        total: 5,
        completed: 5,
        failed: 0,
        ready: true,
        updatedAt: new Date(Date.now() - 30 * 60 * 1000), // old but completed
      });

      await service.getStatus('plan-1');

      expect(mockDb.failStalePendingJobs).not.toHaveBeenCalled();
    });
  });

  // =========================================================================
  // getStatus
  // =========================================================================

  describe('getStatus', () => {
    it('returns current status after recovery check', async () => {
      const expectedStatus = {
        status: 'completed',
        total: 10,
        completed: 10,
        failed: 0,
        ready: true,
        updatedAt: new Date(),
      };
      mockDb.getPlanTtsStatus.mockResolvedValue(expectedStatus);

      const result = await service.getStatus('plan-1');

      expect(result).toEqual(expectedStatus);
      // getPlanTtsStatus called twice: once in recoverIfStale, once for the return value.
      expect(mockDb.getPlanTtsStatus).toHaveBeenCalledTimes(2);
    });
  });
});

// ===========================================================================
// Feature-flag tests: use_plan_voices_gate = false  (dual-write / AC-006)
// ===========================================================================

describe('TtsBatchPregenService — flag=false (dual-write AC-006)', () => {
  let mockDb: jest.Mocked<DatabaseService>;
  let mockTtsService: ReturnType<typeof createMockTtsService>;
  let mockEnumService: ReturnType<typeof createMockEnumService>;
  let mockWorkerDispatch: ReturnType<typeof createMockWorkerDispatch>;
  let mockPlanVoicesRepo: jest.Mocked<PlanVoicesRepository>;
  let service: TtsBatchPregenService;

  beforeEach(async () => {
    jest.clearAllMocks();
    mockS3Send.mockRejectedValue(new Error('NotFound'));

    mockDb = createMockDatabaseService();
    mockTtsService = createMockTtsService();
    mockEnumService = createMockEnumService();
    mockWorkerDispatch = createMockWorkerDispatch();
    mockPlanVoicesRepo = createMockPlanVoicesRepo();

    service = await buildService({
      usePlanVoicesGate: false,
      mockDb,
      mockTtsService,
      mockEnumService,
      mockWorkerDispatch,
      mockPlanVoicesRepo,
    });
  });

  afterEach(() => {
    jest.restoreAllMocks();
    mockS3Send.mockReset();
  });

  it('writes both tts_status and plan_voices when no pairs exist', async () => {
    mockEnumService.enumerate.mockReturnValue([]);

    await service.startBatchPregen('plan-1', '{}', 'voice-uuid-1', 'enUS', 'gemini', '1.00');

    // Legacy write
    expect(mockDb.setTtsStatus).toHaveBeenCalledWith('plan-1', 'completed', 0, 0);
    // New plan_voices write
    expect(mockPlanVoicesRepo.upsertPlanVoice).toHaveBeenCalledWith(
      expect.objectContaining({ planId: 'plan-1', voiceId: 'voice-uuid-1', locale: 'enUS', status: 'ready' }),
    );
  });

  it('writes both tts_status and plan_voices when all pairs are S3-cached', async () => {
    mockEnumService.enumerate.mockReturnValue([makePair({ cacheKey: 'cached1' })]);
    mockS3Send.mockResolvedValue({}); // all cached

    await service.startBatchPregen('plan-1', '{}', 'voice-uuid-1', 'enUS', 'gemini', '1.00');

    // Legacy write
    expect(mockDb.setTtsStatus).toHaveBeenCalledWith('plan-1', 'completed', 0, 0);
    // New plan_voices write → 'ready' because all steps have S3 audio
    expect(mockPlanVoicesRepo.upsertPlanVoice).toHaveBeenCalledWith(
      expect.objectContaining({ planId: 'plan-1', status: 'ready' }),
    );
  });

  it('writes both tts_status=processing and plan_voices=processing when jobs created', async () => {
    mockEnumService.enumerate.mockReturnValue([makePair({ cacheKey: 'ck1' })]);
    mockS3Send.mockRejectedValue(new Error('NotFound')); // not cached
    mockDb.createTtsJobs.mockResolvedValue([{ id: 'j1', cacheKey: 'ck1' }] as any);

    await service.startBatchPregen('plan-1', '{}', 'voice-uuid-1', 'enUS', 'gemini', '1.00');

    expect(mockDb.setTtsStatus).toHaveBeenCalledWith('plan-1', 'processing', 1, 0);
    expect(mockPlanVoicesRepo.upsertPlanVoice).toHaveBeenCalledWith(
      expect.objectContaining({ planId: 'plan-1', status: 'processing' }),
    );
  });

  it('calls incrementTtsCompleted (legacy counter) when flag=false', async () => {
    const job = {
      id: 'j1', text: 'hello', cacheKey: 'ck1',
      voiceId: 'voice-uuid-1', locale: 'enUS', provider: 'gemini', speechRate: '1.0',
    };
    mockDb.getTtsJobsByIds.mockResolvedValue([job] as any);
    mockS3Send.mockRejectedValue(new Error('NotFound'));
    mockDb.getPlanTtsStatus.mockResolvedValue({
      status: 'processing', total: 1, completed: 1, failed: 0, ready: false, updatedAt: new Date(),
    });

    const task: TtsBatchPregenWorkerTask = {
      task: 'ttsBatchPregen',
      planId: 'plan-1',
      groups: [{ voiceId: 'voice-uuid-1', locale: 'enUS', provider: 'gemini', jobIds: ['j1'] }],
    };

    await service.processTask(task);

    expect(mockDb.incrementTtsCompleted).toHaveBeenCalledWith('plan-1');
  });

  it('writes plan_voices=ready after successful group processing', async () => {
    const job = {
      id: 'j1', text: 'hello', cacheKey: 'ck1',
      voiceId: 'voice-uuid-1', locale: 'enUS', provider: 'gemini', speechRate: '1.0',
    };
    mockDb.getTtsJobsByIds.mockResolvedValue([job] as any);
    mockS3Send.mockRejectedValue(new Error('NotFound'));
    mockDb.getPlanTtsStatus.mockResolvedValue({
      status: 'processing', total: 1, completed: 1, failed: 0, ready: false, updatedAt: new Date(),
    });

    const task: TtsBatchPregenWorkerTask = {
      task: 'ttsBatchPregen',
      planId: 'plan-1',
      groups: [{ voiceId: 'voice-uuid-1', locale: 'enUS', provider: 'gemini', jobIds: ['j1'] }],
    };

    await service.processTask(task);

    expect(mockPlanVoicesRepo.upsertPlanVoice).toHaveBeenCalledWith(
      expect.objectContaining({ planId: 'plan-1', voiceId: 'voice-uuid-1', locale: 'enUS', status: 'ready' }),
    );
  });

  it('writes plan_voices=failed after failed group processing', async () => {
    const job = {
      id: 'j1', text: 'fail me', cacheKey: 'ck1',
      voiceId: 'voice-uuid-1', locale: 'enUS', provider: 'gemini', speechRate: '1.0',
    };
    mockDb.getTtsJobsByIds.mockResolvedValue([job] as any);
    mockS3Send.mockRejectedValue(new Error('NotFound'));
    mockTtsService.synthesize.mockRejectedValue(new Error('TTS down'));
    mockDb.getPlanTtsStatus.mockResolvedValue({
      status: 'processing', total: 1, completed: 0, failed: 1, ready: false, updatedAt: new Date(),
    });

    const task: TtsBatchPregenWorkerTask = {
      task: 'ttsBatchPregen',
      planId: 'plan-1',
      groups: [{ voiceId: 'voice-uuid-1', locale: 'enUS', provider: 'gemini', jobIds: ['j1'] }],
    };

    await service.processTask(task);

    expect(mockPlanVoicesRepo.upsertPlanVoice).toHaveBeenCalledWith(
      expect.objectContaining({ planId: 'plan-1', voiceId: 'voice-uuid-1', locale: 'enUS', status: 'failed' }),
    );
  });

  it('calls finalizePlanTtsStatus (legacy finalization) when flag=false', async () => {
    mockDb.getTtsJobsByIds.mockResolvedValue([]);
    mockDb.getPlanTtsStatus.mockResolvedValue({
      status: 'processing', total: 2, completed: 1, failed: 1, ready: false, updatedAt: new Date(),
    });

    const task: TtsBatchPregenWorkerTask = {
      task: 'ttsBatchPregen',
      planId: 'plan-1',
      groups: [],
    };

    await service.processTask(task);

    expect(mockDb.finalizePlanTtsStatus).toHaveBeenCalledWith('plan-1');
  });
});

// ===========================================================================
// Feature-flag tests: use_plan_voices_gate = true  (single-write / AC-007)
// ===========================================================================

describe('TtsBatchPregenService — flag=true (single-write AC-007)', () => {
  let mockDb: jest.Mocked<DatabaseService>;
  let mockTtsService: ReturnType<typeof createMockTtsService>;
  let mockEnumService: ReturnType<typeof createMockEnumService>;
  let mockWorkerDispatch: ReturnType<typeof createMockWorkerDispatch>;
  let mockPlanVoicesRepo: jest.Mocked<PlanVoicesRepository>;
  let service: TtsBatchPregenService;

  beforeEach(async () => {
    jest.clearAllMocks();
    mockS3Send.mockRejectedValue(new Error('NotFound'));

    mockDb = createMockDatabaseService();
    mockTtsService = createMockTtsService();
    mockEnumService = createMockEnumService();
    mockWorkerDispatch = createMockWorkerDispatch();
    mockPlanVoicesRepo = createMockPlanVoicesRepo();

    service = await buildService({
      usePlanVoicesGate: true,
      mockDb,
      mockTtsService,
      mockEnumService,
      mockWorkerDispatch,
      mockPlanVoicesRepo,
    });
  });

  afterEach(() => {
    jest.restoreAllMocks();
    mockS3Send.mockReset();
  });

  it('does NOT write tts_status when no pairs exist (flag=true)', async () => {
    mockEnumService.enumerate.mockReturnValue([]);

    await service.startBatchPregen('plan-1', '{}', 'voice-uuid-1', 'enUS', 'gemini', '1.00');

    // Legacy write must NOT happen when gate is on.
    expect(mockDb.setTtsStatus).not.toHaveBeenCalled();
    // plan_voices MUST be written.
    expect(mockPlanVoicesRepo.upsertPlanVoice).toHaveBeenCalledWith(
      expect.objectContaining({ planId: 'plan-1', voiceId: 'voice-uuid-1', locale: 'enUS', status: 'ready' }),
    );
  });

  it('does NOT write tts_status when all pairs are S3-cached (flag=true)', async () => {
    mockEnumService.enumerate.mockReturnValue([makePair({ cacheKey: 'ck1' })]);
    mockS3Send.mockResolvedValue({}); // all cached

    await service.startBatchPregen('plan-1', '{}', 'voice-uuid-1', 'enUS', 'gemini', '1.00');

    expect(mockDb.setTtsStatus).not.toHaveBeenCalled();
    expect(mockPlanVoicesRepo.upsertPlanVoice).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'ready' }),
    );
  });

  it('does NOT write tts_status=processing when jobs created (flag=true)', async () => {
    mockEnumService.enumerate.mockReturnValue([makePair({ cacheKey: 'ck1' })]);
    mockS3Send.mockRejectedValue(new Error('NotFound'));
    mockDb.createTtsJobs.mockResolvedValue([{ id: 'j1', cacheKey: 'ck1' }] as any);

    await service.startBatchPregen('plan-1', '{}', 'voice-uuid-1', 'enUS', 'gemini', '1.00');

    expect(mockDb.setTtsStatus).not.toHaveBeenCalled();
    expect(mockPlanVoicesRepo.upsertPlanVoice).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'processing' }),
    );
  });

  it('does NOT call incrementTtsCompleted when flag=true', async () => {
    const job = {
      id: 'j1', text: 'hello', cacheKey: 'ck1',
      voiceId: 'voice-uuid-1', locale: 'enUS', provider: 'gemini', speechRate: '1.0',
    };
    mockDb.getTtsJobsByIds.mockResolvedValue([job] as any);
    mockS3Send.mockRejectedValue(new Error('NotFound'));
    mockDb.getPlanTtsStatus.mockResolvedValue({
      status: 'processing', total: 1, completed: 1, failed: 0, ready: false, updatedAt: new Date(),
    });

    const task: TtsBatchPregenWorkerTask = {
      task: 'ttsBatchPregen',
      planId: 'plan-1',
      groups: [{ voiceId: 'voice-uuid-1', locale: 'enUS', provider: 'gemini', jobIds: ['j1'] }],
    };

    await service.processTask(task);

    // incrementTtsCompleted is a legacy plans.tts_completed update — skip when flag=true.
    expect(mockDb.incrementTtsCompleted).not.toHaveBeenCalled();
  });

  it('does NOT call finalizePlanTtsStatus when flag=true', async () => {
    mockDb.getTtsJobsByIds.mockResolvedValue([]);
    mockDb.getPlanTtsStatus.mockResolvedValue({
      status: 'processing', total: 2, completed: 1, failed: 1, ready: false, updatedAt: new Date(),
    });

    const task: TtsBatchPregenWorkerTask = {
      task: 'ttsBatchPregen',
      planId: 'plan-1',
      groups: [],
    };

    await service.processTask(task);

    expect(mockDb.finalizePlanTtsStatus).not.toHaveBeenCalled();
  });

  it('still calls updateTtsJobStatus (job-level) even when flag=true', async () => {
    const job = {
      id: 'j1', text: 'hello', cacheKey: 'ck1',
      voiceId: 'voice-uuid-1', locale: 'enUS', provider: 'gemini', speechRate: '1.0',
    };
    mockDb.getTtsJobsByIds.mockResolvedValue([job] as any);
    mockS3Send.mockRejectedValue(new Error('NotFound'));
    mockDb.getPlanTtsStatus.mockResolvedValue({
      status: 'processing', total: 1, completed: 1, failed: 0, ready: false, updatedAt: new Date(),
    });

    const task: TtsBatchPregenWorkerTask = {
      task: 'ttsBatchPregen',
      planId: 'plan-1',
      groups: [{ voiceId: 'voice-uuid-1', locale: 'enUS', provider: 'gemini', jobIds: ['j1'] }],
    };

    await service.processTask(task);

    // tts_jobs row must always be updated regardless of flag.
    expect(mockDb.updateTtsJobStatus).toHaveBeenCalledWith('j1', 'completed', 'tts/ck1.wav');
  });

  it('writes plan_voices=ready after successful synthesis (flag=true)', async () => {
    const job = {
      id: 'j1', text: 'hello', cacheKey: 'ck1',
      voiceId: 'voice-uuid-1', locale: 'enUS', provider: 'gemini', speechRate: '1.0',
    };
    mockDb.getTtsJobsByIds.mockResolvedValue([job] as any);
    mockS3Send.mockRejectedValue(new Error('NotFound'));
    mockDb.getPlanTtsStatus.mockResolvedValue({
      status: 'processing', total: 1, completed: 1, failed: 0, ready: false, updatedAt: new Date(),
    });

    const task: TtsBatchPregenWorkerTask = {
      task: 'ttsBatchPregen',
      planId: 'plan-1',
      groups: [{ voiceId: 'voice-uuid-1', locale: 'enUS', provider: 'gemini', jobIds: ['j1'] }],
    };

    await service.processTask(task);

    expect(mockPlanVoicesRepo.upsertPlanVoice).toHaveBeenCalledWith(
      expect.objectContaining({ planId: 'plan-1', voiceId: 'voice-uuid-1', locale: 'enUS', status: 'ready' }),
    );
  });

  it('writes plan_voices=ready when all jobs were pre-cached (flag=true)', async () => {
    const job = {
      id: 'j1', text: 'hello', cacheKey: 'ck1',
      voiceId: 'voice-uuid-1', locale: 'enUS', provider: 'gemini', speechRate: '1.0',
    };
    mockDb.getTtsJobsByIds.mockResolvedValue([job] as any);
    // S3 cached → filterAndMarkCached returns []
    mockS3Send.mockResolvedValue({});
    mockDb.getPlanTtsStatus.mockResolvedValue({
      status: 'processing', total: 1, completed: 1, failed: 0, ready: false, updatedAt: new Date(),
    });

    const task: TtsBatchPregenWorkerTask = {
      task: 'ttsBatchPregen',
      planId: 'plan-1',
      groups: [{ voiceId: 'voice-uuid-1', locale: 'enUS', provider: 'gemini', jobIds: ['j1'] }],
    };

    await service.processTask(task);

    // Even though all jobs were cached, plan_voices must still be updated.
    expect(mockPlanVoicesRepo.upsertPlanVoice).toHaveBeenCalledWith(
      expect.objectContaining({ planId: 'plan-1', voiceId: 'voice-uuid-1', locale: 'enUS', status: 'ready' }),
    );
    // incrementTtsCompleted NOT called (flag=true)
    expect(mockDb.incrementTtsCompleted).not.toHaveBeenCalled();
  });

  it('writes plan_voices=failed after synthesis failure (flag=true)', async () => {
    const job = {
      id: 'j1', text: 'fail', cacheKey: 'ck1',
      voiceId: 'voice-uuid-1', locale: 'enUS', provider: 'gemini', speechRate: '1.0',
    };
    mockDb.getTtsJobsByIds.mockResolvedValue([job] as any);
    mockS3Send.mockRejectedValue(new Error('NotFound'));
    mockTtsService.synthesize.mockRejectedValue(new Error('TTS down'));
    mockDb.getPlanTtsStatus.mockResolvedValue({
      status: 'processing', total: 1, completed: 0, failed: 1, ready: false, updatedAt: new Date(),
    });

    const task: TtsBatchPregenWorkerTask = {
      task: 'ttsBatchPregen',
      planId: 'plan-1',
      groups: [{ voiceId: 'voice-uuid-1', locale: 'enUS', provider: 'gemini', jobIds: ['j1'] }],
    };

    await service.processTask(task);

    expect(mockPlanVoicesRepo.upsertPlanVoice).toHaveBeenCalledWith(
      expect.objectContaining({ planId: 'plan-1', status: 'failed' }),
    );
    expect(mockDb.finalizePlanTtsStatus).not.toHaveBeenCalled();
  });
});

// ===========================================================================
// regenerateVoice tests
// ===========================================================================

describe('TtsBatchPregenService — regenerateVoice()', () => {
  let mockDb: jest.Mocked<DatabaseService>;
  let mockTtsService: ReturnType<typeof createMockTtsService>;
  let mockEnumService: ReturnType<typeof createMockEnumService>;
  let mockWorkerDispatch: ReturnType<typeof createMockWorkerDispatch>;
  let mockPlanVoicesRepo: jest.Mocked<PlanVoicesRepository>;
  let service: TtsBatchPregenService;

  const planId = 'plan-regen-1';
  const voiceId = 'voice-uuid-regen';
  const locale = 'enUS';
  const planJson = '{"steps":[{"type":"say","text":"hello"}]}';
  const provider = 'gemini';
  const speechRate = '1.00';

  beforeEach(async () => {
    jest.clearAllMocks();
    mockS3Send.mockRejectedValue(new Error('NotFound'));

    mockDb = createMockDatabaseService();
    mockTtsService = createMockTtsService();
    mockEnumService = createMockEnumService();
    mockWorkerDispatch = createMockWorkerDispatch();
    mockPlanVoicesRepo = createMockPlanVoicesRepo();

    service = await buildService({
      usePlanVoicesGate: true,
      mockDb,
      mockTtsService,
      mockEnumService,
      mockWorkerDispatch,
      mockPlanVoicesRepo,
    });
  });

  afterEach(() => {
    jest.restoreAllMocks();
    mockS3Send.mockReset();
  });

  it('upserts plan_voices row with status=pending before queuing TTS', async () => {
    mockEnumService.enumerate.mockReturnValue([]);

    await service.regenerateVoice(planId, voiceId, locale, planJson, provider, speechRate);

    // The FIRST upsertPlanVoice call must be 'pending' (pre-queue reset).
    expect(mockPlanVoicesRepo.upsertPlanVoice).toHaveBeenCalledWith(
      expect.objectContaining({ planId, voiceId, locale, status: 'pending' }),
    );
    // The pending upsert must happen before startBatchPregen dispatches.
    const firstCall = mockPlanVoicesRepo.upsertPlanVoice.mock.calls[0][0];
    expect(firstCall.status).toBe('pending');
  });

  it('calls startBatchPregen after setting plan_voices=pending', async () => {
    mockEnumService.enumerate.mockReturnValue([]);

    await service.regenerateVoice(planId, voiceId, locale, planJson, provider, speechRate);

    // enumerate() is called inside startBatchPregen — verifies it was invoked.
    expect(mockEnumService.enumerate).toHaveBeenCalledWith(planJson, voiceId, locale, provider, speechRate);
  });

  it('queues TTS worker dispatch for non-empty pairs', async () => {
    const pair = makePair({ cacheKey: 'regen-ck1', voiceId, locale, provider });
    mockEnumService.enumerate.mockReturnValue([pair]);
    mockS3Send.mockRejectedValue(new Error('NotFound'));
    mockDb.createTtsJobs.mockResolvedValue([{ id: 'j-regen-1', cacheKey: 'regen-ck1' }] as any);

    await service.regenerateVoice(planId, voiceId, locale, planJson, provider, speechRate);

    expect(mockWorkerDispatch.dispatchBatchPregen).toHaveBeenCalledTimes(1);
    const task: TtsBatchPregenWorkerTask = mockWorkerDispatch.dispatchBatchPregen.mock.calls[0][0];
    expect(task.planId).toBe(planId);
  });

  it('does nothing when PlanVoicesRepository is not injected', async () => {
    // Build service without planVoicesRepo (null → not provided).
    const serviceNoRepo = await buildService({
      usePlanVoicesGate: true,
      mockDb,
      mockTtsService,
      mockEnumService,
      mockWorkerDispatch,
      mockPlanVoicesRepo: null,
    });

    // Should return silently without throwing.
    await expect(
      serviceNoRepo.regenerateVoice(planId, voiceId, locale, planJson, provider, speechRate),
    ).resolves.toBeUndefined();

    // No DB calls from regenerateVoice.
    expect(mockPlanVoicesRepo.upsertPlanVoice).not.toHaveBeenCalled();
    expect(mockWorkerDispatch.dispatchBatchPregen).not.toHaveBeenCalled();
  });

  it('uses default speechRate of 1.0 when omitted', async () => {
    mockEnumService.enumerate.mockReturnValue([]);

    // Call without speechRate (uses default '1.0')
    await service.regenerateVoice(planId, voiceId, locale, planJson, provider);

    expect(mockEnumService.enumerate).toHaveBeenCalledWith(
      planJson, voiceId, locale, provider, '1.0',
    );
  });
});

// ===========================================================================
// PlanVoicesRepository not injected — graceful degradation
// ===========================================================================

describe('TtsBatchPregenService — no PlanVoicesRepository (legacy mode)', () => {
  let mockDb: jest.Mocked<DatabaseService>;
  let mockEnumService: ReturnType<typeof createMockEnumService>;
  let service: TtsBatchPregenService;

  beforeEach(async () => {
    jest.clearAllMocks();
    mockS3Send.mockRejectedValue(new Error('NotFound'));

    mockDb = createMockDatabaseService();
    mockEnumService = createMockEnumService();

    service = await buildService({
      usePlanVoicesGate: false,
      mockDb,
      mockTtsService: createMockTtsService(),
      mockEnumService,
      mockWorkerDispatch: createMockWorkerDispatch(),
      mockPlanVoicesRepo: null,  // not injected
    });
  });

  afterEach(() => {
    jest.restoreAllMocks();
    mockS3Send.mockReset();
  });

  it('still writes tts_status when plan_voices repo absent', async () => {
    mockEnumService.enumerate.mockReturnValue([]);

    await service.startBatchPregen('plan-1', '{}', 'aoede', 'enUS', 'gemini', '1.00');

    expect(mockDb.setTtsStatus).toHaveBeenCalledWith('plan-1', 'completed', 0, 0);
  });
});
