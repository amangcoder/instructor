import { Test, TestingModule } from '@nestjs/testing';
import { TtsBatchPregenService, chunkJobsForGemini } from './tts-batch-pregen.service';
import { DatabaseService } from '../database/database.service';
import { TtsService } from './tts.service';
import { TtsEnumerationService } from './tts-enumeration.service';
import { WorkerDispatchService } from '../worker-dispatch/worker-dispatch.service';
import { TtsAlignmentService } from './tts-alignment.service';
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
}));

// Mock pcm-splitter: returns equal-sized buffers by default.
const splitEvenly = (pcm: Buffer, count: number): Buffer[] => {
  const size = Math.floor(pcm.length / count);
  const segments: Buffer[] = [];
  for (let i = 0; i < count; i++) {
    const start = i * size;
    const end = i === count - 1 ? pcm.length : (i + 1) * size;
    segments.push(pcm.subarray(start, end));
  }
  return segments;
};
jest.mock('./pcm-splitter', () => ({
  splitPcmOnSilence: jest.fn((pcm: Buffer, count: number) => splitEvenly(pcm, count)),
  splitPcmAtBoundaries: jest.fn((pcm: Buffer, boundaries: Array<{ startMs: number; endMs: number }>) =>
    splitEvenly(pcm, boundaries.length),
  ),
}));

// Mock wav-utils: prepends a 44-byte header to the PCM buffer.
jest.mock('./wav-utils', () => ({
  buildWav: jest.fn((pcm: Buffer) => Buffer.concat([Buffer.alloc(44), pcm])),
}));

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createMockTtsService() {
  return {
    synthesize: jest.fn().mockResolvedValue(Buffer.alloc(64)),
    cacheKey: jest.fn((...args: string[]) => `ck_${args.join('_')}`),
    synthesizeGeminiRaw: jest.fn().mockResolvedValue(Buffer.alloc(200)),
    writeToCacheByKey: jest.fn().mockResolvedValue(undefined),
    writeRawToS3: jest.fn().mockResolvedValue(undefined),
    geminiTtsRequestBody: jest.fn().mockReturnValue({ contents: [] }),
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

function createMockAlignmentService() {
  return {
    align: jest.fn().mockResolvedValue(undefined),
  };
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('TtsBatchPregenService', () => {
  let service: TtsBatchPregenService;
  let mockDb: jest.Mocked<DatabaseService>;
  let mockTtsService: ReturnType<typeof createMockTtsService>;
  let mockEnumService: ReturnType<typeof createMockEnumService>;
  let mockWorkerDispatch: ReturnType<typeof createMockWorkerDispatch>;
  let mockAlignmentService: ReturnType<typeof createMockAlignmentService>;

  beforeEach(async () => {
    // Reset call counts on module-level mocks (pcm-splitter, wav-utils, S3).
    // restoreAllMocks in afterEach only restores spies, not factory mocks.
    jest.clearAllMocks();

    // Ensure the S3 client is instantiated by providing a bucket.
    process.env.AWS_S3_BUCKET = 'test-bucket';
    process.env.AWS_REGION = 'us-east-1';

    mockDb = createMockDatabaseService();
    mockTtsService = createMockTtsService();
    mockEnumService = createMockEnumService();
    mockWorkerDispatch = createMockWorkerDispatch();
    mockAlignmentService = createMockAlignmentService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TtsBatchPregenService,
        { provide: DatabaseService, useValue: mockDb },
        { provide: TtsService, useValue: mockTtsService },
        { provide: TtsEnumerationService, useValue: mockEnumService },
        { provide: WorkerDispatchService, useValue: mockWorkerDispatch },
        { provide: TtsAlignmentService, useValue: mockAlignmentService },
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
  // processGroupIndividual (via processTask with non-gemini provider)
  // =========================================================================

  describe('processGroupIndividual', () => {
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
  // synthesizeBatchGemini
  // =========================================================================

  describe('synthesizeBatchGemini', () => {
    it('skips already-cached pairs', async () => {
      // All pairs cached.
      mockS3Send.mockResolvedValue({});

      const pairs = [
        { text: 'hello', cacheKey: 'ck1' },
        { text: 'world', cacheKey: 'ck2' },
      ];

      await service.synthesizeBatchGemini(pairs, 'aoede', 'enUS');

      expect(mockTtsService.synthesizeGeminiRaw).not.toHaveBeenCalled();
      expect(mockTtsService.writeToCacheByKey).not.toHaveBeenCalled();
    });

    it('calls synthesizeGeminiRaw with combined SSML', async () => {
      // None cached.
      mockS3Send.mockRejectedValue(new Error('NotFound'));

      const rawPcm = Buffer.alloc(200);
      mockTtsService.synthesizeGeminiRaw.mockResolvedValue(rawPcm);

      const pairs = [
        { text: 'step one', cacheKey: 'ck1' },
        { text: 'step two', cacheKey: 'ck2' },
      ];

      await service.synthesizeBatchGemini(pairs, 'aoede', 'enUS');

      expect(mockTtsService.synthesizeGeminiRaw).toHaveBeenCalledTimes(1);
      const ssml = mockTtsService.synthesizeGeminiRaw.mock.calls[0][0] as string;
      expect(ssml).toContain('<speak>');
      expect(ssml).toContain('step one');
      expect(ssml).toContain('<break time="2500ms"/>');
      expect(ssml).toContain('step two');
      // Locale is forwarded so buildPrompt can wrap the SSML in <lang xml:lang="…">.
      expect(mockTtsService.synthesizeGeminiRaw.mock.calls[0][2]).toBe('enUS');
    });

    it('splits PCM and writes individual cache entries', async () => {
      // None cached.
      mockS3Send.mockRejectedValue(new Error('NotFound'));

      const rawPcm = Buffer.alloc(200);
      mockTtsService.synthesizeGeminiRaw.mockResolvedValue(rawPcm);

      const pairs = [
        { text: 'step one', cacheKey: 'ck1' },
        { text: 'step two', cacheKey: 'ck2' },
      ];

      await service.synthesizeBatchGemini(pairs, 'aoede', 'enUS');

      // Should write the combined audio + each individual segment.
      // 1 combined + 2 individual = 3 calls.
      expect(mockTtsService.writeToCacheByKey).toHaveBeenCalledTimes(3);

      // Combined key: first cacheKey + _batch + count.
      expect(mockTtsService.writeToCacheByKey).toHaveBeenCalledWith(
        'ck1_batch2',
        expect.any(Buffer),
      );

      // Individual cache entries.
      expect(mockTtsService.writeToCacheByKey).toHaveBeenCalledWith('ck1', expect.any(Buffer));
      expect(mockTtsService.writeToCacheByKey).toHaveBeenCalledWith('ck2', expect.any(Buffer));
    });

    it('saves the prompt JSON to S3 before synthesizing', async () => {
      mockS3Send.mockRejectedValue(new Error('NotFound'));

      const rawPcm = Buffer.alloc(100);
      mockTtsService.synthesizeGeminiRaw.mockResolvedValue(rawPcm);
      mockTtsService.geminiTtsRequestBody.mockReturnValue({ prompt: 'test' });

      const pairs = [{ text: 'hello', cacheKey: 'ck1' }];

      await service.synthesizeBatchGemini(pairs, 'aoede', 'enUS');

      expect(mockTtsService.writeRawToS3).toHaveBeenCalledWith(
        'tts/ck1_batch1_prompt.json',
        expect.any(Buffer),
        'application/json',
      );
    });

    it('uses forced-alignment boundaries when alignment succeeds', async () => {
      mockS3Send.mockRejectedValue(new Error('NotFound'));
      const rawPcm = Buffer.alloc(200);
      mockTtsService.synthesizeGeminiRaw.mockResolvedValue(rawPcm);

      mockAlignmentService.align.mockResolvedValue({
        boundaries: [
          { startMs: 0, endMs: 1500 },
          { startMs: 1500, endMs: 3000 },
        ],
        durationMs: 3000,
      });

      const { splitPcmAtBoundaries, splitPcmOnSilence } = jest.requireMock('./pcm-splitter');

      await service.synthesizeBatchGemini(
        [
          { text: 'step one', cacheKey: 'ck1' },
          { text: 'step two', cacheKey: 'ck2' },
        ],
        'aoede',
        'enUS',
      );

      expect(mockAlignmentService.align).toHaveBeenCalledWith(
        expect.objectContaining({
          texts: ['step one', 'step two'],
          sampleRate: 24_000,
          language: 'eng',
        }),
      );
      expect(splitPcmAtBoundaries).toHaveBeenCalledTimes(1);
      expect(splitPcmOnSilence).not.toHaveBeenCalled();
    });

    it('falls back to silence splitting when alignment returns undefined', async () => {
      mockS3Send.mockRejectedValue(new Error('NotFound'));
      const rawPcm = Buffer.alloc(200);
      mockTtsService.synthesizeGeminiRaw.mockResolvedValue(rawPcm);

      // Alignment unavailable (e.g. Modal unreachable).
      mockAlignmentService.align.mockResolvedValue(undefined);

      const { splitPcmAtBoundaries, splitPcmOnSilence } = jest.requireMock('./pcm-splitter');

      await service.synthesizeBatchGemini(
        [
          { text: 'step one', cacheKey: 'ck1' },
          { text: 'step two', cacheKey: 'ck2' },
        ],
        'aoede',
        'enUS',
      );

      expect(splitPcmAtBoundaries).not.toHaveBeenCalled();
      expect(splitPcmOnSilence).toHaveBeenCalledTimes(1);
    });

    it('skips alignment for a single-pair batch', async () => {
      mockS3Send.mockRejectedValue(new Error('NotFound'));
      mockTtsService.synthesizeGeminiRaw.mockResolvedValue(Buffer.alloc(80));

      await service.synthesizeBatchGemini(
        [{ text: 'only one', cacheKey: 'ck1' }],
        'aoede',
        'enUS',
      );

      expect(mockAlignmentService.align).not.toHaveBeenCalled();
    });

    it('maps non-English locales to ISO-639-3 for the aligner', async () => {
      mockS3Send.mockRejectedValue(new Error('NotFound'));
      mockTtsService.synthesizeGeminiRaw.mockResolvedValue(Buffer.alloc(120));
      mockAlignmentService.align.mockResolvedValue({
        boundaries: [
          { startMs: 0, endMs: 60 },
          { startMs: 60, endMs: 120 },
        ],
        durationMs: 120,
      });

      await service.synthesizeBatchGemini(
        [
          { text: 'hola', cacheKey: 'ck1' },
          { text: 'mundo', cacheKey: 'ck2' },
        ],
        'aoede',
        'es',
      );

      expect(mockAlignmentService.align).toHaveBeenCalledWith(
        expect.objectContaining({ language: 'spa' }),
      );
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

  // =========================================================================
  // processGroupGemini (via processTask with gemini provider)
  // =========================================================================

  describe('processGroupGemini', () => {
    it('marks all jobs completed on successful batch synthesis', async () => {
      const jobs = [
        { id: 'j1', text: 'step 1', cacheKey: 'ck1' },
        { id: 'j2', text: 'step 2', cacheKey: 'ck2' },
      ];
      mockDb.getTtsJobsByIds.mockResolvedValue(jobs as any);

      // S3 checks in synthesizeBatchGemini — not cached.
      mockS3Send.mockRejectedValue(new Error('NotFound'));

      const rawPcm = Buffer.alloc(200);
      mockTtsService.synthesizeGeminiRaw.mockResolvedValue(rawPcm);

      mockDb.getPlanTtsStatus.mockResolvedValue({
        status: 'processing', total: 2, completed: 2, failed: 0, ready: false, updatedAt: new Date(),
      });

      const task: TtsBatchPregenWorkerTask = {
        task: 'ttsBatchPregen',
        planId: 'plan-1',
        groups: [{ voiceId: 'aoede', locale: 'enUS', provider: 'gemini', jobIds: ['j1', 'j2'] }],
      };

      await service.processTask(task);

      expect(mockDb.updateTtsJobStatus).toHaveBeenCalledWith('j1', 'completed', 'tts/ck1.wav');
      expect(mockDb.updateTtsJobStatus).toHaveBeenCalledWith('j2', 'completed', 'tts/ck2.wav');
      expect(mockDb.incrementTtsCompleted).toHaveBeenCalledTimes(2);
    });

    it('marks all jobs failed after max attempts when synthesis fails', async () => {
      const jobs = [
        { id: 'j1', text: 'step 1', cacheKey: 'ck1' },
        { id: 'j2', text: 'step 2', cacheKey: 'ck2' },
      ];
      mockDb.getTtsJobsByIds.mockResolvedValue(jobs as any);

      // synthesizeBatchGemini will call checkS3Exists first, then synthesizeGeminiRaw.
      mockS3Send.mockRejectedValue(new Error('NotFound'));
      mockTtsService.synthesizeGeminiRaw.mockRejectedValue(new Error('Gemini API error'));

      mockDb.getPlanTtsStatus.mockResolvedValue({
        status: 'processing', total: 2, completed: 0, failed: 2, ready: false, updatedAt: new Date(),
      });

      const task: TtsBatchPregenWorkerTask = {
        task: 'ttsBatchPregen',
        planId: 'plan-1',
        groups: [{ voiceId: 'aoede', locale: 'enUS', provider: 'gemini', jobIds: ['j1', 'j2'] }],
      };

      await service.processTask(task);

      // Should have retried 3 times.
      expect(mockTtsService.synthesizeGeminiRaw).toHaveBeenCalledTimes(3);

      // Both jobs failed.
      expect(mockDb.updateTtsJobStatus).toHaveBeenCalledWith(
        'j1', 'failed', undefined, 'Gemini API error',
      );
      expect(mockDb.updateTtsJobStatus).toHaveBeenCalledWith(
        'j2', 'failed', undefined, 'Gemini API error',
      );
    });

    it('splits a 20-step group into multiple sub-batches and makes one Gemini call per sub-batch', async () => {
      const jobs = Array.from({ length: 20 }, (_, i) => ({
        id: `j${i}`,
        text: `step ${i}`,
        cacheKey: `ck${i}`,
      }));
      mockDb.getTtsJobsByIds.mockResolvedValue(jobs as any);

      mockS3Send.mockRejectedValue(new Error('NotFound'));
      mockTtsService.synthesizeGeminiRaw.mockResolvedValue(Buffer.alloc(200));
      mockAlignmentService.align.mockResolvedValue({
        boundaries: jobs.map((_, i) => ({ startMs: i * 10, endMs: (i + 1) * 10 })),
        durationMs: 200,
      });

      mockDb.getPlanTtsStatus.mockResolvedValue({
        status: 'processing', total: 20, completed: 20, failed: 0, ready: false, updatedAt: new Date(),
      });

      const task: TtsBatchPregenWorkerTask = {
        task: 'ttsBatchPregen',
        planId: 'plan-1',
        groups: [{ voiceId: 'aoede', locale: 'enUS', provider: 'gemini', jobIds: jobs.map((j) => j.id) }],
      };

      await service.processTask(task);

      // 20 jobs / 6 max per sub-batch → 4 sub-batches → 4 Gemini calls.
      expect(mockTtsService.synthesizeGeminiRaw).toHaveBeenCalledTimes(4);
      // All 20 jobs marked completed.
      expect(mockDb.incrementTtsCompleted).toHaveBeenCalledTimes(20);
    });

    it('isolates sub-batch failures: bad sub-batch fails only its jobs', async () => {
      const jobs = Array.from({ length: 12 }, (_, i) => ({
        id: `j${i}`,
        text: `step ${i}`,
        cacheKey: `ck${i}`,
      }));
      mockDb.getTtsJobsByIds.mockResolvedValue(jobs as any);

      mockS3Send.mockRejectedValue(new Error('NotFound'));

      // First sub-batch (6 jobs) succeeds; second sub-batch (6 jobs) fails on every retry.
      let call = 0;
      mockTtsService.synthesizeGeminiRaw.mockImplementation(async () => {
        call++;
        // Sub-batch 1 = call 1 (success).
        // Sub-batch 2 = calls 2,3,4 (fail × 3 retries).
        if (call === 1) return Buffer.alloc(200);
        throw new Error('429 quota exhausted');
      });
      mockAlignmentService.align.mockResolvedValue({
        boundaries: Array.from({ length: 6 }, (_, i) => ({ startMs: i * 10, endMs: (i + 1) * 10 })),
        durationMs: 60,
      });

      mockDb.getPlanTtsStatus.mockResolvedValue({
        status: 'processing', total: 12, completed: 6, failed: 6, ready: false, updatedAt: new Date(),
      });

      const task: TtsBatchPregenWorkerTask = {
        task: 'ttsBatchPregen',
        planId: 'plan-1',
        groups: [{ voiceId: 'aoede', locale: 'enUS', provider: 'gemini', jobIds: jobs.map((j) => j.id) }],
      };

      await service.processTask(task);

      // 1 success + 3 retries on failure = 4 Gemini calls total.
      expect(mockTtsService.synthesizeGeminiRaw).toHaveBeenCalledTimes(4);
      // First 6 jobs marked completed.
      for (let i = 0; i < 6; i++) {
        expect(mockDb.updateTtsJobStatus).toHaveBeenCalledWith(`j${i}`, 'completed', `tts/ck${i}.wav`);
      }
      // Last 6 jobs marked failed with the upstream error message.
      for (let i = 6; i < 12; i++) {
        expect(mockDb.updateTtsJobStatus).toHaveBeenCalledWith(
          `j${i}`, 'failed', undefined, '429 quota exhausted',
        );
      }
    });
  });
});

// ---------------------------------------------------------------------------
// chunkJobsForGemini — pure function, exercised standalone
// ---------------------------------------------------------------------------

describe('chunkJobsForGemini', () => {
  it('returns one sub-batch when input fits both caps', () => {
    const jobs = Array.from({ length: 4 }, (_, i) => ({ text: `step ${i}` }));
    const out = chunkJobsForGemini(jobs);
    expect(out).toHaveLength(1);
    expect(out[0]).toHaveLength(4);
  });

  it('caps each sub-batch at maxSteps', () => {
    const jobs = Array.from({ length: 14 }, (_, i) => ({ text: `s${i}` }));
    const out = chunkJobsForGemini(jobs, 6, 10_000);
    expect(out.map((b) => b.length)).toEqual([6, 6, 2]);
  });

  it('splits earlier when char cap would be exceeded', () => {
    // 4 jobs of ~1500 chars each — at maxChars=3000, two should fit per batch.
    const long = 'x'.repeat(1500);
    const jobs = Array.from({ length: 4 }, () => ({ text: long }));
    const out = chunkJobsForGemini(jobs, 100, 3_000);
    expect(out.map((b) => b.length)).toEqual([2, 2]);
  });

  it('keeps an oversized single job in its own sub-batch rather than dropping it', () => {
    const jobs = [
      { text: 'short' },
      { text: 'x'.repeat(10_000) },  // exceeds char cap on its own
      { text: 'short' },
    ];
    const out = chunkJobsForGemini(jobs, 6, 3_000);
    // ['short'], ['x...'], ['short']
    expect(out.map((b) => b.length)).toEqual([1, 1, 1]);
  });

  it('preserves order and identity of jobs', () => {
    const jobs = [
      { text: 'a', id: 1 },
      { text: 'b', id: 2 },
      { text: 'c', id: 3 },
    ];
    const out = chunkJobsForGemini(jobs, 2, 1_000);
    expect(out).toEqual([
      [{ text: 'a', id: 1 }, { text: 'b', id: 2 }],
      [{ text: 'c', id: 3 }],
    ]);
  });

  it('returns empty array for empty input', () => {
    expect(chunkJobsForGemini([])).toEqual([]);
  });
});
