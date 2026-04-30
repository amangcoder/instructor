/**
 * Pure utility functions for admin analytics data transformation.
 *
 * Extracted from AdminAnalyticsService (TASK-007) so they can be
 * reused by any service or tested independently of the database.
 *
 * All functions are stateless and have zero database dependencies.
 */

import type {
  TimeSeriesPoint,
  TimeSeriesRatePoint,
  OverviewMetric,
  FunnelStage,
} from '../admin/dto/analytics.dto';

// ---------------------------------------------------------------------------
// fillDateGaps — contiguous daily time series with zero-fill
// ---------------------------------------------------------------------------

/**
 * Generate a contiguous daily time series, filling missing dates with value=0.
 *
 * The frontend expects exactly N entries for an N-day range so that charts
 * render a continuous x-axis without gaps.
 *
 * @param dataMap  Map of ISO date strings (YYYY-MM-DD) to numeric values
 * @param startDate  Start of the range (inclusive, truncated to UTC day)
 * @param endDate    End of the range (inclusive, truncated to UTC day)
 * @returns Array of { date, value } covering every calendar day in the range
 */
export function fillDateGaps(
  dataMap: Map<string, number>,
  startDate: Date,
  endDate: Date,
): TimeSeriesPoint[] {
  const series: TimeSeriesPoint[] = [];
  const current = new Date(
    Date.UTC(
      startDate.getUTCFullYear(),
      startDate.getUTCMonth(),
      startDate.getUTCDate(),
    ),
  );
  const end = new Date(
    Date.UTC(
      endDate.getUTCFullYear(),
      endDate.getUTCMonth(),
      endDate.getUTCDate(),
    ),
  );

  while (current <= end) {
    const dateStr = current.toISOString().slice(0, 10);
    series.push({
      date: dateStr,
      value: dataMap.get(dateStr) ?? 0,
    });
    current.setUTCDate(current.getUTCDate() + 1);
  }

  return series;
}

// ---------------------------------------------------------------------------
// fillDateGapsWithRate — contiguous daily time series for rate metrics
// ---------------------------------------------------------------------------

/**
 * Fill date gaps for rate-based time series (e.g. activation rate).
 *
 * Each entry contains the absolute count, the rate (0..1), and the
 * denominator total. Missing dates are filled with zeroes.
 */
export function fillDateGapsWithRate(
  dataMap: Map<string, { value: number; rate: number; total: number }>,
  startDate: Date,
  endDate: Date,
): TimeSeriesRatePoint[] {
  const series: TimeSeriesRatePoint[] = [];
  const current = new Date(
    Date.UTC(
      startDate.getUTCFullYear(),
      startDate.getUTCMonth(),
      startDate.getUTCDate(),
    ),
  );
  const end = new Date(
    Date.UTC(
      endDate.getUTCFullYear(),
      endDate.getUTCMonth(),
      endDate.getUTCDate(),
    ),
  );

  while (current <= end) {
    const dateStr = current.toISOString().slice(0, 10);
    const entry = dataMap.get(dateStr);
    series.push(
      entry
        ? { date: dateStr, ...entry }
        : { date: dateStr, value: 0, rate: 0, total: 0 },
    );
    current.setUTCDate(current.getUTCDate() + 1);
  }

  return series;
}

// ---------------------------------------------------------------------------
// buildMetric — OverviewMetric with period-over-period delta
// ---------------------------------------------------------------------------

/**
 * Compute an OverviewMetric with a percentage delta between two periods.
 *
 * @param current   Metric value for the current period
 * @param previous  Metric value for the previous period
 * @returns         OverviewMetric with deltaPercent (null if previous is 0)
 */
export function buildMetric(current: number, previous: number): OverviewMetric {
  const deltaPercent =
    previous === 0 ? null : ((current - previous) / previous) * 100;
  return { current, previous, deltaPercent };
}

// ---------------------------------------------------------------------------
// buildFunnelStages — plan lifecycle funnel with drop-off calculations
// ---------------------------------------------------------------------------

/**
 * Build funnel stages with percentOfTop and dropOffPercent calculations.
 *
 * Each stage shows what fraction of the top-of-funnel (created) reached it,
 * and how much dropped off from the immediately preceding stage.
 */
export function buildFunnelStages(
  created: number,
  ttsStarted: number,
  ttsCompleted: number,
  activated: number,
  sessionCompleted: number,
): FunnelStage[] {
  const stagesData: Array<{
    stage: FunnelStage['stage'];
    label: string;
    count: number;
  }> = [
    { stage: 'created', label: 'Plans Created', count: created },
    { stage: 'tts_started', label: 'TTS Started', count: ttsStarted },
    { stage: 'tts_completed', label: 'TTS Completed', count: ttsCompleted },
    { stage: 'activated', label: 'Activated', count: activated },
    {
      stage: 'session_completed',
      label: 'Session Completed',
      count: sessionCompleted,
    },
  ];

  return stagesData.map((s, i) => {
    const percentOfTop =
      created > 0 ? Math.round((s.count / created) * 1000) / 10 : 0;
    const prevCount = i > 0 ? stagesData[i - 1].count : null;
    const dropOffPercent =
      prevCount === null
        ? null
        : prevCount > 0
          ? Math.round(((prevCount - s.count) / prevCount) * 1000) / 10
          : 0;

    return {
      stage: s.stage,
      label: s.label,
      count: s.count,
      percentOfTop,
      dropOffPercent,
    };
  });
}

// ---------------------------------------------------------------------------
// sanitizeErrorMessage — strip PII from error strings
// ---------------------------------------------------------------------------

/**
 * Strip PII and internal details from TTS provider error messages.
 *
 * - Truncates to 200 characters
 * - Strips email-like patterns (anything@something.ext)
 * - Strips file paths (/foo/bar/baz or C:\foo\bar)
 */
export function sanitizeErrorMessage(raw: string): string {
  let cleaned = raw;
  // Strip email-like patterns
  cleaned = cleaned.replace(/\b[\w.+-]+@[\w.-]+\.\w{2,}\b/g, '[REDACTED_EMAIL]');
  // Strip Unix-style absolute file paths
  cleaned = cleaned.replace(/\/(?:[\w.-]+\/){2,}[\w.-]+/g, '[REDACTED_PATH]');
  // Strip Windows-style absolute file paths
  cleaned = cleaned.replace(/[A-Z]:\\(?:[\w.-]+\\){1,}[\w.-]+/gi, '[REDACTED_PATH]');
  // Truncate to 200 chars
  if (cleaned.length > 200) {
    cleaned = cleaned.slice(0, 200);
  }
  return cleaned;
}

// ---------------------------------------------------------------------------
// computeRetentionRate — safe division for retention cohorts
// ---------------------------------------------------------------------------

/**
 * Compute a retention rate as a decimal (0..1).
 *
 * Returns 0 when cohortSize is 0, avoiding NaN / Infinity.
 *
 * @param retained   Number of users retained
 * @param cohortSize Total users in the cohort
 * @returns          Retention rate in [0, 1]
 */
export function computeRetentionRate(retained: number, cohortSize: number): number {
  if (cohortSize === 0) return 0;
  return retained / cohortSize;
}
