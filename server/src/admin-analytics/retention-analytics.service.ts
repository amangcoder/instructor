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

import { Injectable, Logger, GatewayTimeoutException } from '@nestjs/common';
import { sql, count } from 'drizzle-orm';
import { DatabaseService } from '../database/database.service';
import type { RetentionResponse, ActiveUsersResponse } from './dto/retention.dto';
import type { AnalyticsRange } from '../admin/dto/analytics.dto';
import { rangeToDate } from './dto/range-query.dto';
import { fillDateGaps } from './admin-analytics.service';

@Injectable()
export class RetentionAnalyticsService {
  private readonly logger = new Logger(RetentionAnalyticsService.name);

  constructor(private readonly db: DatabaseService) {}

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
      const drizzle = this.db.getDb();
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
        const [
          d7CohortResult,
          d7RetainedResult,
          d7PrevCohortResult,
          d7PrevRetainedResult,
          d30CohortResult,
          d30RetainedResult,
          d30PrevCohortResult,
          d30PrevRetainedResult,
        ] = await Promise.all([
          // D7 current cohort size
          drizzle.execute(sql`
            SELECT COUNT(DISTINCT u.id)::int AS cohort_size
            FROM users u
            WHERE u.created_at >= ${d7CohortStart}
              AND u.created_at < ${d7CohortEnd}
          `),

          // D7 current retained count (single-query JOIN)
          drizzle.execute(sql`
            SELECT COUNT(DISTINCT sc.user_id)::int AS retained_count
            FROM session_completions sc
            INNER JOIN users u ON u.id = sc.user_id
            WHERE u.created_at >= ${d7CohortStart}
              AND u.created_at < ${d7CohortEnd}
              AND sc.completed_at >= ${d7RetentionStart}
          `),

          // D7 previous cohort size
          drizzle.execute(sql`
            SELECT COUNT(DISTINCT u.id)::int AS cohort_size
            FROM users u
            WHERE u.created_at >= ${d7PrevCohortStart}
              AND u.created_at < ${d7PrevCohortEnd}
          `),

          // D7 previous retained count
          drizzle.execute(sql`
            SELECT COUNT(DISTINCT sc.user_id)::int AS retained_count
            FROM session_completions sc
            INNER JOIN users u ON u.id = sc.user_id
            WHERE u.created_at >= ${d7PrevCohortStart}
              AND u.created_at < ${d7PrevCohortEnd}
              AND sc.completed_at >= ${d7PrevRetentionStart}
              AND sc.completed_at < ${d7PrevRetentionEnd}
          `),

          // D30 current cohort size
          drizzle.execute(sql`
            SELECT COUNT(DISTINCT u.id)::int AS cohort_size
            FROM users u
            WHERE u.created_at >= ${d30CohortStart}
              AND u.created_at < ${d30CohortEnd}
          `),

          // D30 current retained count
          drizzle.execute(sql`
            SELECT COUNT(DISTINCT sc.user_id)::int AS retained_count
            FROM session_completions sc
            INNER JOIN users u ON u.id = sc.user_id
            WHERE u.created_at >= ${d30CohortStart}
              AND u.created_at < ${d30CohortEnd}
              AND sc.completed_at >= ${d30RetentionStart}
          `),

          // D30 previous cohort size
          drizzle.execute(sql`
            SELECT COUNT(DISTINCT u.id)::int AS cohort_size
            FROM users u
            WHERE u.created_at >= ${d30PrevCohortStart}
              AND u.created_at < ${d30PrevCohortEnd}
          `),

          // D30 previous retained count
          drizzle.execute(sql`
            SELECT COUNT(DISTINCT sc.user_id)::int AS retained_count
            FROM session_completions sc
            INNER JOIN users u ON u.id = sc.user_id
            WHERE u.created_at >= ${d30PrevCohortStart}
              AND u.created_at < ${d30PrevCohortEnd}
              AND sc.completed_at >= ${d30PrevRetentionStart}
              AND sc.completed_at < ${d30PrevRetentionEnd}
          `),
        ]);

        // Extract values safely (Neon HTTP driver returns rows as array)
        const extractInt = (result: unknown, key: string): number => {
          const rows = result as Array<Record<string, unknown>>;
          const val = rows[0]?.[key];
          return val ? Number(val) : 0;
        };

        const d7CohortSize = extractInt(d7CohortResult.rows, 'cohort_size');
        const d7RetainedCount = extractInt(d7RetainedResult.rows, 'retained_count');
        const d7PrevCohortSize = extractInt(d7PrevCohortResult.rows, 'cohort_size');
        const d7PrevRetainedCount = extractInt(d7PrevRetainedResult.rows, 'retained_count');

        const d30CohortSize = extractInt(d30CohortResult.rows, 'cohort_size');
        const d30RetainedCount = extractInt(d30RetainedResult.rows, 'retained_count');
        const d30PrevCohortSize = extractInt(d30PrevCohortResult.rows, 'cohort_size');
        const d30PrevRetainedCount = extractInt(d30PrevRetainedResult.rows, 'retained_count');

        const d7Rate = d7CohortSize > 0 ? d7RetainedCount / d7CohortSize : 0;
        const d7PrevRate = d7PrevCohortSize > 0 ? d7PrevRetainedCount / d7PrevCohortSize : 0;

        const d30Rate = d30CohortSize > 0 ? d30RetainedCount / d30CohortSize : 0;
        const d30PrevRate = d30PrevCohortSize > 0 ? d30PrevRetainedCount / d30PrevCohortSize : 0;

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
      const drizzle = this.db.getDb();
      const startDate = rangeToDate(range);
      const now = new Date();

      try {
        const [dauRows, wauRows, mauRows] = await Promise.all([
          // DAU: distinct users per day
          drizzle.execute(sql`
            SELECT
              DATE_TRUNC('day', completed_at)::date::text AS date,
              COUNT(DISTINCT user_id)::int AS value
            FROM session_completions
            WHERE completed_at >= ${startDate}
              AND completed_at <= ${now}
            GROUP BY DATE_TRUNC('day', completed_at)
            ORDER BY DATE_TRUNC('day', completed_at)
          `),

          // WAU: distinct users per ISO week
          drizzle.execute(sql`
            SELECT
              DATE_TRUNC('week', completed_at)::date::text AS date,
              COUNT(DISTINCT user_id)::int AS value
            FROM session_completions
            WHERE completed_at >= ${startDate}
              AND completed_at <= ${now}
            GROUP BY DATE_TRUNC('week', completed_at)
            ORDER BY DATE_TRUNC('week', completed_at)
          `),

          // MAU: distinct users per month
          drizzle.execute(sql`
            SELECT
              DATE_TRUNC('month', completed_at)::date::text AS date,
              COUNT(DISTINCT user_id)::int AS value
            FROM session_completions
            WHERE completed_at >= ${startDate}
              AND completed_at <= ${now}
            GROUP BY DATE_TRUNC('month', completed_at)
            ORDER BY DATE_TRUNC('month', completed_at)
          `),
        ]);

        const toPoints = (result: unknown): Array<{ date: string; value: number }> => {
          const rows = result as Array<Record<string, unknown>>;
          return rows.map((r) => ({
            date: String(r.date ?? ''),
            value: Number(r.value ?? 0),
          }));
        };

        // Fill DAU gaps so the frontend gets a contiguous series
        const dauMap = new Map<string, number>();
        for (const row of (dauRows.rows as Array<Record<string, unknown>>)) {
          dauMap.set(String(row.date ?? ''), Number(row.value ?? 0));
        }
        const dau = fillDateGaps(dauMap, startDate, now);

        return {
          dau,
          wau: toPoints(wauRows.rows),
          mau: toPoints(mauRows.rows),
        };
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
