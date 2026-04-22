-- Migration: 0007_alter_deletion_requests
-- Adds status, processed_at, and ip_address columns to deletion_requests table.
-- These columns are required for the admin deletion-request management feature.
-- All statements are idempotent (IF NOT EXISTS guards).

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- deletion_requests: Add status, processed_at, ip_address columns
-- ---------------------------------------------------------------------------

ALTER TABLE "deletion_requests"
  ADD COLUMN IF NOT EXISTS "status" VARCHAR(20) NOT NULL DEFAULT 'pending';
--> statement-breakpoint

ALTER TABLE "deletion_requests"
  ADD COLUMN IF NOT EXISTS "processed_at" TIMESTAMP WITH TIME ZONE;
--> statement-breakpoint

ALTER TABLE "deletion_requests"
  ADD COLUMN IF NOT EXISTS "ip_address" VARCHAR;
--> statement-breakpoint

-- Partial index for efficient pending-request queries (sidebar badge count)
CREATE INDEX IF NOT EXISTS "idx_deletion_requests_status"
  ON "deletion_requests" ("status")
  WHERE "status" = 'pending';
--> statement-breakpoint

-- Index for activity feed queries (TASK-008: ORDER BY requested_at DESC)
CREATE INDEX IF NOT EXISTS "idx_deletion_requests_created_at"
  ON "deletion_requests" ("created_at");
--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- session_completions: Add index for DAU/WAU/MAU range scans (TASK-002)
-- The existing idx_session_completions_user_completed index leads with user_id,
-- so it cannot efficiently serve completedAt-only range queries.
-- This index supports time-series aggregations that filter by date range only.
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS "idx_session_completions_completed_at"
  ON "session_completions" ("completed_at");
--> statement-breakpoint
