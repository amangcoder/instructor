-- Migration: 0004_add_streaks_sharing
-- Adds streak tracking and plan sharing support to PostgreSQL schema.
--
-- Changes:
--   1. Add share_token and share_token_created_at columns to plans table for plan sharing
--   2. Create session_completions table for tracking session completion events
--   3. Create streak_freezes table for managing streak freeze mechanic
--
-- Apply with: npm run db:migrate (from server/ directory)
-- Requires DATABASE_URL_DIRECT — see scripts/migrate.sh for details.

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- ALTER plans table — add sharing support
-- ---------------------------------------------------------------------------

ALTER TABLE "plans" ADD COLUMN IF NOT EXISTS "share_token" varchar(20);

--> statement-breakpoint

ALTER TABLE "plans" ADD COLUMN IF NOT EXISTS "share_token_created_at" timestamp with time zone;

--> statement-breakpoint

-- Unique index on share_token for fast public endpoint lookups: GET /api/plans/shared/:shareToken
CREATE UNIQUE INDEX IF NOT EXISTS "idx_plans_share_token" ON "plans" ("share_token");

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- session_completions
--
-- Stores session completion records synced from client.
-- Used for cross-device streak consistency and completion history.
-- client_id is a UUID generated on the client to ensure idempotency —
-- the server uses ON CONFLICT (client_id) DO NOTHING to prevent duplicates.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "session_completions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"plan_id" uuid NOT NULL,
	"completed_at" timestamp with time zone NOT NULL,
	"duration_ms" integer NOT NULL,
	"client_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "session_completions_client_id_unique" UNIQUE("client_id")
);

--> statement-breakpoint

-- Query by userId for cross-device streak queries: get all completions for a user
CREATE INDEX IF NOT EXISTS "idx_session_completions_user_created" ON "session_completions" ("user_id", "created_at");

--> statement-breakpoint

-- Query by planId for plan-specific completion history
CREATE INDEX IF NOT EXISTS "idx_session_completions_plan_completed" ON "session_completions" ("plan_id", "completed_at");

--> statement-breakpoint

-- Foreign key: user_id references users(id)
ALTER TABLE "session_completions"
	ADD CONSTRAINT "session_completions_user_id_users_id_fk"
	FOREIGN KEY ("user_id") REFERENCES "users"("id")
	ON DELETE cascade ON UPDATE no action;

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- streak_freezes
--
-- Streak freeze records — users have a max of 2 active freezes.
-- Replenished at 1 per 7 consecutive active days.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "streak_freezes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"frozen_at" timestamp with time zone NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"consumed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);

--> statement-breakpoint

-- Query active freezes by userId for freeze availability checks
CREATE INDEX IF NOT EXISTS "idx_streak_freezes_user_id" ON "streak_freezes" ("user_id");

--> statement-breakpoint

-- Foreign key: user_id references users(id)
ALTER TABLE "streak_freezes"
	ADD CONSTRAINT "streak_freezes_user_id_users_id_fk"
	FOREIGN KEY ("user_id") REFERENCES "users"("id")
	ON DELETE cascade ON UPDATE no action;
