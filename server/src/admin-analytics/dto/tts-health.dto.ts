/**
 * TASK-003: TTS provider health DTOs
 *
 * Real-time health status derived exclusively from tts_jobs table.
 * No outbound API calls to TTS providers.
 */

export type TtsProviderStatus = 'healthy' | 'degraded' | 'unknown';

export interface TtsProviderHealth {
  /** Provider name: 'kokoro' | 'elevenlabs' */
  provider: string;
  /** Health status based on error rate and recency */
  status: TtsProviderStatus;
  /** Error rate for last 60 minutes (0..1 decimal) */
  errorRateLast60m: number;
  /** ISO 8601 timestamp of last successful job, or null if none */
  lastSuccessAt: string | null;
}

export interface TtsHealthResponse {
  providers: TtsProviderHealth[];
}
