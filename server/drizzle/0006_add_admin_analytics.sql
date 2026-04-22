-- Migration: 0006_add_admin_analytics
-- Adds the admin role column and analytics-supporting indexes across users,
-- plans, tts_jobs, and session_completions. All statements are idempotent so
-- this migration is safe to re-run on environments where a subset has already
-- been applied manually.
--
-- Apply with: npm run db:migrate (from server/ directory)
-- Requires DATABASE_URL_DIRECT — see scripts/migrate.sh for details.

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- users: role column + CHECK + signup-trends index
-- ---------------------------------------------------------------------------

ALTER TABLE "users"
  ADD COLUMN IF NOT EXISTS "role" text NOT NULL DEFAULT 'user';
--> statement-breakpoint

ALTER TABLE "users"
  DROP CONSTRAINT IF EXISTS "users_role_check";
--> statement-breakpoint

ALTER TABLE "users"
  ADD CONSTRAINT "users_role_check" CHECK ("role" IN ('user', 'admin'));
--> statement-breakpoint

CREATE INDEX IF NOT EXISTS "idx_users_created_at"
  ON "users" ("created_at");
--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- plans: composite (user_id, created_at) supersedes the old per-user index.
-- Add per-day and per-source-library analytics indexes.
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS "idx_plans_user_created"
  ON "plans" ("user_id", "created_at");
--> statement-breakpoint

DROP INDEX IF EXISTS "idx_plans_user_id";
--> statement-breakpoint

CREATE INDEX IF NOT EXISTS "idx_plans_created_at"
  ON "plans" ("created_at");
--> statement-breakpoint

CREATE INDEX IF NOT EXISTS "idx_plans_source_library"
  ON "plans" ("source_library_plan_id", "created_at")
  WHERE "source_library_plan_id" IS NOT NULL;
--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- tts_jobs: analytics indexes for volume-by-provider/voice and failures
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS "idx_tts_jobs_created_provider_voice"
  ON "tts_jobs" ("created_at", "provider", "voice_id");
--> statement-breakpoint

CREATE INDEX IF NOT EXISTS "idx_tts_jobs_failed"
  ON "tts_jobs" ("created_at")
  WHERE "status" = 'failed';
--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- session_completions: PARTITION BY user_id window-function index
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS "idx_session_completions_user_completed"
  ON "session_completions" ("user_id", "completed_at");
