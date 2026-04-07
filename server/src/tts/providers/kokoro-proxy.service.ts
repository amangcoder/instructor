import {
  Injectable,
  Logger,
  BadGatewayException,
  BadRequestException,
} from '@nestjs/common';

export interface KokoroSynthesizeParams {
  text: string;
  voice: string;
  language: string;
  speed?: number;
}

@Injectable()
export class KokoroProxyService {
  private readonly logger = new Logger(KokoroProxyService.name);
  private readonly kokoroUrl: string;
  private readonly synthTimeoutMs = 30_000;

  constructor() {
    this.kokoroUrl =
      process.env.KOKORO_SERVER_URL ?? 'http://127.0.0.1:3070';
  }

  /**
   * Forwards a TTS synthesis request to the Kokoro Python server.
   * Returns raw WAV audio bytes on success.
   *
   * @throws BadGatewayException if the Kokoro server is unreachable (502).
   * @throws BadRequestException if the Kokoro server rejects the request (400).
   */
  async synthesize(params: KokoroSynthesizeParams): Promise<Buffer> {
    const { text, voice, language, speed = 1.0 } = params;
    const url = `${this.kokoroUrl}/synthesize`;

    this.logger.log(
      `Kokoro synthesize — voice=${voice}, lang=${language}, text="${text.slice(0, 60)}…"`,
    );

    let response: Response;
    try {
      response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text, voice, language, speed }),
        signal: AbortSignal.timeout(this.synthTimeoutMs),
      });
    } catch (err: any) {
      const msg = err instanceof Error ? err.message : String(err);
      this.logger.error(`Kokoro server unreachable — ${msg}`);
      throw new BadGatewayException('Kokoro server unavailable');
    }

    if (response.status === 400) {
      const body = await response.text().catch(() => '');
      this.logger.warn(`Kokoro returned 400 — ${body}`);
      // Extract only the detail field from Pydantic's error response to avoid
      // leaking internal server topology or field-level validation structures.
      let detail: string;
      try {
        detail = (JSON.parse(body) as { detail?: string })?.detail ?? 'Invalid TTS parameters';
      } catch {
        detail = 'Invalid TTS parameters';
      }
      throw new BadRequestException(detail);
    }

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      this.logger.error(`Kokoro returned ${response.status} — ${body}`);
      throw new BadGatewayException('Kokoro server unavailable');
    }

    const arrayBuffer = await response.arrayBuffer();
    return Buffer.from(arrayBuffer);
  }

  /** Quick health check — returns true if Kokoro is ready. */
  async isHealthy(): Promise<boolean> {
    try {
      const resp = await fetch(`${this.kokoroUrl}/health`, {
        signal: AbortSignal.timeout(3_000),
      });
      if (!resp.ok) return false;
      const data = (await resp.json()) as { status?: string };
      return data.status === 'ready';
    } catch {
      return false;
    }
  }
}
