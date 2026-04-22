/**
 * User Analytics API — Response types for user session history and plan summaries.
 *
 * These mirror the server-side DTOs in server/src/admin-analytics/admin-users.service.ts.
 * They are duplicated here so the Next.js web app does not depend on the
 * NestJS server package at build time.
 */

// ---------------------------------------------------------------------------
// User Session History  — GET /api/admin/users/:id/sessions
// ---------------------------------------------------------------------------

/** Single session completion record for user history */
export interface UserSession {
  /** Name of the plan that was completed */
  planName: string;
  /** ISO 8601 timestamp when the session was completed */
  completedAt: string;
  /** Session duration in milliseconds */
  durationMs: number;
}

/** User session history response showing last completions */
export interface UserSessionsResponse {
  /** Array of the last 20 session completions, most recent first */
  sessions: UserSession[];
}

// ---------------------------------------------------------------------------
// User Plan Summary  — included in extended user detail response
// ---------------------------------------------------------------------------

/** TTS processing status for a plan */
export type TtsStatus = 'pending' | 'in_progress' | 'completed' | 'failed';

/** Per-plan summary for user detail view */
export interface UserPlanSummary {
  /** Plan unique identifier */
  planId: string;
  /** Plan display name */
  name: string;
  /** ISO 8601 timestamp when the plan was created by the user */
  createdAt: string;
  /** Current TTS synthesis status */
  ttsStatus: TtsStatus;
  /** Number of session completions on this plan */
  runCount: number;
  /** ISO 8601 timestamp of the most recent session completion, or null if never run */
  lastRunAt: string | null;
  /** Whether the plan is currently active (user is engaged with it) */
  isActive: boolean;
}
