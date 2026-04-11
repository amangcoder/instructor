/**
 * Unit tests for ProviderRegistryService — ProviderCatalogCache behaviour.
 *
 * Covers TASK-001 acceptance criteria:
 *   (1) CATALOG_CACHE_KEY is consistent between GET and SET operations.
 *   (2) redis.set and redis.get work with 3600 s TTL.
 *   (3) Cache gracefully returns fresh data when Redis is unavailable.
 *   (4) Cache hit, miss, expiry (null return = expired key), and fallback
 *       scenarios are all exercised with >90 % coverage of the cache helpers.
 */

import { Test, TestingModule } from '@nestjs/testing';
import { ProviderRegistryService, ProviderConfig } from './provider-registry.service';
import { ElevenLabsProxyService } from './elevenlabs-proxy.service';

// ---------------------------------------------------------------------------
// Mock @upstash/redis
// We intercept the Redis constructor and expose per-test mock fns.
// ---------------------------------------------------------------------------

const mockRedisGet = jest.fn();
const mockRedisSet = jest.fn();

jest.mock('@upstash/redis', () => ({
  Redis: jest.fn().mockImplementation(() => ({
    get: mockRedisGet,
    set: mockRedisSet,
  })),
}));

// ---------------------------------------------------------------------------
// Mock global fetch (used by getKokoroConfig)
// ---------------------------------------------------------------------------

const mockFetch = jest.fn();
(global as unknown as Record<string, unknown>).fetch = mockFetch;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const CATALOG_CACHE_KEY = 'tts:provider-catalog'; // must match service constant

function makeSampleCatalog(): ProviderConfig[] {
  return [
    {
      id: 'gemini',
      label: 'Google Gemini TTS',
      voices: [{ id: 'aoede', label: 'Aoede' }],
      locales: [{ id: 'enUS', label: 'English (US)' }],
      voiceMap: {},
    },
    {
      id: 'kokoro',
      label: 'Kokoro TTS (Self-Hosted)',
      voices: [{ id: 'af_heart', label: 'Heart (Female, US)' }],
      locales: [{ id: 'en-us', label: 'English (US)' }],
      voiceMap: {},
    },
    {
      id: 'elevenlabs',
      label: 'ElevenLabs',
      voices: [{ id: 'EXAVITQu4vr4xnSDxMaL', label: 'Sarah (Female)' }],
      locales: [{ id: 'en', label: 'English' }],
      voiceMap: {},
    },
  ];
}

/** Build a minimal OK Kokoro /voices HTTP response. */
function makeKokoroResponse(voices: Array<{ id: string; label: string }>) {
  return {
    ok: true,
    json: jest.fn().mockResolvedValue({ voices }),
  };
}

// ---------------------------------------------------------------------------
// Suite
// ---------------------------------------------------------------------------

describe('ProviderRegistryService — ProviderCatalogCache', () => {
  let service: ProviderRegistryService;
  let mockElevenLabs: jest.Mocked<ElevenLabsProxyService>;

  beforeEach(async () => {
    // Reset all mock state before each test.
    jest.clearAllMocks();
    mockRedisGet.mockReset();
    mockRedisSet.mockReset();
    mockFetch.mockReset();

    // Set env vars so Redis is not in noop mode.
    process.env.UPSTASH_REDIS_REST_URL = 'https://redis.example.upstash.io';
    process.env.UPSTASH_REDIS_REST_TOKEN = 'test-token';
    process.env.KOKORO_SERVER_URL = 'http://127.0.0.1:3070';

    mockElevenLabs = {
      fetchVoices: jest.fn().mockResolvedValue([]),
    } as unknown as jest.Mocked<ElevenLabsProxyService>;

    // Default: Kokoro server unreachable (fetch rejects) → fallback voices.
    mockFetch.mockRejectedValue(new Error('ECONNREFUSED'));

    // Default: Redis SET succeeds.
    mockRedisSet.mockResolvedValue('OK');

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ProviderRegistryService,
        { provide: ElevenLabsProxyService, useValue: mockElevenLabs },
      ],
    }).compile();

    service = module.get<ProviderRegistryService>(ProviderRegistryService);
  });

  afterEach(() => {
    delete process.env.UPSTASH_REDIS_REST_URL;
    delete process.env.UPSTASH_REDIS_REST_TOKEN;
  });

  // -------------------------------------------------------------------------
  // (1) Cache HIT — Redis returns serialised catalog
  // -------------------------------------------------------------------------

  describe('cache HIT', () => {
    it('returns parsed catalog from Redis without calling Kokoro or ElevenLabs', async () => {
      const catalog = makeSampleCatalog();
      mockRedisGet.mockResolvedValue(JSON.stringify(catalog));

      const result = await service.getProviders();

      // Result must match the cached data exactly.
      expect(result).toEqual(catalog);

      // No upstream service calls.
      expect(mockFetch).not.toHaveBeenCalled();
      expect(mockElevenLabs.fetchVoices).not.toHaveBeenCalled();
    });

    it('uses consistent CATALOG_CACHE_KEY for GET operation', async () => {
      const catalog = makeSampleCatalog();
      mockRedisGet.mockResolvedValue(JSON.stringify(catalog));

      await service.getProviders();

      // Redis GET must be called with the canonical cache key.
      expect(mockRedisGet).toHaveBeenCalledWith(CATALOG_CACHE_KEY);
    });

    it('filters by provider when ?provider= is specified (cache hit path)', async () => {
      const catalog = makeSampleCatalog();
      mockRedisGet.mockResolvedValue(JSON.stringify(catalog));

      const result = await service.getProviders('gemini');

      expect(result).toHaveLength(1);
      expect(result[0].id).toBe('gemini');
    });

    it('second call uses cache — Redis GET called twice, SET never called', async () => {
      const catalog = makeSampleCatalog();
      // Both calls hit cache.
      mockRedisGet.mockResolvedValue(JSON.stringify(catalog));

      await service.getProviders();
      await service.getProviders();

      expect(mockRedisGet).toHaveBeenCalledTimes(2);
      expect(mockRedisSet).not.toHaveBeenCalled();
    });
  });

  // -------------------------------------------------------------------------
  // (2) Cache MISS — Redis returns null, fetch fresh data & store
  // -------------------------------------------------------------------------

  describe('cache MISS', () => {
    it('fetches fresh catalog when Redis returns null', async () => {
      // Cache miss.
      mockRedisGet.mockResolvedValue(null);

      const result = await service.getProviders();

      // Should return 3 providers (gemini, kokoro fallback, elevenlabs fallback).
      expect(result.map(p => p.id)).toEqual(['gemini', 'kokoro', 'elevenlabs']);
    });

    it('uses consistent CATALOG_CACHE_KEY for SET operation', async () => {
      mockRedisGet.mockResolvedValue(null);

      await service.getProviders();

      // Allow micro-task queue to flush the fire-and-forget _setCachedCatalog.
      await new Promise(resolve => setImmediate(resolve));

      // Redis SET must be called with the same canonical cache key.
      expect(mockRedisSet).toHaveBeenCalledWith(
        CATALOG_CACHE_KEY,
        expect.any(String),
        { ex: 3600 },
      );
    });

    it('stores valid JSON in Redis on cache miss', async () => {
      mockRedisGet.mockResolvedValue(null);

      await service.getProviders();
      await new Promise(resolve => setImmediate(resolve));

      const setArgs = mockRedisSet.mock.calls[0];
      const stored = JSON.parse(setArgs[1] as string) as ProviderConfig[];
      expect(stored).toBeInstanceOf(Array);
      expect(stored.length).toBeGreaterThan(0);
      stored.forEach(p => {
        expect(p).toHaveProperty('id');
        expect(p).toHaveProperty('voices');
        expect(p).toHaveProperty('locales');
        expect(p).toHaveProperty('voiceMap');
      });
    });

    it('includes live Kokoro voices when server is reachable (cache miss path)', async () => {
      mockRedisGet.mockResolvedValue(null);
      const liveVoices = [
        { id: 'af_heart', label: 'Heart' },
        { id: 'am_custom', label: 'Custom Male' },
      ];
      mockFetch.mockResolvedValue(makeKokoroResponse(liveVoices));

      const result = await service.getProviders();

      const kokoro = result.find(p => p.id === 'kokoro');
      expect(kokoro).toBeDefined();
      expect(kokoro!.voices.map(v => v.id)).toEqual(['af_heart', 'am_custom']);
    });

    it('uses fallback voices when Kokoro server is unreachable (cache miss path)', async () => {
      mockRedisGet.mockResolvedValue(null);
      // fetch rejects (already set in beforeEach but be explicit here).
      mockFetch.mockRejectedValue(new Error('ECONNREFUSED'));

      const result = await service.getProviders();

      const kokoro = result.find(p => p.id === 'kokoro');
      expect(kokoro).toBeDefined();
      // Fallback must include at least one voice.
      expect(kokoro!.voices.length).toBeGreaterThan(0);
    });

    it('uses ElevenLabs live voices when API key is set (cache miss path)', async () => {
      mockRedisGet.mockResolvedValue(null);
      const apiVoices = [
        { voice_id: 'voice-abc', name: 'Custom Voice' },
      ];
      mockElevenLabs.fetchVoices.mockResolvedValue(apiVoices);

      const result = await service.getProviders();

      const el = result.find(p => p.id === 'elevenlabs');
      expect(el).toBeDefined();
      expect(el!.voices).toEqual([{ id: 'voice-abc', label: 'Custom Voice' }]);
    });
  });

  // -------------------------------------------------------------------------
  // (3) Cache EXPIRY — expired Redis key returns null (same as miss)
  // -------------------------------------------------------------------------

  describe('cache EXPIRY (expired key returns null from Redis)', () => {
    it('treats null response as expired/missing — fetches fresh data', async () => {
      // Simulate TTL expiry: Redis returns null for the key.
      mockRedisGet.mockResolvedValue(null);

      const result = await service.getProviders();

      // Should still return valid data.
      expect(result.length).toBeGreaterThan(0);
      // Should attempt to repopulate the cache.
      await new Promise(resolve => setImmediate(resolve));
      expect(mockRedisSet).toHaveBeenCalledWith(
        CATALOG_CACHE_KEY,
        expect.any(String),
        { ex: 3600 },
      );
    });

    it('TTL set to 3600 seconds on every cache store operation', async () => {
      mockRedisGet.mockResolvedValue(null);

      await service.getProviders();
      await new Promise(resolve => setImmediate(resolve));

      const setArgs = mockRedisSet.mock.calls[0];
      // Third argument is the options object: { ex: 3600 }
      expect(setArgs[2]).toEqual({ ex: 3600 });
    });
  });

  // -------------------------------------------------------------------------
  // (4) FALLBACK — Redis unavailable (connection error / timeout)
  // -------------------------------------------------------------------------

  describe('fallback — Redis unavailable', () => {
    it('returns fresh catalog when Redis GET throws a connection error', async () => {
      mockRedisGet.mockRejectedValue(new Error('Redis connection refused'));

      const result = await service.getProviders();

      // Must still return valid provider data.
      expect(result.map(p => p.id)).toEqual(['gemini', 'kokoro', 'elevenlabs']);
    });

    it('returns fresh catalog when Redis GET times out', async () => {
      mockRedisGet.mockRejectedValue(new Error('Redis request timeout'));

      const result = await service.getProviders();

      expect(result.length).toBeGreaterThan(0);
    });

    it('does not throw when Redis SET fails (fire-and-forget is non-fatal)', async () => {
      mockRedisGet.mockResolvedValue(null);
      mockRedisSet.mockRejectedValue(new Error('Redis write failure'));

      // getProviders must resolve without throwing even if SET fails.
      await expect(service.getProviders()).resolves.toBeDefined();

      // Wait for the fire-and-forget SET to settle.
      await new Promise(resolve => setImmediate(resolve));
    });

    it('still fetches from Kokoro after Redis GET fails', async () => {
      mockRedisGet.mockRejectedValue(new Error('Redis unavailable'));
      const liveVoices = [{ id: 'af_heart', label: 'Heart' }];
      mockFetch.mockResolvedValue(makeKokoroResponse(liveVoices));

      const result = await service.getProviders();

      const kokoro = result.find(p => p.id === 'kokoro');
      expect(kokoro!.voices[0].id).toBe('af_heart');
    });

    it('still fetches from ElevenLabs after Redis GET fails', async () => {
      mockRedisGet.mockRejectedValue(new Error('Redis unavailable'));
      const apiVoices = [{ voice_id: 'voice-xyz', name: 'Live Voice' }];
      mockElevenLabs.fetchVoices.mockResolvedValue(apiVoices);

      const result = await service.getProviders();

      const el = result.find(p => p.id === 'elevenlabs');
      expect(el!.voices[0].id).toBe('voice-xyz');
    });
  });

  // -------------------------------------------------------------------------
  // (5) NOOP mode — Redis env vars not set
  // -------------------------------------------------------------------------

  describe('noop mode (Redis env vars absent)', () => {
    beforeEach(async () => {
      // Remove env vars and rebuild service without Redis credentials.
      delete process.env.UPSTASH_REDIS_REST_URL;
      delete process.env.UPSTASH_REDIS_REST_TOKEN;

      const module: TestingModule = await Test.createTestingModule({
        providers: [
          ProviderRegistryService,
          { provide: ElevenLabsProxyService, useValue: mockElevenLabs },
        ],
      }).compile();

      service = module.get<ProviderRegistryService>(ProviderRegistryService);
    });

    it('returns fresh catalog without any Redis calls in noop mode', async () => {
      // Re-reset Redis mocks to ensure they are not called.
      mockRedisGet.mockReset();
      mockRedisSet.mockReset();

      const result = await service.getProviders();

      expect(result.length).toBeGreaterThan(0);
      expect(mockRedisGet).not.toHaveBeenCalled();
      expect(mockRedisSet).not.toHaveBeenCalled();
    });
  });

  // -------------------------------------------------------------------------
  // (6) Cache key consistency
  // -------------------------------------------------------------------------

  describe('cache key consistency', () => {
    it('GET and SET both use the same CATALOG_CACHE_KEY', async () => {
      // First call: cache miss → SET.
      mockRedisGet.mockResolvedValue(null);
      await service.getProviders();
      await new Promise(resolve => setImmediate(resolve));

      const getKey = mockRedisGet.mock.calls[0][0] as string;
      const setKey = mockRedisSet.mock.calls[0][0] as string;

      expect(getKey).toBe(setKey);
      expect(getKey).toBe(CATALOG_CACHE_KEY);
    });
  });

  // -------------------------------------------------------------------------
  // (7) Static provider helpers
  // -------------------------------------------------------------------------

  describe('getProviderIds and isKnownProvider', () => {
    it('returns the three registered provider IDs', () => {
      expect(service.getProviderIds()).toEqual(['gemini', 'kokoro', 'elevenlabs']);
    });

    it('returns true for known providers', () => {
      expect(service.isKnownProvider('gemini')).toBe(true);
      expect(service.isKnownProvider('kokoro')).toBe(true);
      expect(service.isKnownProvider('elevenlabs')).toBe(true);
    });

    it('returns false for unknown providers', () => {
      expect(service.isKnownProvider('openai')).toBe(false);
      expect(service.isKnownProvider('')).toBe(false);
      expect(service.isKnownProvider('GEMINI')).toBe(false); // case-sensitive
    });
  });
});
