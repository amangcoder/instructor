/**
 * Library Categories API — Response types for library plan category breakdown.
 *
 * These mirror the server-side DTOs in server/src/admin-analytics/admin-analytics.service.ts.
 * They are duplicated here so the Next.js web app does not depend on the
 * NestJS server package at build time.
 */

// ---------------------------------------------------------------------------
// Library Category Breakdown  — GET /api/admin/analytics/library/categories?range=7d|30d|90d
// ---------------------------------------------------------------------------

/** Category-level breakdown of library plan performance metrics */
export interface CategoryRow {
  /** Category name (e.g., "fitness", "meditation", "mindfulness") */
  category: string;
  /** Number of published library plans in this category */
  publishedPlans: number;
  /** Total adoptions of plans from this category (all time) */
  totalAdoptions: number;
  /** Adoptions within the selected date range */
  rangeAdoptions: number;
  /** Session completions on plans from this category (range) */
  totalSessions: number;
  /** Conversion rate: totalSessions / totalAdoptions (decimal 0..1). null if totalAdoptions is 0 */
  conversionRate: number | null;
}

/** Category-level breakdown response for library analytics */
export interface CategoryBreakdownResponse {
  /** Array of category rows sorted by category name */
  rows: CategoryRow[];
}
