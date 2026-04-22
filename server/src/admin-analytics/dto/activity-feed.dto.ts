/**
 * DTOs for the recent activity feed endpoint.
 *
 * GET /api/admin/analytics/overview/activity
 */

export interface ActivityEvent {
  /** Event type: 'signup', 'tts_failure', 'deletion_request' */
  type: 'signup' | 'tts_failure' | 'deletion_request';
  /** Human-readable description of the event */
  description: string;
  /** ISO 8601 timestamp of when the event occurred */
  occurredAt: string;
}

export interface ActivityFeedResponse {
  events: ActivityEvent[];
}
