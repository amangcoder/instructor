/**
 * TASK-002: Retention analytics DTOs
 *
 * D7/D30 cohort retention rates computed from users and session_completions.
 * Uses single-query JOIN pattern (NOT IN-list) for performance.
 */

export interface RetentionMetric {
  /** Retention rate as a decimal (0..1), e.g., 0.15 = 15% */
  rate: number;
  /** Size of the cohort (users who signed up in the cohort window) */
  cohortSize: number;
  /** Count of cohort users who had at least one session in the retention window */
  retainedCount: number;
  /** Percentage point change vs previous cohort (e.g., 2.1 = +2.1pp) */
  delta: number;
}

export interface RetentionResponse {
  d7: RetentionMetric;
  d30: RetentionMetric;
}

/**
 * Active users time series: DAU, WAU, MAU
 */
export interface ActiveUsersResponse {
  dau: Array<{ date: string; value: number }>; // Daily Active Users
  wau: Array<{ date: string; value: number }>; // Weekly Active Users
  mau: Array<{ date: string; value: number }>; // Monthly Active Users
}
