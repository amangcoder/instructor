/**
 * TtsAlignmentService
 *
 * HTTP client for the kokoro-server /align endpoint. Given a single
 * concatenated PCM buffer plus the ordered list of texts that produced it,
 * returns one {startMs, endMs} window per text — for slicing the PCM into
 * per-step audio without relying on silence heuristics.
 *
 * Failure modes are reported to the caller as undefined return + warning log,
 * so the batch-pregen pipeline can fall back to the legacy silence splitter
 * without surfacing alignment outages to the user.
 */
import { Injectable, Logger, Optional, Inject } from '@nestjs/common';
import type { AppConfig } from '../config/app-config.interface';
import type { PcmBoundaryMs } from './pcm-splitter';

export interface AlignParams {
  pcm: Buffer;
  sampleRate: number;
  texts: string[];
  language?: string;  // ISO-639-3 (e.g. 'eng', 'hin', 'spa'). Defaults to 'eng'.
}

export interface AlignResult {
  boundaries: PcmBoundaryMs[];
  durationMs: number;
}

interface AlignWireResponse {
  boundaries: Array<{ start_ms: number; end_ms: number }>;
  duration_ms: number;
}

@Injectable()
export class TtsAlignmentService {
  private readonly logger = new Logger(TtsAlignmentService.name);
  private readonly kokoroUrl: string;
  private readonly apiKey: string | null;
  private readonly timeoutMs: number;

  constructor(@Optional() @Inject('APP_CONFIG') config?: AppConfig) {
    this.kokoroUrl =
      config?.kokoroServerUrl ?? process.env.KOKORO_SERVER_URL ?? 'http://127.0.0.1:3070';
    this.apiKey = (config?.kokoroApiKey || process.env.KOKORO_API_KEY) ?? null;
    // Generous default — Modal cold-start + MMS-300M load can take 20–30s.
    this.timeoutMs = Number(process.env.ALIGN_TIMEOUT_MS ?? 90_000);
  }

  /**
   * Aligns texts against PCM and returns per-text byte boundaries.
   *
   * Returns `undefined` on any failure (network error, non-2xx, malformed
   * response) so callers can fall back to silence-based splitting.
   */
  async align(params: AlignParams): Promise<AlignResult | undefined> {
    if (params.texts.length <= 1) {
      // No alignment work to do — caller shouldn't need it, but guard anyway.
      return undefined;
    }

    const url = `${this.kokoroUrl}/align`;
    const body = {
      audio_b64: params.pcm.toString('base64'),
      sample_rate: params.sampleRate,
      texts: params.texts,
      language: params.language ?? 'eng',
    };

    this.logger.log(
      `align — texts=${params.texts.length}, pcm_bytes=${params.pcm.length}, sample_rate=${params.sampleRate}`,
    );

    let response: Response;
    try {
      const headers: Record<string, string> = { 'Content-Type': 'application/json' };
      if (this.apiKey) headers['Authorization'] = `Bearer ${this.apiKey}`;

      response = await fetch(url, {
        method: 'POST',
        headers,
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      this.logger.warn(`align — request failed: ${msg}`);
      return undefined;
    }

    if (!response.ok) {
      const detail = await response.text().catch(() => '');
      this.logger.warn(`align — server returned ${response.status}: ${detail.slice(0, 200)}`);
      return undefined;
    }

    let data: AlignWireResponse;
    try {
      data = (await response.json()) as AlignWireResponse;
    } catch (err) {
      this.logger.warn(`align — malformed JSON response: ${(err as Error).message}`);
      return undefined;
    }

    if (!Array.isArray(data.boundaries) || data.boundaries.length !== params.texts.length) {
      this.logger.warn(
        `align — boundary count mismatch: expected=${params.texts.length}, got=${data.boundaries?.length}`,
      );
      return undefined;
    }

    return {
      boundaries: data.boundaries.map((b) => ({ startMs: b.start_ms, endMs: b.end_ms })),
      durationMs: data.duration_ms,
    };
  }
}
