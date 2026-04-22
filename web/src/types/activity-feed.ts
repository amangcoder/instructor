/**
 * Activity Feed API — Response types for platform events and recent activity.
 *
 * These mirror the server-side DTOs in server/src/admin-analytics/admin-analytics.service.ts.
 * They are duplicated here so the Next.js web app does not depend on the
 * NestJS server package at build time.
 */

// ---------------------------------------------------------------------------
// Activity Event Types  — GET /api/admin/analytics/overview/activity
// ---------------------------------------------------------------------------

/** Type of activity event */
export type ActivityEventType = 'signup' | 'tts_failure' | 'deletion_request';

/** Single platform event for the activity feed */
export interface ActivityEvent {
  /** Type of activity: new signup, TTS failure, or deletion request */
  type: ActivityEventType;
  /** Human-readable description of the event (e.g., "user@example.com signed up", "TTS job failed for user@example.com") */
  description: string;
  /** ISO 8601 timestamp when the event occurred */
  occurredAt: string;
}

// ---------------------------------------------------------------------------
// Activity Feed Response  — GET /api/admin/analytics/overview/activity
// ---------------------------------------------------------------------------

/** Recent platform activity for overview dashboard widget */
export interface ActivityFeedResponse {
  /** Last 10 platform events in reverse-chronological order (most recent first) */
  events: ActivityEvent[];
}
