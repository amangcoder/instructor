/**
 * Admin Analytics API — Response types for the web admin dashboard.
 *
 * These mirror the server-side DTOs in server/src/admin/dto/analytics.dto.ts.
 * They are duplicated here so the Next.js web app does not depend on the
 * NestJS server package at build time.
 */

// ---------------------------------------------------------------------------
// Shared / base types
// ---------------------------------------------------------------------------

export interface TimeSeriesPoint {
  date: string;
  value: number;
}

// ---------------------------------------------------------------------------
// TTS Volume  — GET /api/admin/analytics/tts/volume
// ---------------------------------------------------------------------------

export interface TtsVolumePoint {
  date: string;
  value: number;
  byProvider: Record<string, number>;
  byVoice: Array<{ voiceId: string; count: number }>;
}

export interface TtsVolumeTotals {
  totalCompleted: number;
  byProvider: Record<string, number>;
  topVoices: Array<{ voiceId: string; count: number }>;
}

export interface TtsVolumeResponse {
  series: TtsVolumePoint[];
  totals: TtsVolumeTotals;
}

// ---------------------------------------------------------------------------
// TTS Errors  — GET /api/admin/analytics/tts/errors
// ---------------------------------------------------------------------------

export interface TtsErrorPoint {
  date: string;
  value: number;
  errorRate: number;
}

export interface TtsErrorMessage {
  message: string;
  count: number;
  lastSeen: string;
}

export interface TtsErrorsTotals {
  totalErrors: number;
  overallErrorRate: number;
  topErrors: TtsErrorMessage[];
}

export interface TtsErrorsResponse {
  series: TtsErrorPoint[];
  totals: TtsErrorsTotals;
}

// ---------------------------------------------------------------------------
// Engagement Streaks  — GET /api/admin/analytics/engagement/streaks
// ---------------------------------------------------------------------------

export interface StreakBucket {
  bucket: string;
  min: number;
  max: number | null;
  userCount: number;
}

export interface StreaksTotals {
  usersWithStreaks: number;
  avgStreak: number;
  medianStreak: number;
  maxStreak: number;
  activeStreakUsers: number;
}

export interface StreaksResponse {
  series: StreakBucket[];
  totals: StreaksTotals;
}

// ---------------------------------------------------------------------------
// Library Plan CRUD  — /api/library/plans
// ---------------------------------------------------------------------------

export interface AdminLibraryPlanRecord {
  id: string;
  name: string;
  description: string | null;
  category: string;
  tags: string;
  defaultVoice: string;
  planJson: string;
  locale: string;
  isPublished: boolean;
  sortOrder: number;
}

// ---------------------------------------------------------------------------
// Library Conversions  — GET /api/admin/analytics/library
// ---------------------------------------------------------------------------

export interface LibraryPlanRow {
  id: string;
  name: string;
  category: string;
  isPublished: boolean;
  totalAdoptions: number;
  rangeAdoptions: number;
  activatedCount: number;
  sessionCount: number;
  conversionRate: number | null;
}

export interface LibraryTotals {
  publishedCount: number;
  totalAdoptions: number;
  overallConversionRate: number | null;
}

export interface LibraryResponse {
  series: LibraryPlanRow[];
  totals: LibraryTotals;
}

// ---------------------------------------------------------------------------
// Extended Overview Response  — GET /api/admin/analytics/overview?range=7d|30d|90d
// ---------------------------------------------------------------------------

/** Metric with optional sparkline for charts within stat cards */
export interface OverviewMetric {
  /** Current count for the selected range */
  current: number;
  /** Count for the previous equivalent range (for delta calculation) */
  previous: number;
  /** Percentage change: ((current - previous) / previous) * 100. null if previous is 0 */
  deltaPercent: number | null;
}

/** Sparkline variant of OverviewMetric for time-series visualization */
export interface OverviewMetricWithSparkline extends OverviewMetric {
  /** 7-point time series data for inline sparkline chart */
  sparkline: TimeSeriesPoint[];
}

/** Extended overview totals including new metrics for the North Star */
export interface ExtendedOverviewTotals {
  /** Total registered users (all time) */
  totalUsers: OverviewMetric;
  /** New user signups in the selected range */
  newSignups: OverviewMetric;
  /** Active plans in the selected range */
  activePlans: OverviewMetric;
  /** Total library plans (all time) */
  totalPlans: OverviewMetric;
  /** Completed TTS synthesis jobs in the selected range */
  ttsJobsCompleted: OverviewMetric;
  /** Failed TTS synthesis jobs in the selected range */
  ttsJobsFailed: OverviewMetric;
  /** Completed session runs in the selected range (North Star metric) */
  totalSessions: OverviewMetric;
  /** Average session duration in milliseconds */
  avgSessionDurationMs: OverviewMetric;
  /** Weekly plans played: session completions with 7-point sparkline for trend visualization */
  weeklyPlansPlayed: OverviewMetricWithSparkline;
  /** Plan completion rate: sessions completed / plans activated (sessions / activations) */
  planCompletionRate: OverviewMetric;
}

/** Extended overview response with new metrics, backwards compatible with OverviewResponse */
export interface ExtendedOverviewResponse {
  /** Always empty for overview endpoint */
  series: [];
  /** Top-line metrics with 7-day deltas and new North Star metrics */
  totals: ExtendedOverviewTotals;
}
