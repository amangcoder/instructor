-- Migration: 0018_user_library_links
-- Introduces user_library_links — a lightweight join table that tracks which
-- library plans a user has linked to their collection.
--
-- Design: link, not clone.
--   Previously, "adding" a library plan copied its planJson into a new plans
--   row (sourceLibraryPlanId tracked the origin). This caused data duplication
--   and required app-level dedup logic to prevent multiple copies.
--
--   With this table, the user holds a reference to library_plans.id. planJson
--   is always read from library_plans at query time — so admin updates to a
--   library plan reach all linked users automatically, and dedup is enforced
--   at the DB level via UNIQUE (user_id, library_plan_id).
--
-- Apply with:  npm run db:migrate   (from server/ directory)

--> statement-breakpoint

CREATE TABLE IF NOT EXISTS "user_library_links" (
  "id"              uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
  "user_id"         uuid NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  "library_plan_id" uuid NOT NULL REFERENCES "library_plans"("id") ON DELETE CASCADE,
  "last_used_at"    timestamp with time zone,
  "added_at"        timestamp with time zone DEFAULT now() NOT NULL
);

--> statement-breakpoint

-- Primary dedup constraint: one link per (user, library plan).
CREATE UNIQUE INDEX IF NOT EXISTS "user_library_links_user_library_unique"
  ON "user_library_links" ("user_id", "library_plan_id");

--> statement-breakpoint

-- Per-user list ordered by most recently added.
CREATE INDEX IF NOT EXISTS "idx_user_library_links_user_added"
  ON "user_library_links" ("user_id", "added_at");
