/**
 * Types for the plan-voices admin endpoints.
 *
 * Consumed by:
 *   PlanVoiceJobTable — client component on the /admin/tts page
 *
 * Upstream:
 *   GET /api/admin/plan-voices?status=failed&page=N&pageSize=N
 *     → ListFailedResponseDto { items: PlanVoice[]; total; page; pageSize }
 */

// ────────────────────────────────────────────────────────────────────────────
// Enumerations
// ────────────────────────────────────────────────────────────────────────────

export type PlanVoiceStatus = 'pending' | 'processing' | 'ready' | 'failed';

// ────────────────────────────────────────────────────────────────────────────
// Row shape (mirrors server PlanVoice / plan_voices table select)
// ────────────────────────────────────────────────────────────────────────────

export interface PlanVoiceRow {
  /** Primary key UUID. */
  id: string;
  /** FK to plans.id */
  planId: string;
  /** FK to voices.id */
  voiceId: string;
  /** BCP-47 locale string, e.g. "en-US" */
  locale: string;
  /** Synthesis lifecycle status. */
  status: PlanVoiceStatus;
  /** S3 URL of the synthesised audio (populated when status='ready'). */
  audioUrl: string | null;
  /** Duration of the audio in milliseconds (populated when status='ready'). */
  durationMs: number | null;
  /** Error message from the TTS worker (populated when status='failed'). */
  errorMsg: string | null;
  /** ISO 8601 timestamp when synthesis completed or failed. */
  generatedAt: string | null;
  /** ISO 8601 row creation timestamp. */
  createdAt: string;
  /** ISO 8601 last-update timestamp. */
  updatedAt: string;
}

// ────────────────────────────────────────────────────────────────────────────
// Paginated list response
// ────────────────────────────────────────────────────────────────────────────

export interface PlanVoiceJobsResponse {
  items: PlanVoiceRow[];
  /** Total number of matching rows across all pages. */
  total: number;
  /** Current 1-indexed page number. */
  page: number;
  /** Number of rows per page. */
  pageSize: number;
}
