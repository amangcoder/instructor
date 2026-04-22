/**
 * Admin Analytics API — Response DTOs
 *
 * All endpoints: GET /api/admin/analytics/*
 * Guards: JwtAuthGuard + AdminRoleGuard
 * Query: ?range=7d|30d|90d (default 30d). Invalid range returns 400.
 *
 * Consistent response shape: { series: [...], totals: {...} }
 *
 * Error responses:
 *   400 — invalid range parameter
 *   401 — missing or invalid JWT
 *   403 — authenticated but not admin role
 *   500 — server error
 */

// ---------------------------------------------------------------------------
// Shared / base types
// ---------------------------------------------------------------------------

/** Valid range query parameter values. */
export type AnalyticsRange = '7d' | '30d' | '90d';

/** A single time-series data point (date + numeric value). */
export interface TimeSeriesPoint {
  /** ISO 8601 date string, truncated to day: "2026-04-15" */
  date: string;
  /** Metric value for that day */
  value: number;
}

/** A time-series point with a percentage alongside the count. */
export interface TimeSeriesRatePoint {
  date: string;
  /** Absolute count (e.g. activated users) */
  value: number;
  /** Rate as a decimal 0..1 (e.g. 0.42 = 42%) */
  rate: number;
  /** Denominator (e.g. total signups that day) */
  total: number;
}

// ---------------------------------------------------------------------------
// 1. GET /api/admin/analytics/overview
//
// Top-line counts with 7-day deltas for dashboard header cards.
// `series` is empty — this endpoint is card-only, not charted.
// ---------------------------------------------------------------------------

export interface OverviewMetric {
  /** Current count for the selected range */
  current: number;
  /** Count for the previous equivalent range (for delta calculation) */
  previous: number;
  /** Percentage change: ((current - previous) / previous) * 100. null if previous is 0 */
  deltaPercent: number | null;
}

/** OverviewMetric with a daily sparkline time series for 7d/30d/90d display */
export interface MetricWithSparkline extends OverviewMetric {
  sparkline: TimeSeriesPoint[];
}

export interface OverviewTotals {
  weeklyPlansPlayed: MetricWithSparkline;
  planCompletionRate: OverviewMetric;
  totalUsers: OverviewMetric;
  newSignups: OverviewMetric;
  activePlans: OverviewMetric;
  totalPlans: OverviewMetric;
  ttsJobsCompleted: OverviewMetric;
  ttsJobsFailed: OverviewMetric;
  totalSessions: OverviewMetric;
  /** Average session duration in milliseconds */
  avgSessionDurationMs: OverviewMetric;
}

export interface OverviewResponse {
  series: [];
  totals: OverviewTotals;
}

// ---------------------------------------------------------------------------
// 2. GET /api/admin/analytics/users/signups
//
// Daily time series of new user registrations.
// Recharts pattern: TimeSeriesChart (XAxis=date, YAxis=value)
// ---------------------------------------------------------------------------

export interface SignupsTotals {
  /** Total signups in the selected range */
  total: number;
  /** Average daily signups */
  avgPerDay: number;
  /** Peak day count */
  peakDay: number;
  /** ISO date of the peak day */
  peakDate: string;
}

export interface SignupsResponse {
  series: TimeSeriesPoint[];
  totals: SignupsTotals;
}

// ---------------------------------------------------------------------------
// 3. GET /api/admin/analytics/users/activation
//
// Daily activation rate: users who created a plan within 24h of signup.
// Recharts pattern: TimeSeriesChart with dual Y-axes (count + rate%)
// ---------------------------------------------------------------------------

export interface ActivationTotals {
  /** Total users who signed up in the range */
  totalSignups: number;
  /** Total users who activated (created plan within 24h) */
  totalActivated: number;
  /** Overall activation rate for the range (decimal 0..1) */
  overallRate: number;
}

export interface ActivationResponse {
  series: TimeSeriesRatePoint[];
  totals: ActivationTotals;
}

// ---------------------------------------------------------------------------
// 4. GET /api/admin/analytics/plans/funnel
//
// Counts at each plan lifecycle stage with drop-off percentages.
// Recharts pattern: FunnelChart or horizontal BarChart
// ---------------------------------------------------------------------------

export interface FunnelStage {
  /** Lifecycle stage identifier */
  stage: 'created' | 'tts_started' | 'tts_completed' | 'activated' | 'session_completed';
  /** Human-readable label */
  label: string;
  /** Count of plans that reached this stage */
  count: number;
  /** Percentage of the first stage (created) that reached this stage. 0..100 */
  percentOfTop: number;
  /** Drop-off percentage from the previous stage. 0..100. null for first stage */
  dropOffPercent: number | null;
}

export interface FunnelTotals {
  /** Total plans created in the range */
  totalCreated: number;
  /** Overall conversion from created to session_completed */
  overallConversionPercent: number;
}

export interface FunnelResponse {
  series: FunnelStage[];
  totals: FunnelTotals;
}

// ---------------------------------------------------------------------------
// 5. GET /api/admin/analytics/plans/usage (should-have)
//
// Plans-per-user distribution + active vs dormant breakdown.
// Recharts pattern: BarChart (distribution) + PieChart or stacked bar (active/dormant)
// ---------------------------------------------------------------------------

export interface PlansPerUserBucket {
  /** Bucket label: "0", "1", "2", "3", "4", "5+" */
  bucket: string;
  /** Number of users in this bucket */
  userCount: number;
}

export interface PlanUsageTotals {
  /** Total users who have at least one plan */
  usersWithPlans: number;
  /** Total users with zero plans */
  usersWithoutPlans: number;
  /** Average plans per user (among users with plans) */
  avgPlansPerUser: number;
  /** Plans with isActive=true */
  activePlans: number;
  /** Plans with no session completion in the last 30 days */
  dormantPlans: number;
  /** Total plans */
  totalPlans: number;
}

export interface PlanUsageResponse {
  series: PlansPerUserBucket[];
  totals: PlanUsageTotals;
}

// ---------------------------------------------------------------------------
// 6. GET /api/admin/analytics/tts/volume
//
// Daily TTS job counts grouped by provider and voiceId.
// Recharts pattern: stacked BarChart or AreaChart (one series per provider)
// ---------------------------------------------------------------------------

export interface TtsVolumePoint {
  date: string;
  /** Total TTS jobs completed that day */
  value: number;
  /** Breakdown by provider */
  byProvider: Record<string, number>;
  /** Top voice IDs with counts (capped at 10 per day) */
  byVoice: Array<{ voiceId: string; count: number }>;
}

export interface TtsVolumeTotals {
  /** Total completed TTS jobs in the range */
  totalCompleted: number;
  /** Breakdown by provider for the entire range */
  byProvider: Record<string, number>;
  /** Top 10 voice IDs across the range */
  topVoices: Array<{ voiceId: string; count: number }>;
}

export interface TtsVolumeResponse {
  series: TtsVolumePoint[];
  totals: TtsVolumeTotals;
}

// ---------------------------------------------------------------------------
// 7. GET /api/admin/analytics/tts/errors
//
// Daily error count series + top error messages.
// Recharts pattern: TimeSeriesChart (errors/day) + table for top errors
// ---------------------------------------------------------------------------

export interface TtsErrorPoint {
  date: string;
  /** Total TTS errors that day */
  value: number;
  /** Error rate: failed / (failed + completed) for that day. Decimal 0..1 */
  errorRate: number;
}

export interface TtsErrorMessage {
  /** Truncated error message (first 200 chars) */
  message: string;
  /** Number of occurrences in the range */
  count: number;
  /** Most recent occurrence (ISO 8601 datetime) */
  lastSeen: string;
}

export interface TtsErrorsTotals {
  /** Total failed TTS jobs in the range */
  totalErrors: number;
  /** Overall error rate for the range (decimal 0..1) */
  overallErrorRate: number;
  /** Top 10 error messages by frequency */
  topErrors: TtsErrorMessage[];
}

export interface TtsErrorsResponse {
  series: TtsErrorPoint[];
  totals: TtsErrorsTotals;
}

// ---------------------------------------------------------------------------
// 8. GET /api/admin/analytics/engagement/streaks (should-have)
//
// Distribution of active streak lengths across all users.
// Recharts pattern: BarChart (x=streak length bucket, y=user count)
// ---------------------------------------------------------------------------

export interface StreakBucket {
  /** Bucket label: "0", "1-2", "3-6", "7-13", "14-29", "30+" */
  bucket: string;
  /** Minimum streak length in this bucket (inclusive) */
  min: number;
  /** Maximum streak length in this bucket (inclusive, Infinity for last bucket) */
  max: number | null;
  /** Number of users whose current streak falls in this bucket */
  userCount: number;
}

export interface StreaksTotals {
  /** Total users with at least one session completion */
  usersWithStreaks: number;
  /** Average current streak length (days) */
  avgStreak: number;
  /** Median current streak length (days) */
  medianStreak: number;
  /** Longest active streak (days) */
  maxStreak: number;
  /** Users with active streak (completed a session today or yesterday) */
  activeStreakUsers: number;
}

export interface StreaksResponse {
  series: StreakBucket[];
  totals: StreaksTotals;
}

// ---------------------------------------------------------------------------
// 9. GET /api/admin/analytics/library (should-have)
//
// Library plan adoption and conversion table.
// Recharts pattern: horizontal BarChart or sortable table
// ---------------------------------------------------------------------------

export interface LibraryPlanRow {
  /** Library plan UUID */
  id: string;
  /** Library plan display name */
  name: string;
  /** Category (e.g. "fitness", "meditation") */
  category: string;
  /** Whether the library plan is currently published */
  isPublished: boolean;
  /** Number of user plans sourced from this library plan (all time) */
  totalAdoptions: number;
  /** Adoptions within the selected range */
  rangeAdoptions: number;
  /** Users who activated the adopted plan (isActive=true) */
  activatedCount: number;
  /** Users who completed at least one session with the adopted plan */
  sessionCount: number;
  /** Conversion rate: sessionCount / totalAdoptions (decimal 0..1). null if totalAdoptions is 0 */
  conversionRate: number | null;
}

export interface LibraryTotals {
  /** Total published library plans */
  publishedCount: number;
  /** Total adoptions across all library plans in the range */
  totalAdoptions: number;
  /** Overall conversion rate across all library plans */
  overallConversionRate: number | null;
}

export interface LibraryResponse {
  series: LibraryPlanRow[];
  totals: LibraryTotals;
}

// ---------------------------------------------------------------------------
// Error response shape (matches NestJS default HttpException format)
// ---------------------------------------------------------------------------

export interface AnalyticsErrorResponse {
  statusCode: 400 | 401 | 403 | 500;
  message: string;
  error: string;
}
