import {
  Injectable,
  Logger,
  BadGatewayException,
  BadRequestException,
} from '@nestjs/common';

export interface ElevenLabsSynthesizeParams {
  text: string;
  voice: string;
  modelId?: string;
  stability?: number;
  similarityBoost?: number;
}

@Injectable()
export class ElevenLabsProxyService {
  private readonly logger = new Logger(ElevenLabsProxyService.name);
  private readonly baseUrl = 'https://api.elevenlabs.io/v1';
  private readonly synthTimeoutMs = 30_000;

  private get apiKey(): string {
    return process.env.ELEVENLABS_API_KEY ?? '';
  }

  /**
   * Synthesizes text to speech via the ElevenLabs API.
   * Returns raw WAV-like audio bytes (PCM s16le wrapped in a WAV header by
   * requesting pcm_24000 output format, then wrapping it ourselves).
   *
   * We request `pcm_24000` (raw 16-bit LE, 24 kHz mono) to match the Gemini
   * output format, then prepend a WAV header so the rest of the pipeline
   * (cache, Flutter player) works identically.
   */
  async synthesize(params: ElevenLabsSynthesizeParams): Promise<Buffer> {
    const {
      text,
      voice,
      modelId = 'eleven_multilingual_v2',
      stability = 0.5,
      similarityBoost = 0.75,
    } = params;

    const key = this.apiKey;
    if (!key) {
      this.logger.error('ELEVENLABS_API_KEY is not set');
      throw new BadGatewayException('ElevenLabs TTS is not configured');
    }

    const url = `${this.baseUrl}/text-to-speech/${voice}?output_format=pcm_24000`;

    this.logger.log(
      `ElevenLabs synthesize — voice=${voice}, model=${modelId}, text="${text.slice(0, 60)}…"`,
    );

    let response: Response;
    try {
      response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'xi-api-key': key,
        },
        body: JSON.stringify({
          text,
          model_id: modelId,
          voice_settings: { stability, similarity_boost: similarityBoost },
        }),
        signal: AbortSignal.timeout(this.synthTimeoutMs),
      });
    } catch (err: any) {
      const msg = err instanceof Error ? err.message : String(err);
      this.logger.error(`ElevenLabs API unreachable — ${msg}`);
      throw new BadGatewayException('ElevenLabs API unavailable');
    }

    if (response.status === 400 || response.status === 422) {
      const body = await response.text().catch(() => '');
      this.logger.warn(`ElevenLabs returned ${response.status} — ${body}`);
      throw new BadRequestException('Invalid ElevenLabs TTS parameters');
    }

    if (response.status === 401) {
      this.logger.error('ElevenLabs API key is invalid (401)');
      throw new BadGatewayException('ElevenLabs API key is invalid');
    }

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      this.logger.error(`ElevenLabs returned ${response.status} — ${body}`);
      throw new BadGatewayException('ElevenLabs API error');
    }

    const arrayBuffer = await response.arrayBuffer();
    const pcm = Buffer.from(arrayBuffer);

    this.logger.log(`ElevenLabs returned ${pcm.length} bytes of PCM audio`);

    // Wrap raw PCM in a WAV header (16-bit LE, 24 kHz, mono) to match
    // the format used by Gemini and Kokoro paths.
    return this.buildWav(pcm);
  }

  /**
   * Fetches available voices from the ElevenLabs API.
   * Returns the list of pre-made voices.
   */
  async fetchVoices(): Promise<Array<{ voice_id: string; name: string }>> {
    const key = this.apiKey;
    if (!key) return [];

    try {
      const resp = await fetch(`${this.baseUrl}/voices`, {
        headers: { 'xi-api-key': key },
        signal: AbortSignal.timeout(5_000),
      });
      if (!resp.ok) return [];
      const data = (await resp.json()) as {
        voices: Array<{ voice_id: string; name: string }>;
      };
      return data.voices ?? [];
    } catch {
      this.logger.warn('Failed to fetch ElevenLabs voices');
      return [];
    }
  }

  /** Quick health check — returns true if API key is set and API responds. */
  async isHealthy(): Promise<boolean> {
    const key = this.apiKey;
    if (!key) return false;
    try {
      const resp = await fetch(`${this.baseUrl}/voices?page_size=1`, {
        headers: { 'xi-api-key': key },
        signal: AbortSignal.timeout(3_000),
      });
      return resp.ok;
    } catch {
      return false;
    }
  }

  /**
   * Prepends a standard 44-byte WAV header to raw 16-bit LE, 24 kHz, mono PCM.
   */
  private buildWav(pcm: Buffer): Buffer {
    const dataSize = pcm.length;
    const header = Buffer.alloc(44);

    header.write('RIFF', 0, 'ascii');
    header.writeUInt32LE(36 + dataSize, 4);
    header.write('WAVE', 8, 'ascii');

    header.write('fmt ', 12, 'ascii');
    header.writeUInt32LE(16, 16);
    header.writeUInt16LE(1, 20);        // PCM
    header.writeUInt16LE(1, 22);        // Mono
    header.writeUInt32LE(24000, 24);    // 24 kHz
    header.writeUInt32LE(48000, 28);    // ByteRate = 24000 * 1 * 2
    header.writeUInt16LE(2, 32);        // BlockAlign
    header.writeUInt16LE(16, 34);       // BitsPerSample

    header.write('data', 36, 'ascii');
    header.writeUInt32LE(dataSize, 40);

    return Buffer.concat([header, pcm]);
  }
}
