/**
 * TTS Health API — Response types for TTS provider health monitoring.
 *
 * These mirror the server-side DTOs in server/src/admin-analytics/admin-analytics.service.ts.
 * They are duplicated here so the Next.js web app does not depend on the
 * NestJS server package at build time.
 */

// ---------------------------------------------------------------------------
// TTS Provider Health  — GET /api/admin/analytics/tts/health
// ---------------------------------------------------------------------------

/** Health status of a TTS provider */
export type TtsHealthStatus = 'healthy' | 'degraded' | 'unknown';

/** Health metrics for a single TTS provider */
export interface TtsProviderHealth {
  /** Provider name: 'kokoro' or 'elevenlabs' */
  provider: 'kokoro' | 'elevenlabs';
  /** Current health status based on recent error rate and success time */
  status: TtsHealthStatus;
  /** Error rate in the last 60 minutes (decimal 0..1), e.g., 0.05 = 5% errors */
  errorRateLast60m: number;
  /** ISO 8601 timestamp of the last successful TTS job, or null if no success in 60m */
  lastSuccessAt: string | null;
}

/** Real-time TTS provider health status response */
export interface TtsHealthResponse {
  /** Array of health status for each configured TTS provider */
  providers: TtsProviderHealth[];
}
