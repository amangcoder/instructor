import {
  Controller,
  Get,
  Post,
  Body,
  Res,
  Headers,
  Query,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import type { Response } from 'express';
import type { Request } from 'express';
import { TtsService } from './tts.service';
import { ProviderRegistryService } from './providers/provider-registry.service';
import { SynthesizeDto } from './dto/synthesize.dto';
import { JwtService } from '@nestjs/jwt';
import { extractBearer } from '../auth/jwt-auth.guard';

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
    private readonly providerRegistry: ProviderRegistryService,
    private readonly jwt: JwtService,
  ) {}

  /**
   * GET /api/tts/providers?provider=gemini
   * Returns available TTS providers with their voices and locales.
   * Optional ?provider= filter to return a single provider's config.
   */
  @Get('providers')
  async getProviders(@Query('provider') provider?: string) {
    this.logger.log(`GET /tts/providers — filter=${provider ?? 'all'}`);
    const configs = await this.providerRegistry.getProviders(provider);
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
    const provider = dto.provider ?? 'gemini';
    this.logger.log(
      `POST /synthesize — voice=${dto.voice}, locale=${dto.locale}, provider=${provider}, text="${dto.text?.slice(0, 60)}…"`,
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

    // Try x-api-key.
    const serverKey = process.env.API_KEY;
    if (serverKey && apiKey === serverKey) {
      return; // Valid API key → allow
    }

    // Neither credential passed.
    this.logger.warn('TTS auth failed — no valid JWT or API key');
    throw new UnauthorizedException('Invalid or missing authentication credentials');
  }
}
