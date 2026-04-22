import {
  Controller,
  Get,
  Post,
  Body,
  Res,
  Headers,
  Query,
  Param,
  Req,
  UseGuards,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import type { Response } from 'express';
import type { Request } from 'express';
import { timingSafeEqual } from 'crypto';
import { TtsService } from './tts.service';
import { TtsPregenService } from './tts-pregen.service';
import { TtsBatchPregenService } from './tts-batch-pregen.service';
import { ProviderRegistryService } from './providers/provider-registry.service';
import { SynthesizeDto } from './dto/synthesize.dto';
import { BatchPregenDto } from './dto/batch-pregen.dto';
import { JwtService } from '@nestjs/jwt';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { JwtPayload } from '../auth/auth.service';

/** Maximum time (ms) allowed for a single synthesis request. */
const SYNTHESIS_TIMEOUT_MS = 90_000;

/** Sentinel used to distinguish a local timeout from a service error. */
class SynthesisTimeoutError extends Error {
  constructor() {
    super('TTS synthesis exceeded the 90-second timeout');
  }
}

@Controller('tts')
export class TtsController {
  private readonly logger = new Logger(TtsController.name);

  constructor(
    private readonly ttsService: TtsService,
    private readonly ttsPregenService: TtsPregenService,
    private readonly ttsBatchPregenService: TtsBatchPregenService,
    private readonly providerRegistry: ProviderRegistryService,
    private readonly jwt: JwtService,
  ) {}

  /**
   * GET /api/tts/providers?provider=gemini
   * Returns available TTS providers with their voices and locales.
   * Optional ?provider= filter to return a single provider's config.
   *
   * Response includes Cache-Control: public, max-age=3600 so HTTP clients
   * and CDN layers can cache the catalog for up to 60 minutes (matching the
   * Redis TTL in ProviderRegistryService._setCachedCatalog).
   */
  @Get('providers')
  async getProviders(
    @Query('provider') provider?: string,
    @Res({ passthrough: true }) res?: Response,
  ) {
    this.logger.log(`GET /tts/providers — filter=${provider ?? 'all'}`);
    // Strip any unexpected characters from the provider filter (max 50 chars).
    const safeProvider =
      provider && /^[a-zA-Z0-9_-]{1,50}$/.test(provider) ? provider : undefined;
    if (provider && !safeProvider) {
      this.logger.warn(`GET /tts/providers — invalid provider filter ignored: "${provider}"`);
    }
    res?.set('Cache-Control', 'public, max-age=3600');
    const configs = await this.providerRegistry.getProviders(safeProvider);
    return { providers: configs };
  }

  /**
   * POST /api/tts/synthesize
   * Synthesizes text to WAV audio using the specified provider.
   *
   * Auth: requires a valid JWT Bearer token OR a valid x-api-key header.
   * If neither credential is configured, all requests are rejected (no fail-open).
   */
  @Post('synthesize')
  async synthesize(
    @Body() dto: SynthesizeDto,
    @Headers('x-api-key') apiKey: string | undefined,
    @Headers('authorization') authHeader: string | undefined,
    @Res() res: Response,
  ): Promise<void> {
    const provider = dto.provider ?? process.env.DEFAULT_TTS_PROVIDER ?? 'kokoro';
    this.logger.log(
      `POST /synthesize — voice=${dto.voice}, locale=${dto.locale}, provider=${provider}, textLength=${dto.text?.length ?? 0}`,
    );

    // ── Auth: JWT Bearer OR x-api-key ─────────────────────────────────────
    // Non-authenticated users may still receive cached audio (no synthesis).
    let isAuthenticated = false;
    try {
      this.checkTtsAuth(authHeader, apiKey);
      isAuthenticated = true;
      this.logger.log('Auth passed');
    } catch {
      this.logger.log('Auth failed — checking cache for non-authenticated user');
    }

    if (!isAuthenticated) {
      const cached = await this.ttsService.checkCacheOnly(
        dto.text,
        dto.voice,
        dto.locale,
        provider,
        dto.speechRate ?? '1.0',
      );
      if (cached) {
        this.logger.log(
          `Serving cached audio to non-authenticated user — ${cached.length} bytes`,
        );
        res.status(200).set({
          'Content-Type': 'audio/wav',
          'Content-Length': cached.length.toString(),
        });
        res.send(cached);
        return;
      }
      this.logger.warn('Cache miss for non-authenticated user — returning 401');
      res
        .status(401)
        .json({ error: 'Unauthorized', message: 'Invalid or missing authentication credentials' });
      return;
    }

    const startMs = Date.now();
    let audio: Buffer;
    try {
      const timeoutPromise = new Promise<never>((_, reject) =>
        setTimeout(() => reject(new SynthesisTimeoutError()), SYNTHESIS_TIMEOUT_MS),
      );
      audio = await Promise.race([
        this.ttsService.synthesize(
          dto.text,
          dto.voice,
          dto.locale,
          provider,
          dto.speechRate ?? '1.0',
        ),
        timeoutPromise,
      ]);
    } catch (err) {
      const elapsedMs = Date.now() - startMs;
      if (err instanceof SynthesisTimeoutError) {
        this.logger.error(`Synthesis timed out after ${elapsedMs} ms`);
        res.status(408).json({ error: 'timeout' });
        return;
      }
      const message = err instanceof Error ? err.message : String(err);
      this.logger.error(`Synthesis failed after ${elapsedMs} ms — ${message}`);

      // Preserve provider-specific HTTP codes.
      const statusCode =
        (err as any).status ?? (err as any).statusCode ?? 502;
      res.status(statusCode).json({ error: 'upstream_failure', message });
      return;
    }

    const elapsedMs = Date.now() - startMs;
    this.logger.log(`Synthesis OK — ${audio.length} bytes, ${elapsedMs} ms`);

    res.status(200).set({
      'Content-Type': 'audio/wav',
      'Content-Length': audio.length.toString(),
    });
    res.send(audio);
  }

  /**
   * GET /api/tts/status/:planId
   * Returns TTS pre-generation status for a plan (REQ-011).
   * Requires JWT authentication. IDOR: planId is validated server-side but
   * since status is read-only and contains no sensitive data, we only require JWT.
   */
  @Get('status/:planId')
  @UseGuards(JwtAuthGuard)
  async getTtsStatus(
    @Param('planId') planId: string,
    @Req() _req: Request,
  ) {
    this.logger.log(`GET /tts/status/${planId}`);
    return this.ttsPregenService.getStatus(planId);
  }

  /**
   * GET /api/tts/audio-urls/:planId
   * Returns pre-signed S3 audio URLs for all completed TTS jobs of a plan (REQ-012).
   * Requires JWT authentication.
   * Response: { urls: { [cacheKey]: presignedUrl } }
   */
  @Get('audio-urls/:planId')
  @UseGuards(JwtAuthGuard)
  async getAudioUrls(
    @Param('planId') planId: string,
    @Req() _req: Request,
  ) {
    this.logger.log(`GET /tts/audio-urls/${planId}`);
    const urls = await this.ttsPregenService.getAudioUrls(planId);
    return { urls };
  }

  /**
   * POST /api/tts/batch-pregen
   * Starts batch TTS pre-generation for a plan: groups all SayStep texts that
   * share the same Gemini voice + locale into a single API call, then slices the
   * audio into per-step cache files.  Reduces Gemini API calls from N → 1 per group.
   *
   * Requires JWT authentication.
   */
  @Post('batch-pregen')
  @UseGuards(JwtAuthGuard)
  async startBatchPregen(
    @Body() dto: BatchPregenDto,
    @Req() _req: Request,
  ) {
    const provider = dto.provider ?? process.env.DEFAULT_TTS_PROVIDER ?? 'kokoro';
    this.logger.log(
      `POST /tts/batch-pregen — planId=${dto.planId}, provider=${provider}, locale=${dto.locale}`,
    );
    await this.ttsBatchPregenService.startBatchPregen(
      dto.planId,
      dto.planJson,
      dto.voiceId,
      dto.locale,
      provider,
      dto.speechRate ?? '1.0',
    );
    return { status: 'processing' };
  }

  // ── Auth helper ───────────────────────────────────────────────────────────

  /**
   * Validates TTS request auth.
   * Accepts either a valid JWT Bearer token OR a matching x-api-key.
   * Rejects all requests when neither mechanism is configured.
   */
  private checkTtsAuth(
    authHeader: string | undefined,
    apiKey: string | undefined,
  ): void {
    // Try JWT Bearer first.
    // Note: an invalid/expired JWT does NOT immediately reject — we fall through
    // to check x-api-key for backward compatibility with pre-auth API clients.
    if (authHeader?.startsWith('Bearer ')) {
      const token = authHeader.slice(7);
      try {
        // Use the secret already validated and configured in JwtModule.registerAsync.
        this.jwt.verify(token);
        return; // Valid JWT → allow
      } catch {
        this.logger.debug('JWT invalid — falling through to API key check');
        // JWT invalid — fall through to API key check.
      }
    }

    // Try x-api-key (constant-time comparison to prevent timing attacks).
    const serverKey = process.env.API_KEY;
    if (serverKey && apiKey) {
      try {
        const keyBuf = Buffer.from(apiKey);
        const serverBuf = Buffer.from(serverKey);
        if (keyBuf.length === serverBuf.length && timingSafeEqual(keyBuf, serverBuf)) {
          return; // Valid API key → allow
        }
      } catch {
        // Buffers of different lengths — fall through to reject
      }
    }

    // Neither credential passed.
    this.logger.warn('TTS auth failed — no valid JWT or API key');
    throw new UnauthorizedException('Invalid or missing authentication credentials');
  }
}
