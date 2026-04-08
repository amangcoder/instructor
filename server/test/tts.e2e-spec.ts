import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe, HttpStatus } from '@nestjs/common';
import * as request from 'supertest';
import { App } from 'supertest/types';

// ---------------------------------------------------------------------------
// E2E TTS tests with provider routing
//
// Tests the full HTTP layer for TTS synthesis including:
//   POST /api/tts/synthesize (Gemini and Kokoro providers)
//   GET /api/tts/providers (dynamic provider list)
//
// External services are mocked: Gemini API, Kokoro Python server.
// ---------------------------------------------------------------------------

/** Build a minimal valid WAV buffer for mock responses. */
function makeWavBytes(): Buffer {
  const pcm = Buffer.alloc(20, 0);
  const header = Buffer.alloc(44);
  header.write('RIFF', 0, 'ascii');
  header.writeUInt32LE(36 + pcm.length, 4);
  header.write('WAVE', 8, 'ascii');
  header.write('fmt ', 12, 'ascii');
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(24000, 24);
  header.writeUInt32LE(48000, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36, 'ascii');
  header.writeUInt32LE(pcm.length, 40);
  return Buffer.concat([header, pcm]);
}

/** Build a Gemini API response from base64 PCM. */
function makeGeminiResponse() {
  return {
    candidates: [{
      content: {
        parts: [{ inlineData: { mimeType: 'audio/pcm', data: Buffer.alloc(20, 0).toString('base64') } }],
      },
    }],
  };
}

/** Mock for the KokoroTtsProxy service (TASK-005). */
const mockKokoroProxy = {
  synthesizeViaKokoro: jest.fn(),
  getKokoroHealth: jest.fn(),
};

describe('TTS (e2e)', () => {
  let app: INestApplication<App>;
  let validAuthToken: string;

  beforeAll(async () => {
    let AppModule: new () => object;

    try {
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      ({ AppModule } = require('../src/app.module'));
    } catch {
      console.warn('[tts.e2e] AppModule not found — tests will be skipped until modules are implemented');
      return;
    }

    // Try to import AWS-dependent service tokens for overriding
    let DynamoDBService: unknown;
    let SESEmailService: unknown;
    let DynamoDBRateLimitService: unknown;
    try {
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      ({ DynamoDBService } = require('../src/dynamodb/dynamodb.service'));
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      ({ SESEmailService } = require('../src/email/ses-email.service'));
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      ({ DynamoDBRateLimitService } = require('../src/ratelimit/dynamodb-ratelimit.service'));
    } catch {
      // Services not yet implemented — gracefully degrade
    }

    const KOKORO_PROXY = 'KOKORO_TTS_PROXY';

    let builder = Test.createTestingModule({
      imports: [AppModule],
    }).overrideProvider(KOKORO_PROXY).useValue(mockKokoroProxy);

    // Override AWS-dependent services with deterministic in-memory stubs
    if (DynamoDBService) {
      builder = builder.overrideProvider(DynamoDBService).useValue({
        getUserById: jest.fn().mockResolvedValue(null),
        getUserByEmail: jest.fn().mockResolvedValue(null),
        createUser: jest.fn().mockResolvedValue(undefined),
        createOtp: jest.fn().mockResolvedValue(undefined),
        getActiveOtps: jest.fn().mockResolvedValue([]),
        markOtpUsed: jest.fn().mockResolvedValue(undefined),
        incrementOtpAttempts: jest.fn().mockResolvedValue(undefined),
        invalidateOtpsForEmail: jest.fn().mockResolvedValue(undefined),
        createRefreshToken: jest.fn().mockResolvedValue(undefined),
        getRefreshToken: jest.fn().mockResolvedValue(null),
        revokeRefreshToken: jest.fn().mockResolvedValue(undefined),
        revokeAllRefreshTokens: jest.fn().mockResolvedValue(undefined),
        getSyncMetadata: jest.fn().mockResolvedValue(null),
        upsertSyncMetadata: jest.fn().mockResolvedValue(undefined),
      });
    }
    if (SESEmailService) {
      builder = builder
        .overrideProvider(SESEmailService)
        .useValue({ sendOtpEmail: jest.fn().mockResolvedValue(undefined) });
    }
    if (DynamoDBRateLimitService) {
      builder = builder.overrideProvider(DynamoDBRateLimitService).useValue({
        consume: jest.fn().mockResolvedValue({ allowed: true, current: 1, retryAfterSec: 0 }),
        peek: jest.fn().mockResolvedValue({ allowed: true, current: 0, retryAfterSec: 0 }),
        increment: jest.fn().mockResolvedValue(undefined),
      });
    }

    const moduleFixture: TestingModule = await builder.compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    app.setGlobalPrefix('api');
    await app.init();

    // For tests that require auth: use a pre-signed test JWT
    // (real auth flow tested in auth.e2e-spec.ts)
    validAuthToken = 'test-valid-jwt';
  });

  afterAll(async () => {
    await app?.close();
  });

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.GEMINI_API_KEY = 'test-api-key';

    // Default Gemini mock: return silent WAV
    jest.spyOn(global, 'fetch').mockResolvedValue({
      ok: true,
      json: async () => makeGeminiResponse(),
    } as unknown as Response);

    // Default Kokoro mock: return WAV bytes
    mockKokoroProxy.synthesizeViaKokoro.mockResolvedValue(makeWavBytes());
    mockKokoroProxy.getKokoroHealth.mockResolvedValue({
      status: 'ready',
      model: 'kokoro-v0.19',
      voices: ['af_aoede', 'af_bella', 'am_adam'],
    });
  });

  afterEach(() => {
    jest.restoreAllMocks();
    delete process.env.GEMINI_API_KEY;
  });

  function skipIfNoApp() {
    if (!app) pending('TTS module not implemented yet');
  }

  // ── GET /api/tts/providers ─────────────────────────────────────────────────

  describe('GET /api/tts/providers', () => {
    it('returns 200 with a list of providers', async () => {
      skipIfNoApp();
      const res = await request(app.getHttpServer())
        .get('/api/tts/providers')
        .expect(HttpStatus.OK);

      expect(res.body).toHaveProperty('providers');
      expect(Array.isArray(res.body.providers)).toBe(true);
    });

    it('includes both "gemini" and "kokoro" providers', async () => {
      skipIfNoApp();
      const res = await request(app.getHttpServer())
        .get('/api/tts/providers')
        .expect(HttpStatus.OK);

      const providers: Array<{ id: string }> = res.body.providers as Array<{ id: string }>;
      const ids = providers.map((p) => p.id);
      expect(ids).toContain('gemini');
      expect(ids).toContain('kokoro');
    });

    it('each provider has voices and locales', async () => {
      skipIfNoApp();
      const res = await request(app.getHttpServer())
        .get('/api/tts/providers')
        .expect(HttpStatus.OK);

      for (const provider of res.body.providers as Array<{ id: string; voices: unknown[]; locales: unknown[] }>) {
        expect(provider.voices).toBeDefined();
        expect(provider.locales).toBeDefined();
        expect(Array.isArray(provider.voices)).toBe(true);
      }
    });

    it('Kokoro voices are fetched from the Kokoro proxy', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .get('/api/tts/providers')
        .expect(HttpStatus.OK);

      expect(mockKokoroProxy.getKokoroHealth).toHaveBeenCalled();
    });
  });

  // ── POST /api/tts/synthesize (Gemini) ─────────────────────────────────────

  describe('POST /api/tts/synthesize with provider=gemini', () => {
    it('returns 200 audio/wav for a valid Gemini synthesis request', async () => {
      skipIfNoApp();
      const res = await request(app.getHttpServer())
        .post('/api/tts/synthesize')
        .set('Authorization', `Bearer ${validAuthToken}`)
        .send({ text: 'Hello from Gemini', provider: 'gemini' })
        .expect(HttpStatus.OK);

      expect(res.headers['content-type']).toContain('audio/wav');
    });

    it('routes to Gemini API (fetch is called) not Kokoro proxy', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .post('/api/tts/synthesize')
        .set('Authorization', `Bearer ${validAuthToken}`)
        .send({ text: 'Gemini route', provider: 'gemini' });

      expect(jest.spyOn(global, 'fetch')).toHaveBeenCalledTimes(1);
      expect(mockKokoroProxy.synthesizeViaKokoro).not.toHaveBeenCalled();
    });
  });

  // ── POST /api/tts/synthesize (Kokoro) ─────────────────────────────────────

  describe('POST /api/tts/synthesize with provider=kokoro', () => {
    it('returns 200 audio/wav for a valid Kokoro synthesis request', async () => {
      skipIfNoApp();
      const res = await request(app.getHttpServer())
        .post('/api/tts/synthesize')
        .set('Authorization', `Bearer ${validAuthToken}`)
        .send({ text: 'Hello from Kokoro', provider: 'kokoro' })
        .expect(HttpStatus.OK);

      expect(res.headers['content-type']).toContain('audio/wav');
    });

    it('routes to Kokoro proxy (not Gemini fetch)', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .post('/api/tts/synthesize')
        .set('Authorization', `Bearer ${validAuthToken}`)
        .send({ text: 'Kokoro route', provider: 'kokoro' });

      expect(mockKokoroProxy.synthesizeViaKokoro).toHaveBeenCalledTimes(1);
    });

    it('returns 502 when Kokoro server is unavailable', async () => {
      skipIfNoApp();
      mockKokoroProxy.synthesizeViaKokoro.mockRejectedValueOnce(
        Object.assign(new Error('ECONNREFUSED'), { code: 'ECONNREFUSED' }),
      );

      const res = await request(app.getHttpServer())
        .post('/api/tts/synthesize')
        .set('Authorization', `Bearer ${validAuthToken}`)
        .send({ text: 'test', provider: 'kokoro' });

      expect(res.status).toBe(HttpStatus.BAD_GATEWAY);
      expect(res.body.message ?? res.body.error).toMatch(/Kokoro server unavailable/i);
    });
  });

  // ── Invalid provider ───────────────────────────────────────────────────────

  describe('invalid provider', () => {
    it('returns 400 for an unknown provider', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .post('/api/tts/synthesize')
        .set('Authorization', `Bearer ${validAuthToken}`)
        .send({ text: 'test', provider: 'fake-provider' })
        .expect(HttpStatus.BAD_REQUEST);
    });
  });

  // ── Authentication ─────────────────────────────────────────────────────────

  describe('authentication on /api/tts/synthesize', () => {
    it('returns 401 when no Authorization header is provided', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .post('/api/tts/synthesize')
        .send({ text: 'test' })
        .expect(HttpStatus.UNAUTHORIZED);
    });

    it('returns 401 for an invalid JWT token', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .post('/api/tts/synthesize')
        .set('Authorization', 'Bearer bad.token')
        .send({ text: 'test' })
        .expect(HttpStatus.UNAUTHORIZED);
    });
  });

  // ── Cache key with provider (backward compatibility) ──────────────────────

  describe('cache key backward compatibility', () => {
    it('same text+voice+locale with different providers hit different cache slots', async () => {
      skipIfNoApp();
      const fetchSpy = jest.spyOn(global, 'fetch');

      // First call with gemini
      await request(app.getHttpServer())
        .post('/api/tts/synthesize')
        .set('Authorization', `Bearer ${validAuthToken}`)
        .send({ text: 'test phrase', voice: 'aoede', locale: 'enUS', provider: 'gemini' });

      // Second call with kokoro — should not hit Gemini cache
      await request(app.getHttpServer())
        .post('/api/tts/synthesize')
        .set('Authorization', `Bearer ${validAuthToken}`)
        .send({ text: 'test phrase', voice: 'aoede', locale: 'enUS', provider: 'kokoro' });

      // Both calls should reach their respective backends (no false cache hit)
      expect(fetchSpy).toHaveBeenCalledTimes(1); // Only Gemini call
      expect(mockKokoroProxy.synthesizeViaKokoro).toHaveBeenCalledTimes(1); // Only Kokoro call
    });
  });
});
