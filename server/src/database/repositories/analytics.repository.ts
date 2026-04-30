/**
 * AdminAnalyticsRepository — data-access layer for admin analytics queries.
 *
 * Extracted from AdminAnalyticsService (TASK-007) to separate raw database
 * queries from business logic and response formatting.
 *
 * All methods return raw data shapes; the service layer is responsible for
 * transforming these into API response DTOs.
 */

import { Injectable } from '@nestjs/common';
import { count, sql, gte, and, eq, ilike, or, desc, asc, inArray } from 'drizzle-orm';
import { DatabaseService } from '../database.service';
import {
  users,
  plans,
  ttsJobs,
  sessionCompletions,
  deletionRequests,
  libraryPlans,
  appVersionConfig,
} from '../schema';

// ---------------------------------------------------------------------------
// Raw result types (not API DTOs — just DB row shapes)
// ---------------------------------------------------------------------------

export interface OverviewRawCounts {
  totalUsers: number;
  totalPlans: number;
  totalTtsJobs: number;
  totalSessions: number;
  newSignupsCurrent: number;
  newPlansCurrent: number;
  ttsCompletedCurrent: number;
  ttsFailedCurrent: number;
  sessionsCurrent: number;
  avgDurationCurrent: number;
  activePlansCurrent: number;
  newSignupsPrevious: number;
  newPlansPrevious: number;
  ttsCompletedPrevious: number;
  ttsFailedPrevious: number;
  sessionsPrevious: number;
  avgDurationPrevious: number;
  activePlansPrevious: number;
  weeklyPlansPlayedCurrent: number;
  planCompletedCurrent: number;
  planActivatedCurrent: number;
  weeklyPlansPlayedPrevious: number;
  planCompletedPrevious: number;
  planActivatedPrevious: number;
}

export interface DateCountRow {
  date: string;
  value: number;
}

export interface ActivationRow {
  day: string;
  signups: number;
  activated: number;
}

export interface FunnelRawCounts {
  created: number;
  ttsStarted: number;
  ttsCompleted: number;
  activated: number;
  sessionCompleted: number;
}

export interface TtsVolumeRow {
  day: string;
  provider: string;
  voiceId: string;
  cnt: number;
}

export interface TtsErrorDailyRow {
  day: string;
  failedCount: number;
}

export interface TtsErrorTopRow {
  error: string | null;
  cnt: number;
  lastSeen: string;
}

export interface TtsErrorDailyTotalRow {
  day: string;
  totalCount: number;
}

export interface PlanDistributionRow {
  planCount: number;
  userCount: number;
}

export interface DormantRow {
  totalPlans: number;
  activePlans: number;
  recentlyUsed: number;
}

export interface StreakLengthRow {
  length: number;
  userCount: number;
}

export interface LibraryRawRow {
  id: string;
  name: string;
  category: string;
  isPublished: boolean;
  totalAdoptions: number;
  rangeAdoptions: number;
  activatedCount: number;
  sessionCount: number;
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

@Injectable()
export class AdminAnalyticsRepository {
  constructor(private readonly db: DatabaseService) {}

  // ========================================================================
  // 1. Overview metrics — parallel count queries
  // ========================================================================

  async getOverviewCounts(
    sevenDaysAgo: Date,
    fourteenDaysAgo: Date,
    currentStart: Date,
    currentEnd: Date,
    previousStart: Date,
    previousEnd: Date,
  ): Promise<OverviewRawCounts> {
    const drizzle = this.db.getDb();

    const [
      totalUsersResult,
      totalPlansResult,
      totalTtsJobsResult,
      totalSessionsResult,
      newSignupsCurrent,
      newPlansCurrent,
      ttsCompletedCurrent,
      ttsFailedCurrent,
      sessionsCurrent,
      avgDurationCurrent,
      activePlansCurrent,
      weeklyPlansPlayedCurrent,
      planCompletedCurrent,
      planActivatedCurrent,
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

      // ── TASK-001: weeklyPlansPlayed (current range) ──
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

    return {
      totalUsers: totalUsersResult[0].value,
      totalPlans: totalPlansResult[0].value,
      totalTtsJobs: totalTtsJobsResult[0].value,
      totalSessions: totalSessionsResult[0].value,
      newSignupsCurrent: newSignupsCurrent[0].value,
      newPlansCurrent: newPlansCurrent[0].value,
      ttsCompletedCurrent: ttsCompletedCurrent[0].value,
      ttsFailedCurrent: ttsFailedCurrent[0].value,
      sessionsCurrent: sessionsCurrent[0].value,
      avgDurationCurrent: Math.round(Number(avgDurationCurrent[0].value)),
      activePlansCurrent: activePlansCurrent[0].value,
      newSignupsPrevious: newSignupsPrevious[0].value,
      newPlansPrevious: newPlansPrevious[0].value,
      ttsCompletedPrevious: ttsCompletedPrevious[0].value,
      ttsFailedPrevious: ttsFailedPrevious[0].value,
      sessionsPrevious: sessionsPrevious[0].value,
      avgDurationPrevious: Math.round(Number(avgDurationPrevious[0].value)),
      activePlansPrevious: activePlansPrevious[0].value,
      weeklyPlansPlayedCurrent: weeklyPlansPlayedCurrent[0].value,
      planCompletedCurrent: planCompletedCurrent[0].value,
      planActivatedCurrent: planActivatedCurrent[0].value,
      weeklyPlansPlayedPrevious: weeklyPlansPlayedPrevious[0].value,
      planCompletedPrevious: planCompletedPrevious[0].value,
      planActivatedPrevious: planActivatedPrevious[0].value,
    };
  }

  /**
   * Daily session completion sparkline for the overview cards.
   */
  async getOverviewSparkline(
    currentStart: Date,
    currentEnd: Date,
  ): Promise<DateCountRow[]> {
    const drizzle = this.db.getDb();

    const rows = await drizzle
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

    return rows.map((r) => ({ date: r.date, value: Number(r.value) }));
  }

  // ========================================================================
  // 2. User signups time series
  // ========================================================================

  async getSignupsTimeSeries(startDate: Date): Promise<DateCountRow[]> {
    const drizzle = this.db.getDb();

    const rows = await drizzle
      .select({
        date: sql<string>`DATE_TRUNC('day', ${users.createdAt})::date::text`,
        value: count(),
      })
      .from(users)
      .where(gte(users.createdAt, startDate))
      .groupBy(sql`DATE_TRUNC('day', ${users.createdAt})`)
      .orderBy(sql`DATE_TRUNC('day', ${users.createdAt})`);

    return rows.map((r) => ({ date: r.date, value: Number(r.value) }));
  }

  // ========================================================================
  // 3. User activation (CTE query)
  // ========================================================================

  async getActivationTimeSeries(
    startDate: Date,
    endDate: Date,
  ): Promise<ActivationRow[]> {
    const drizzle = this.db.getDb();

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

    return (result.rows as Array<{ day: string; signups: number; activated: number }>).map(
      (r) => ({
        day: r.day,
        signups: Number(r.signups),
        activated: Number(r.activated),
      }),
    );
  }

  // ========================================================================
  // 4. Plan funnel
  // ========================================================================

  async getFunnelCounts(startDate: Date): Promise<FunnelRawCounts> {
    const drizzle = this.db.getDb();

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

    return {
      created: Number(row.created),
      ttsStarted: Number(row.tts_started),
      ttsCompleted: Number(row.tts_completed),
      activated: Number(row.activated),
      sessionCompleted: Number(row.session_completed),
    };
  }

  // ========================================================================
  // 5. TTS volume
  // ========================================================================

  async getTtsVolumeTimeSeries(startDate: Date): Promise<TtsVolumeRow[]> {
    const drizzle = this.db.getDb();

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

    return (
      result.rows as Array<{
        day: string;
        provider: string;
        voice_id: string;
        cnt: number;
      }>
    ).map((r) => ({
      day: r.day,
      provider: r.provider,
      voiceId: r.voice_id,
      cnt: Number(r.cnt),
    }));
  }

  // ========================================================================
  // 6. TTS errors
  // ========================================================================

  async getTtsErrorData(startDate: Date): Promise<{
    dailyFailed: TtsErrorDailyRow[];
    topErrors: TtsErrorTopRow[];
    totalJobs: number;
  }> {
    const drizzle = this.db.getDb();

    const [dailyResult, topErrorsResult, totalJobsResult] = await Promise.all([
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

    const dailyFailed = (
      dailyResult.rows as Array<{ day: string; failed_count: number }>
    ).map((r) => ({
      day: r.day,
      failedCount: Number(r.failed_count),
    }));

    const topErrors = (
      topErrorsResult.rows as Array<{
        error: string | null;
        cnt: number;
        last_seen: string;
      }>
    ).map((r) => ({
      error: r.error,
      cnt: Number(r.cnt),
      lastSeen: r.last_seen,
    }));

    const totalJobs = Number(
      (totalJobsResult.rows[0] as { total: number })?.total ?? 0,
    );

    return { dailyFailed, topErrors, totalJobs };
  }

  async getTtsDailyTotals(startDate: Date): Promise<TtsErrorDailyTotalRow[]> {
    const drizzle = this.db.getDb();

    const result = await drizzle.execute(sql`
      SELECT
        DATE_TRUNC('day', created_at)::date::text AS day,
        COUNT(*)::int AS total_count
      FROM tts_jobs
      WHERE created_at >= ${startDate.toISOString()}
      GROUP BY 1
    `);

    return (
      result.rows as Array<{ day: string; total_count: number }>
    ).map((r) => ({
      day: r.day,
      totalCount: Number(r.total_count),
    }));
  }

  // ========================================================================
  // 7. Plan usage
  // ========================================================================

  async getPlanDistribution(startDate: Date): Promise<PlanDistributionRow[]> {
    const drizzle = this.db.getDb();

    const result = await drizzle.execute(sql`
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

    return (
      result.rows as Array<{ plan_count: number; user_count: number }>
    ).map((r) => ({
      planCount: Number(r.plan_count),
      userCount: Number(r.user_count),
    }));
  }

  async getDormantStats(startDate: Date): Promise<DormantRow> {
    const drizzle = this.db.getDb();
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    const result = await drizzle.execute(sql`
      SELECT
        COUNT(*)::int AS total_plans,
        COUNT(*) FILTER (WHERE is_active = true)::int AS active_plans,
        COUNT(DISTINCT CASE WHEN sc.completed_at >= ${thirtyDaysAgo.toISOString()} THEN p.id END)::int AS recently_used
      FROM plans p
      LEFT JOIN session_completions sc ON sc.plan_id = p.id
      WHERE p.created_at >= ${startDate.toISOString()}
    `);

    const row = result.rows[0] as {
      total_plans: number;
      active_plans: number;
      recently_used: number;
    };

    return {
      totalPlans: Number(row.total_plans),
      activePlans: Number(row.active_plans),
      recentlyUsed: Number(row.recently_used),
    };
  }

  async getTotalUserCount(): Promise<number> {
    const drizzle = this.db.getDb();
    const result = await drizzle.select({ value: count() }).from(users);
    return result[0].value;
  }

  // ========================================================================
  // 8. Engagement streaks
  // ========================================================================

  async getStreakDistribution(ninetyDaysAgo: Date): Promise<StreakLengthRow[]> {
    const drizzle = this.db.getDb();

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

    return (
      result.rows as Array<{ length: number; user_count: number }>
    ).map((r) => ({
      length: Number(r.length),
      userCount: Number(r.user_count),
    }));
  }

  async getActiveStreakUsers(
    ninetyDaysAgo: Date,
    yesterdayStr: string,
  ): Promise<number> {
    const drizzle = this.db.getDb();

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
      SELECT COUNT(*)::int AS active_count
      FROM current_streaks
      WHERE streak_end >= ${yesterdayStr}
    `);

    return Number(
      (result.rows[0] as { active_count: number })?.active_count ?? 0,
    );
  }

  // ========================================================================
  // 9. Library conversions
  // ========================================================================

  async getLibraryConversionRows(startDate: Date): Promise<LibraryRawRow[]> {
    const drizzle = this.db.getDb();

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

    return (
      result.rows as Array<{
        id: string;
        name: string;
        category: string;
        is_published: boolean;
        total_adoptions: number;
        range_adoptions: number;
        activated_count: number;
        session_count: number;
      }>
    ).map((r) => ({
      id: r.id,
      name: r.name,
      category: r.category,
      isPublished: r.is_published,
      totalAdoptions: Number(r.total_adoptions),
      rangeAdoptions: Number(r.range_adoptions),
      activatedCount: Number(r.activated_count),
      sessionCount: Number(r.session_count),
    }));
  }

  // ─── Retention Analytics ──────────────────────────────────────────────────

  /** Get cohort size (users created between start and end). */
  async getCohortSize(start: Date, end: Date): Promise<number> {
    const drizzle = this.db.getDb();
    const result = await drizzle.execute(sql`
      SELECT COUNT(DISTINCT u.id)::int AS cohort_size
      FROM users u
      WHERE u.created_at >= ${start} AND u.created_at < ${end}
    `);
    const rows = result.rows as Array<Record<string, unknown>>;
    return Number(rows[0]?.cohort_size ?? 0);
  }

  /** Get retained user count (users in cohort who completed sessions in retention window). */
  async getRetainedCount(
    cohortStart: Date,
    cohortEnd: Date,
    retentionStart: Date,
    retentionEnd?: Date,
  ): Promise<number> {
    const drizzle = this.db.getDb();
    const result = retentionEnd
      ? await drizzle.execute(sql`
          SELECT COUNT(DISTINCT sc.user_id)::int AS retained_count
          FROM session_completions sc
          INNER JOIN users u ON u.id = sc.user_id
          WHERE u.created_at >= ${cohortStart}
            AND u.created_at < ${cohortEnd}
            AND sc.completed_at >= ${retentionStart}
            AND sc.completed_at < ${retentionEnd}
        `)
      : await drizzle.execute(sql`
          SELECT COUNT(DISTINCT sc.user_id)::int AS retained_count
          FROM session_completions sc
          INNER JOIN users u ON u.id = sc.user_id
          WHERE u.created_at >= ${cohortStart}
            AND u.created_at < ${cohortEnd}
            AND sc.completed_at >= ${retentionStart}
        `);
    const rows = result.rows as Array<Record<string, unknown>>;
    return Number(rows[0]?.retained_count ?? 0);
  }

  /** Get DAU time series (distinct users per day). */
  async getDauTimeSeries(startDate: Date, endDate: Date): Promise<Array<{ date: string; value: number }>> {
    const drizzle = this.db.getDb();
    const result = await drizzle.execute(sql`
      SELECT
        DATE_TRUNC('day', completed_at)::date::text AS date,
        COUNT(DISTINCT user_id)::int AS value
      FROM session_completions
      WHERE completed_at >= ${startDate} AND completed_at <= ${endDate}
      GROUP BY DATE_TRUNC('day', completed_at)
      ORDER BY DATE_TRUNC('day', completed_at)
    `);
    return (result.rows as Array<Record<string, unknown>>).map((r) => ({
      date: String(r.date ?? ''),
      value: Number(r.value ?? 0),
    }));
  }

  /** Get WAU time series (distinct users per ISO week). */
  async getWauTimeSeries(startDate: Date, endDate: Date): Promise<Array<{ date: string; value: number }>> {
    const drizzle = this.db.getDb();
    const result = await drizzle.execute(sql`
      SELECT
        DATE_TRUNC('week', completed_at)::date::text AS date,
        COUNT(DISTINCT user_id)::int AS value
      FROM session_completions
      WHERE completed_at >= ${startDate} AND completed_at <= ${endDate}
      GROUP BY DATE_TRUNC('week', completed_at)
      ORDER BY DATE_TRUNC('week', completed_at)
    `);
    return (result.rows as Array<Record<string, unknown>>).map((r) => ({
      date: String(r.date ?? ''),
      value: Number(r.value ?? 0),
    }));
  }

  /** Get MAU time series (distinct users per month). */
  async getMauTimeSeries(startDate: Date, endDate: Date): Promise<Array<{ date: string; value: number }>> {
    const drizzle = this.db.getDb();
    const result = await drizzle.execute(sql`
      SELECT
        DATE_TRUNC('month', completed_at)::date::text AS date,
        COUNT(DISTINCT user_id)::int AS value
      FROM session_completions
      WHERE completed_at >= ${startDate} AND completed_at <= ${endDate}
      GROUP BY DATE_TRUNC('month', completed_at)
      ORDER BY DATE_TRUNC('month', completed_at)
    `);
    return (result.rows as Array<Record<string, unknown>>).map((r) => ({
      date: String(r.date ?? ''),
      value: Number(r.value ?? 0),
    }));
  }

  // ─── Activity Feed ────────────────────────────────────────────────────────

  /** Get recent signups (last N). */
  async getRecentSignups(limit: number): Promise<Array<{ id: string; email: string; createdAt: string }>> {
    const drizzle = this.db.getDb();
    const result = await drizzle.execute(sql`
      SELECT id, email, created_at FROM users ORDER BY created_at DESC LIMIT ${limit}
    `);
    return (result.rows as Array<Record<string, unknown>>).map((r) => ({
      id: String(r.id ?? ''),
      email: String(r.email ?? ''),
      createdAt: r.created_at instanceof Date
        ? r.created_at.toISOString()
        : new Date(r.created_at as string).toISOString(),
    }));
  }

  /** Get recent TTS failures (last N). */
  async getRecentTtsFailures(limit: number): Promise<Array<{ id: string; provider: string; error: string; createdAt: string }>> {
    const drizzle = this.db.getDb();
    const result = await drizzle.execute(sql`
      SELECT id, provider, error, created_at FROM tts_jobs WHERE status = 'failed' ORDER BY created_at DESC LIMIT ${limit}
    `);
    return (result.rows as Array<Record<string, unknown>>).map((r) => ({
      id: String(r.id ?? ''),
      provider: String(r.provider ?? 'unknown'),
      error: String(r.error ?? 'Unknown error'),
      createdAt: r.created_at instanceof Date
        ? r.created_at.toISOString()
        : new Date(r.created_at as string).toISOString(),
    }));
  }

  /** Get recent deletion requests (last N). */
  async getRecentDeletionRequests(limit: number): Promise<Array<{ id: string; email: string; requestedAt: string }>> {
    const drizzle = this.db.getDb();
    const result = await drizzle.execute(sql`
      SELECT id, email, requested_at FROM deletion_requests ORDER BY requested_at DESC LIMIT ${limit}
    `);
    return (result.rows as Array<Record<string, unknown>>).map((r) => ({
      id: String(r.id ?? ''),
      email: String(r.email ?? ''),
      requestedAt: r.requested_at instanceof Date
        ? r.requested_at.toISOString()
        : new Date(r.requested_at as string).toISOString(),
    }));
  }

  // ─── TTS Health ───────────────────────────────────────────────────────────

  /** Get TTS job counts for a provider in a time window. */
  async getTtsProviderCounts(provider: string, since: Date): Promise<{ total: number; failed: number }> {
    const drizzle = this.db.getDb();
    const result = await drizzle.execute(sql`
      SELECT
        COUNT(*)::int AS total,
        COUNT(*) FILTER (WHERE status = 'failed')::int AS failed
      FROM tts_jobs
      WHERE created_at >= ${since} AND provider = ${provider}
    `);
    const row = (result.rows as Array<Record<string, unknown>>)[0] ?? {};
    return { total: Number(row.total ?? 0), failed: Number(row.failed ?? 0) };
  }

  /** Get last successful TTS job timestamp for a provider. */
  async getTtsLastSuccess(provider: string): Promise<Date | null> {
    const drizzle = this.db.getDb();
    const result = await drizzle.execute(sql`
      SELECT MAX(created_at) AS last_success_at
      FROM tts_jobs
      WHERE status = 'completed' AND provider = ${provider}
    `);
    const row = (result.rows as Array<Record<string, unknown>>)[0] ?? {};
    const raw = row.last_success_at;
    return raw ? new Date(raw as string) : null;
  }

  // ─── Library Category ─────────────────────────────────────────────────────

  /** Get library plan category breakdown with adoption and session stats. */
  async getLibraryCategoryBreakdown(
    startDate: Date,
    endDate: Date,
  ): Promise<Array<{ category: string; publishedPlans: number; totalAdoptions: number; totalSessions: number }>> {
    const drizzle = this.db.getDb();
    const result = await drizzle.execute(sql`
      SELECT
        lp.category,
        COUNT(DISTINCT lp.id) FILTER (WHERE lp.is_published = true)::int AS published_plans,
        COUNT(DISTINCT p.user_id) FILTER (
          WHERE p.created_at >= ${startDate} AND p.created_at <= ${endDate}
        )::int AS total_adoptions,
        COUNT(DISTINCT sc.id) FILTER (
          WHERE sc.completed_at >= ${startDate} AND sc.completed_at <= ${endDate}
        )::int AS total_sessions
      FROM library_plans lp
      LEFT JOIN plans p ON p.source_library_plan_id = lp.id
      LEFT JOIN session_completions sc ON sc.plan_id = p.id
      GROUP BY lp.category
      ORDER BY lp.category
    `);
    return (result.rows as Array<Record<string, unknown>>).map((r) => ({
      category: String(r.category ?? ''),
      publishedPlans: Number(r.published_plans ?? 0),
      totalAdoptions: Number(r.total_adoptions ?? 0),
      totalSessions: Number(r.total_sessions ?? 0),
    }));
  }

  // ─── Admin Users ──────────────────────────────────────────────────────────

  /** List users with pagination, search, and role filter. Returns raw DB rows. */
  async listAdminUsers(params: {
    page: number;
    pageSize: number;
    searchPattern: string | null;
    role?: string;
  }): Promise<{ rows: Array<Record<string, unknown>>; total: number }> {
    const drizzle = this.db.getDb();

    const searchClause = params.searchPattern
      ? or(
          ilike(users.email, params.searchPattern),
          ilike(users.name, params.searchPattern),
          ilike(users.username, params.searchPattern),
        )
      : undefined;
    const roleClause = params.role ? eq(users.role, params.role) : undefined;
    const whereClause =
      searchClause && roleClause
        ? and(searchClause, roleClause)
        : (searchClause ?? roleClause);

    const planCounts = drizzle
      .select({
        userId: plans.userId,
        planCount: count().as('plan_count'),
      })
      .from(plans)
      .groupBy(plans.userId)
      .as('plan_counts');

    const lastActivity = drizzle
      .select({
        userId: sessionCompletions.userId,
        lastActivityAt: sql<Date | null>`MAX(${sessionCompletions.completedAt})`.as('last_activity_at'),
      })
      .from(sessionCompletions)
      .groupBy(sessionCompletions.userId)
      .as('last_activity');

    const [totalResult, rows] = await Promise.all([
      drizzle
        .select({ value: count() })
        .from(users)
        .where(whereClause ?? sql`true`),
      drizzle
        .select({
          id: users.id,
          email: users.email,
          name: users.name,
          username: users.username,
          role: users.role,
          createdAt: users.createdAt,
          planCount: planCounts.planCount,
          lastActivityAt: lastActivity.lastActivityAt,
        })
        .from(users)
        .leftJoin(planCounts, eq(planCounts.userId, users.id))
        .leftJoin(lastActivity, eq(lastActivity.userId, users.id))
        .where(whereClause ?? sql`true`)
        .orderBy(desc(users.createdAt), asc(users.id))
        .limit(params.pageSize)
        .offset((params.page - 1) * params.pageSize),
    ]);

    return {
      rows: rows as unknown as Array<Record<string, unknown>>,
      total: totalResult[0]?.value ?? 0,
    };
  }

  /** Get a single user by ID with basic fields. */
  async getAdminUserById(id: string) {
    const drizzle = this.db.getDb();
    const rows = await drizzle
      .select({
        id: users.id,
        email: users.email,
        name: users.name,
        username: users.username,
        role: users.role,
        photoUrl: users.photoUrl,
        createdAt: users.createdAt,
      })
      .from(users)
      .where(eq(users.id, id))
      .limit(1);
    return rows[0] ?? null;
  }

  /** Get plan stats, session stats, TTS stats, and recent plans for a user. */
  async getUserDetailStats(userId: string) {
    const drizzle = this.db.getDb();
    const [planStats, sessionStats, ttsStats, recentPlans] = await Promise.all([
      drizzle
        .select({
          total: count(),
          active: sql<number>`COUNT(*) FILTER (WHERE ${plans.isActive} = true)::int`,
        })
        .from(plans)
        .where(eq(plans.userId, userId)),
      drizzle
        .select({
          total: count(),
          avgDurationMs: sql<number>`AVG(${sessionCompletions.durationMs})`,
          totalDurationMs: sql<number>`SUM(${sessionCompletions.durationMs})`,
          lastCompletedAt: sql<Date | null>`MAX(${sessionCompletions.completedAt})`,
        })
        .from(sessionCompletions)
        .where(eq(sessionCompletions.userId, userId)),
      drizzle
        .select({
          total: count(),
          completed: sql<number>`COUNT(*) FILTER (WHERE ${ttsJobs.status} = 'completed')::int`,
          failed: sql<number>`COUNT(*) FILTER (WHERE ${ttsJobs.status} = 'failed')::int`,
        })
        .from(ttsJobs)
        .innerJoin(plans, eq(ttsJobs.planId, plans.id))
        .where(eq(plans.userId, userId)),
      drizzle
        .select({
          id: plans.id,
          name: plans.name,
          isActive: plans.isActive,
          ttsStatus: plans.ttsStatus,
          createdAt: plans.createdAt,
        })
        .from(plans)
        .where(eq(plans.userId, userId))
        .orderBy(desc(plans.createdAt))
        .limit(25),
    ]);
    return { planStats, sessionStats, ttsStats, recentPlans };
  }

  /** Get session stats grouped by plan IDs. */
  async getPlanSessionStats(planIds: string[]) {
    if (planIds.length === 0) return [];
    const drizzle = this.db.getDb();
    return drizzle
      .select({
        planId: sessionCompletions.planId,
        runCount: count(),
        lastRunAt: sql<Date | null>`MAX(${sessionCompletions.completedAt})`,
      })
      .from(sessionCompletions)
      .where(inArray(sessionCompletions.planId, planIds))
      .groupBy(sessionCompletions.planId);
  }

  /** Get plan detail by ID. */
  async getAdminPlanDetail(planId: string) {
    const drizzle = this.db.getDb();
    const rows = await drizzle
      .select({
        id: plans.id,
        userId: plans.userId,
        name: plans.name,
        planJson: plans.planJson,
        isActive: plans.isActive,
        ttsStatus: plans.ttsStatus,
        ttsTotal: plans.ttsTotal,
        ttsCompleted: plans.ttsCompleted,
        voiceQuality: plans.voiceQuality,
        shareToken: plans.shareToken,
        createdAt: plans.createdAt,
        updatedAt: plans.updatedAt,
      })
      .from(plans)
      .where(eq(plans.id, planId))
      .limit(1);
    return rows[0] ?? null;
  }

  /** Get user sessions with plan names. */
  async getAdminUserSessions(userId: string, limit: number) {
    const drizzle = this.db.getDb();
    const result = await drizzle.execute(sql`
      SELECT
        sc.id,
        COALESCE(lp.name, p.name, 'Unknown Plan') AS plan_name,
        sc.completed_at,
        sc.duration_ms
      FROM session_completions sc
      LEFT JOIN plans p ON p.id = sc.plan_id
      LEFT JOIN library_plans lp ON lp.id = p.source_library_plan_id
      WHERE sc.user_id = ${userId}
      ORDER BY sc.completed_at DESC
      LIMIT ${limit}
    `);
    return result.rows as Array<Record<string, unknown>>;
  }

  /** Get plans with summary for a user. */
  async getAdminPlansWithSummary(userId: string, limit: number) {
    const drizzle = this.db.getDb();
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const result = await drizzle.execute(sql`
      SELECT
        p.id, p.name, p.is_active, p.tts_status, p.created_at,
        COUNT(sc.id)::int AS run_count,
        MAX(sc.completed_at) AS last_run_at,
        CASE WHEN MAX(sc.completed_at) >= ${thirtyDaysAgo} THEN true ELSE false END AS has_recent_session
      FROM plans p
      LEFT JOIN session_completions sc ON sc.plan_id = p.id
      WHERE p.user_id = ${userId}
      GROUP BY p.id, p.name, p.is_active, p.tts_status, p.created_at
      ORDER BY p.created_at DESC
      LIMIT ${limit}
    `);
    return result.rows as Array<Record<string, unknown>>;
  }

  /** Update user role. */
  async updateAdminUserRole(id: string, role: string) {
    const drizzle = this.db.getDb();
    return drizzle
      .update(users)
      .set({ role })
      .where(eq(users.id, id))
      .returning({ id: users.id, role: users.role });
  }

  // ─── CSV Export ───────────────────────────────────────────────────────────

  /** Fetch a batch of users for CSV export. */
  async getUsersCsvBatch(params: {
    search?: string;
    role?: string;
    limit: number;
    offset: number;
  }) {
    const drizzle = this.db.getDb();
    const conditions: Array<ReturnType<typeof eq>> = [];
    if (params.search) {
      conditions.push(ilike(users.email, `%${params.search}%`) as unknown as ReturnType<typeof eq>);
    }
    if (params.role) {
      conditions.push(eq(users.role, params.role));
    }
    const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

    return drizzle
      .select({
        id: users.id,
        email: users.email,
        role: users.role,
        createdAt: users.createdAt,
        planCount: sql<number>`(SELECT COUNT(*)::int FROM ${plans} WHERE ${plans.userId} = ${users.id})`,
        lastActiveAt: sql<Date | null>`(SELECT MAX(${sessionCompletions.completedAt}) FROM ${sessionCompletions} WHERE ${sessionCompletions.userId} = ${users.id})`,
      })
      .from(users)
      .where(whereClause)
      .orderBy(desc(users.createdAt))
      .limit(params.limit)
      .offset(params.offset);
  }

  /** Fetch a batch of deletion requests for CSV export. */
  async getDeletionRequestsCsvBatch(params: {
    search?: string;
    status?: string;
    limit: number;
    offset: number;
  }) {
    const drizzle = this.db.getDb();
    const conditions: Array<ReturnType<typeof eq>> = [];
    if (params.search) {
      conditions.push(ilike(deletionRequests.email, `%${params.search}%`) as unknown as ReturnType<typeof eq>);
    }
    if (params.status) {
      conditions.push(eq(deletionRequests.status, params.status));
    }
    const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

    return drizzle
      .select()
      .from(deletionRequests)
      .where(whereClause)
      .orderBy(desc(deletionRequests.createdAt))
      .limit(params.limit)
      .offset(params.offset);
  }

  // ─── Deletion Requests Admin ──────────────────────────────────────────────

  /** List deletion requests with pagination. */
  async listDeletionRequests(params: {
    page: number;
    pageSize: number;
    search?: string;
    status?: string;
  }): Promise<{ rows: typeof deletionRequests.$inferSelect[]; total: number }> {
    const drizzle = this.db.getDb();
    const offset = (params.page - 1) * params.pageSize;
    const conditions: Parameters<typeof and>[0][] = [];

    if (params.search) {
      conditions.push(ilike(deletionRequests.email, `%${params.search}%`));
    }
    if (params.status) {
      conditions.push(eq(deletionRequests.status, params.status));
    }
    const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

    const totalResult = await drizzle
      .select({ value: count() })
      .from(deletionRequests)
      .where(whereClause);

    const rows = await drizzle
      .select()
      .from(deletionRequests)
      .where(whereClause)
      .orderBy(deletionRequests.createdAt)
      .limit(params.pageSize)
      .offset(offset);

    return { rows, total: totalResult[0].value };
  }

  /** Atomically mark a deletion request as processed. Returns updated row or null. */
  async processDeletionRequestById(id: string) {
    const drizzle = this.db.getDb();
    return drizzle
      .update(deletionRequests)
      .set({ status: 'processed', processedAt: new Date() })
      .where(and(eq(deletionRequests.id, id), eq(deletionRequests.status, 'pending')))
      .returning({
        id: deletionRequests.id,
        status: deletionRequests.status,
        processedAt: deletionRequests.processedAt,
      });
  }

  /** Check if a deletion request exists and get its status. */
  async getDeletionRequestStatus(id: string) {
    const drizzle = this.db.getDb();
    return drizzle
      .select({ status: deletionRequests.status })
      .from(deletionRequests)
      .where(eq(deletionRequests.id, id));
  }

  /** Get count of pending deletion requests. */
  async getPendingDeletionRequestCount(): Promise<number> {
    const drizzle = this.db.getDb();
    const result = await drizzle
      .select({ value: count() })
      .from(deletionRequests)
      .where(eq(deletionRequests.status, 'pending'));
    return result[0].value;
  }

  // ─── App Version Admin ────────────────────────────────────────────────────

  /** Get app version config. */
  async getAppVersionConfig() {
    const drizzle = this.db.getDb();
    const rows = await drizzle.select().from(appVersionConfig).limit(1);
    return rows[0] ?? null;
  }

  /** Update app version config. */
  async updateAppVersionConfig(configId: string, setClause: Record<string, unknown>) {
    const drizzle = this.db.getDb();
    return drizzle
      .update(appVersionConfig)
      .set(setClause as Partial<typeof appVersionConfig.$inferInsert>)
      .where(eq(appVersionConfig.id, configId))
      .returning();
  }
}
