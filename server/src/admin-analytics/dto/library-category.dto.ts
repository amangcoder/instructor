/**
 * TASK-004: Library category breakdown DTOs
 *
 * Category-level analytics for library plans: adoption, sessions, conversion.
 */

export interface CategoryRow {
  category: string;
  /** Current published plans in this category (not range-filtered) */
  publishedPlans: number;
  /** Distinct users who adopted a library plan in this category within range */
  totalAdoptions: number;
  /** Session completions for plans in this category within range */
  totalSessions: number;
  /** Conversion: totalSessions / totalAdoptions (0 if totalAdoptions=0) */
  conversionRate: number;
}

/** Response for GET /api/admin/analytics/library/categories */
export interface LibraryCategoryResponse {
  categories: CategoryRow[];
}

/** @deprecated Use LibraryCategoryResponse */
export interface CategoryBreakdownResponse {
  rows: CategoryRow[];
}
