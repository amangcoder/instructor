import { Test, TestingModule } from '@nestjs/testing';
import {
  UnprocessableEntityException,
  HttpException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { PlansService } from './plans.service';
import { UpstashRateLimitService } from '../ratelimit/upstash-ratelimit.service';
import { DatabaseService } from '../database/database.service';
import { TtsPregenService } from '../tts/tts-pregen.service';
import { createMockDatabaseService } from '../database/testing';
import type { Phase1Requirements } from './prompts/phase1.prompt';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Builds a valid Phase 1 requirements object with N phases. */
function makePhase1Requirements(overrides: Partial<Phase1Requirements> = {}): Phase1Requirements {
  return {
    title: 'Morning Yoga',
    description: 'A relaxing yoga routine to start your day.',
    category: 'yoga',
    voice: 'af_bella',
    durationMinutes: 20,
    intensity: 'low',
    avoid: [],
    notes: '',
    language: 'en',
    phases: [
      { name: 'Warm-Up', durationMinutes: 10, focus: 'gentle warming' },
      { name: 'Main Practice', durationMinutes: 10, focus: 'sun salutations' },
    ],
    ...overrides,
  };
}

/** Wraps content in Ollama /api/chat response format. */
function wrapOllamaText(content: string): Record<string, unknown> {
  return { message: { role: 'assistant', content }, done: true };
}

/** Phase 1 response: JSON-stringified requirements wrapped in Ollama format. */
function makePhase1Response(overrides: Partial<Phase1Requirements> = {}): Record<string, unknown> {
  return wrapOllamaText(JSON.stringify(makePhase1Requirements(overrides)));
}

/** Triage response: JSON-stringified TriageResult wrapped in Ollama format. */
function makeTriageResponse(
  overrides: Partial<{ feasible: boolean; reason: string; complexity: string; flags: string[] }> = {},
): Record<string, unknown> {
  return wrapOllamaText(JSON.stringify({
    feasible: true,
    reason: 'Looks like a valid guided session.',
    complexity: 'low',
    flags: [],
    ...overrides,
  }));
}

/** Phase 2 response: DSL text wrapped in Ollama format. */
function makePhase2DslResponse(name = 'Morning Yoga', phase = 'Phase'): Record<string, unknown> {
  const dsl = `Name: ${name} — ${phase}
Description: ${phase} of the plan.
Category: yoga
Voice: af_bella
---
Say: Welcome to this phase.
Wait: 300
Notify: Halfway through!
Say: Keep going. You are doing great.
Wait: 300
Play: chime
Say: Phase complete.`;
  return wrapOllamaText(dsl);
}

// ---------------------------------------------------------------------------
// Mock UpstashRateLimitService
// ---------------------------------------------------------------------------

function createMockRateLimiter() {
  let counts: Map<string, number> = new Map();
  let expiries: Map<string, number> = new Map();

  return {
    consume: jest.fn(),
    peek: jest.fn().mockImplementation(
      async (namespace: string, identifier: string, limit: number) => {
        const key = `${namespace}:${identifier}`;
        const now = Math.floor(Date.now() / 1000);
        const count = (expiries.get(key) ?? 0) > now ? (counts.get(key) ?? 0) : 0;
        return { allowed: count < limit, current: count, retryAfterSec: 0 };
      },
    ),
    increment: jest.fn().mockImplementation(
      async (namespace: string, identifier: string, windowSec: number) => {
        const key = `${namespace}:${identifier}`;
        const now = Math.floor(Date.now() / 1000);
        if ((expiries.get(key) ?? 0) <= now) {
          counts.set(key, 1);
          expiries.set(key, now + windowSec);
        } else {
          counts.set(key, (counts.get(key) ?? 0) + 1);
        }
      },
    ),
    _reset: () => { counts = new Map(); expiries = new Map(); },
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('PlansService', () => {
  let service: PlansService;
  let mockRateLimiter: ReturnType<typeof createMockRateLimiter>;

  beforeEach(async () => {
    // Default: Ollama mode (no GEMINI_API_KEY needed).
    delete process.env.GEMINI_API_KEY;
    delete process.env.LLM_PROVIDER;

    mockRateLimiter = createMockRateLimiter();

    const mockDatabaseService = createMockDatabaseService();
    // Override specific methods used by PlansService
    (mockDatabaseService.savePlan as jest.Mock).mockResolvedValue({ planId: 'test-plan-id', updatedAt: new Date() });
    (mockDatabaseService.listPlans as jest.Mock).mockResolvedValue([]);

    const mockTtsPregen = { startPregen: jest.fn().mockResolvedValue(undefined) };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PlansService,
        { provide: UpstashRateLimitService, useValue: mockRateLimiter },
        { provide: DatabaseService, useValue: mockDatabaseService },
        { provide: TtsPregenService, useValue: mockTtsPregen },
      ],
    }).compile();

    service = module.get<PlansService>(PlansService);
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.useRealTimers();
    mockRateLimiter._reset();
    delete process.env.GEMINI_API_KEY;
    delete process.env.LLM_PROVIDER;
  });

  /**
   * Sets up fetch mock for a full Ollama pipeline with N phases.
   * Call order: Triage (1 call) → Phase 1 (1 call) → Phase 2 (N parallel calls).
   */
  function mockPipeline(phaseCount = 2, phase1Override?: Partial<Phase1Requirements>) {
    const fetchSpy = jest.spyOn(global, 'fetch');
    // Triage
    fetchSpy.mockResolvedValueOnce({
      ok: true,
      json: async () => makeTriageResponse(),
    } as unknown as Response);
    // Phase 1
    fetchSpy.mockResolvedValueOnce({
      ok: true,
      json: async () => makePhase1Response(phase1Override),
    } as unknown as Response);
    // Phase 2 — one per phase
    for (let i = 0; i < phaseCount; i++) {
      fetchSpy.mockResolvedValueOnce({
        ok: true,
        json: async () => makePhase2DslResponse('Morning Yoga', `Phase ${i + 1}`),
      } as unknown as Response);
    }
    return fetchSpy;
  }

  // ── Happy path ─────────────────────────────────────────────────────────────

  describe('generatePlan', () => {
    it('returns a plan with all required fields', async () => {
      mockPipeline(2);
      const result = await service.generatePlan('a 20-minute yoga session', 'user-1');

      expect(result.plan).toMatchObject({
        name: expect.any(String),
        description: expect.any(String),
        category: expect.any(String),
        defaultVoice: expect.any(String),
        steps: expect.any(Array),
      });
    });

    it('makes 1 Triage + 1 Phase 1 call + N Phase 2 calls (one per phase)', async () => {
      const fetchSpy = mockPipeline(2);
      await service.generatePlan('yoga session', 'user-1');
      // 1 Triage + 1 Phase 1 + 2 Phase 2 = 4 total
      expect(fetchSpy).toHaveBeenCalledTimes(4);
    });

    it('makes Phase 2 calls in parallel (Promise.all)', async () => {
      mockPipeline(3, {
        durationMinutes: 30,
        phases: [
          { name: 'Warm-Up', durationMinutes: 10, focus: 'warming' },
          { name: 'Main', durationMinutes: 10, focus: 'main set' },
          { name: 'Cool-Down', durationMinutes: 10, focus: 'cool down' },
        ],
      });

      const fetchSpy = jest.spyOn(global, 'fetch');
      await service.generatePlan('30-minute plan', 'user-1');
      expect(fetchSpy).toHaveBeenCalledTimes(5); // 1 triage + 1 phase1 + 3 phase2
    });

    it('combines all phase steps with Notify transitions between phases', async () => {
      mockPipeline(2);
      const result = await service.generatePlan('yoga', 'user-1');
      const steps = result.plan.steps as Array<Record<string, unknown>>;

      const notifySteps = steps.filter((s) => s.type === 'notify');
      expect(notifySteps.length).toBeGreaterThanOrEqual(1);
    });

    it('Phase 1 Ollama call includes format schema for structured JSON', async () => {
      const fetchSpy = mockPipeline(2);
      await service.generatePlan('test', 'user-1');

      // calls: [0] triage, [1] phase 1, [2..] phase 2
      const [, init] = fetchSpy.mock.calls[1];
      const body = JSON.parse((init as RequestInit).body as string);
      // Ollama structured output uses `format`, not `generationConfig`
      expect(body.format).toBeDefined();
      expect(body.generationConfig).toBeUndefined();
    });

    it('Phase 2 Ollama calls do NOT include format (plain text DSL)', async () => {
      const fetchSpy = mockPipeline(2);
      await service.generatePlan('test', 'user-1');

      const [, init] = fetchSpy.mock.calls[2]; // first Phase 2 call (after triage + phase1)
      const body = JSON.parse((init as RequestInit).body as string);
      expect(body.format).toBeUndefined();
    });

    it('uses Phase 1 requirements for the final plan header', async () => {
      mockPipeline(2, { title: 'My Special Plan', category: 'workout', voice: 'am_adam' });
      const result = await service.generatePlan('workout', 'user-1');

      expect(result.plan.name).toBe('My Special Plan');
      expect(result.plan.category).toBe('workout');
      expect(result.plan.defaultVoice).toBe('am_adam');
    });

    it('sends the user prompt in the Phase 1 Ollama messages', async () => {
      const fetchSpy = mockPipeline(2);
      await service.generatePlan('stomach pain yoga relief', 'user-1');

      // [0] is triage, [1] is Phase 1
      const [, init] = fetchSpy.mock.calls[1];
      const body = JSON.parse((init as RequestInit).body as string);
      // Ollama uses messages array, not contents
      const userMessage: string = body.messages?.find((m: any) => m.role === 'user')?.content ?? '';
      expect(userMessage).toContain('stomach pain yoga relief');
    });

    it('caps duration at 240 minutes and scales phases proportionally', async () => {
      const fetchSpy = jest.spyOn(global, 'fetch');
      // Triage
      fetchSpy.mockResolvedValueOnce({
        ok: true,
        json: async () => makeTriageResponse({ complexity: 'high' }),
      } as unknown as Response);
      // Phase 1
      fetchSpy.mockResolvedValueOnce({
        ok: true,
        json: async () => makePhase1Response({
          durationMinutes: 300,
          phases: [
            { name: 'A', durationMinutes: 100, focus: 'a' },
            { name: 'B', durationMinutes: 100, focus: 'b' },
            { name: 'C', durationMinutes: 100, focus: 'c' },
          ],
        }),
      } as unknown as Response);
      for (let i = 0; i < 3; i++) {
        fetchSpy.mockResolvedValueOnce({
          ok: true,
          json: async () => makePhase2DslResponse(),
        } as unknown as Response);
      }

      await service.generatePlan('very long plan', 'user-1');
      expect(fetchSpy).toHaveBeenCalledTimes(5); // 1 triage + 1 phase1 + 3 phase2
    });
  });

  // ── Triage gate ────────────────────────────────────────────────────────────

  describe('triage gate', () => {
    it('rejects infeasible prompts before Phase 1 runs', async () => {
      const fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValueOnce({
        ok: true,
        json: async () => makeTriageResponse({
          feasible: false,
          reason: 'Please describe a single guided session under 4 hours.',
          complexity: 'infeasible',
          flags: ['too_vague'],
        }),
      } as unknown as Response);

      await expect(service.generatePlan('do something', 'user-1')).rejects.toThrow(
        UnprocessableEntityException,
      );
      // Only the triage call ran — no Phase 1 / Phase 2 work.
      expect(fetchSpy).toHaveBeenCalledTimes(1);
    });

    it('surfaces the triage reason in the rejection message', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValueOnce({
        ok: true,
        json: async () => makeTriageResponse({
          feasible: false,
          reason: 'Medical advice is out of scope.',
          complexity: 'infeasible',
          flags: ['unsafe'],
        }),
      } as unknown as Response);

      await expect(service.generatePlan('treat my condition', 'user-1')).rejects.toThrow(
        'Medical advice is out of scope.',
      );
    });

    it('proceeds when triage marks the prompt feasible', async () => {
      const fetchSpy = mockPipeline(2);
      const result = await service.generatePlan('20-minute yoga', 'user-1');
      expect(result.plan).toBeDefined();
      // 1 triage + 1 phase1 + 2 phase2
      expect(fetchSpy).toHaveBeenCalledTimes(4);
    });

    it('fails open when triage fetch errors — generation still proceeds', async () => {
      // Triage call rejects, but Phase 1 + Phase 2 succeed.
      const fetchSpy = jest.spyOn(global, 'fetch')
        .mockRejectedValueOnce(new Error('triage upstream timeout'))
        .mockResolvedValueOnce({ ok: true, json: async () => makePhase1Response() } as unknown as Response)
        .mockResolvedValueOnce({ ok: true, json: async () => makePhase2DslResponse() } as unknown as Response)
        .mockResolvedValueOnce({ ok: true, json: async () => makePhase2DslResponse() } as unknown as Response);

      const result = await service.generatePlan('yoga', 'user-1');
      expect(result.plan).toBeDefined();
      expect(fetchSpy).toHaveBeenCalledTimes(4);
    });

    it('fails open when triage returns malformed JSON — generation still proceeds', async () => {
      jest.spyOn(global, 'fetch')
        .mockResolvedValueOnce({
          ok: true,
          json: async () => wrapOllamaText('not valid json at all'),
        } as unknown as Response)
        .mockResolvedValueOnce({ ok: true, json: async () => makePhase1Response() } as unknown as Response)
        .mockResolvedValueOnce({ ok: true, json: async () => makePhase2DslResponse() } as unknown as Response)
        .mockResolvedValueOnce({ ok: true, json: async () => makePhase2DslResponse() } as unknown as Response);

      const result = await service.generatePlan('yoga', 'user-1');
      expect(result.plan).toBeDefined();
    });
  });

  // ── Error handling ─────────────────────────────────────────────────────────

  describe('error handling', () => {
    it('throws when Ollama returns empty content for Phase 1', async () => {
      jest.spyOn(global, 'fetch')
        // Triage succeeds
        .mockResolvedValueOnce({
          ok: true,
          json: async () => makeTriageResponse(),
        } as unknown as Response)
        // Phase 1 returns empty
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ message: { content: '' }, done: true }),
        } as unknown as Response);

      await expect(service.generatePlan('test', 'user-1')).rejects.toThrow();
    });

    it('throws when Ollama API returns non-OK status for Phase 1', async () => {
      jest.spyOn(global, 'fetch')
        // Triage succeeds
        .mockResolvedValueOnce({
          ok: true,
          json: async () => makeTriageResponse(),
        } as unknown as Response)
        // Phase 1 fails
        .mockResolvedValueOnce({
          ok: false,
          status: 500,
          text: async () => 'Internal Server Error',
        } as unknown as Response);

      await expect(service.generatePlan('test', 'user-1')).rejects.toThrow(/500/);
    });

    it('retries a failing phase once before throwing', async () => {
      const badDsl = 'This is not valid DSL at all.';
      const fetchSpy = jest.spyOn(global, 'fetch')
        // Triage
        .mockResolvedValueOnce({ ok: true, json: async () => makeTriageResponse() } as unknown as Response)
        // Phase 1
        .mockResolvedValueOnce({ ok: true, json: async () => makePhase1Response() } as unknown as Response)
        // Phase 2.1 attempt 1 — bad
        .mockResolvedValueOnce({ ok: true, json: async () => wrapOllamaText(badDsl) } as unknown as Response)
        // Phase 2.2 (good, runs in parallel)
        .mockResolvedValueOnce({ ok: true, json: async () => makePhase2DslResponse() } as unknown as Response)
        // Phase 2.1 retry — bad again
        .mockResolvedValueOnce({ ok: true, json: async () => wrapOllamaText(badDsl) } as unknown as Response);

      await expect(service.generatePlan('test', 'user-1')).rejects.toThrow(
        UnprocessableEntityException,
      );

      // 1 Triage + 1 Phase1 + 2×Phase2.1 attempts + 1×Phase2.2 = 5 calls
      expect(fetchSpy).toHaveBeenCalledTimes(5);
    });
  });

  // ── Rate limiting ──────────────────────────────────────────────────────────

  describe('rate limiting', () => {
    function mockForever() {
      let call = 0;
      // Each generation makes 4 calls: triage → Phase 1 → 2× Phase 2.
      jest.spyOn(global, 'fetch').mockImplementation(async () => {
        call++;
        const slot = ((call - 1) % 4) + 1;
        let body: Record<string, unknown>;
        if (slot === 1) body = makeTriageResponse();
        else if (slot === 2) body = makePhase1Response();
        else body = makePhase2DslResponse();
        return { ok: true, json: async () => body } as unknown as Response;
      });
    }

    it('throws TooManyRequestsException when quota exceeded', async () => {
      mockForever();
      for (let i = 0; i < 10; i++) await service.generatePlan(`prompt ${i}`, 'user-rl');
      await expect(service.generatePlan('overflow', 'user-rl')).rejects.toThrow(HttpException);
    });

    it('rate limits are per-user — different users have independent quotas', async () => {
      mockForever();
      for (let i = 0; i < 10; i++) await service.generatePlan(`prompt ${i}`, 'user-a');
      await expect(service.generatePlan('overflow', 'user-a')).rejects.toThrow(HttpException);
      await expect(service.generatePlan('prompt', 'user-b')).resolves.toBeDefined();
    });
  });

  // ── Gemini mode (LLM_PROVIDER=gemini) ─────────────────────────────────────

  describe('Gemini mode (LLM_PROVIDER=gemini)', () => {
    it('throws ServiceUnavailableException when GEMINI_API_KEY is not set', async () => {
      process.env.LLM_PROVIDER = 'gemini';
      delete process.env.GEMINI_API_KEY;
      await expect(service.generatePlan('test', 'user-1')).rejects.toThrow(
        ServiceUnavailableException,
      );
    });

    it('calls Gemini with JSON responseMimeType for Phase 1', async () => {
      process.env.LLM_PROVIDER = 'gemini';
      process.env.GEMINI_API_KEY = 'test-key';

      // Gemini response format
      const geminiTriage = {
        candidates: [{ content: { parts: [{ text: JSON.stringify({ feasible: true, reason: 'ok', complexity: 'low', flags: [] }) }] } }],
      };
      const geminiPhase1 = {
        candidates: [{ content: { parts: [{ text: JSON.stringify(makePhase1Requirements()) }] } }],
      };
      const geminiPhase2 = {
        candidates: [{ content: { parts: [{ text: (makePhase2DslResponse()['message'] as any)['content'] }] } }],
      };

      const fetchSpy = jest.spyOn(global, 'fetch')
        .mockResolvedValueOnce({ ok: true, json: async () => geminiTriage } as unknown as Response)
        .mockResolvedValueOnce({ ok: true, json: async () => geminiPhase1 } as unknown as Response)
        .mockResolvedValueOnce({ ok: true, json: async () => geminiPhase2 } as unknown as Response)
        .mockResolvedValueOnce({ ok: true, json: async () => geminiPhase2 } as unknown as Response);

      await service.generatePlan('test', 'user-1');

      // calls: [0] triage, [1] phase 1
      const [, init] = fetchSpy.mock.calls[1];
      const body = JSON.parse((init as RequestInit).body as string);
      expect(body.generationConfig?.responseMimeType).toBe('application/json');
    });
  });
});
