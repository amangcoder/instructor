import {
  Injectable,
  Logger,
  BadGatewayException,
  BadRequestException,
  Optional,
  Inject,
} from '@nestjs/common';
import type { AppConfig } from '../../config/app-config.interface';

export interface VibeVoiceSynthesizeParams {
  text: string;
  /** Comma-separated voice ids when sending multi-speaker dialogue. */
  voice: string;
  language: string;
  cfgScale?: number;
  ddpmSteps?: number;
}

@Injectable()
export class VibeVoiceProxyService {
  private readonly logger = new Logger(VibeVoiceProxyService.name);
  private readonly serverUrl: string;
  private readonly apiKey: string | null;
  // VibeVoice diffusion runs are slower than Kokoro — give them headroom.
  private readonly synthTimeoutMs = 300_000;

  constructor(@Optional() @Inject('APP_CONFIG') config?: AppConfig) {
    this.serverUrl =
      config?.vibevoiceServerUrl ??
      process.env.VIBEVOICE_SERVER_URL ??
      'http://127.0.0.1:3073';
    this.apiKey = (config?.vibevoiceApiKey || process.env.VIBEVOICE_API_KEY) ?? null;
  }

  /**
   * Forwards a TTS synthesis request to the VibeVoice Python server.
   * Returns raw WAV audio bytes on success.
   */
  async synthesize(params: VibeVoiceSynthesizeParams): Promise<Buffer> {
    const { text, voice, language, cfgScale, ddpmSteps } = params;
    const url = `${this.serverUrl}/synthesize`;

    this.logger.log(
      `VibeVoice synthesize — voice=${voice}, lang=${language}, text="${text.slice(0, 60)}…"`,
    );

    const body: Record<string, unknown> = { text, voice, language };
    if (cfgScale !== undefined) body.cfg_scale = cfgScale;
    if (ddpmSteps !== undefined) body.ddpm_steps = ddpmSteps;

    let response: Response;
    try {
      const headers: Record<string, string> = { 'Content-Type': 'application/json' };
      if (this.apiKey) {
        headers['Authorization'] = `Bearer ${this.apiKey}`;
      }

      response = await fetch(url, {
        method: 'POST',
        headers,
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(this.synthTimeoutMs),
      });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      this.logger.error(`VibeVoice server unreachable — ${msg}`);
      throw new BadGatewayException('VibeVoice server unavailable');
    }

    if (response.status === 400) {
      const raw = await response.text().catch(() => '');
      this.logger.warn(`VibeVoice returned 400 — ${raw}`);
      // Surface only the `detail` string from FastAPI's error body to avoid
      // leaking server topology / Pydantic validation internals.
      let detail: string;
      try {
        detail = (JSON.parse(raw) as { detail?: string })?.detail ?? 'Invalid TTS parameters';
      } catch {
        detail = 'Invalid TTS parameters';
      }
      throw new BadRequestException(detail);
    }

    if (!response.ok) {
      const raw = await response.text().catch(() => '');
      this.logger.error(`VibeVoice returned ${response.status} — ${raw}`);
      throw new BadGatewayException('VibeVoice server unavailable');
    }

    const arrayBuffer = await response.arrayBuffer();
    return Buffer.from(arrayBuffer);
  }

  /** Quick health check — returns true if VibeVoice is ready. */
  async isHealthy(): Promise<boolean> {
    try {
      const headers: Record<string, string> = {};
      if (this.apiKey) {
        headers['Authorization'] = `Bearer ${this.apiKey}`;
      }

      const resp = await fetch(`${this.serverUrl}/health`, {
        headers,
        signal: AbortSignal.timeout(3_000),
      });
      if (!resp.ok) return false;
      const data = (await resp.json()) as { status?: string };
      return data.status === 'ready';
    } catch {
      return false;
    }
  }

  /** Fetches the live voice catalog from the VibeVoice server. */
  async fetchVoices(): Promise<Array<{ id: string; label: string }>> {
    try {
      const headers: Record<string, string> = {};
      if (this.apiKey) {
        headers['Authorization'] = `Bearer ${this.apiKey}`;
      }

      const resp = await fetch(`${this.serverUrl}/voices`, {
        headers,
        signal: AbortSignal.timeout(5_000),
      });
      if (!resp.ok) return [];
      const data = (await resp.json()) as {
        voices?: Array<{ id: string; label?: string }>;
      };
      return (data.voices ?? []).map((v) => ({ id: v.id, label: v.label ?? v.id }));
    } catch {
      return [];
    }
  }
}
