import { Injectable, Logger } from '@nestjs/common';
import { Redis } from '@upstash/redis';
import { ElevenLabsProxyService } from './elevenlabs-proxy.service';

// ── Redis catalog cache ───────────────────────────────────────────────────────

/** Redis key for the full provider catalog JSON. */
const CATALOG_CACHE_KEY = 'tts:provider-catalog';

/** Catalog cache TTL in seconds (60 minutes). */
const CATALOG_CACHE_TTL_SEC = 3600;


export interface VoiceOption {
  id: string;
  label: string;
}

export interface LocaleOption {
  id: string;
  label: string;
}

export interface ProviderConfig {
  id: string;
  label: string;
  voices: VoiceOption[];
  locales: LocaleOption[];
  /** Maps foreign voice IDs → this provider's native voice IDs. */
  voiceMap: Record<string, string>;
}

// ── Gemini static voice/locale catalog ───────────────────────────────────────

const GEMINI_VOICES: VoiceOption[] = [
  { id: 'aoede', label: 'Aoede' },
  { id: 'charon', label: 'Charon' },
  { id: 'fenrir', label: 'Fenrir' },
  { id: 'kore', label: 'Kore' },
  { id: 'leda', label: 'Leda' },
  { id: 'orus', label: 'Orus' },
  { id: 'puck', label: 'Puck' },
  { id: 'schedar', label: 'Schedar' },
  { id: 'zephyr', label: 'Zephyr' },
];

const GEMINI_LOCALES: LocaleOption[] = [
  // English accents
  { id: 'enUS', label: 'English (US)' },
  { id: 'enGB', label: 'English (UK)' },
  { id: 'enIN', label: 'English (India)' },
  { id: 'enAU', label: 'English (Australia)' },
  { id: 'enCA', label: 'English (Canada)' },
  // Non-English languages routed to Gemini TTS
  { id: 'es', label: 'Spanish' },
  { id: 'fr', label: 'French' },
  { id: 'de', label: 'German' },
  { id: 'ja', label: 'Japanese' },
  { id: 'pt', label: 'Portuguese' },
  { id: 'it', label: 'Italian' },
  { id: 'ar', label: 'Arabic' },
  { id: 'zh', label: 'Mandarin Chinese' },
  { id: 'ko', label: 'Korean' },
  { id: 'ru', label: 'Russian' },
];

// ── Kokoro fallback catalog (used when Kokoro server is unreachable) ──────────

// Mirrors VOICE_CATALOG in kokoro-server/tts_engine.py — keep in sync.
const KOKORO_FALLBACK_VOICES: VoiceOption[] = [
  // American English — Female
  { id: 'af_heart', label: 'Heart (Female, US)' },
  { id: 'af_sky', label: 'Sky (Female, US)' },
  { id: 'af_bella', label: 'Bella (Female, US)' },
  { id: 'af_sarah', label: 'Sarah (Female, US)' },
  { id: 'af_nicole', label: 'Nicole (Female, US)' },
  { id: 'af_nova', label: 'Nova (Female, US)' },
  // American English — Male
  { id: 'am_adam', label: 'Adam (Male, US)' },
  { id: 'am_michael', label: 'Michael (Male, US)' },
  { id: 'am_echo', label: 'Echo (Male, US)' },
  { id: 'am_eric', label: 'Eric (Male, US)' },
  { id: 'am_liam', label: 'Liam (Male, US)' },
  { id: 'am_onyx', label: 'Onyx (Male, US)' },
  // British English — Female
  { id: 'bf_emma', label: 'Emma (Female, UK)' },
  { id: 'bf_isabella', label: 'Isabella (Female, UK)' },
  { id: 'bf_alice', label: 'Alice (Female, UK)' },
  { id: 'bf_lily', label: 'Lily (Female, UK)' },
  // British English — Male
  { id: 'bm_george', label: 'George (Male, UK)' },
  { id: 'bm_lewis', label: 'Lewis (Male, UK)' },
  { id: 'bm_daniel', label: 'Daniel (Male, UK)' },
  { id: 'bm_fable', label: 'Fable (Male, UK)' },
  // Hindi — Female
  { id: 'hf_alpha', label: 'Alpha (Female, Hindi)' },
  { id: 'hf_beta', label: 'Beta (Female, Hindi)' },
  // Hindi — Male
  { id: 'hm_omega', label: 'Omega (Male, Hindi)' },
  { id: 'hm_psi', label: 'Psi (Male, Hindi)' },
];

const KOKORO_FALLBACK_LOCALES: LocaleOption[] = [
  { id: 'en-us', label: 'English (US)' },
  { id: 'en-gb', label: 'English (UK)' },
  { id: 'hi', label: 'Hindi' },
];

// ── ElevenLabs static voice/locale catalog ──────────────────────────────────
// Popular pre-made ElevenLabs voices. The live list is fetched at runtime
// when the API key is set; this catalog is the fallback.

const ELEVENLABS_FALLBACK_VOICES: VoiceOption[] = [
  { id: 'EXAVITQu4vr4xnSDxMaL', label: 'Sarah (Female)' },
  { id: 'FGY2WhTYpPnrIDTdsKH5', label: 'Laura (Female)' },
  { id: 'IKne3meq5aSn9XLyUdCD', label: 'Charlie (Male)' },
  { id: 'JBFqnCBsd6RMkjVDRZzb', label: 'George (Male)' },
  { id: 'TX3LPaxmHKxFdv7VOQHJ', label: 'Liam (Male)' },
  { id: 'XB0fDUnXU5powFXDhCwa', label: 'Charlotte (Female)' },
  { id: 'Xb7hH8MSUJpSbSDYk0k2', label: 'Alice (Female)' },
  { id: 'bIHbv24MWmeRgasZH58o', label: 'Will (Male)' },
  { id: 'cgSgspJ2msm6clMCkdW9', label: 'Jessica (Female)' },
  { id: 'cjVigY5qzO86Huf0OWal', label: 'Eric (Male)' },
  { id: 'iP95p4xoKVk53GoZ742B', label: 'Chris (Male)' },
  { id: 'nPczCjzI2devNBz1zQrb', label: 'Brian (Male)' },
  { id: 'onwK4e9ZLuTAKqWW03F9', label: 'Daniel (Male)' },
  { id: 'pFZP5JQG7iQjIQuC4Bku', label: 'Lily (Female)' },
  { id: 'pqHfZKP75CvOlQylNhV4', label: 'Bill (Male)' },
];

// ElevenLabs handles accent via the voice itself and the model — locale
// selection is less meaningful than Gemini/Kokoro. We expose a single
// "English" locale so the settings UI stays consistent.
const ELEVENLABS_LOCALES: LocaleOption[] = [
  { id: 'en', label: 'English' },
];

// ── Cross-provider voice mappings ───────────────────────────────────────────
// Maps foreign voice IDs → native voice IDs for each provider.
// Included in the /api/tts/providers response so the frontend can remap
// plan voices when the user switches providers.

/** Maps Kokoro + ElevenLabs voice IDs → nearest Gemini equivalent. */
export const GEMINI_VOICE_MAP: Record<string, string> = {
  // Kokoro → Gemini
  af_heart: 'aoede',
  af_sky: 'zephyr',
  af_bella: 'leda',
  af_sarah: 'leda',
  af_nicole: 'kore',
  af_nova: 'aoede',
  am_adam: 'charon',
  am_michael: 'puck',
  am_echo: 'charon',
  am_eric: 'fenrir',
  am_liam: 'puck',
  am_onyx: 'charon',
  bf_emma: 'leda',
  bf_isabella: 'kore',
  bf_alice: 'leda',
  bf_lily: 'leda',
  bm_george: 'charon',
  bm_lewis: 'puck',
  bm_daniel: 'puck',
  bm_fable: 'fenrir',
  // ElevenLabs → Gemini
  EXAVITQu4vr4xnSDxMaL: 'aoede',    // Sarah → Aoede
  FGY2WhTYpPnrIDTdsKH5: 'leda',     // Laura → Leda
  IKne3meq5aSn9XLyUdCD: 'puck',     // Charlie → Puck
  JBFqnCBsd6RMkjVDRZzb: 'charon',   // George → Charon
  TX3LPaxmHKxFdv7VOQHJ: 'orus',     // Liam → Orus
  XB0fDUnXU5powFXDhCwa: 'kore',     // Charlotte → Kore
  Xb7hH8MSUJpSbSDYk0k2: 'leda',    // Alice → Leda
  bIHbv24MWmeRgasZH58o: 'fenrir',   // Will → Fenrir
  cgSgspJ2msm6clMCkdW9: 'leda',     // Jessica → Leda
  cjVigY5qzO86Huf0OWal: 'fenrir',   // Eric → Fenrir
  iP95p4xoKVk53GoZ742B: 'charon',   // Chris → Charon
  nPczCjzI2devNBz1zQrb: 'schedar',  // Brian → Schedar
  onwK4e9ZLuTAKqWW03F9: 'puck',     // Daniel → Puck
  pFZP5JQG7iQjIQuC4Bku: 'zephyr',   // Lily → Zephyr
  pqHfZKP75CvOlQylNhV4: 'charon',   // Bill → Charon
};

/** Maps Gemini + ElevenLabs voice IDs → nearest Kokoro equivalent. */
const KOKORO_VOICE_MAP: Record<string, string> = {
  // Gemini → Kokoro
  aoede: 'af_heart',
  leda: 'af_bella',
  kore: 'af_nicole',
  charon: 'am_adam',
  puck: 'am_michael',
  fenrir: 'am_eric',
  orus: 'am_liam',
  schedar: 'am_echo',
  zephyr: 'af_sky',
  // ElevenLabs → Kokoro
  EXAVITQu4vr4xnSDxMaL: 'af_heart',   // Sarah → Heart
  FGY2WhTYpPnrIDTdsKH5: 'af_bella',    // Laura → Bella
  IKne3meq5aSn9XLyUdCD: 'am_michael',  // Charlie → Michael
  JBFqnCBsd6RMkjVDRZzb: 'bm_george',   // George → George
  TX3LPaxmHKxFdv7VOQHJ: 'am_liam',    // Liam → Liam
  XB0fDUnXU5powFXDhCwa: 'af_nicole',   // Charlotte → Nicole
  Xb7hH8MSUJpSbSDYk0k2: 'bf_alice',   // Alice → Alice
  bIHbv24MWmeRgasZH58o: 'am_adam',     // Will → Adam
  cgSgspJ2msm6clMCkdW9: 'af_bella',    // Jessica → Bella
  cjVigY5qzO86Huf0OWal: 'am_eric',     // Eric → Eric
  iP95p4xoKVk53GoZ742B: 'am_adam',     // Chris → Adam
  nPczCjzI2devNBz1zQrb: 'am_echo',     // Brian → Echo
  onwK4e9ZLuTAKqWW03F9: 'bm_daniel',   // Daniel → Daniel
  pFZP5JQG7iQjIQuC4Bku: 'bf_lily',     // Lily → Lily
  pqHfZKP75CvOlQylNhV4: 'am_onyx',     // Bill → Onyx
};

/** Maps Gemini + Kokoro voice IDs → nearest ElevenLabs equivalent. */
const ELEVENLABS_VOICE_MAP: Record<string, string> = {
  // Gemini → ElevenLabs
  aoede: 'EXAVITQu4vr4xnSDxMaL',   // Sarah
  leda: 'cgSgspJ2msm6clMCkdW9',     // Jessica
  kore: 'XB0fDUnXU5powFXDhCwa',     // Charlotte
  charon: 'JBFqnCBsd6RMkjVDRZzb',   // George
  puck: 'IKne3meq5aSn9XLyUdCD',     // Charlie
  fenrir: 'cjVigY5qzO86Huf0OWal',   // Eric
  orus: 'TX3LPaxmHKxFdv7VOQHJ',     // Liam
  schedar: 'nPczCjzI2devNBz1zQrb',  // Brian
  zephyr: 'pFZP5JQG7iQjIQuC4Bku',   // Lily
  // Kokoro → ElevenLabs
  af_heart: 'EXAVITQu4vr4xnSDxMaL',  // Sarah
  af_sky: 'pFZP5JQG7iQjIQuC4Bku',    // Lily
  af_bella: 'cgSgspJ2msm6clMCkdW9',   // Jessica
  af_sarah: 'EXAVITQu4vr4xnSDxMaL',  // Sarah
  af_nicole: 'XB0fDUnXU5powFXDhCwa',  // Charlotte
  af_nova: 'FGY2WhTYpPnrIDTdsKH5',   // Laura
  am_adam: 'JBFqnCBsd6RMkjVDRZzb',    // George
  am_michael: 'IKne3meq5aSn9XLyUdCD', // Charlie
  am_echo: 'nPczCjzI2devNBz1zQrb',    // Brian
  am_eric: 'cjVigY5qzO86Huf0OWal',    // Eric
  am_liam: 'TX3LPaxmHKxFdv7VOQHJ',   // Liam
  am_onyx: 'pqHfZKP75CvOlQylNhV4',   // Bill
  bf_emma: 'Xb7hH8MSUJpSbSDYk0k2',   // Alice
  bf_isabella: 'XB0fDUnXU5powFXDhCwa',// Charlotte
  bf_alice: 'Xb7hH8MSUJpSbSDYk0k2',  // Alice
  bf_lily: 'pFZP5JQG7iQjIQuC4Bku',   // Lily
  bm_george: 'JBFqnCBsd6RMkjVDRZzb',  // George
  bm_lewis: 'IKne3meq5aSn9XLyUdCD',   // Charlie
  bm_daniel: 'onwK4e9ZLuTAKqWW03F9',  // Daniel
  bm_fable: 'bIHbv24MWmeRgasZH58o',   // Will
};

@Injectable()
export class ProviderRegistryService {
  private readonly logger = new Logger(ProviderRegistryService.name);
  private readonly kokoroUrl: string;
  private readonly redis: Redis | null;
  private readonly cacheNoop: boolean;

  constructor(private readonly elevenLabs: ElevenLabsProxyService) {
    this.kokoroUrl =
      process.env.KOKORO_SERVER_URL ?? 'http://127.0.0.1:3070';
    const url = process.env.UPSTASH_REDIS_REST_URL ?? '';
    const token = process.env.UPSTASH_REDIS_REST_TOKEN ?? '';
    this.cacheNoop = url === '';
    this.redis = this.cacheNoop ? null : new Redis({ url, token });
    if (this.cacheNoop) {
      this.logger.warn('UPSTASH_REDIS_REST_URL not set — provider catalog caching disabled');
    }
  }

  /** Returns the static list of registered provider IDs. */
  getProviderIds(): string[] {
    return ['gemini', 'kokoro', 'elevenlabs'];
  }

  /** Returns true if the given provider ID is registered. */
  isKnownProvider(id: string): boolean {
    return this.getProviderIds().includes(id);
  }

  /**
   * Returns provider configs for the requested provider(s).
   *
   * When no provider filter is specified (all providers requested), results
   * are cached in Upstash Redis with a 3600s TTL. Cache misses and
   * single-provider queries fetch fresh data from upstream services.
   *
   * Kokoro voices are fetched live from the Python server; falls back to
   * a static list if the server is unreachable.
   * ElevenLabs voices are fetched from the API when a key is configured.
   */
  async getProviders(provider?: string): Promise<ProviderConfig[]> {
    // Always operate on the full catalog — fetch/cache all 3 providers, then
    // filter to the requested provider if one was specified.
    const cached = await this._getCachedCatalog();
    if (cached !== null) {
      this.logger.log('Provider catalog cache HIT');
      return provider ? cached.filter(c => c.id === provider) : cached;
    }

    this.logger.log('Provider catalog cache MISS — fetching live');

    const allConfigs: ProviderConfig[] = [
      {
        id: 'gemini',
        label: 'Google Gemini TTS',
        voices: GEMINI_VOICES,
        locales: GEMINI_LOCALES,
        voiceMap: GEMINI_VOICE_MAP,
      },
      await this.getKokoroConfig(),
      await this.getElevenLabsConfig(),
    ];

    // Fire-and-forget: store in Redis without blocking the response.
    this._setCachedCatalog(allConfigs);

    return provider ? allConfigs.filter(c => c.id === provider) : allConfigs;
  }

  // ── Redis cache helpers ───────────────────────────────────────────────────

  /**
   * Attempts to read the provider catalog from Redis.
   * Returns null on cache miss, Redis error, or noop mode.
   * All errors are swallowed so callers always fall back to live fetch.
   */
  private async _getCachedCatalog(): Promise<ProviderConfig[] | null> {
    if (this.cacheNoop) return null;
    try {
      const raw = await this.redis!.get<string>(CATALOG_CACHE_KEY);
      if (!raw) return null;
      const parsed = JSON.parse(raw) as ProviderConfig[];
      return parsed;
    } catch (err) {
      this.logger.warn(`Redis catalog GET failed — falling back to live fetch: ${err}`);
      return null;
    }
  }

  /**
   * Stores the provider catalog in Redis with a CATALOG_CACHE_TTL_SEC TTL.
   * All errors are swallowed so a Redis failure never blocks the response.
   */
  private async _setCachedCatalog(configs: ProviderConfig[]): Promise<void> {
    if (this.cacheNoop) return;
    try {
      await this.redis!.set(CATALOG_CACHE_KEY, JSON.stringify(configs), {
        ex: CATALOG_CACHE_TTL_SEC,
      });
      this.logger.debug('Provider catalog stored in Redis cache');
    } catch (err) {
      this.logger.warn(`Redis catalog SET failed (non-fatal): ${err}`);
    }
  }

  private async getKokoroConfig(): Promise<ProviderConfig> {
    try {
      const resp = await fetch(`${this.kokoroUrl}/voices`, {
        signal: AbortSignal.timeout(5_000),
      });
      if (resp.ok) {
        const data = (await resp.json()) as { voices: Array<{ id: string; label: string }> };
        const voices: VoiceOption[] = data.voices.map((v) => ({
          id: v.id,
          label: v.label ?? v.id,
        }));
        return {
          id: 'kokoro',
          label: 'Kokoro TTS (Self-Hosted)',
          voices,
          locales: KOKORO_FALLBACK_LOCALES,
          voiceMap: KOKORO_VOICE_MAP,
        };
      }
    } catch {
      this.logger.warn('Kokoro server unreachable — using fallback voice list');
    }

    return {
      id: 'kokoro',
      label: 'Kokoro TTS (Self-Hosted)',
      voices: KOKORO_FALLBACK_VOICES,
      locales: KOKORO_FALLBACK_LOCALES,
      voiceMap: KOKORO_VOICE_MAP,
    };
  }

  private async getElevenLabsConfig(): Promise<ProviderConfig> {
    try {
      const apiVoices = await this.elevenLabs.fetchVoices();
      if (apiVoices.length > 0) {
        const voices: VoiceOption[] = apiVoices.map((v) => ({
          id: v.voice_id,
          label: v.name,
        }));
        return {
          id: 'elevenlabs',
          label: 'ElevenLabs',
          voices,
          locales: ELEVENLABS_LOCALES,
          voiceMap: ELEVENLABS_VOICE_MAP,
        };
      }
    } catch {
      this.logger.warn('ElevenLabs API unreachable — using fallback voice list');
    }

    return {
      id: 'elevenlabs',
      label: 'ElevenLabs',
      voices: ELEVENLABS_FALLBACK_VOICES,
      locales: ELEVENLABS_LOCALES,
      voiceMap: ELEVENLABS_VOICE_MAP,
    };
  }
}
