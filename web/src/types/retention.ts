/**
 * Retention Analytics API — Response types for user retention and active user metrics.
 *
 * These mirror the server-side DTOs in server/src/admin-analytics/admin-analytics.service.ts.
 * They are duplicated here so the Next.js web app does not depend on the
 * NestJS server package at build time.
 */

import { TimeSeriesPoint } from './analytics';

// ---------------------------------------------------------------------------
// Retention Rates  — GET /api/admin/analytics/engagement/retention
// ---------------------------------------------------------------------------

/** D7 and D30 cohort retention metrics with delta tracking */
export interface RetentionMetric {
  /** Retention rate as a decimal (0..1), e.g., 0.42 = 42% */
  rate: number;
  /** Percentage point change from previous period */
  deltaPercent: number | null;
}

/** Cohort retention response showing D7 and D30 retention rates */
export interface RetentionResponse {
  /** Day-7 retention: % of users who returned within 7 days of signup */
  d7: RetentionMetric;
  /** Day-30 retention: % of users who returned within 30 days of signup */
  d30: RetentionMetric;
}

// ---------------------------------------------------------------------------
// Active Users Time Series  — GET /api/admin/analytics/engagement/active-users?range=7d|30d|90d
// ---------------------------------------------------------------------------

/** Daily, weekly, and monthly active user counts */
export interface ActiveUsersResponse {
  /** Daily Active Users — unique users with session completion per day */
  dau: TimeSeriesPoint[];
  /** Weekly Active Users — unique users with session completion per week */
  wau: TimeSeriesPoint[];
  /** Monthly Active Users — unique users with session completion per month */
  mau: TimeSeriesPoint[];
}
