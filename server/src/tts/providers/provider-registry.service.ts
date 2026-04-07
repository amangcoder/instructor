import { Injectable, Logger } from '@nestjs/common';

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
  { id: 'enUS', label: 'English (US)' },
  { id: 'enGB', label: 'English (UK)' },
  { id: 'enIN', label: 'English (India)' },
  { id: 'enAU', label: 'English (Australia)' },
  { id: 'enCA', label: 'English (Canada)' },
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
];

const KOKORO_FALLBACK_LOCALES: LocaleOption[] = [
  { id: 'en-us', label: 'English (US)' },
  { id: 'en-gb', label: 'English (UK)' },
];

// ── Cross-provider voice mappings ───────────────────────────────────────────
// Maps foreign voice IDs → native voice IDs for each provider.
// Included in the /api/tts/providers response so the frontend can remap
// plan voices when the user switches providers.

/** Maps Kokoro voice IDs → nearest Gemini equivalent. */
const GEMINI_VOICE_MAP: Record<string, string> = {
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
};

/** Maps Gemini voice IDs → nearest Kokoro equivalent. */
const KOKORO_VOICE_MAP: Record<string, string> = {
  aoede: 'af_heart',
  leda: 'af_bella',
  kore: 'af_nicole',
  charon: 'am_adam',
  puck: 'am_michael',
  fenrir: 'am_eric',
  orus: 'am_liam',
  schedar: 'am_echo',
  zephyr: 'af_sky',
};

@Injectable()
export class ProviderRegistryService {
  private readonly logger = new Logger(ProviderRegistryService.name);
  private readonly kokoroUrl: string;

  constructor() {
    this.kokoroUrl =
      process.env.KOKORO_SERVER_URL ?? 'http://127.0.0.1:3070';
  }

  /** Returns the static list of registered provider IDs. */
  getProviderIds(): string[] {
    return ['gemini', 'kokoro'];
  }

  /** Returns true if the given provider ID is registered. */
  isKnownProvider(id: string): boolean {
    return this.getProviderIds().includes(id);
  }

  /**
   * Returns provider configs for the requested provider(s).
   * Kokoro voices are fetched live from the Python server; falls back to
   * a static list if the server is unreachable.
   */
  async getProviders(provider?: string): Promise<ProviderConfig[]> {
    const ids = provider ? [provider] : this.getProviderIds();
    const configs: ProviderConfig[] = [];

    for (const id of ids) {
      if (id === 'gemini') {
        configs.push({
          id: 'gemini',
          label: 'Google Gemini TTS',
          voices: GEMINI_VOICES,
          locales: GEMINI_LOCALES,
          voiceMap: GEMINI_VOICE_MAP,
        });
      } else if (id === 'kokoro') {
        configs.push(await this.getKokoroConfig());
      }
    }

    return configs;
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
}
