/**
 * LibraryCategoryService — TASK-004
 *
 * Produces a category-level breakdown of library plans: published plan count,
 * adoptions, sessions, and conversion rate.
 *
 * Uses idx_plans_source_library partial index for efficient filtering of
 * plans sourced from the library.
 *
 * Categories returned include all known categories even if they have zero plans.
 */

import { Injectable, Logger } from '@nestjs/common';
import { sql } from 'drizzle-orm';
import { DatabaseService } from '../database/database.service';
import type { AnalyticsRange } from '../admin/dto/analytics.dto';
import { rangeToDate } from './dto/range-query.dto';
import type { LibraryCategoryResponse, CategoryRow } from './dto/library-category.dto';

/** All known library plan categories */
const ALL_CATEGORIES = [
  'yoga',
  'meditation',
  'workout',
  'cooking',
  'routine',
  'focus',
  'custom',
] as const;

@Injectable()
export class LibraryCategoryService {
  private readonly logger = new Logger(LibraryCategoryService.name);

  constructor(private readonly db: DatabaseService) {}

  /**
   * Get library plan category breakdown.
   *
   * For each category:
   *   - publishedPlans: COUNT library_plans WHERE published=true (not range-filtered)
   *   - totalAdoptions: COUNT DISTINCT plans.userId (in range)
   *   - totalSessions: COUNT session_completions (in range)
   *   - conversionRate: totalSessions / totalAdoptions (0 if totalAdoptions=0)
   *
   * @param range  Analytics range for filtering adoptions and sessions
   * @returns      Array of category breakdowns including zero-plan categories
   */
  async getLibraryCategories(range: AnalyticsRange): Promise<LibraryCategoryResponse> {
    return this.db.withRetry(async () => {
      const drizzle = this.db.getDb();
      const startDate = rangeToDate(range);
      const now = new Date();

      // Single query that joins library_plans → plans → session_completions
      // and groups by category
      const rows = await drizzle.execute(sql`
        SELECT
          lp.category,
          COUNT(DISTINCT lp.id) FILTER (WHERE lp.is_published = true)::int AS published_plans,
          COUNT(DISTINCT p.user_id) FILTER (
            WHERE p.created_at >= ${startDate}
              AND p.created_at <= ${now}
          )::int AS total_adoptions,
          COUNT(DISTINCT sc.id) FILTER (
            WHERE sc.completed_at >= ${startDate}
              AND sc.completed_at <= ${now}
          )::int AS total_sessions
        FROM library_plans lp
        LEFT JOIN plans p
          ON p.source_library_plan_id = lp.id
        LEFT JOIN session_completions sc
          ON sc.plan_id = p.id
        GROUP BY lp.category
        ORDER BY lp.category
      `);

      // Build a map from the query results
      const categoryMap = new Map<string, CategoryRow>();
      for (const row of rows.rows as Array<Record<string, unknown>>) {
        const category = String(row.category ?? '');
        const publishedPlans = Number(row.published_plans ?? 0);
        const totalAdoptions = Number(row.total_adoptions ?? 0);
        const totalSessions = Number(row.total_sessions ?? 0);
        const conversionRate = totalAdoptions > 0
          ? Math.round((totalSessions / totalAdoptions) * 10000) / 10000
          : 0;

        categoryMap.set(category, {
          category,
          publishedPlans,
          totalAdoptions,
          totalSessions,
          conversionRate,
        });
      }

      // Ensure all known categories are included (even with zero values)
      const categories: CategoryRow[] = ALL_CATEGORIES.map((cat) =>
        categoryMap.get(cat) ?? {
          category: cat,
          publishedPlans: 0,
          totalAdoptions: 0,
          totalSessions: 0,
          conversionRate: 0,
        },
      );

      // Also include any categories from the DB not in ALL_CATEGORIES
      for (const [cat, row] of categoryMap) {
        if (!ALL_CATEGORIES.includes(cat as typeof ALL_CATEGORIES[number])) {
          categories.push(row);
        }
      }

      return { categories };
    });
  }
}
