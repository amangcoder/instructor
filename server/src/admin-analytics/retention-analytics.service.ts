/**
 * RetentionAnalyticsService — TASK-002
 *
 * Computes D7 and D30 cohort retention rates and DAU/WAU/MAU active-user
 * time series using the session_completions table.
 *
 * CRITICAL: Does NOT use SET LOCAL statement_timeout — Neon HTTP driver
 * treats each query as a separate HTTP request; SET LOCAL is a no-op.
 * Instead, catches PostgreSQL error code '57014' (query_canceled) and
 * throws HTTP 504 GatewayTimeoutException.
 *
 * Uses idx_session_completions_completed_at (added in TASK-000 migration)
 * for efficient completedAt-only range queries.
 */

import { Injectable, Logger, GatewayTimeoutException, Inject } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { AdminAnalyticsRepository } from '../database/repositories/analytics.repository';
import type { RetentionResponse, ActiveUsersResponse } from './dto/retention.dto';
import type { AnalyticsRange } from '../admin/dto/analytics.dto';
import { rangeToDate } from './dto/range-query.dto';
import { fillDateGaps, computeRetentionRate } from '../common/analytics-utils';

@Injectable()
export class RetentionAnalyticsService {
  private readonly logger = new Logger(RetentionAnalyticsService.name);
  constructor(
    private readonly db: DatabaseService,
    @Inject(AdminAnalyticsRepository) private readonly repo: AdminAnalyticsRepository,
  ) {}

  // =========================================================================
  // getRetention() — D7 and D30 cohort retention
  // =========================================================================

  /**
   * Compute D7 and D30 cohort retention rates.
   *
   * D7: users who signed up in the window (now-8d → now-7d) AND completed
   *     a session in the next 7 days (completedAt >= now-7d).
   *     Delta: previous cohort (now-15d → now-14d), sessions (now-14d → now-7d).
   *
   * D30: users who signed up in (now-31d → now-30d) AND completed a session
   *      in the next 30 days (completedAt >= now-30d).
   *      Delta: previous cohort (now-61d → now-60d), sessions (now-60d → now-30d).
   *
   * Uses INNER JOIN pattern (NOT IN-list) for efficient single-query execution.
   *
   * @returns RetentionResponse with d7 and d30 metrics
   * @throws GatewayTimeoutException (HTTP 504) if PostgreSQL cancels the query
   */
  async getRetention(): Promise<RetentionResponse> {
    return this.db.withRetry(async () => {
      const now = new Date();

      // D7 windows
      const d7CohortStart = new Date(now.getTime() - 8 * 24 * 60 * 60 * 1000);
      const d7CohortEnd = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      const d7RetentionStart = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

      // D7 previous cohort windows (for delta)
      const d7PrevCohortStart = new Date(now.getTime() - 15 * 24 * 60 * 60 * 1000);
      const d7PrevCohortEnd = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);
      const d7PrevRetentionStart = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);
      const d7PrevRetentionEnd = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

      // D30 windows
      const d30CohortStart = new Date(now.getTime() - 31 * 24 * 60 * 60 * 1000);
      const d30CohortEnd = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      const d30RetentionStart = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

      // D30 previous cohort windows
      const d30PrevCohortStart = new Date(now.getTime() - 61 * 24 * 60 * 60 * 1000);
      const d30PrevCohortEnd = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000);
      const d30PrevRetentionStart = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000);
      const d30PrevRetentionEnd = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

      try {
        let d7CohortSize: number, d7RetainedCount: number, d7PrevCohortSize: number, d7PrevRetainedCount: number;
        let d30CohortSize: number, d30RetainedCount: number, d30PrevCohortSize: number, d30PrevRetainedCount: number;

        [d7CohortSize, d7RetainedCount, d7PrevCohortSize, d7PrevRetainedCount,
           d30CohortSize, d30RetainedCount, d30PrevCohortSize, d30PrevRetainedCount] = await Promise.all([
            this.repo.getCohortSize(d7CohortStart, d7CohortEnd),
            this.repo.getRetainedCount(d7CohortStart, d7CohortEnd, d7RetentionStart),
            this.repo.getCohortSize(d7PrevCohortStart, d7PrevCohortEnd),
            this.repo.getRetainedCount(d7PrevCohortStart, d7PrevCohortEnd, d7PrevRetentionStart, d7PrevRetentionEnd),
            this.repo.getCohortSize(d30CohortStart, d30CohortEnd),
            this.repo.getRetainedCount(d30CohortStart, d30CohortEnd, d30RetentionStart),
            this.repo.getCohortSize(d30PrevCohortStart, d30PrevCohortEnd),
            this.repo.getRetainedCount(d30PrevCohortStart, d30PrevCohortEnd, d30PrevRetentionStart, d30PrevRetentionEnd),
          ]);

        const d7Rate = computeRetentionRate(d7RetainedCount, d7CohortSize);
        const d7PrevRate = computeRetentionRate(d7PrevRetainedCount, d7PrevCohortSize);

        const d30Rate = computeRetentionRate(d30RetainedCount, d30CohortSize);
        const d30PrevRate = computeRetentionRate(d30PrevRetainedCount, d30PrevCohortSize);

        return {
          d7: {
            rate: Math.round(d7Rate * 10000) / 10000, // 4 decimal places
            cohortSize: d7CohortSize,
            retainedCount: d7RetainedCount,
            delta: Math.round((d7Rate - d7PrevRate) * 1000) / 10, // percentage points, 1 decimal
          },
          d30: {
            rate: Math.round(d30Rate * 10000) / 10000,
            cohortSize: d30CohortSize,
            retainedCount: d30RetainedCount,
            delta: Math.round((d30Rate - d30PrevRate) * 1000) / 10,
          },
        };
      } catch (err) {
        // Catch PostgreSQL query_canceled (57014) and return 504
        const pgCode = (err as { code?: string }).code;
        if (pgCode === '57014') {
          this.logger.warn('Retention query canceled (statement_timeout exceeded)');
          throw new GatewayTimeoutException({ error: 'query_timeout' });
        }
        throw err;
      }
    });
  }

  // =========================================================================
  // getActiveUsers(range) — DAU/WAU/MAU time series
  // =========================================================================

  /**
   * Compute DAU, WAU, MAU active user time series.
   *
   * Uses idx_session_completions_completed_at (TASK-000) for efficient
   * completedAt-only range scans.
   *
   * @param range  Analytics range ('7d' | '30d' | '90d')
   * @returns      { dau, wau, mau } — each is an array of { date, value }
   */
  async getActiveUsers(range: AnalyticsRange): Promise<ActiveUsersResponse> {
    return this.db.withRetry(async () => {
      const startDate = rangeToDate(range);
      const now = new Date();

      try {
        let dauPoints: Array<{ date: string; value: number }>;
        let wauPoints: Array<{ date: string; value: number }>;
        let mauPoints: Array<{ date: string; value: number }>;

        [dauPoints, wauPoints, mauPoints] = await Promise.all([
            this.repo.getDauTimeSeries(startDate, now),
            this.repo.getWauTimeSeries(startDate, now),
            this.repo.getMauTimeSeries(startDate, now),
          ]);

        // Fill DAU gaps so the frontend gets a contiguous series
        const dauMap = new Map<string, number>();
        for (const row of dauPoints) {
          dauMap.set(row.date, row.value);
        }
        const dau = fillDateGaps(dauMap, startDate, now);

        return { dau, wau: wauPoints, mau: mauPoints };
      } catch (err) {
        const pgCode = (err as { code?: string }).code;
        if (pgCode === '57014') {
          this.logger.warn('Active users query canceled (statement_timeout exceeded)');
          throw new GatewayTimeoutException({ error: 'query_timeout' });
        }
        throw err;
      }
    });
  }
}
