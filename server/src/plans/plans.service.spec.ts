import { Test, TestingModule } from '@nestjs/testing';
import {
  UnprocessableEntityException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { PlansService } from './plans.service';
import { UpstashRateLimitService } from '../ratelimit/upstash-ratelimit.service';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const GEMINI_API_KEY = 'test-gemini-api-key';

/**
 * Builds a minimal valid plan that passes the Gemini JSON schema validator.
 * Step shapes match the actual PLAN_SCHEMA defined in PlansService.
 */
function makeValidPlan(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    name: 'Morning Yoga',
    description: 'A relaxing 20-minute yoga routine to start your day',
    category: 'fitness',
    defaultVoice: 'aoede',
    steps: [
      { type: 'say', text: 'Start in mountain pose, feet hip-width apart' },
      { type: 'wait', durationSeconds: 10 },
      { type: 'say', text: 'Now raise your arms overhead and breathe in' },
      { type: 'wait', durationSeconds: 10 },
      { type: 'notify', message: 'Great job! Keep it up.' },
    ],
    ...overrides,
  };
}

/**
 * Wraps a plan in the Gemini API response envelope.
 * The service calls JSON.parse(data.candidates[0].content.parts[0].text),
 * so the text field must be a JSON string of the plan object itself.
 */
function makeGeminiResponse(plan: Record<string, unknown>): Record<string, unknown> {
  return {
    candidates: [
      {
        content: {
          parts: [{ text: JSON.stringify(plan) }],
        },
        finishReason: 'STOP',
      },
    ],
  };
}

/**
 * Returns a Gemini response whose text contains invalid JSON (causes callGemini to throw).
 */
function makeGeminiInvalidJsonResponse(): Record<string, unknown> {
  return {
    candidates: [
      {
        content: {
          parts: [{ text: '{ this is : not valid json }' }],
        },
        finishReason: 'STOP',
      },
    ],
  };
}

/**
 * Returns a Gemini response whose text is valid JSON but fails validatePlan.
 * Used to trigger the retry loop.
 */
function makeGeminiInvalidPlanResponse(): Record<string, unknown> {
  return {
    candidates: [
      {
        content: {
          parts: [{ text: JSON.stringify({ description: 'missing name and steps' }) }],
        },
        finishReason: 'STOP',
      },
    ],
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Mock UpstashRateLimitService factory
// ---------------------------------------------------------------------------

function createMockRateLimiter() {
  let callCounts: Map<string, number> = new Map();
  let windowExpiresAt: Map<string, number> = new Map();

  return {
    consume: jest.fn().mockImplementation(
      async (namespace: string, identifier: string, limit: number, windowSec: number) => {
        const key = `${namespace}:${identifier}`;
        const now = Math.floor(Date.now() / 1000);
        const expiry = windowExpiresAt.get(key) ?? 0;

        if (expiry <= now) {
          // New window
          callCounts.set(key, 1);
          windowExpiresAt.set(key, now + windowSec);
          return { allowed: true, current: 1, retryAfterSec: 0 };
        }

        const count = (callCounts.get(key) ?? 0);
        if (count >= limit) {
          return { allowed: false, current: count, retryAfterSec: expiry - now };
        }

        callCounts.set(key, count + 1);
        return { allowed: true, current: count + 1, retryAfterSec: 0 };
      },
    ),
    peek: jest.fn().mockImplementation(
      async (namespace: string, identifier: string, limit: number) => {
        const key = `${namespace}:${identifier}`;
        const now = Math.floor(Date.now() / 1000);
        const expiry = windowExpiresAt.get(key) ?? 0;
        const count = expiry > now ? (callCounts.get(key) ?? 0) : 0;
        const allowed = count < limit;
        return {
          allowed,
          current: count,
          retryAfterSec: allowed ? 0 : Math.max(0, expiry - now),
        };
      },
    ),
    increment: jest.fn().mockImplementation(
      async (namespace: string, identifier: string, windowSec: number) => {
        const key = `${namespace}:${identifier}`;
        const now = Math.floor(Date.now() / 1000);
        const expiry = windowExpiresAt.get(key) ?? 0;

        if (expiry <= now) {
          callCounts.set(key, 1);
          windowExpiresAt.set(key, now + windowSec);
        } else {
          callCounts.set(key, (callCounts.get(key) ?? 0) + 1);
        }
      },
    ),
    _reset: () => {
      callCounts = new Map();
      windowExpiresAt = new Map();
    },
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('PlansService', () => {
  let service: PlansService;
  let mockRateLimiter: ReturnType<typeof createMockRateLimiter>;

  beforeEach(async () => {
    process.env.GEMINI_API_KEY = GEMINI_API_KEY;

    mockRateLimiter = createMockRateLimiter();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PlansService,
        { provide: UpstashRateLimitService, useValue: mockRateLimiter },
      ],
    }).compile();

    service = module.get<PlansService>(PlansService);
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.useRealTimers();
    mockRateLimiter._reset();
    delete process.env.GEMINI_API_KEY;
  });

  // ── generatePlan — happy path ────────────────────────────────────────────

  describe('generatePlan', () => {
    it('returns a plan with all required fields for a valid prompt', async () => {
      const plan = makeValidPlan();
      jest.spyOn(global, 'fetch').mockResolvedValueOnce({
        ok: true,
        json: async () => makeGeminiResponse(plan),
      } as unknown as Response);

      const result = await service.generatePlan('a 20-minute yoga session', 'user-1');

      expect(result.plan).toMatchObject({
        name: expect.any(String),
        description: expect.any(String),
        category: expect.any(String),
        defaultVoice: expect.any(String),
        steps: expect.any(Array),
      });
    });

    it('calls the Gemini API with responseMimeType: application/json', async () => {
      const fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValueOnce({
        ok: true,
        json: async () => makeGeminiResponse(makeValidPlan()),
      } as unknown as Response);

      await service.generatePlan('morning workout', 'user-1');

      const [, init] = fetchSpy.mock.calls[0];
      const body = JSON.parse((init as RequestInit).body as string);
      expect(body.generationConfig?.responseMimeType).toBe('application/json');
    });

    it('sends the GEMINI_API_KEY in the x-goog-api-key header', async () => {
      const fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValueOnce({
        ok: true,
        json: async () => makeGeminiResponse(makeValidPlan()),
      } as unknown as Response);

      await service.generatePlan('test prompt', 'user-1');

      const [, init] = fetchSpy.mock.calls[0];
      const headers = (init as RequestInit).headers as Record<string, string>;
      expect(headers['x-goog-api-key']).toBe(GEMINI_API_KEY);
    });

    it('prefixes the prompt with the category when category is provided', async () => {
      const fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValueOnce({
        ok: true,
        json: async () => makeGeminiResponse(makeValidPlan({ category: 'fitness' })),
      } as unknown as Response);

      await service.generatePlan('quick workout', 'user-1', 'fitness');

      const [, init] = fetchSpy.mock.calls[0];
      const body = JSON.parse((init as RequestInit).body as string);
      const promptText: string = body.contents?.[0]?.parts?.[0]?.text ?? '';
      expect(promptText).toContain('fitness');
    });

    it('does not include category prefix when category is omitted', async () => {
      const fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValueOnce({
        ok: true,
        json: async () => makeGeminiResponse(makeValidPlan()),
      } as unknown as Response);

      await service.generatePlan('a nice workout', 'user-1');

      const [, init] = fetchSpy.mock.calls[0];
      const body = JSON.parse((init as RequestInit).body as string);
      const promptText: string = body.contents?.[0]?.parts?.[0]?.text ?? '';
      // Without a category, the raw prompt should appear verbatim
      expect(promptText).toContain('a nice workout');
    });

    it('generates different plans for different prompts', async () => {
      const plan1 = makeValidPlan({ name: 'Yoga Session' });
      const plan2 = makeValidPlan({ name: 'Running Plan' });

      jest
        .spyOn(global, 'fetch')
        .mockResolvedValueOnce({
          ok: true,
          json: async () => makeGeminiResponse(plan1),
        } as unknown as Response)
        .mockResolvedValueOnce({
          ok: true,
          json: async () => makeGeminiResponse(plan2),
        } as unknown as Response);

      const [r1, r2] = await Promise.all([
        service.generatePlan('yoga', 'user-1'),
        service.generatePlan('running', 'user-2'),
      ]);
      expect(r1.plan.name).not.toBe(r2.plan.name);
    });
  });

  // ── Schema validation ──────────────────────────────────────────────────────

  describe('response validation', () => {
    it('throws UnprocessableEntityException when plan is missing "name"', async () => {
      const invalid = makeValidPlan();
      delete invalid.name;

      jest.spyOn(global, 'fetch').mockResolvedValue({
        ok: true,
        json: async () => makeGeminiResponse(invalid),
      } as unknown as Response);

      await expect(service.generatePlan('test', 'user-1')).rejects.toThrow(
        UnprocessableEntityException,
      );
    });

    it('throws UnprocessableEntityException when plan has no steps', async () => {
      const invalid = makeValidPlan({ steps: [] });

      jest.spyOn(global, 'fetch').mockResolvedValue({
        ok: true,
        json: async () => makeGeminiResponse(invalid),
      } as unknown as Response);

      await expect(service.generatePlan('test', 'user-1')).rejects.toThrow(
        UnprocessableEntityException,
      );
    });

    it('throws UnprocessableEntityException when a step has an unknown type', async () => {
      const invalid = makeValidPlan({
        steps: [{ type: 'unknown_step_type', text: 'hello' }],
      });

      jest.spyOn(global, 'fetch').mockResolvedValue({
        ok: true,
        json: async () => makeGeminiResponse(invalid),
      } as unknown as Response);

      await expect(service.generatePlan('test', 'user-1')).rejects.toThrow(
        UnprocessableEntityException,
      );
    });

    it('throws Error when Gemini returns invalid (non-parseable) JSON', async () => {
      // callGemini throws immediately on JSON.parse failure — no retry
      jest.spyOn(global, 'fetch').mockResolvedValueOnce({
        ok: true,
        json: async () => makeGeminiInvalidJsonResponse(),
      } as unknown as Response);

      await expect(service.generatePlan('test', 'user-1')).rejects.toThrow(/invalid JSON/i);
    });

    it('throws Error when Gemini response has no candidates', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValueOnce({
        ok: true,
        json: async () => ({ candidates: [] }),
      } as unknown as Response);

      await expect(service.generatePlan('test', 'user-1')).rejects.toThrow();
    });

    it('throws Error when Gemini API returns non-OK status', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValueOnce({
        ok: false,
        status: 500,
        text: async () => 'Internal Server Error',
      } as unknown as Response);

      await expect(service.generatePlan('test', 'user-1')).rejects.toThrow(/500/);
    });
  });

  // ── Retry logic ────────────────────────────────────────────────────────────

  describe('retry on invalid plan output', () => {
    it('retries once and succeeds on second attempt if first response fails validation', async () => {
      const validPlan = makeValidPlan();
      const fetchSpy = jest.spyOn(global, 'fetch')
        .mockResolvedValueOnce({
          ok: true,
          json: async () => makeGeminiInvalidPlanResponse(),
        } as unknown as Response)
        .mockResolvedValueOnce({
          ok: true,
          json: async () => makeGeminiResponse(validPlan),
        } as unknown as Response);

      const result = await service.generatePlan('test', 'user-1');

      expect(fetchSpy).toHaveBeenCalledTimes(2);
      expect(result.plan.name).toBe(validPlan.name);
    });

    it('throws UnprocessableEntityException after MAX_RETRIES (3 total attempts) all fail', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValue({
        ok: true,
        json: async () => makeGeminiInvalidPlanResponse(),
      } as unknown as Response);

      await expect(service.generatePlan('test', 'user-1')).rejects.toThrow(
        UnprocessableEntityException,
      );
    });

    it('makes at most 3 total Gemini API calls (1 initial + 2 retries)', async () => {
      const fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValue({
        ok: true,
        json: async () => makeGeminiInvalidPlanResponse(),
      } as unknown as Response);

      await service.generatePlan('test', 'user-1').catch(() => null);

      expect(fetchSpy).toHaveBeenCalledTimes(3);
    });
  });

  // ── Rate limiting via UpstashRateLimitService (10 per hour per user) ────────

  describe('rate limiting', () => {
    beforeEach(() => {
      // Stub all Gemini calls to succeed instantly
      jest.spyOn(global, 'fetch').mockResolvedValue({
        ok: true,
        json: async () => makeGeminiResponse(makeValidPlan()),
      } as unknown as Response);
    });

    it('allows the first 10 requests within the same hour', async () => {
      for (let i = 0; i < 10; i++) {
        await expect(service.generatePlan(`prompt ${i}`, 'user-rl')).resolves.toBeDefined();
      }
    });

    it('throws TooManyRequestsException on the 11th request within an hour', async () => {
      for (let i = 0; i < 10; i++) {
        await service.generatePlan(`prompt ${i}`, 'user-rl');
      }
      await expect(service.generatePlan('overflow', 'user-rl')).rejects.toThrow(
        HttpException,
      );
    });

    it('does not call Gemini when rate-limited', async () => {
      for (let i = 0; i < 10; i++) {
        await service.generatePlan(`prompt ${i}`, 'user-rl2');
      }
      const fetchSpy = jest.spyOn(global, 'fetch');
      fetchSpy.mockClear();

      await service.generatePlan('overflow', 'user-rl2').catch(() => null);
      expect(fetchSpy).not.toHaveBeenCalled();
    });

    it('rate limits are per-user (different users have independent quotas)', async () => {
      // Exhaust user-a
      for (let i = 0; i < 10; i++) {
        await service.generatePlan(`prompt ${i}`, 'user-a');
      }

      // user-a is blocked
      await expect(service.generatePlan('overflow', 'user-a')).rejects.toThrow(
        HttpException,
      );

      // user-b should still be allowed
      await expect(service.generatePlan('prompt', 'user-b')).resolves.toBeDefined();
    });

    it('resets the window after 1 hour elapses', async () => {
      jest.useFakeTimers();

      for (let i = 0; i < 10; i++) {
        await service.generatePlan(`prompt ${i}`, 'user-timer');
      }
      await expect(service.generatePlan('overflow', 'user-timer')).rejects.toThrow(
        HttpException,
      );

      // Advance past the 1-hour window
      jest.advanceTimersByTime(60 * 60 * 1001);

      await expect(service.generatePlan('after reset', 'user-timer')).resolves.toBeDefined();
    });
  });

  // ── GEMINI_API_KEY ─────────────────────────────────────────────────────────

  describe('GEMINI_API_KEY', () => {
    it('throws when GEMINI_API_KEY is not set in the environment', async () => {
      delete process.env.GEMINI_API_KEY;
      await expect(service.generatePlan('test', 'user-1')).rejects.toThrow(/GEMINI_API_KEY/i);
    });
  });
});
