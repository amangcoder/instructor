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
import { ProviderRegistryService } from './providers/provider-registry.service';
import { KokoroProxyService } from './providers/kokoro-proxy.service';

/** L1: local disk cache directory (fast, ephemeral across deploys). */
const TTS_CACHE_DIR = join(process.cwd(), 'tts-cache');

/** S3 key prefix for all TTS audio files. */
const S3_PREFIX = 'tts';

/** Maps Gemini locale codes to accent descriptions used in the Gemini prompt. */
const LOCALE_ACCENT_MAP: Record<string, string> = {
  enIN: 'Indian English accent',
  enGB: 'British English accent',
  enAU: 'Australian English accent',
  enCA: 'Canadian English accent',
  enUS: 'American English accent',
};

/** Valid Kokoro voice IDs. */
const KOKORO_VOICES = new Set([
  'af_heart', 'af_sky', 'af_bella', 'af_sarah', 'af_nicole', 'af_nova',
  'am_adam', 'am_michael', 'am_echo', 'am_eric', 'am_liam', 'am_onyx',
  'bf_emma', 'bf_isabella', 'bf_alice', 'bf_lily',
  'bm_george', 'bm_lewis', 'bm_daniel', 'bm_fable',
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
   * Compute cache key including provider and speechRate.
   * Keys use alphabetically sorted JSON to match the Flutter client's hash_utils.dart.
   * Format: SHA256(JSON.stringify({ locale, provider, speechRate, text, voice }))
   */
  cacheKey(
    text: string,
    voice: string,
    locale?: string,
    provider = 'gemini',
    speechRate = '1.0',
  ): string {
    // Alphabetical key order ensures Flutter client produces identical keys.
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
    provider = 'gemini',
    speechRate = '1.0',
  ): Promise<Buffer | null> {
    const rawVoice = (voice ?? 'aoede').trim().toLowerCase();
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
    provider = 'gemini',
    speechRate = '1.0',
  ): Promise<Buffer> {
    // Validate provider.
    if (!this.providerRegistry.isKnownProvider(provider)) {
      throw new BadRequestException(`Unknown provider: ${provider}`);
    }

    const rawVoice = (voice ?? 'aoede').trim().toLowerCase();

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

    // Validate voice is native to the requested provider.
    // Voice remapping is handled by the frontend when the user switches providers.
    this.validateVoice(rawVoice, provider);

    // Route to appropriate provider.
    let audio: Buffer;
    if (provider === 'kokoro') {
      audio = await this.synthesizeKokoro(text, rawVoice, locale ?? 'en-us');
    } else {
      audio = await this.synthesizeGemini(text, rawVoice, locale);
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
        return this.buildWav(pcm);
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
    const accent = LOCALE_ACCENT_MAP[locale];
    if (!accent) return text;
    return `Say the following in ${accent}: ${text}`;
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

  /**
   * Prepends a standard 44-byte WAV header to raw 16-bit LE, 24 kHz, mono PCM
   * data returned by the Gemini TTS API.
   */
  private buildWav(pcm: Buffer): Buffer {
    const dataSize = pcm.length;
    const header = Buffer.alloc(44);

    // RIFF chunk descriptor
    header.write('RIFF', 0, 'ascii');
    header.writeUInt32LE(36 + dataSize, 4);   // ChunkSize
    header.write('WAVE', 8, 'ascii');

    // "fmt " sub-chunk (16 bytes)
    header.write('fmt ', 12, 'ascii');
    header.writeUInt32LE(16, 16);              // Subchunk1Size (PCM = 16)
    header.writeUInt16LE(1, 20);               // AudioFormat  (1 = PCM)
    header.writeUInt16LE(1, 22);               // NumChannels  (mono)
    header.writeUInt32LE(24000, 24);           // SampleRate   (24 kHz)
    header.writeUInt32LE(48000, 28);           // ByteRate = 24000 * 1 * 2
    header.writeUInt16LE(2, 32);               // BlockAlign   = 1 * 2
    header.writeUInt16LE(16, 34);              // BitsPerSample

    // "data" sub-chunk
    header.write('data', 36, 'ascii');
    header.writeUInt32LE(dataSize, 40);        // Subchunk2Size

    return Buffer.concat([header, pcm]);
  }
}
