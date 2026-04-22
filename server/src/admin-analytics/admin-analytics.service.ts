/**
 * AdminAnalyticsService — read-only analytics aggregation queries.
 *
 * All database operations use `this.db.withRetry()` to handle Neon cold starts.
 * All queries use `this.db.getDb()` for direct Drizzle access.
 *
 * Methods:
 *   - getOverview()            — top-line counts with 7-day deltas
 *   - getUserSignups(range)    — daily signup time series
 *   - getUserActivation(range) — daily activation rate (CTE + COUNT FILTER)
 *   - getPlanFunnel(range)     — plan lifecycle funnel with drop-off percentages
 *   - getTtsVolume(range)      — daily TTS volume grouped by provider and voiceId
 *   - getTtsErrors(range)      — daily TTS error counts + top error messages
 *   - getPlanUsage(range)      — plans-per-user distribution + active/dormant
 *   - getEngagementStreaks()   — streak length distribution via gaps-and-islands
 *   - getLibraryConversions(range) — library plan adoption counts
 */

import { Injectable, Logger } from '@nestjs/common';
import { count, sql, gte, and } from 'drizzle-orm';
import { DatabaseService } from '../database/database.service';
import {
  users,
  plans,
  ttsJobs,
  sessionCompletions,
  libraryPlans,
} from '../database/schema';
import type { AnalyticsRange } from '../admin/dto/analytics.dto';
import type {
  OverviewResponse,
  OverviewMetric,
  SignupsResponse,
  TimeSeriesPoint,
  ActivationResponse,
  TimeSeriesRatePoint,
  FunnelResponse,
  FunnelStage,
  TtsVolumeResponse,
  TtsVolumePoint,
  TtsErrorsResponse,
  TtsErrorPoint,
  TtsErrorMessage,
  PlanUsageResponse,
  PlansPerUserBucket,
  StreaksResponse,
  StreakBucket,
  LibraryResponse,
  LibraryPlanRow,
} from '../admin/dto/analytics.dto';
import { rangeToDate } from './dto/range-query.dto';

// ---------------------------------------------------------------------------
// Utility: fill date gaps in time series
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

/**
 * Fill date gaps for rate-based time series (activation).
 */
function fillDateGapsWithRate(
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
// Helper: compute OverviewMetric with delta
// ---------------------------------------------------------------------------

function buildMetric(current: number, previous: number): OverviewMetric {
  const deltaPercent =
    previous === 0 ? null : ((current - previous) / previous) * 100;
  return { current, previous, deltaPercent };
}

// ---------------------------------------------------------------------------
// Helper: build funnel stages with drop-off calculations
// ---------------------------------------------------------------------------

function buildFunnelStages(
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
// Helper: sanitize error messages for safe API responses
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
// Service
// ---------------------------------------------------------------------------

@Injectable()
export class AdminAnalyticsService {
  private readonly logger = new Logger(AdminAnalyticsService.name);

  constructor(private readonly db: DatabaseService) {}

  // ========================================================================
  // 1. getOverview()
  // ========================================================================

  /**
   * Top-line counts with range-configurable deltas for dashboard header cards.
   *
   * Accepts an AnalyticsRange parameter ('7d' | '30d' | '90d', default '30d').
   * Computes period-over-period deltas for metrics within that range.
   *
   * NEW (TASK-001): Adds two new metrics:
   *   - weeklyPlansPlayed: COUNT of session_completions in range with sparkline
   *   - planCompletionRate: (completed plans / activated plans) * 100
   *
   * Runs 8+ parallel COUNT queries:
   *   - 4 total counts (users, plans, ttsJobs, sessionCompletions)
   *   - 4-6 range-filtered counts for current period
   *   - 4-6 range-filtered counts for previous period (for deltas)
   *
   * Keep totalUsers and totalPlans as ALL-TIME counts (no range filter).
   * Only period metrics are range-filtered.
   */
  async getOverview(range?: AnalyticsRange): Promise<OverviewResponse> {
    return this.db.withRetry(async () => {
      const drizzle = this.db.getDb();
      const resolvedRange: AnalyticsRange = range ?? '30d';

      // Compute date windows based on range
      const now = new Date();
      const startDate = rangeToDate(resolvedRange);
      const endDate = new Date();

      // Previous period: from (2 * offset days ago) to (offset days ago)
      let rangeDays = 7;
      if (resolvedRange === '30d') rangeDays = 30;
      if (resolvedRange === '90d') rangeDays = 90;

      const currentStart = new Date(startDate);
      const currentEnd = new Date(now);
      const previousEnd = new Date(currentStart);
      const previousStart = new Date(currentStart.getTime() - rangeDays * 24 * 60 * 60 * 1000);

      // Legacy: also keep sevenDaysAgo for backward compatibility with existing metrics
      const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      const fourteenDaysAgo = new Date(
        now.getTime() - 14 * 24 * 60 * 60 * 1000,
      );

      const [
        // Total counts (all-time, no range filter)
        totalUsersResult,
        totalPlansResult,
        totalTtsJobsResult,
        totalSessionsResult,
        // Current range counts
        newSignupsCurrent,
        newPlansCurrent,
        ttsCompletedCurrent,
        ttsFailedCurrent,
        sessionsCurrent,
        avgDurationCurrent,
        activePlansCurrent,
        weeklyPlansPlayedCurrent, // TASK-001: session completions in current range
        planCompletedCurrent,     // TASK-001: plans with ttsStatus='completed' AND isActive=true
        planActivatedCurrent,     // TASK-001: plans with isActive=true
        // Previous range counts (for deltas)
        newSignupsPrevious,
        newPlansPrevious,
        ttsCompletedPrevious,
        ttsFailedPrevious,
        sessionsPrevious,
        avgDurationPrevious,
        activePlansPrevious,
        weeklyPlansPlayedPrevious,
        planCompletedPrevious,
        planActivatedPrevious,
      ] = await Promise.all([
        // ── Total counts ──
        drizzle.select({ value: count() }).from(users),
        drizzle.select({ value: count() }).from(plans),
        drizzle.select({ value: count() }).from(ttsJobs),
        drizzle.select({ value: count() }).from(sessionCompletions),

        // ── Current 7d ──
        drizzle
          .select({ value: count() })
          .from(users)
          .where(gte(users.createdAt, sevenDaysAgo)),
        drizzle
          .select({ value: count() })
          .from(plans)
          .where(gte(plans.createdAt, sevenDaysAgo)),
        drizzle
          .select({ value: count() })
          .from(ttsJobs)
          .where(
            and(
              gte(ttsJobs.createdAt, sevenDaysAgo),
              sql`${ttsJobs.status} = 'completed'`,
            ),
          ),
        drizzle
          .select({ value: count() })
          .from(ttsJobs)
          .where(
            and(
              gte(ttsJobs.createdAt, sevenDaysAgo),
              sql`${ttsJobs.status} = 'failed'`,
            ),
          ),
        drizzle
          .select({ value: count() })
          .from(sessionCompletions)
          .where(gte(sessionCompletions.createdAt, sevenDaysAgo)),
        drizzle
          .select({
            value: sql<number>`COALESCE(AVG(${sessionCompletions.durationMs}), 0)`,
          })
          .from(sessionCompletions)
          .where(gte(sessionCompletions.createdAt, sevenDaysAgo)),
        drizzle
          .select({ value: count() })
          .from(plans)
          .where(
            and(
              sql`${plans.isActive} = true`,
              gte(plans.createdAt, sevenDaysAgo),
            ),
          ),

        // ── Previous 7d (7-14 days ago) ──
        drizzle
          .select({ value: count() })
          .from(users)
          .where(
            and(
              gte(users.createdAt, fourteenDaysAgo),
              sql`${users.createdAt} < ${sevenDaysAgo}`,
            ),
          ),
        drizzle
          .select({ value: count() })
          .from(plans)
          .where(
            and(
              gte(plans.createdAt, fourteenDaysAgo),
              sql`${plans.createdAt} < ${sevenDaysAgo}`,
            ),
          ),
        drizzle
          .select({ value: count() })
          .from(ttsJobs)
          .where(
            and(
              gte(ttsJobs.createdAt, fourteenDaysAgo),
              sql`${ttsJobs.createdAt} < ${sevenDaysAgo}`,
              sql`${ttsJobs.status} = 'completed'`,
            ),
          ),
        drizzle
          .select({ value: count() })
          .from(ttsJobs)
          .where(
            and(
              gte(ttsJobs.createdAt, fourteenDaysAgo),
              sql`${ttsJobs.createdAt} < ${sevenDaysAgo}`,
              sql`${ttsJobs.status} = 'failed'`,
            ),
          ),
        drizzle
          .select({ value: count() })
          .from(sessionCompletions)
          .where(
            and(
              gte(sessionCompletions.createdAt, fourteenDaysAgo),
              sql`${sessionCompletions.createdAt} < ${sevenDaysAgo}`,
            ),
          ),
        drizzle
          .select({
            value: sql<number>`COALESCE(AVG(${sessionCompletions.durationMs}), 0)`,
          })
          .from(sessionCompletions)
          .where(
            and(
              gte(sessionCompletions.createdAt, fourteenDaysAgo),
              sql`${sessionCompletions.createdAt} < ${sevenDaysAgo}`,
            ),
          ),
        drizzle
          .select({ value: count() })
          .from(plans)
          .where(
            and(
              sql`${plans.isActive} = true`,
              gte(plans.createdAt, fourteenDaysAgo),
              sql`${plans.createdAt} < ${sevenDaysAgo}`,
            ),
          ),

        // ── TASK-001: weeklyPlansPlayed (current range) ──
        // COUNT session completions in the current range
        drizzle
          .select({ value: count() })
          .from(sessionCompletions)
          .where(
            and(
              gte(sessionCompletions.completedAt, currentStart),
              sql`${sessionCompletions.completedAt} <= ${currentEnd}`,
            ),
          ),
        // ── TASK-001: planCompletionRate (current range) ──
        // Plans with ttsStatus='completed' AND isActive=true (within current range)
        drizzle
          .select({ value: count() })
          .from(plans)
          .where(
            and(
              sql`${plans.ttsStatus} = 'completed'`,
              sql`${plans.isActive} = true`,
              gte(plans.createdAt, currentStart),
              sql`${plans.createdAt} <= ${currentEnd}`,
            ),
          ),
        // Activated plans in current range (for denominator of completion rate)
        drizzle
          .select({ value: count() })
          .from(plans)
          .where(
            and(
              sql`${plans.isActive} = true`,
              gte(plans.createdAt, currentStart),
              sql`${plans.createdAt} <= ${currentEnd}`,
            ),
          ),

        // ── TASK-001: weeklyPlansPlayed (previous range) ──
        drizzle
          .select({ value: count() })
          .from(sessionCompletions)
          .where(
            and(
              gte(sessionCompletions.completedAt, previousStart),
              sql`${sessionCompletions.completedAt} < ${previousEnd}`,
            ),
          ),
        // ── TASK-001: planCompletionRate (previous range) ──
        drizzle
          .select({ value: count() })
          .from(plans)
          .where(
            and(
              sql`${plans.ttsStatus} = 'completed'`,
              sql`${plans.isActive} = true`,
              gte(plans.createdAt, previousStart),
              sql`${plans.createdAt} < ${previousEnd}`,
            ),
          ),
        // Activated plans in previous range
        drizzle
          .select({ value: count() })
          .from(plans)
          .where(
            and(
              sql`${plans.isActive} = true`,
              gte(plans.createdAt, previousStart),
              sql`${plans.createdAt} < ${previousEnd}`,
            ),
          ),
      ]);

      // TASK-001: Generate sparkline for weeklyPlansPlayed
      const sparklineRows = await drizzle
        .select({
          date: sql<string>`DATE_TRUNC('day', ${sessionCompletions.completedAt})::date::text`,
          value: count(),
        })
        .from(sessionCompletions)
        .where(
          and(
            gte(sessionCompletions.completedAt, currentStart),
            sql`${sessionCompletions.completedAt} <= ${currentEnd}`,
          ),
        )
        .groupBy(sql`DATE_TRUNC('day', ${sessionCompletions.completedAt})`)
        .orderBy(sql`DATE_TRUNC('day', ${sessionCompletions.completedAt})`);

      const sparklineMap = new Map<string, number>();
      for (const row of sparklineRows) {
        sparklineMap.set(row.date, Number(row.value));
      }
      const sparkline = fillDateGaps(sparklineMap, currentStart, currentEnd);

      // TASK-001: Calculate planCompletionRate as a decimal percentage
      const completedCurrent = planCompletedCurrent[0].value;
      const activatedCurrent = planActivatedCurrent[0].value;
      const completedPrevious = planCompletedPrevious[0].value;
      const activatedPrevious = planActivatedPrevious[0].value;

      const completionRateCurrent = activatedCurrent > 0
        ? (completedCurrent / activatedCurrent) * 100
        : 0;
      const completionRatePrevious = activatedPrevious > 0
        ? (completedPrevious / activatedPrevious) * 100
        : 0;

      return {
        series: [] as [],
        totals: {
          weeklyPlansPlayed: {
            current: weeklyPlansPlayedCurrent[0].value,
            previous: weeklyPlansPlayedPrevious[0].value,
            deltaPercent:
              weeklyPlansPlayedPrevious[0].value === 0
                ? null
                : ((weeklyPlansPlayedCurrent[0].value - weeklyPlansPlayedPrevious[0].value) /
                   weeklyPlansPlayedPrevious[0].value) *
                  100,
            sparkline,
          },
          planCompletionRate: buildMetric(
            Math.round(completionRateCurrent * 10) / 10,
            Math.round(completionRatePrevious * 10) / 10,
          ),
          totalUsers: buildMetric(
            totalUsersResult[0].value,
            totalUsersResult[0].value, // total doesn't have a "previous" — same value
          ),
          newSignups: buildMetric(
            newSignupsCurrent[0].value,
            newSignupsPrevious[0].value,
          ),
          activePlans: buildMetric(
            activePlansCurrent[0].value,
            activePlansPrevious[0].value,
          ),
          totalPlans: buildMetric(
            totalPlansResult[0].value,
            totalPlansResult[0].value,
          ),
          ttsJobsCompleted: buildMetric(
            ttsCompletedCurrent[0].value,
            ttsCompletedPrevious[0].value,
          ),
          ttsJobsFailed: buildMetric(
            ttsFailedCurrent[0].value,
            ttsFailedPrevious[0].value,
          ),
          totalSessions: buildMetric(
            sessionsCurrent[0].value,
            sessionsPrevious[0].value,
          ),
          avgSessionDurationMs: buildMetric(
            Math.round(Number(avgDurationCurrent[0].value)),
            Math.round(Number(avgDurationPrevious[0].value)),
          ),
        },
      };
    });
  }

  // ========================================================================
  // 2. getUserSignups(range)
  // ========================================================================

  /**
   * Daily time series of new user registrations.
   *
   * Uses date_trunc('day', users.createdAt) for grouping, then fills
   * any missing calendar days with value=0 via fillDateGaps().
   */
  async getUserSignups(range: AnalyticsRange): Promise<SignupsResponse> {
    return this.db.withRetry(async () => {
      const drizzle = this.db.getDb();
      const startDate = rangeToDate(range);
      const endDate = new Date();

      const rows = await drizzle
        .select({
          date: sql<string>`DATE_TRUNC('day', ${users.createdAt})::date::text`,
          value: count(),
        })
        .from(users)
        .where(gte(users.createdAt, startDate))
        .groupBy(sql`DATE_TRUNC('day', ${users.createdAt})`)
        .orderBy(sql`DATE_TRUNC('day', ${users.createdAt})`);

      // Build a lookup map for fillDateGaps
      const dataMap = new Map<string, number>();
      for (const row of rows) {
        dataMap.set(row.date, Number(row.value));
      }

      const series = fillDateGaps(dataMap, startDate, endDate);

      // Compute totals
      const total = series.reduce((sum, p) => sum + p.value, 0);
      const dayCount = series.length || 1;
      const avgPerDay = Math.round((total / dayCount) * 100) / 100;

      let peakDay = 0;
      let peakDate = series[0]?.date ?? startDate.toISOString().slice(0, 10);
      for (const point of series) {
        if (point.value > peakDay) {
          peakDay = point.value;
          peakDate = point.date;
        }
      }

      return {
        series,
        totals: {
          total,
          avgPerDay,
          peakDay,
          peakDate,
        },
      };
    });
  }

  // ========================================================================
  // 3. getUserActivation(range)
  // ========================================================================

  /**
   * Daily activation rate: users who created a plan within 24h of signup.
   *
   * Uses CTE + COUNT FILTER approach (NOT LATERAL JOIN) for performance:
   *   - Single hash-aggregate on plans table
   *   - Avoids O(N) index probes that LATERAL JOIN would cause
   *
   * SQL:
   *   WITH first_plans AS (
   *     SELECT user_id, MIN(created_at) AS first_plan_at
   *     FROM plans GROUP BY user_id
   *   )
   *   SELECT
   *     DATE_TRUNC('day', u.created_at) AS day,
   *     COUNT(*) AS signups,
   *     COUNT(*) FILTER (
   *       WHERE fp.first_plan_at <= u.created_at + INTERVAL '24 hours'
   *     ) AS activated
   *   FROM users u
   *   LEFT JOIN first_plans fp ON fp.user_id = u.id
   *   WHERE u.created_at BETWEEN $1 AND $2
   *   GROUP BY 1
   */
  async getUserActivation(range: AnalyticsRange): Promise<ActivationResponse> {
    return this.db.withRetry(async () => {
      const drizzle = this.db.getDb();
      const startDate = rangeToDate(range);
      const endDate = new Date();

      const result = await drizzle.execute(sql`
        WITH first_plans AS (
          SELECT user_id, MIN(created_at) AS first_plan_at
          FROM plans
          GROUP BY user_id
        )
        SELECT
          DATE_TRUNC('day', u.created_at)::date::text AS day,
          COUNT(*)::int AS signups,
          COUNT(*) FILTER (
            WHERE fp.first_plan_at <= u.created_at + INTERVAL '24 hours'
          )::int AS activated
        FROM users u
        LEFT JOIN first_plans fp ON fp.user_id = u.id
        WHERE u.created_at BETWEEN ${startDate.toISOString()} AND ${endDate.toISOString()}
        GROUP BY 1
        ORDER BY 1
      `);

      const rows = result.rows as Array<{
        day: string;
        signups: number;
        activated: number;
      }>;

      // Build rate map for fillDateGapsWithRate
      const dataMap = new Map<
        string,
        { value: number; rate: number; total: number }
      >();
      let totalSignups = 0;
      let totalActivated = 0;

      for (const row of rows) {
        const signups = Number(row.signups);
        const activated = Number(row.activated);
        const rate = signups > 0 ? activated / signups : 0;

        dataMap.set(row.day, {
          value: activated,
          rate: Math.round(rate * 10000) / 10000, // 4 decimal places
          total: signups,
        });

        totalSignups += signups;
        totalActivated += activated;
      }

      const series = fillDateGapsWithRate(dataMap, startDate, endDate);

      const overallRate =
        totalSignups > 0
          ? Math.round((totalActivated / totalSignups) * 10000) / 10000
          : 0;

      return {
        series,
        totals: {
          totalSignups,
          totalActivated,
          overallRate,
        },
      };
    });
  }

  // ========================================================================
  // 4. getPlanFunnel(range)
  // ========================================================================

  /**
   * Plan lifecycle funnel: created → tts_started → tts_completed → activated → session_completed.
   *
   * Each stage counts plans (created within the range) that reached that lifecycle point.
   * Drop-off percentages are calculated relative to the previous stage.
   * Division by zero returns 0 (not NaN or Infinity).
   */
  async getPlanFunnel(range: AnalyticsRange): Promise<FunnelResponse> {
    return this.db.withRetry(async () => {
      const drizzle = this.db.getDb();
      const startDate = rangeToDate(range);

      const result = await drizzle.execute(sql`
        SELECT
          COUNT(*)::int AS created,
          COUNT(*) FILTER (WHERE tts_status != 'none')::int AS tts_started,
          COUNT(*) FILTER (WHERE tts_status = 'completed')::int AS tts_completed,
          COUNT(*) FILTER (WHERE is_active = true)::int AS activated,
          COUNT(DISTINCT sc.plan_id)::int AS session_completed
        FROM plans p
        LEFT JOIN session_completions sc ON sc.plan_id = p.id
        WHERE p.created_at >= ${startDate.toISOString()}
      `);

      const row = result.rows[0] as {
        created: number;
        tts_started: number;
        tts_completed: number;
        activated: number;
        session_completed: number;
      };

      const created = Number(row.created);
      const ttsStarted = Number(row.tts_started);
      const ttsCompleted = Number(row.tts_completed);
      const activated = Number(row.activated);
      const sessionCompleted = Number(row.session_completed);

      const stages: FunnelStage[] = buildFunnelStages(
        created,
        ttsStarted,
        ttsCompleted,
        activated,
        sessionCompleted,
      );

      const overallConversionPercent =
        created > 0
          ? Math.round((sessionCompleted / created) * 1000) / 10
          : 0;

      return {
        series: stages,
        totals: {
          totalCreated: created,
          overallConversionPercent,
        },
      };
    });
  }

  // ========================================================================
  // 5. getTtsVolume(range)
  // ========================================================================

  /**
   * Daily TTS job counts grouped by provider and voiceId.
   *
   * Uses the idx_tts_jobs_created_provider_voice composite index for efficient
   * GROUP BY date_trunc('day', createdAt), provider, voiceId.
   */
  async getTtsVolume(range: AnalyticsRange): Promise<TtsVolumeResponse> {
    return this.db.withRetry(async () => {
      const drizzle = this.db.getDb();
      const startDate = rangeToDate(range);
      const endDate = new Date();

      // Get daily breakdown by provider and voiceId
      const result = await drizzle.execute(sql`
        SELECT
          DATE_TRUNC('day', created_at)::date::text AS day,
          provider,
          voice_id,
          COUNT(*)::int AS cnt
        FROM tts_jobs
        WHERE created_at >= ${startDate.toISOString()}
        GROUP BY 1, provider, voice_id
        ORDER BY 1
      `);

      const rows = result.rows as Array<{
        day: string;
        provider: string;
        voice_id: string;
        cnt: number;
      }>;

      // Aggregate into daily series and totals
      const dayMap = new Map<
        string,
        { value: number; byProvider: Record<string, number>; byVoice: Map<string, number> }
      >();
      const totalByProvider: Record<string, number> = {};
      const totalByVoice = new Map<string, number>();

      for (const row of rows) {
        const day = row.day;
        const provider = row.provider;
        const voiceId = row.voice_id;
        const cnt = Number(row.cnt);

        if (!dayMap.has(day)) {
          dayMap.set(day, { value: 0, byProvider: {}, byVoice: new Map() });
        }
        const entry = dayMap.get(day)!;
        entry.value += cnt;
        entry.byProvider[provider] = (entry.byProvider[provider] ?? 0) + cnt;
        entry.byVoice.set(voiceId, (entry.byVoice.get(voiceId) ?? 0) + cnt);

        // Totals
        totalByProvider[provider] = (totalByProvider[provider] ?? 0) + cnt;
        totalByVoice.set(voiceId, (totalByVoice.get(voiceId) ?? 0) + cnt);
      }

      // Build series with date gap filling
      const filledDates = fillDateGaps(new Map(), startDate, endDate);
      const series: TtsVolumePoint[] = filledDates.map((point) => {
        const entry = dayMap.get(point.date);
        if (!entry) {
          return { date: point.date, value: 0, byProvider: {}, byVoice: [] };
        }
        // Top 10 voices per day
        const byVoice = [...entry.byVoice.entries()]
          .sort((a, b) => b[1] - a[1])
          .slice(0, 10)
          .map(([voiceId, count]) => ({ voiceId, count }));
        return {
          date: point.date,
          value: entry.value,
          byProvider: entry.byProvider,
          byVoice,
        };
      });

      // Top 10 voices overall
      const topVoices = [...totalByVoice.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, 10)
        .map(([voiceId, count]) => ({ voiceId, count }));

      const totalCompleted = series.reduce((sum, p) => sum + p.value, 0);

      return {
        series,
        totals: {
          totalCompleted,
          byProvider: totalByProvider,
          topVoices,
        },
      };
    });
  }

  // ========================================================================
  // 6. getTtsErrors(range)
  // ========================================================================

  /**
   * Daily TTS error counts + top error messages.
   *
   * Uses the idx_tts_jobs_failed partial index (WHERE status='failed')
   * for efficient range scans on failed jobs.
   *
   * SECURITY: Error messages are sanitized before returning — truncated to
   * 200 chars, email-like patterns and file paths are stripped since raw
   * TTS provider errors may contain PII or internal service details.
   */
  async getTtsErrors(range: AnalyticsRange): Promise<TtsErrorsResponse> {
    return this.db.withRetry(async () => {
      const drizzle = this.db.getDb();
      const startDate = rangeToDate(range);
      const endDate = new Date();

      // Run three queries in parallel:
      // 1. Daily failed counts
      // 2. Top 10 error messages
      // 3. Total jobs in range (for error rate denominator)
      const [dailyResult, topErrorsResult, totalJobsResult] =
        await Promise.all([
          drizzle.execute(sql`
            SELECT
              DATE_TRUNC('day', created_at)::date::text AS day,
              COUNT(*)::int AS failed_count
            FROM tts_jobs
            WHERE status = 'failed' AND created_at >= ${startDate.toISOString()}
            GROUP BY 1
            ORDER BY 1
          `),
          drizzle.execute(sql`
            SELECT
              error,
              COUNT(*)::int AS cnt,
              MAX(created_at)::text AS last_seen
            FROM tts_jobs
            WHERE status = 'failed'
              AND created_at >= ${startDate.toISOString()}
              AND error IS NOT NULL
            GROUP BY error
            ORDER BY cnt DESC
            LIMIT 10
          `),
          drizzle.execute(sql`
            SELECT COUNT(*)::int AS total
            FROM tts_jobs
            WHERE created_at >= ${startDate.toISOString()}
          `),
        ]);

      const dailyRows = dailyResult.rows as Array<{
        day: string;
        failed_count: number;
      }>;
      const topErrorRows = topErrorsResult.rows as Array<{
        error: string | null;
        cnt: number;
        last_seen: string;
      }>;
      const totalJobs = Number(
        (totalJobsResult.rows[0] as { total: number })?.total ?? 0,
      );

      // Build daily failed count map
      const failedMap = new Map<string, number>();
      let totalFailed = 0;
      for (const row of dailyRows) {
        const cnt = Number(row.failed_count);
        failedMap.set(row.day, cnt);
        totalFailed += cnt;
      }

      // Build daily total map for per-day error rate
      // We need per-day totals for errorRate — query all jobs grouped by day
      const dailyTotalResult = await drizzle.execute(sql`
        SELECT
          DATE_TRUNC('day', created_at)::date::text AS day,
          COUNT(*)::int AS total_count
        FROM tts_jobs
        WHERE created_at >= ${startDate.toISOString()}
        GROUP BY 1
      `);
      const dailyTotalRows = dailyTotalResult.rows as Array<{
        day: string;
        total_count: number;
      }>;
      const dailyTotalMap = new Map<string, number>();
      for (const row of dailyTotalRows) {
        dailyTotalMap.set(row.day, Number(row.total_count));
      }

      // Fill date gaps and compute per-day error rates
      const filledDates = fillDateGaps(failedMap, startDate, endDate);
      const series: TtsErrorPoint[] = filledDates.map((point) => {
        const dayTotal = dailyTotalMap.get(point.date) ?? 0;
        const errorRate =
          dayTotal > 0 ? Math.round((point.value / dayTotal) * 10000) / 10000 : 0;
        return {
          date: point.date,
          value: point.value,
          errorRate,
        };
      });

      // Sanitize and build top errors
      const topErrors: TtsErrorMessage[] = topErrorRows.map((row) => ({
        message: sanitizeErrorMessage(row.error ?? 'Unknown error'),
        count: Number(row.cnt),
        lastSeen: row.last_seen,
      }));

      const overallErrorRate =
        totalJobs > 0
          ? Math.round((totalFailed / totalJobs) * 10000) / 10000
          : 0;

      return {
        series,
        totals: {
          totalErrors: totalFailed,
          overallErrorRate,
          topErrors,
        },
      };
    });
  }

  // ========================================================================
  // 7. getPlanUsage(range)
  // ========================================================================

  /**
   * Plans-per-user distribution + active vs dormant breakdown.
   *
   * Two subqueries:
   *   (a) Plans-per-user distribution bucketed as "0", "1", "2", "3", "4", "5+"
   *   (b) Active vs dormant: a plan is "active" if it has at least one
   *       session_completion in the last 30 days, otherwise "dormant".
   */
  async getPlanUsage(range: AnalyticsRange): Promise<PlanUsageResponse> {
    return this.db.withRetry(async () => {
      const drizzle = this.db.getDb();
      const startDate = rangeToDate(range);

      // (a) Plans-per-user distribution
      const distributionResult = await drizzle.execute(sql`
        WITH user_plan_counts AS (
          SELECT user_id, COUNT(*)::int AS plan_count
          FROM plans
          WHERE created_at >= ${startDate.toISOString()}
          GROUP BY user_id
        )
        SELECT plan_count, COUNT(*)::int AS user_count
        FROM user_plan_counts
        GROUP BY plan_count
        ORDER BY plan_count
      `);

      const distributionRows = distributionResult.rows as Array<{
        plan_count: number;
        user_count: number;
      }>;

      // (b) Active vs dormant plans
      const thirtyDaysAgo = new Date(
        Date.now() - 30 * 24 * 60 * 60 * 1000,
      );

      const dormantResult = await drizzle.execute(sql`
        SELECT
          COUNT(*)::int AS total_plans,
          COUNT(*) FILTER (WHERE is_active = true)::int AS active_plans,
          COUNT(DISTINCT CASE WHEN sc.completed_at >= ${thirtyDaysAgo.toISOString()} THEN p.id END)::int AS recently_used
        FROM plans p
        LEFT JOIN session_completions sc ON sc.plan_id = p.id
        WHERE p.created_at >= ${startDate.toISOString()}
      `);

      const dormantRow = dormantResult.rows[0] as {
        total_plans: number;
        active_plans: number;
        recently_used: number;
      };

      const totalPlans = Number(dormantRow.total_plans);
      const activePlans = Number(dormantRow.active_plans);
      const recentlyUsed = Number(dormantRow.recently_used);
      const dormantPlans = totalPlans - recentlyUsed;

      // Build buckets: "0", "1", "2", "3", "4", "5+"
      const bucketCounts = new Map<string, number>();
      bucketCounts.set('1', 0);
      bucketCounts.set('2', 0);
      bucketCounts.set('3', 0);
      bucketCounts.set('4', 0);
      bucketCounts.set('5+', 0);

      let usersWithPlans = 0;
      let totalPlanCount = 0;

      for (const row of distributionRows) {
        const planCount = Number(row.plan_count);
        const userCount = Number(row.user_count);
        usersWithPlans += userCount;
        totalPlanCount += planCount * userCount;

        if (planCount >= 5) {
          bucketCounts.set('5+', (bucketCounts.get('5+') ?? 0) + userCount);
        } else {
          const key = String(planCount);
          bucketCounts.set(key, (bucketCounts.get(key) ?? 0) + userCount);
        }
      }

      // Get total users count for "0 plans" bucket
      const totalUsersResult = await drizzle
        .select({ value: count() })
        .from(users);
      const totalUsers = totalUsersResult[0].value;
      const usersWithoutPlans = totalUsers - usersWithPlans;

      const series: PlansPerUserBucket[] = [
        { bucket: '0', userCount: usersWithoutPlans },
        { bucket: '1', userCount: bucketCounts.get('1') ?? 0 },
        { bucket: '2', userCount: bucketCounts.get('2') ?? 0 },
        { bucket: '3', userCount: bucketCounts.get('3') ?? 0 },
        { bucket: '4', userCount: bucketCounts.get('4') ?? 0 },
        { bucket: '5+', userCount: bucketCounts.get('5+') ?? 0 },
      ];

      const avgPlansPerUser =
        usersWithPlans > 0
          ? Math.round((totalPlanCount / usersWithPlans) * 100) / 100
          : 0;

      return {
        series,
        totals: {
          usersWithPlans,
          usersWithoutPlans,
          avgPlansPerUser,
          activePlans,
          dormantPlans,
          totalPlans,
        },
      };
    });
  }

  // ========================================================================
  // 8. getEngagementStreaks()
  // ========================================================================

  /**
   * Distribution of active streak lengths using gaps-and-islands window
   * function approach via raw SQL.
   *
   * Algorithm:
   *   1. Get distinct (userId, date) pairs from session_completions (last 90d)
   *   2. Compute gaps: date - ROW_NUMBER() gives a constant group identifier
   *      for consecutive days
   *   3. Count streak lengths per (userId, group)
   *   4. Take the most recent (current) streak per user
   *   5. Bucket into distribution: "0", "1-2", "3-6", "7-13", "14-29", "30+"
   *
   * PERFORMANCE: Limited to 90-day window. Uses statement_timeout=5000ms.
   */
  async getEngagementStreaks(): Promise<StreaksResponse> {
    return this.db.withRetry(async () => {
      const drizzle = this.db.getDb();
      const ninetyDaysAgo = new Date(
        Date.now() - 90 * 24 * 60 * 60 * 1000,
      );

      // Set statement timeout for this query (SLA risk mitigation)
      await drizzle.execute(sql`SET LOCAL statement_timeout = '5000ms'`);

      const result = await drizzle.execute(sql`
        WITH daily AS (
          SELECT
            user_id,
            DATE(completed_at) AS d
          FROM session_completions
          WHERE completed_at >= ${ninetyDaysAgo.toISOString()}
          GROUP BY user_id, DATE(completed_at)
        ),
        gaps AS (
          SELECT
            user_id,
            d,
            d - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY d))::int AS grp
          FROM daily
        ),
        streaks AS (
          SELECT
            user_id,
            grp,
            COUNT(*)::int AS length,
            MAX(d) AS streak_end
          FROM gaps
          GROUP BY user_id, grp
        ),
        current_streaks AS (
          SELECT DISTINCT ON (user_id)
            user_id,
            length,
            streak_end
          FROM streaks
          ORDER BY user_id, streak_end DESC
        )
        SELECT
          length,
          COUNT(*)::int AS user_count
        FROM current_streaks
        GROUP BY length
        ORDER BY length
      `);

      const rows = result.rows as Array<{
        length: number;
        user_count: number;
      }>;

      // Build bucket distribution
      const bucketDefs: Array<{
        bucket: string;
        min: number;
        max: number | null;
      }> = [
        { bucket: '0', min: 0, max: 0 },
        { bucket: '1-2', min: 1, max: 2 },
        { bucket: '3-6', min: 3, max: 6 },
        { bucket: '7-13', min: 7, max: 13 },
        { bucket: '14-29', min: 14, max: 29 },
        { bucket: '30+', min: 30, max: null },
      ];

      const bucketMap = new Map<string, number>();
      for (const def of bucketDefs) {
        bucketMap.set(def.bucket, 0);
      }

      let usersWithStreaks = 0;
      let totalStreakLength = 0;
      let maxStreak = 0;
      const allLengths: number[] = [];

      for (const row of rows) {
        const len = Number(row.length);
        const cnt = Number(row.user_count);

        usersWithStreaks += cnt;
        totalStreakLength += len * cnt;
        if (len > maxStreak) maxStreak = len;

        // Add to allLengths for median calculation
        for (let i = 0; i < cnt; i++) {
          allLengths.push(len);
        }

        // Assign to bucket
        for (const def of bucketDefs) {
          if (def.max === null) {
            if (len >= def.min) {
              bucketMap.set(def.bucket, (bucketMap.get(def.bucket) ?? 0) + cnt);
            }
          } else if (len >= def.min && len <= def.max) {
            bucketMap.set(def.bucket, (bucketMap.get(def.bucket) ?? 0) + cnt);
          }
        }
      }

      // Calculate active streak users (streak ended today or yesterday)
      const today = new Date();
      const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000);
      const yesterdayStr = yesterday.toISOString().slice(0, 10);

      const activeResult = await drizzle.execute(sql`
        WITH daily AS (
          SELECT
            user_id,
            DATE(completed_at) AS d
          FROM session_completions
          WHERE completed_at >= ${ninetyDaysAgo.toISOString()}
          GROUP BY user_id, DATE(completed_at)
        ),
        gaps AS (
          SELECT
            user_id,
            d,
            d - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY d))::int AS grp
          FROM daily
        ),
        streaks AS (
          SELECT
            user_id,
            grp,
            COUNT(*)::int AS length,
            MAX(d) AS streak_end
          FROM gaps
          GROUP BY user_id, grp
        ),
        current_streaks AS (
          SELECT DISTINCT ON (user_id)
            user_id,
            length,
            streak_end
          FROM streaks
          ORDER BY user_id, streak_end DESC
        )
        SELECT COUNT(*)::int AS active_count
        FROM current_streaks
        WHERE streak_end >= ${yesterdayStr}
      `);

      const activeStreakUsers = Number(
        (activeResult.rows[0] as { active_count: number })?.active_count ?? 0,
      );

      // Compute median
      allLengths.sort((a, b) => a - b);
      const medianStreak =
        allLengths.length === 0
          ? 0
          : allLengths.length % 2 === 1
            ? allLengths[Math.floor(allLengths.length / 2)]
            : Math.round(
                ((allLengths[allLengths.length / 2 - 1] +
                  allLengths[allLengths.length / 2]) /
                  2) *
                  100,
              ) / 100;

      const avgStreak =
        usersWithStreaks > 0
          ? Math.round((totalStreakLength / usersWithStreaks) * 100) / 100
          : 0;

      const series: StreakBucket[] = bucketDefs.map((def) => ({
        bucket: def.bucket,
        min: def.min,
        max: def.max,
        userCount: bucketMap.get(def.bucket) ?? 0,
      }));

      return {
        series,
        totals: {
          usersWithStreaks,
          avgStreak,
          medianStreak,
          maxStreak,
          activeStreakUsers,
        },
      };
    });
  }

  // ========================================================================
  // 9. getLibraryConversions(range)
  // ========================================================================

  /**
   * Library plan adoption and conversion table.
   *
   * Shows each library plan's name, category, publication status,
   * adoption count (total + in range), activation count, session count,
   * and conversion rate.
   *
   * Uses idx_plans_source_library partial index for efficient filtering.
   */
  async getLibraryConversions(range: AnalyticsRange): Promise<LibraryResponse> {
    return this.db.withRetry(async () => {
      const drizzle = this.db.getDb();
      const startDate = rangeToDate(range);

      const result = await drizzle.execute(sql`
        SELECT
          lp.id,
          lp.name,
          lp.category,
          lp.is_published,
          COUNT(p.id)::int AS total_adoptions,
          COUNT(p.id) FILTER (WHERE p.created_at >= ${startDate.toISOString()})::int AS range_adoptions,
          COUNT(p.id) FILTER (WHERE p.is_active = true)::int AS activated_count,
          COUNT(DISTINCT sc.plan_id) FILTER (WHERE sc.id IS NOT NULL)::int AS session_count
        FROM library_plans lp
        LEFT JOIN plans p ON p.source_library_plan_id = lp.id
        LEFT JOIN session_completions sc ON sc.plan_id = p.id
        GROUP BY lp.id, lp.name, lp.category, lp.is_published
        ORDER BY total_adoptions DESC
      `);

      const rows = result.rows as Array<{
        id: string;
        name: string;
        category: string;
        is_published: boolean;
        total_adoptions: number;
        range_adoptions: number;
        activated_count: number;
        session_count: number;
      }>;

      let publishedCount = 0;
      let totalAdoptionsInRange = 0;
      let totalSessionsAcrossAll = 0;
      let totalAdoptionsAll = 0;

      const series: LibraryPlanRow[] = rows.map((row) => {
        const totalAdoptions = Number(row.total_adoptions);
        const rangeAdoptions = Number(row.range_adoptions);
        const activatedCount = Number(row.activated_count);
        const sessionCount = Number(row.session_count);
        const isPublished = row.is_published;

        if (isPublished) publishedCount++;
        totalAdoptionsInRange += rangeAdoptions;
        totalAdoptionsAll += totalAdoptions;
        totalSessionsAcrossAll += sessionCount;

        const conversionRate =
          totalAdoptions > 0
            ? Math.round((sessionCount / totalAdoptions) * 10000) / 10000
            : null;

        return {
          id: row.id,
          name: row.name,
          category: row.category,
          isPublished: isPublished,
          totalAdoptions: totalAdoptions,
          rangeAdoptions: rangeAdoptions,
          activatedCount: activatedCount,
          sessionCount: sessionCount,
          conversionRate: conversionRate,
        };
      });

      const overallConversionRate =
        totalAdoptionsAll > 0
          ? Math.round((totalSessionsAcrossAll / totalAdoptionsAll) * 10000) /
            10000
          : null;

      return {
        series,
        totals: {
          publishedCount,
          totalAdoptions: totalAdoptionsInRange,
          overallConversionRate,
        },
      };
    });
  }
}
