import {
  Injectable,
  Logger,
  BadGatewayException,
  BadRequestException,
  HttpException,
  Optional,
  Inject,
} from '@nestjs/common';
import type { AppConfig } from '../config/app-config.interface';
import { createHash } from 'crypto';
import { existsSync, mkdirSync } from 'fs';
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'path';
import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
} from '@aws-sdk/client-s3';
import {
  ProviderRegistryService,
  GEMINI_VOICE_MAP,
  KOKORO_VOICE_MAP,
} from './providers/provider-registry.service';
import { KokoroProxyService } from './providers/kokoro-proxy.service';
import { ElevenLabsProxyService } from './providers/elevenlabs-proxy.service';
import { buildWav } from './wav-utils';

/**
 * L1: local disk cache directory.
 * On Lambda: /tmp/tts-cache (ephemeral per-container, survives warm invocations).
 * Locally: <cwd>/tts-cache (persistent across restarts).
 */
const TTS_CACHE_DIR = process.env.AWS_LAMBDA_FUNCTION_NAME
  ? '/tmp/tts-cache'
  : join(process.cwd(), 'tts-cache');

/** S3 key prefix for all TTS audio files. */
const S3_PREFIX = 'tts';

/** Maps locale codes to prompt descriptions used in the Gemini TTS prompt. */
const LOCALE_PROMPT_MAP: Record<string, string> = {
  enUS: 'American English accent',
  enGB: 'British English accent',
  enIN: 'Indian English accent',
  enAU: 'Australian English accent',
  enCA: 'Canadian English accent',
  hi: 'Hindi',
  es: 'Spanish',
  fr: 'French',
  de: 'German',
  ja: 'Japanese',
  pt: 'Portuguese',
  it: 'Italian',
  ar: 'Arabic',
  zh: 'Mandarin Chinese',
  ko: 'Korean',
  ru: 'Russian',
};

/**
 * Maps internal locale codes to BCP-47 tags for SSML `<lang xml:lang="...">`.
 * Used when the input text is SSML so we set language inside `<speak>` without
 * a plain-text prefix that would interfere with `<break>` and other SSML tags.
 */
const LOCALE_BCP47_MAP: Record<string, string> = {
  enUS: 'en-US',
  enGB: 'en-GB',
  enIN: 'en-IN',
  enAU: 'en-AU',
  enCA: 'en-CA',
  hi: 'hi-IN',
  es: 'es-ES',
  fr: 'fr-FR',
  de: 'de-DE',
  ja: 'ja-JP',
  pt: 'pt-BR',
  it: 'it-IT',
  ar: 'ar-SA',
  zh: 'zh-CN',
  ko: 'ko-KR',
  ru: 'ru-RU',
};

/** Non-English locales that bypass Kokoro and route to Gemini TTS. */
const NON_ENGLISH_LOCALES = new Set(['es', 'fr', 'de', 'ja', 'pt', 'it', 'ar', 'zh', 'ko', 'ru']);

/** Valid Kokoro voice IDs (English + Hindi). */
const KOKORO_VOICES = new Set([
  // English
  'af_heart', 'af_sky', 'af_bella', 'af_sarah', 'af_nicole', 'af_nova',
  'am_adam', 'am_michael', 'am_echo', 'am_eric', 'am_liam', 'am_onyx',
  'bf_emma', 'bf_isabella', 'bf_alice', 'bf_lily',
  'bm_george', 'bm_lewis', 'bm_daniel', 'bm_fable',
  // Hindi
  'hf_alpha', 'hf_beta', 'hm_omega', 'hm_psi',
]);

/** Valid Gemini voice IDs. */
const GEMINI_VOICES = new Set([
  'aoede', 'charon', 'fenrir', 'kore', 'leda', 'orus', 'puck', 'schedar', 'zephyr',
]);

/** Maps Gemini-style locale codes to Kokoro locale codes. */
const KOKORO_LOCALE_MAP: Record<string, string> = {
  enUS: 'en-us',
  enGB: 'en-gb',
  enIN: 'en-us',
  enAU: 'en-gb',
  enCA: 'en-us',
  hi: 'hi',
};

/**
 * When an English Kokoro voice is requested with Hindi locale, remap to the
 * closest Hindi voice so Kokoro can synthesize it correctly.
 */
const HINDI_VOICE_FALLBACK: Record<string, string> = {
  // Female English → Female Hindi
  af_heart: 'hf_alpha', af_sky: 'hf_alpha', af_bella: 'hf_alpha',
  af_sarah: 'hf_beta',  af_nicole: 'hf_beta', af_nova: 'hf_beta',
  bf_emma: 'hf_alpha',  bf_isabella: 'hf_alpha', bf_alice: 'hf_beta', bf_lily: 'hf_beta',
  // Male English → Male Hindi
  am_adam: 'hm_omega',  am_michael: 'hm_omega', am_echo: 'hm_omega',
  am_eric: 'hm_psi',    am_liam: 'hm_psi',    am_onyx: 'hm_psi',
  bm_george: 'hm_omega', bm_lewis: 'hm_omega', bm_daniel: 'hm_psi', bm_fable: 'hm_psi',
};

/** HTTP status codes that should trigger a retry (Gemini path only). */
const RETRYABLE_STATUSES = new Set([429, 500, 503]);

const GEMINI_TTS_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent';

/**
 * Pulls a human-readable reason out of a Gemini error envelope so the DB
 * `error` column says e.g. "429: Resource exhausted (quota)" instead of the
 * generic "service unavailable". Falls back to a status-based label when the
 * body isn't parseable.
 */
function summarizeGeminiError(status: number, body: string): string {
  const trimmed = (body ?? '').trim();
  if (trimmed) {
    try {
      const parsed = JSON.parse(trimmed) as { error?: { message?: string; status?: string } };
      const msg = parsed?.error?.message;
      if (msg) return msg.slice(0, 300);
    } catch {
      /* fall through to text snippet */
    }
    return trimmed.slice(0, 300);
  }
  if (status === 429) return 'rate limited (quota exhausted)';
  if (status === 503) return 'upstream overloaded';
  if (status === 500) return 'upstream internal error';
  return `HTTP ${status || 'unknown'}`;
}

interface GeminiPart {
  inlineData?: { mimeType?: string; data: string };
  text?: string;
}

interface GeminiCandidate {
  content?: { parts?: GeminiPart[] };
  finishReason?: string;
  safetyRatings?: Array<{ category: string; probability: string }>;
}

interface GeminiResponse {
  candidates?: GeminiCandidate[];
}

@Injectable()
export class TtsService {
  private readonly logger = new Logger(TtsService.name);
  private readonly MAX_RETRIES = 2;
  private readonly s3: S3Client | null;
  private readonly bucket: string | null;

  constructor(
    private readonly providerRegistry: ProviderRegistryService,
    private readonly kokoroProxy: KokoroProxyService,
    private readonly elevenLabsProxy: ElevenLabsProxyService,
    @Optional() @Inject('APP_CONFIG') private readonly config?: AppConfig,
  ) {
    // L1: ensure local cache directory exists.
    if (!existsSync(TTS_CACHE_DIR)) {
      mkdirSync(TTS_CACHE_DIR, { recursive: true });
      this.logger.log(`Created TTS cache directory: ${TTS_CACHE_DIR}`);
    }

    // L2: initialise S3 client if configured.
    this.bucket = (config?.awsS3Bucket || process.env.AWS_S3_BUCKET) ?? null;
    if (this.bucket) {
      this.s3 = new S3Client({
        region: config?.awsRegion ?? process.env.AWS_REGION ?? 'ap-south-1',
      });
      this.logger.log(`S3 cache enabled — bucket=${this.bucket}`);
    } else {
      this.s3 = null;
      this.logger.warn('AWS_S3_BUCKET not set — S3 cache disabled, using local disk only');
    }
  }

  // ── Cache key (provider-inclusive) ───────────────────────────────────────

  /**
   * Canonicalise a locale string before hashing so equivalent values from
   * different sources (DB voices.locale = 'en-US', Dart TtsLocale.name = 'enUS',
   * variants like 'en_US' / 'EN-us') all collapse to a single cache key.
   *
   * MUST stay byte-for-byte identical to Dart's _normalizeLocale in
   * app/lib/utils/hash_utils.dart.
   */
  private static normalizeLocale(locale: string | undefined): string {
    if (!locale) return '';
    return locale.toLowerCase().replace(/[^a-z0-9]/g, '');
  }

  /**
   * Canonicalise speechRate to exactly 1 decimal place so '1', '1.0', '1.00'
   * all hash identically. Falls back to '1.0' on unparseable input.
   *
   * MUST stay byte-for-byte identical to Dart's _normalizeSpeechRate in
   * app/lib/utils/hash_utils.dart.
   */
  private static normalizeSpeechRate(rate: string | undefined): string {
    const n = parseFloat(rate ?? '1.0');
    return Number.isFinite(n) ? n.toFixed(1) : '1.0';
  }

  /**
   * Locale used for cache key hashing. Devanagari text always hashes as 'hi'
   * regardless of the caller's locale so admin pre-gen (which passes the voice's
   * native DB locale, e.g. 'en-US' for am_michael) and the Dart client (which
   * forces locale=hi for Devanagari text via TtsService._effectiveLocale) agree.
   *
   * MUST stay byte-for-byte identical to Dart's _resolveCacheLocale in
   * app/lib/utils/hash_utils.dart.
   */
  private static resolveCacheLocale(text: string, locale: string | undefined): string {
    if (/[ऀ-ॿ]/.test(text)) return 'hi';
    return TtsService.normalizeLocale(locale);
  }

  /**
   * Compute the full-parameter TTS cache key including provider and speechRate.
   *
   * ## Format
   * `SHA-256(JSON.stringify({ locale, provider, speechRate, text, voice }))`
   *
   * Keys are serialised with **alphabetically ordered fields** (matching the order
   * `JSON.stringify` uses when an object is constructed with keys in that order).
   * This produces the same 64-character hex digest as the Flutter client's
   * `hash_utils.dart` `fullParamCacheKey()` / `mediaCacheKey()` functions.
   *
   * ## Fields included (alphabetical order — MUST stay in sync with Flutter client)
   * 1. `locale`     — locale identifier (e.g. `'en-US'`, `'enIN'`); empty string if omitted
   * 2. `provider`   — TTS provider (e.g. `'kokoro'`, `'gemini'`)
   * 3. `speechRate` — playback speed as a **string** (e.g. `'1.0'`, `'1.5'`)
   * 4. `text`       — text to be synthesised
   * 5. `voice`      — voice identifier (e.g. `'af_heart'`, `'aoede'`)
   *
   * ## Example JSON payload (before hashing)
   * ```json
   * {"locale":"en-US","provider":"kokoro","speechRate":"1.0","text":"Hello","voice":"af_heart"}
   * ```
   *
   * ## ⚠️ SYNC WARNING
   * Any change to the field set or key order MUST be mirrored in
   * `app/lib/utils/hash_utils.dart` `fullParamCacheKey()` to avoid cross-platform
   * cache mismatches. See TASK-018 for the cross-platform unit tests.
   */
  /**
   * Generate a cache key for a TTS synthesis job.
   *
   * speechRate is always a string, pre-formatted (e.g. '1.0').
   * Conversion from number happens at the repository boundary
   * (see DatabaseService.mapTtsJobRecord).
   *
   * Object keys MUST be in alphabetical order so JSON.stringify produces
   * the same string as Dart's jsonEncode with an explicitly sorted map.
   * Do NOT reorder or add fields without updating hash_utils.dart simultaneously.
   */
  cacheKey(
    text: string,
    voice: string,
    locale?: string,
    provider = this.config?.defaultTtsProvider ?? process.env.DEFAULT_TTS_PROVIDER ?? 'kokoro',
    speechRate: string = '1.0',
  ): string {
    return createHash('sha256').update(this.cacheKeyPayload(text, voice, locale, provider, speechRate)).digest('hex');
  }

  /**
   * Returns the exact JSON string that gets SHA-256 hashed by `cacheKey()`.
   * Used in cache-miss logs so diverging cache keys can be diffed byte-by-byte.
   */
  cacheKeyPayload(
    text: string,
    voice: string,
    locale?: string,
    provider = this.config?.defaultTtsProvider ?? process.env.DEFAULT_TTS_PROVIDER ?? 'kokoro',
    speechRate: string = '1.0',
  ): string {
    return JSON.stringify({
      locale: TtsService.resolveCacheLocale(text, locale),
      provider,
      speechRate: TtsService.normalizeSpeechRate(speechRate),
      text,
      voice,
    });
  }

  /** Public exposure of the speechRate canonicalisation rule. */
  static canonicalSpeechRate(rate: string | undefined): string {
    return TtsService.normalizeSpeechRate(rate);
  }

  // ── S3 key ────────────────────────────────────────────────────────────────

  private s3Key(hash: string): string {
    return `${S3_PREFIX}/${hash}.wav`;
  }

  // ── L1 (local disk) cache ─────────────────────────────────────────────────

  /** L1: read from local disk. */
  private async readLocalCache(hash: string): Promise<Buffer | null> {
    const filePath = join(TTS_CACHE_DIR, `${hash}.wav`);
    if (existsSync(filePath)) {
      return readFile(filePath);
    }
    return null;
  }

  /** L1: write to local disk. */
  private async writeLocalCache(hash: string, audio: Buffer): Promise<void> {
    const filePath = join(TTS_CACHE_DIR, `${hash}.wav`);
    await writeFile(filePath, audio);
  }

  // ── L2 (S3) cache ─────────────────────────────────────────────────────────

  /** L2: read from S3. Returns null on miss or if S3 is not configured. */
  private async readS3Cache(hash: string): Promise<Buffer | null> {
    if (!this.s3 || !this.bucket) return null;
    try {
      const resp = await this.s3.send(
        new GetObjectCommand({ Bucket: this.bucket, Key: this.s3Key(hash) }),
      );
      const bytes = await resp.Body?.transformToByteArray();
      return bytes ? Buffer.from(bytes) : null;
    } catch (err: any) {
      if (err.name === 'NoSuchKey' || err.$metadata?.httpStatusCode === 404) {
        return null;
      }
      this.logger.warn(`S3 read error for ${hash.slice(0, 12)}…: ${err.message}`);
      return null;
    }
  }

  /** L2: write to S3. Resolves when the upload completes (or logs a warning on failure). */
  private async writeS3Cache(hash: string, audio: Buffer): Promise<void> {
    if (!this.s3 || !this.bucket) return;
    try {
      await this.s3.send(
        new PutObjectCommand({
          Bucket: this.bucket,
          Key: this.s3Key(hash),
          Body: audio,
          ContentType: 'audio/wav',
        }),
      );
      this.logger.log(`S3 upload OK — ${this.s3Key(hash)}, ${audio.length} bytes`);
    } catch (err: any) {
      this.logger.warn(`S3 upload failed for ${hash.slice(0, 12)}…: ${err.message}`);
    }
  }

  /**
   * Two-layer cache lookup:
   *   L1 (local disk) → L2 (S3) → null (miss)
   */
  private async readCache(hash: string): Promise<Buffer | null> {
    // L1 (local disk)
    const local = await this.readLocalCache(hash);
    if (local) return local;

    // L2 (S3)
    const remote = await this.readS3Cache(hash);
    if (remote) {
      await this.writeLocalCache(hash, remote);
      return remote;
    }

    return null;
  }

  /** Writes to both L1 (local disk) and L2 (S3). Resolves only after both writes complete. */
  private async writeCache(hash: string, audio: Buffer): Promise<void> {
    await this.writeLocalCache(hash, audio).catch((err) =>
      this.logger.warn(`L1 cache write failed for ${hash.slice(0, 12)}…: ${err.message}`),
    );
    await this.writeS3Cache(hash, audio);
  }

  // ── Cache-only lookup (no synthesis) ──────────────────────────────────────

  /**
   * Returns cached audio if it exists (L1 → L2), or null on a miss.
   * Does NOT trigger synthesis — safe for unauthenticated callers.
   */
  async checkCacheOnly(
    text: string,
    voice?: string,
    locale?: string,
    provider = this.config?.defaultTtsProvider ?? process.env.DEFAULT_TTS_PROVIDER ?? 'kokoro',
    speechRate = '1.0',
  ): Promise<Buffer | null> {
    const canonicalRate = TtsService.normalizeSpeechRate(speechRate);
    const effectiveVoice = this.resolveEffectiveVoice(voice, provider);
    const hash = this.cacheKey(text, effectiveVoice, locale, provider, canonicalRate);
    const cached = await this.readCache(hash);
    if (!cached) {
      this.logger.log(
        `Cache MISS (checkCacheOnly) — hash=${hash.slice(0, 12)}… payload=${this.cacheKeyPayload(text, effectiveVoice, locale, provider, canonicalRate)}`,
      );
    }
    return cached;
  }

  /**
   * Normalises and remaps an incoming voice ID to the voice actually used for
   * synthesis on the target provider. Applied BEFORE cache key computation so
   * that requests differing only in their input voice (e.g. a Kokoro voice
   * routed to Gemini) collapse onto a single canonical cache entry.
   *
   * Steps:
   *   1. Trim and (for non-ElevenLabs providers) lowercase the input.
   *   2. If the voice is foreign to the provider but has a documented
   *      cross-provider mapping, swap to the mapped voice.
   *
   * Locale-conditional remaps (e.g. Hindi voice fallback) are intentionally
   * NOT applied here — locale is already part of the cache key.
   */
  resolveEffectiveVoice(voice: string | undefined, provider: string): string {
    // ElevenLabs voice IDs are case-sensitive opaque strings — preserve casing.
    // Gemini and Kokoro IDs are lowercase by convention.
    const rawVoice =
      provider === 'elevenlabs'
        ? (voice ?? '').trim()
        : (voice ?? 'aoede').trim().toLowerCase();

    if (provider === 'gemini' && !GEMINI_VOICES.has(rawVoice) && GEMINI_VOICE_MAP[rawVoice]) {
      return GEMINI_VOICE_MAP[rawVoice];
    }
    if (provider === 'kokoro' && !KOKORO_VOICES.has(rawVoice) && KOKORO_VOICE_MAP[rawVoice]) {
      return KOKORO_VOICE_MAP[rawVoice];
    }
    return rawVoice;
  }

  // ── Main synthesis method ─────────────────────────────────────────────────

  async synthesize(
    text: string,
    voice?: string,
    locale?: string,
    provider = this.config?.defaultTtsProvider ?? process.env.DEFAULT_TTS_PROVIDER ?? 'kokoro',
    speechRate = '1.0',
  ): Promise<Buffer> {
    // Validate provider.
    if (!this.providerRegistry.isKnownProvider(provider)) {
      throw new BadRequestException(`Unknown provider: ${provider}`);
    }

    // Canonicalise speechRate to exactly 1 decimal so '1', '1.0', '1.00' all
    // produce the same downstream behaviour (cache key, logs, provider calls).
    const canonicalRate = TtsService.normalizeSpeechRate(speechRate);

    // Resolve raw → effective voice (provider remap) BEFORE hashing so that
    // foreign-voice requests collapse onto a single canonical cache entry.
    const rawVoice =
      provider === 'elevenlabs'
        ? (voice ?? '').trim()
        : (voice ?? 'aoede').trim().toLowerCase();
    const effectiveVoice = this.resolveEffectiveVoice(voice, provider);
    if (effectiveVoice !== rawVoice) {
      this.logger.log(`Voice remap for ${provider}: ${rawVoice} → ${effectiveVoice}`);
    }

    // Compute cache key (provider + speechRate inclusive) using the effective voice.
    const hash = this.cacheKey(text, effectiveVoice, locale, provider, canonicalRate);

    // Cache lookup (L1 → L2).
    const cached = await this.readCache(hash);
    if (cached) {
      this.logger.log(`Cache HIT — hash=${hash.slice(0, 12)}…, ${cached.length} bytes`);
      return cached;
    }
    this.logger.log(
      `Cache MISS — hash=${hash.slice(0, 12)}… payload=${this.cacheKeyPayload(text, effectiveVoice, locale, provider, canonicalRate)}`,
    );

    // Non-English locales bypass Kokoro (English-only) and go directly to Gemini.
    const skipValidation = provider === 'kokoro' && !!locale && NON_ENGLISH_LOCALES.has(locale);

    // Validate voice is native to the requested provider.
    if (!skipValidation) {
      this.validateVoice(effectiveVoice, provider);
    }

    // Route to appropriate provider, falling back to Gemini on failure.
    let audio: Buffer;
    if (provider === 'kokoro') {
      if (locale && NON_ENGLISH_LOCALES.has(locale)) {
        // Kokoro does not support this locale — route to Gemini TTS instead.
        const geminiVoice = GEMINI_VOICE_MAP[effectiveVoice] ?? 'aoede';
        this.logger.log(
          `Kokoro unsupported locale '${locale}' — routing to Gemini voice=${geminiVoice}`,
        );
        audio = await this.synthesizeGemini(text, geminiVoice, locale);
      } else {
        // Detect Devanagari script to force Hindi voice/language even when
        // the client sends an incorrect locale — prevents Kokoro from crashing
        // when it receives Hindi text with an English voice.
        const isDevanagari = /[\u0900-\u097F]/.test(text);
        const effectiveLocale = isDevanagari ? 'hi' : locale;

        // Remap English voice to Hindi voice when Hindi locale is requested.
        const kokoroVoice = (effectiveLocale === 'hi' && HINDI_VOICE_FALLBACK[effectiveVoice])
          ? HINDI_VOICE_FALLBACK[effectiveVoice]
          : effectiveVoice;
        if (kokoroVoice !== effectiveVoice) {
          this.logger.log(`Hindi voice remap: ${effectiveVoice} → ${kokoroVoice}`);
        }
        try {
          audio = await this.synthesizeKokoro(text, kokoroVoice, effectiveLocale ?? 'en-us');
        } catch (err: unknown) {
          const geminiVoice = GEMINI_VOICE_MAP[effectiveVoice] ?? 'charon';
          this.logger.warn(
            `Kokoro failed (${err instanceof Error ? err.message : err}) — falling back to Gemini voice=${geminiVoice}`,
          );
          audio = await this.synthesizeGemini(text, geminiVoice, locale);
        }
      }
    } else if (provider === 'elevenlabs') {
      try {
        audio = await this.synthesizeElevenLabs(text, effectiveVoice);
      } catch (err: unknown) {
        const geminiVoice = GEMINI_VOICE_MAP[effectiveVoice] ?? 'charon';
        this.logger.warn(
          `ElevenLabs failed (${err instanceof Error ? err.message : err}) — falling back to Gemini voice=${geminiVoice}`,
        );
        audio = await this.synthesizeGemini(text, geminiVoice, locale);
      }
    } else {
      audio = await this.synthesizeGemini(text, effectiveVoice, locale);
    }

    // Persist to L1 + L2. Await so callers know the cache is committed before returning.
    await this.writeCache(hash, audio);
    this.logger.log(`Cached — hash=${hash.slice(0, 12)}…, ${audio.length} bytes`);

    return audio;
  }

  // ── Gemini TTS ────────────────────────────────────────────────────────────

  private async synthesizeGemini(
    text: string,
    rawVoice: string,
    locale?: string,
  ): Promise<Buffer> {
    const apiKey = this.config?.geminiApiKey || process.env.GEMINI_API_KEY;
    if (!apiKey) {
      this.logger.error('GEMINI_API_KEY is not set — cannot synthesize via Gemini');
      throw new BadGatewayException('TTS synthesis service is not configured');
    }

    const voiceName = rawVoice.charAt(0).toUpperCase() + rawVoice.slice(1);
    const prompt = this.buildPrompt(text, locale);

    const requestBody = JSON.stringify({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        responseModalities: ['AUDIO'],
        speechConfig: {
          voiceConfig: {
            prebuiltVoiceConfig: { voiceName },
          },
        },
      },
    });

    this.logger.log(
      `Calling Gemini TTS — voice=${voiceName}, locale=${locale ?? 'none'}`,
    );

    let lastStatus = 0;
    let lastErrorBody = '';

    for (let attempt = 0; attempt <= this.MAX_RETRIES; attempt++) {
      if (attempt > 0) {
        this.logger.log(`Retry ${attempt}/${this.MAX_RETRIES} after backoff ${attempt}s`);
        await new Promise<void>((r) => setTimeout(r, attempt * 1000));
      }

      const attemptStart = Date.now();
      let httpResponse: Response;
      try {
        httpResponse = await fetch(GEMINI_TTS_URL, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: requestBody,
          signal: AbortSignal.timeout(600_000),
        });
      } catch (networkError) {
        const msg =
          networkError instanceof Error
            ? networkError.message
            : String(networkError);
        this.logger.error(`Gemini network error after ${Date.now() - attemptStart} ms — ${msg}`);
        throw new Error(`TTS network error: ${msg}`);
      }

      const latencyMs = Date.now() - attemptStart;

      if (httpResponse.ok) {
        this.logger.log(`Gemini responded 200 in ${latencyMs} ms`);
        const data = (await httpResponse.json()) as GeminiResponse;
        const candidate = data?.candidates?.[0];
        const base64Pcm = this.extractBase64(data);
        if (!base64Pcm) {
          const finishReason = candidate?.finishReason ?? 'unknown';
          this.logger.error(
            `No audio in 200 response — finishReason: ${finishReason}`,
          );
          if (attempt < this.MAX_RETRIES) {
            this.logger.warn(`Retrying after empty-audio 200 (attempt ${attempt + 1}/${this.MAX_RETRIES + 1})`);
            continue;
          }
          throw new Error(`No audio inlineData found in Gemini response (finishReason: ${finishReason})`);
        }
        const pcm = Buffer.from(base64Pcm, 'base64');
        this.logger.log(`Decoded PCM ${pcm.length} bytes → building WAV`);
        return buildWav(pcm);
      }

      lastStatus = httpResponse.status;
      // Snapshot the body for retryable failures too, so the final error
      // surfaces a real reason (quota message, server error blurb) up to the
      // DB instead of the generic "service unavailable".
      lastErrorBody = await httpResponse.text().catch(() => '');

      if (RETRYABLE_STATUSES.has(lastStatus) && attempt < this.MAX_RETRIES) {
        this.logger.warn(
          `TTS attempt ${attempt + 1}/${this.MAX_RETRIES + 1} failed with HTTP ${lastStatus} in ${latencyMs} ms, retrying… body=${lastErrorBody.slice(0, 200)}`,
        );
        continue;
      }

      if (!RETRYABLE_STATUSES.has(lastStatus)) {
        this.logger.error(`Gemini non-retryable error ${lastStatus} in ${latencyMs} ms — ${lastErrorBody}`);
        // Map Gemini 400 (invalid voice/params) to 400 for the client.
        // All other non-retryable errors are treated as 502 Bad Gateway.
        if (lastStatus === 400) {
          throw new BadRequestException('Invalid TTS request parameters (voice or locale not supported)');
        }
        throw new HttpException(
          `TTS upstream error: ${lastStatus}`,
          lastStatus >= 500 ? 502 : lastStatus,
        );
      }
      this.logger.error(`Gemini retryable error ${lastStatus} in ${latencyMs} ms — retries exhausted: ${lastErrorBody}`);
      break;
    }

    const reason = summarizeGeminiError(lastStatus, lastErrorBody);
    this.logger.error(
      `TTS failed after ${this.MAX_RETRIES + 1} attempts (last HTTP status: ${lastStatus}) — ${reason}`,
    );
    throw new BadGatewayException(
      `TTS upstream Gemini API failed — last status ${lastStatus}: ${reason}`,
    );
  }

  // ── Kokoro TTS ────────────────────────────────────────────────────────────

  private async synthesizeKokoro(
    text: string,
    voice: string,
    language: string,
  ): Promise<Buffer> {
    // Map Gemini-style locale codes (enIN) to Kokoro format (en-us).
    const lang = KOKORO_LOCALE_MAP[language] ?? language;
    this.logger.log(`Routing to Kokoro — voice=${voice}, lang=${lang}`);
    return this.kokoroProxy.synthesize({ text, voice, language: lang });
  }

  // ── ElevenLabs TTS ─────────────────────────────────────────────────────────

  private async synthesizeElevenLabs(
    text: string,
    voice: string,
  ): Promise<Buffer> {
    this.logger.log(`Routing to ElevenLabs — voice=${voice}`);
    return this.elevenLabsProxy.synthesize({ text, voice });
  }

  // ── Voice validation ──────────────────────────────────────────────────────

  /**
   * Validates that a voice ID is native to the target provider.
   * Throws BadRequestException if the voice doesn't belong to the provider.
   *
   * Cross-provider voice remapping is handled by the frontend when the user
   * switches providers — the backend no longer translates between providers.
   */
  private validateVoice(voice: string, provider: string): void {
    if (provider === 'kokoro') {
      if (!KOKORO_VOICES.has(voice)) {
        throw new BadRequestException(
          `Unknown voice '${voice}' for provider 'kokoro'. Available: ${[...KOKORO_VOICES].join(', ')}`,
        );
      }
      return;
    }

    if (provider === 'elevenlabs') {
      // ElevenLabs voice IDs are opaque strings (e.g. 'EXAVITQu4vr4xnSDxMaL').
      // We don't maintain a static allowlist — the API itself validates them.
      // Just ensure the ID is non-empty.
      if (!voice) {
        throw new BadRequestException('Voice ID is required for ElevenLabs');
      }
      return;
    }

    // Gemini (default)
    if (!GEMINI_VOICES.has(voice)) {
      throw new BadRequestException(
        `Unknown voice '${voice}' for provider 'gemini'. Available: ${[...GEMINI_VOICES].join(', ')}`,
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /**
   * Builds the prompt sent to Gemini TTS, injecting locale information.
   *
   * For plain text: prepends a natural-language accent instruction
   *   (e.g. enIN → "Say the following in Indian English accent: …").
   *
   * For SSML input (recognised by a leading `<speak>`): wraps the body in
   *   `<lang xml:lang="...">…</lang>`. This keeps the locale hint inside the
   *   SSML grammar so the model still honours `<break>` and other tags — a
   *   plain-text prefix inside `<speak>` is read as part of the speech and
   *   causes the model to ignore subsequent SSML markup.
   */
  private buildPrompt(text: string, locale?: string): string {
    if (!locale) return text;
    const trimmed = text.trimStart();

    if (trimmed.startsWith('<speak>')) {
      const bcp47 = LOCALE_BCP47_MAP[locale];
      if (!bcp47) return text;
      // Wrap the body of <speak>…</speak> in <lang xml:lang="…">…</lang>.
      // Falls through unchanged if the closing tag is missing (malformed SSML).
      const closeIdx = text.lastIndexOf('</speak>');
      if (closeIdx === -1) return text;
      const openIdx = text.indexOf('<speak>') + '<speak>'.length;
      const body = text.slice(openIdx, closeIdx);
      return `${text.slice(0, openIdx)}<lang xml:lang="${bcp47}">${body}</lang>${text.slice(closeIdx)}`;
    }

    const descriptor = LOCALE_PROMPT_MAP[locale];
    if (!descriptor) return text;
    const prefix = NON_ENGLISH_LOCALES.has(locale)
      ? `Speak the following in ${descriptor}: `
      : `Say the following in ${descriptor}: `;
    return `${prefix}${text}`;
  }

  /**
   * Scans the Gemini response parts for an inlineData payload and returns the
   * base-64 encoded PCM string.
   */
  private extractBase64(data: GeminiResponse): string | null {
    const parts = data?.candidates?.[0]?.content?.parts ?? [];
    for (const part of parts) {
      if (part.inlineData?.data) {
        return part.inlineData.data;
      }
    }
    return null;
  }

}

