/**
 * AdminAnalyticsService — read-only analytics aggregation queries.
 *
 * Database queries are delegated to AdminAnalyticsRepository.
 * Pure data transformations use shared utilities from analytics-utils.
 * This service handles retry logic, date range computation, and response formatting.
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
import { DatabaseService } from '../database/database.service';
import { AdminAnalyticsRepository } from '../database/repositories';
import {
  fillDateGaps,
  fillDateGapsWithRate,
  buildMetric,
  buildFunnelStages,
  sanitizeErrorMessage,
} from '../common/analytics-utils';
import type { AnalyticsRange } from '../admin/dto/analytics.dto';
import type {
  OverviewResponse,
  SignupsResponse,
  ActivationResponse,
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

// Re-export utilities so existing imports from this module continue to work
export { fillDateGaps, sanitizeErrorMessage } from '../common/analytics-utils';

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

@Injectable()
export class AdminAnalyticsService {
  private readonly logger = new Logger(AdminAnalyticsService.name);

  constructor(
    private readonly db: DatabaseService,
    private readonly repo: AdminAnalyticsRepository,
  ) {}

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
   * Runs 8+ parallel COUNT queries via AdminAnalyticsRepository.
   *
   * Keep totalUsers and totalPlans as ALL-TIME counts (no range filter).
   * Only period metrics are range-filtered.
   */
  async getOverview(range?: AnalyticsRange): Promise<OverviewResponse> {
    return this.db.withRetry(async () => {
      const resolvedRange: AnalyticsRange = range ?? '30d';

      // Compute date windows based on range
      const now = new Date();
      const startDate = rangeToDate(resolvedRange);

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

      // Fetch raw counts and sparkline in parallel
      const [counts, sparklineRows] = await Promise.all([
        this.repo.getOverviewCounts(
          sevenDaysAgo,
          fourteenDaysAgo,
          currentStart,
          currentEnd,
          previousStart,
          previousEnd,
        ),
        this.repo.getOverviewSparkline(currentStart, currentEnd),
      ]);

      const sparklineMap = new Map<string, number>();
      for (const row of sparklineRows) {
        sparklineMap.set(row.date, row.value);
      }
      const sparkline = fillDateGaps(sparklineMap, currentStart, currentEnd);

      // TASK-001: Calculate planCompletionRate as a decimal percentage
      const completionRateCurrent = counts.planActivatedCurrent > 0
        ? (counts.planCompletedCurrent / counts.planActivatedCurrent) * 100
        : 0;
      const completionRatePrevious = counts.planActivatedPrevious > 0
        ? (counts.planCompletedPrevious / counts.planActivatedPrevious) * 100
        : 0;

      return {
        series: [] as [],
        totals: {
          weeklyPlansPlayed: {
            current: counts.weeklyPlansPlayedCurrent,
            previous: counts.weeklyPlansPlayedPrevious,
            deltaPercent:
              counts.weeklyPlansPlayedPrevious === 0
                ? null
                : ((counts.weeklyPlansPlayedCurrent - counts.weeklyPlansPlayedPrevious) /
                   counts.weeklyPlansPlayedPrevious) *
                  100,
            sparkline,
          },
          planCompletionRate: buildMetric(
            Math.round(completionRateCurrent * 10) / 10,
            Math.round(completionRatePrevious * 10) / 10,
          ),
          totalUsers: buildMetric(
            counts.totalUsers,
            counts.totalUsers, // total doesn't have a "previous" — same value
          ),
          newSignups: buildMetric(
            counts.newSignupsCurrent,
            counts.newSignupsPrevious,
          ),
          activePlans: buildMetric(
            counts.activePlansCurrent,
            counts.activePlansPrevious,
          ),
          totalPlans: buildMetric(
            counts.totalPlans,
            counts.totalPlans,
          ),
          ttsJobsCompleted: buildMetric(
            counts.ttsCompletedCurrent,
            counts.ttsCompletedPrevious,
          ),
          ttsJobsFailed: buildMetric(
            counts.ttsFailedCurrent,
            counts.ttsFailedPrevious,
          ),
          totalSessions: buildMetric(
            counts.sessionsCurrent,
            counts.sessionsPrevious,
          ),
          avgSessionDurationMs: buildMetric(
            counts.avgDurationCurrent,
            counts.avgDurationPrevious,
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
      const startDate = rangeToDate(range);
      const endDate = new Date();

      const rows = await this.repo.getSignupsTimeSeries(startDate);

      // Build a lookup map for fillDateGaps
      const dataMap = new Map<string, number>();
      for (const row of rows) {
        dataMap.set(row.date, row.value);
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
   */
  async getUserActivation(range: AnalyticsRange): Promise<ActivationResponse> {
    return this.db.withRetry(async () => {
      const startDate = rangeToDate(range);
      const endDate = new Date();

      const rows = await this.repo.getActivationTimeSeries(startDate, endDate);

      // Build rate map for fillDateGapsWithRate
      const dataMap = new Map<
        string,
        { value: number; rate: number; total: number }
      >();
      let totalSignups = 0;
      let totalActivated = 0;

      for (const row of rows) {
        const signups = row.signups;
        const activated = row.activated;
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
   * Plan lifecycle funnel: created -> tts_started -> tts_completed -> activated -> session_completed.
   *
   * Each stage counts plans (created within the range) that reached that lifecycle point.
   * Drop-off percentages are calculated relative to the previous stage.
   * Division by zero returns 0 (not NaN or Infinity).
   */
  async getPlanFunnel(range: AnalyticsRange): Promise<FunnelResponse> {
    return this.db.withRetry(async () => {
      const startDate = rangeToDate(range);

      const counts = await this.repo.getFunnelCounts(startDate);

      const stages: FunnelStage[] = buildFunnelStages(
        counts.created,
        counts.ttsStarted,
        counts.ttsCompleted,
        counts.activated,
        counts.sessionCompleted,
      );

      const overallConversionPercent =
        counts.created > 0
          ? Math.round((counts.sessionCompleted / counts.created) * 1000) / 10
          : 0;

      return {
        series: stages,
        totals: {
          totalCreated: counts.created,
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
      const startDate = rangeToDate(range);
      const endDate = new Date();

      const rows = await this.repo.getTtsVolumeTimeSeries(startDate);

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
        const voiceId = row.voiceId;
        const cnt = row.cnt;

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
      const startDate = rangeToDate(range);
      const endDate = new Date();

      // Fetch error data and daily totals in parallel
      const [errorData, dailyTotalRows] = await Promise.all([
        this.repo.getTtsErrorData(startDate),
        this.repo.getTtsDailyTotals(startDate),
      ]);

      // Build daily failed count map
      const failedMap = new Map<string, number>();
      let totalFailed = 0;
      for (const row of errorData.dailyFailed) {
        failedMap.set(row.day, row.failedCount);
        totalFailed += row.failedCount;
      }

      // Build daily total map for per-day error rate
      const dailyTotalMap = new Map<string, number>();
      for (const row of dailyTotalRows) {
        dailyTotalMap.set(row.day, row.totalCount);
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
      const topErrors: TtsErrorMessage[] = errorData.topErrors.map((row) => ({
        message: sanitizeErrorMessage(row.error ?? 'Unknown error'),
        count: row.cnt,
        lastSeen: row.lastSeen,
      }));

      const overallErrorRate =
        errorData.totalJobs > 0
          ? Math.round((totalFailed / errorData.totalJobs) * 10000) / 10000
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
      const startDate = rangeToDate(range);

      // Fetch distribution, dormant stats, and total users in parallel
      const [distributionRows, dormantStats, totalUsers] = await Promise.all([
        this.repo.getPlanDistribution(startDate),
        this.repo.getDormantStats(startDate),
        this.repo.getTotalUserCount(),
      ]);

      const totalPlans = dormantStats.totalPlans;
      const activePlans = dormantStats.activePlans;
      const recentlyUsed = dormantStats.recentlyUsed;
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
        const planCount = row.planCount;
        const userCount = row.userCount;
        usersWithPlans += userCount;
        totalPlanCount += planCount * userCount;

        if (planCount >= 5) {
          bucketCounts.set('5+', (bucketCounts.get('5+') ?? 0) + userCount);
        } else {
          const key = String(planCount);
          bucketCounts.set(key, (bucketCounts.get(key) ?? 0) + userCount);
        }
      }

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
      const ninetyDaysAgo = new Date(
        Date.now() - 90 * 24 * 60 * 60 * 1000,
      );

      const rows = await this.repo.getStreakDistribution(ninetyDaysAgo);

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
        const len = row.length;
        const cnt = row.userCount;

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

      const activeStreakUsers = await this.repo.getActiveStreakUsers(
        ninetyDaysAgo,
        yesterdayStr,
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
      const startDate = rangeToDate(range);

      const rows = await this.repo.getLibraryConversionRows(startDate);

      let publishedCount = 0;
      let totalAdoptionsInRange = 0;
      let totalSessionsAcrossAll = 0;
      let totalAdoptionsAll = 0;

      const series: LibraryPlanRow[] = rows.map((row) => {
        if (row.isPublished) publishedCount++;
        totalAdoptionsInRange += row.rangeAdoptions;
        totalAdoptionsAll += row.totalAdoptions;
        totalSessionsAcrossAll += row.sessionCount;

        const conversionRate =
          row.totalAdoptions > 0
            ? Math.round((row.sessionCount / row.totalAdoptions) * 10000) / 10000
            : null;

        return {
          id: row.id,
          name: row.name,
          category: row.category,
          isPublished: row.isPublished,
          totalAdoptions: row.totalAdoptions,
          rangeAdoptions: row.rangeAdoptions,
          activatedCount: row.activatedCount,
          sessionCount: row.sessionCount,
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
