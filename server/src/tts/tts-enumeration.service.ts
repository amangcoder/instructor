import { Injectable, Logger } from '@nestjs/common';
import { TtsService } from './tts.service';

/**
 * A single TTS synthesis job derived from a plan step.
 */
export interface TtsPair {
  text: string;
  voiceId: string;
  locale: string;
  provider: string;
  speechRate: string;
  /** Pre-computed cache key — matches TtsService.cacheKey(). */
  cacheKey: string;
}

/**
 * TtsEnumerationService
 *
 * Parses a plan's step JSON and extracts all unique text-voice pairs that
 * need to be pre-generated (SayStep and CountdownStep announce intervals).
 * De-duplicates by cacheKey so each unique audio fragment is synthesized once.
 */
@Injectable()
export class TtsEnumerationService {
  private readonly logger = new Logger(TtsEnumerationService.name);

  constructor(private readonly ttsService: TtsService) {}

  /**
   * Enumerate all unique TTS pairs from a plan's JSON.
   *
   * @param planJson   Serialised plan JSON string
   * @param voiceId    Default voice to use for synthesis
   * @param locale     Locale code (e.g. 'enUS')
   * @param provider   TTS provider (e.g. 'kokoro', 'gemini')
   * @param speechRate Speech rate as a pre-formatted string (e.g. '1.00').
   *                   Conversion from NUMERIC happens at the repository boundary.
   * @returns Deduplicated array of TtsPairs
   */
  enumerate(
    planJson: string,
    voiceId: string,
    locale: string,
    provider: string,
    speechRate: string,
  ): TtsPair[] {
    let parsedPlan: { steps?: unknown[] };
    try {
      parsedPlan = JSON.parse(planJson) as { steps?: unknown[] };
    } catch {
      this.logger.warn('enumerate: failed to parse plan JSON — returning empty pair list');
      return [];
    }

    const steps = parsedPlan.steps;
    if (!Array.isArray(steps)) {
      this.logger.warn('enumerate: plan has no steps array — returning empty pair list');
      return [];
    }

    const seen = new Set<string>();
    const pairs: TtsPair[] = [];

    for (const step of steps) {
      const s = step as Record<string, unknown>;
      const type = (s['runtimeType'] as string | undefined)?.toLowerCase();

      if (type === 'say') {
        // SayStep: { type: 'say', text: string }
        const text = s['text'] as string | undefined;
        if (text?.trim()) {
          this.addPair(pairs, seen, text.trim(), voiceId, locale, provider, speechRate);
        }
      } else if (type === 'count') {
        // CountdownStep: { type: 'count', from: number, to: number,
        //                  announceInterval: number, announceText: string }
        const announceText = s['announceText'] as string | undefined;
        const announceInterval = s['announceInterval'] as number | undefined;
        const from = s['from'] as number | undefined;
        const to = s['to'] as number | undefined;

        if (announceText?.trim() && announceInterval && from !== undefined && to !== undefined) {
          // The app announces at each interval during the countdown.
          // Pre-gen the interpolated announce strings.
          const direction = from >= to ? -1 : 1;
          const step = direction * announceInterval;
          for (let t = from; direction > 0 ? t <= to : t >= to; t += step) {
            const interpolated = announceText.replace('{time}', String(t));
            this.addPair(pairs, seen, interpolated.trim(), voiceId, locale, provider, speechRate);
          }
        } else if (announceText?.trim()) {
          // Announce text without time interpolation
          this.addPair(pairs, seen, announceText.trim(), voiceId, locale, provider, speechRate);
        }
      } else if (type === 'notify') {
        // NotifyStep: { type: 'notify', message: string } — uses TTS for message
        const message = s['message'] as string | undefined;
        if (message?.trim()) {
          this.addPair(pairs, seen, message.trim(), voiceId, locale, provider, speechRate);
        }
      }
    }

    this.logger.log(
      `enumerate: found ${pairs.length} unique TTS pairs from ${steps.length} steps`,
    );
    return pairs;
  }

  private addPair(
    pairs: TtsPair[],
    seen: Set<string>,
    text: string,
    voiceId: string,
    locale: string,
    provider: string,
    speechRate: string,
  ): void {
    // Resolve raw → effective voice before hashing so foreign-voice requests
    // (e.g. a Kokoro voice routed to Gemini) collapse onto a canonical cache key.
    const effectiveVoice = this.ttsService.resolveEffectiveVoice(voiceId, provider);
    const cacheKey = this.ttsService.cacheKey(text, effectiveVoice, locale, provider, speechRate);
    if (!seen.has(cacheKey)) {
      seen.add(cacheKey);
      pairs.push({ text, voiceId: effectiveVoice, locale, provider, speechRate, cacheKey });
    }
  }
}
