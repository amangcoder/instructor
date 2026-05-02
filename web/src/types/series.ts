/**
 * Admin Series API — Response types for the series admin page.
 *
 * These mirror the server-side types in server/src/database/database.service.ts
 * and server/src/series/series.service.ts. They are duplicated here so the
 * Next.js web app does not depend on the NestJS server package at build time.
 */

// ---------------------------------------------------------------------------
// Series record — GET /api/admin/series (admin/all)
// ---------------------------------------------------------------------------

/** Full series record as returned by the admin list endpoint. */
export interface AdminSeriesRecord {
  id: string;
  name: string;
  description: string | null;
  /** Legacy free-text category (e.g. "meditation"). */
  category: string;
  /** FK to categories.id — nullable during rollout. */
  categoryId: string | null;
  tags: string;
  defaultVoice: string;
  locale: string;
  isPublished: boolean;
  sortOrder: number;
  /** Number of plans (sessions) in this series. */
  totalSessions: number;
  createdAt: string;
  updatedAt: string;
}

// ---------------------------------------------------------------------------
// Plan record within a series — GET /api/admin/series/:id
// ---------------------------------------------------------------------------

/** Plan record as returned inside a series detail response (subset of server PlanRecord). */
export interface AdminSeriesPlanRecord {
  planId: string;
  name: string;
  isActive: boolean;
  ttsStatus: string;
  ttsTotal: number;
  ttsCompleted: number;
  voiceQuality: string;
  seriesId: string | null;
  createdAt: string;
  updatedAt: string;
}

// ---------------------------------------------------------------------------
// Series with sessions — GET /api/admin/series/:id
// ---------------------------------------------------------------------------

/** Series detail including its ordered session (plan) list, as emitted by GET /series/:id. */
export interface AdminSeriesDetail extends AdminSeriesRecord {
  /** Sessions ordered by their position within the series. */
  sessions: AdminSeriesPlanRecord[];
}

// ---------------------------------------------------------------------------
// Grouped series for the admin UI
// ---------------------------------------------------------------------------

/** Series rows keyed by category label for the grouped UI display. */
export type SeriesByCategory = Record<string, AdminSeriesRecord[]>;
