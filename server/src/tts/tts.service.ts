import {
  Injectable,
  Logger,
  BadGatewayException,
  BadRequestException,
  HttpException,
} from '@nestjs/common';
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
  ) {
    // L1: ensure local cache directory exists.
    if (!existsSync(TTS_CACHE_DIR)) {
      mkdirSync(TTS_CACHE_DIR, { recursive: true });
      this.logger.log(`Created TTS cache directory: ${TTS_CACHE_DIR}`);
    }

    // L2: initialise S3 client if configured.
    this.bucket = process.env.AWS_S3_BUCKET ?? null;
    if (this.bucket) {
      this.s3 = new S3Client({
        region: process.env.AWS_REGION ?? 'ap-south-1',
      });
      this.logger.log(`S3 cache enabled — bucket=${this.bucket}`);
    } else {
      this.s3 = null;
      this.logger.warn('AWS_S3_BUCKET not set — S3 cache disabled, using local disk only');
    }
  }

  // ── Cache key (provider-inclusive) ───────────────────────────────────────

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
  cacheKey(
    text: string,
    voice: string,
    locale?: string,
    provider = process.env.DEFAULT_TTS_PROVIDER ?? 'kokoro',
    speechRate = '1.0',
  ): string {
    // Object keys MUST be in alphabetical order so that JSON.stringify produces
    // the same string as Dart's jsonEncode with an explicitly sorted map.
    // Do NOT reorder or add fields without updating hash_utils.dart simultaneously.
    const payload = JSON.stringify({
      locale: locale ?? '',
      provider,
      speechRate,
      text,
      voice,
    });
    return createHash('sha256').update(payload).digest('hex');
  }

  /**
   * Compute legacy cache key (pre-provider, for backward compatibility).
   * Format: SHA256(JSON.stringify({ locale, text, voice }))
   */
  private legacyCacheKey(text: string, voice: string, locale?: string): string {
    const payload = JSON.stringify({ text, voice, locale: locale ?? '' });
    return createHash('sha256').update(payload).digest('hex');
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

  /** L2: write to S3 (fire-and-forget — don't block the response). */
  private writeS3Cache(hash: string, audio: Buffer): void {
    if (!this.s3 || !this.bucket) return;
    this.s3
      .send(
        new PutObjectCommand({
          Bucket: this.bucket,
          Key: this.s3Key(hash),
          Body: audio,
          ContentType: 'audio/wav',
        }),
      )
      .then(() =>
        this.logger.log(`S3 upload OK — ${this.s3Key(hash)}, ${audio.length} bytes`),
      )
      .catch((err) =>
        this.logger.warn(`S3 upload failed for ${hash.slice(0, 12)}…: ${err.message}`),
      );
  }

  /**
   * Two-layer cache lookup:
   *   L1 (local disk) → L2 (S3) → null (miss)
   *
   * Also checks the legacy key (without provider) for backward compatibility.
   * On legacy hit, copies to the new key location.
   */
  private async readCache(
    hash: string,
    legacyHash?: string,
  ): Promise<Buffer | null> {
    // L1 (new key)
    const local = await this.readLocalCache(hash);
    if (local) return local;

    // L2 (new key)
    const remote = await this.readS3Cache(hash);
    if (remote) {
      await this.writeLocalCache(hash, remote);
      return remote;
    }

    // ── Legacy fallback (backward compat with pre-provider cache) ──────────
    if (legacyHash) {
      const legacyLocal = await this.readLocalCache(legacyHash);
      if (legacyLocal) {
        this.logger.log(`Legacy cache hit — migrating hash ${legacyHash.slice(0, 12)}… → ${hash.slice(0, 12)}…`);
        this.writeCache(hash, legacyLocal);
        return legacyLocal;
      }

      const legacyRemote = await this.readS3Cache(legacyHash);
      if (legacyRemote) {
        this.logger.log(`Legacy S3 cache hit — migrating hash ${legacyHash.slice(0, 12)}… → ${hash.slice(0, 12)}…`);
        await this.writeLocalCache(hash, legacyRemote);
        this.writeS3Cache(hash, legacyRemote);
        return legacyRemote;
      }
    }

    return null;
  }

  /** Writes to both L1 and L2. L1 write is async; S3 upload is non-blocking. */
  private writeCache(hash: string, audio: Buffer): void {
    // Fire-and-forget for both layers — caller has already returned the audio.
    this.writeLocalCache(hash, audio).catch((err) =>
      this.logger.warn(`L1 cache write failed for ${hash.slice(0, 12)}…: ${err.message}`),
    );
    this.writeS3Cache(hash, audio);
  }

  // ── Cache-only lookup (no synthesis) ──────────────────────────────────────

  /**
   * Returns cached audio if it exists (L1 → L2 → legacy), or null on a miss.
   * Does NOT trigger synthesis — safe for unauthenticated callers.
   */
  async checkCacheOnly(
    text: string,
    voice?: string,
    locale?: string,
    provider = process.env.DEFAULT_TTS_PROVIDER ?? 'kokoro',
    speechRate = '1.0',
  ): Promise<Buffer | null> {
    // ElevenLabs voice IDs are case-sensitive opaque strings — preserve casing.
    // Gemini and Kokoro IDs are lowercase by convention.
    const rawVoice =
      provider === 'elevenlabs'
        ? (voice ?? '').trim()
        : (voice ?? 'aoede').trim().toLowerCase();
    const hash = this.cacheKey(text, rawVoice, locale, provider, speechRate);
    const legacyHash =
      provider === 'gemini'
        ? this.legacyCacheKey(text, rawVoice, locale)
        : undefined;
    return this.readCache(hash, legacyHash);
  }

  // ── Main synthesis method ─────────────────────────────────────────────────

  async synthesize(
    text: string,
    voice?: string,
    locale?: string,
    provider = process.env.DEFAULT_TTS_PROVIDER ?? 'kokoro',
    speechRate = '1.0',
  ): Promise<Buffer> {
    // Validate provider.
    if (!this.providerRegistry.isKnownProvider(provider)) {
      throw new BadRequestException(`Unknown provider: ${provider}`);
    }

    // ElevenLabs voice IDs are case-sensitive opaque strings — preserve casing.
    // Gemini and Kokoro IDs are lowercase by convention.
    const rawVoice =
      provider === 'elevenlabs'
        ? (voice ?? '').trim()
        : (voice ?? 'aoede').trim().toLowerCase();

    // Compute new key (provider + speechRate inclusive) and legacy key (backward compat).
    const hash = this.cacheKey(text, rawVoice, locale, provider, speechRate);
    const legacyHash = provider === 'gemini'
      ? this.legacyCacheKey(text, rawVoice, locale)
      : undefined;

    // Cache lookup (L1 → L2 → legacy).
    const cached = await this.readCache(hash, legacyHash);
    if (cached) {
      this.logger.log(`Cache HIT — hash=${hash.slice(0, 12)}…, ${cached.length} bytes`);
      return cached;
    }
    this.logger.log(`Cache MISS — hash=${hash.slice(0, 12)}… (provider=${provider})`);

    // Non-English locales bypass Kokoro (English-only) and go directly to Gemini.
    const skipValidation = provider === 'kokoro' && !!locale && NON_ENGLISH_LOCALES.has(locale);

    // For Gemini provider: if a non-Gemini voice is sent (e.g. a Kokoro voice from
    // the client), remap it to the nearest Gemini equivalent via GEMINI_VOICE_MAP.
    let effectiveVoice = rawVoice;
    if (provider === 'gemini' && !GEMINI_VOICES.has(rawVoice) && GEMINI_VOICE_MAP[rawVoice]) {
      effectiveVoice = GEMINI_VOICE_MAP[rawVoice];
      this.logger.log(`Voice remap for Gemini: ${rawVoice} → ${effectiveVoice}`);
    }

    // Validate voice is native to the requested provider.
    if (!skipValidation) {
      this.validateVoice(effectiveVoice, provider);
    }

    // Route to appropriate provider, falling back to Gemini on failure.
    let audio: Buffer;
    if (provider === 'kokoro') {
      if (locale && NON_ENGLISH_LOCALES.has(locale)) {
        // Kokoro does not support this locale — route to Gemini TTS instead.
        const geminiVoice = GEMINI_VOICE_MAP[rawVoice] ?? 'aoede';
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
        const kokoroVoice = (effectiveLocale === 'hi' && HINDI_VOICE_FALLBACK[rawVoice])
          ? HINDI_VOICE_FALLBACK[rawVoice]
          : rawVoice;
        if (kokoroVoice !== rawVoice) {
          this.logger.log(`Hindi voice remap: ${rawVoice} → ${kokoroVoice}`);
        }
        try {
          audio = await this.synthesizeKokoro(text, kokoroVoice, effectiveLocale ?? 'en-us');
        } catch (err: unknown) {
          const geminiVoice = GEMINI_VOICE_MAP[rawVoice] ?? 'charon';
          this.logger.warn(
            `Kokoro failed (${err instanceof Error ? err.message : err}) — falling back to Gemini voice=${geminiVoice}`,
          );
          audio = await this.synthesizeGemini(text, geminiVoice, locale);
        }
      }
    } else if (provider === 'elevenlabs') {
      try {
        audio = await this.synthesizeElevenLabs(text, rawVoice);
      } catch (err: unknown) {
        const geminiVoice = GEMINI_VOICE_MAP[rawVoice] ?? 'charon';
        this.logger.warn(
          `ElevenLabs failed (${err instanceof Error ? err.message : err}) — falling back to Gemini voice=${geminiVoice}`,
        );
        audio = await this.synthesizeGemini(text, geminiVoice, locale);
      }
    } else {
      audio = await this.synthesizeGemini(text, effectiveVoice, locale);
    }

    // Persist to L1 + L2.
    this.writeCache(hash, audio);
    this.logger.log(`Cached — hash=${hash.slice(0, 12)}…, ${audio.length} bytes`);

    return audio;
  }

  // ── Gemini TTS ────────────────────────────────────────────────────────────

  private async synthesizeGemini(
    text: string,
    rawVoice: string,
    locale?: string,
  ): Promise<Buffer> {
    const apiKey = process.env.GEMINI_API_KEY;
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
          signal: AbortSignal.timeout(60_000),
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

      if (RETRYABLE_STATUSES.has(lastStatus) && attempt < this.MAX_RETRIES) {
        this.logger.warn(
          `TTS attempt ${attempt + 1}/${this.MAX_RETRIES + 1} failed with HTTP ${lastStatus} in ${latencyMs} ms, retrying…`,
        );
        continue;
      }

      const errorText = await httpResponse.text().catch(() => '');
      if (!RETRYABLE_STATUSES.has(lastStatus)) {
        this.logger.error(`Gemini non-retryable error ${lastStatus} in ${latencyMs} ms — ${errorText}`);
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
      this.logger.error(`Gemini retryable error ${lastStatus} in ${latencyMs} ms — retries exhausted`);
      break;
    }

    this.logger.error(
      `TTS failed after ${this.MAX_RETRIES + 1} attempts (last HTTP status: ${lastStatus})`,
    );
    throw new BadGatewayException(
      'TTS service unavailable — upstream Gemini API did not respond successfully',
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
   * Prepends a locale-specific accent instruction to the text when the locale
   * maps to a known accent.  E.g. enIN → "Say the following in Indian English accent: …"
   */
  private buildPrompt(text: string, locale?: string): string {
    if (!locale) return text;
    const descriptor = LOCALE_PROMPT_MAP[locale];
    if (!descriptor) return text;
    if (NON_ENGLISH_LOCALES.has(locale)) {
      return `Speak the following in ${descriptor}: ${text}`;
    }
    return `Say the following in ${descriptor}: ${text}`;
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

