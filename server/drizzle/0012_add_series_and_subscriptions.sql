-- Migration: 0012_add_series_and_subscriptions
-- Adds support for multi-session "series" (e.g. "10 Days to Meditate",
-- "Couch to 5K") and per-user subscription / progress tracking.
--
-- Three changes:
--   1. CREATE TABLE series                — wrapper rows for grouped plans
--   2. ALTER TABLE plans ADD series_id    — nullable FK; existing standalone
--                                            plans are unaffected (NULL)
--   3. CREATE TABLE series_subscriptions  — user opt-in + progress tracking
--
-- Apply with: npm run db:migrate (from server/ directory)
-- Requires DATABASE_URL_DIRECT — see scripts/migrate.sh for details.

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- series
-- Curated multi-session program (e.g. a 30-day strength series). Individual
-- sessions live in plans / library_plans and reference this row.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "series" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"description" text,
	"category" text NOT NULL,
	"tags" text NOT NULL DEFAULT '',
	"default_voice" text NOT NULL,
	"locale" text NOT NULL DEFAULT 'enIn',
	"is_published" boolean NOT NULL DEFAULT false,
	"sort_order" integer NOT NULL DEFAULT 0,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

--> statement-breakpoint

CREATE INDEX IF NOT EXISTS "idx_series_category" ON "series" ("category");

--> statement-breakpoint

CREATE INDEX IF NOT EXISTS "idx_series_published" ON "series" ("is_published");

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- plans.series_id
-- Nullable FK linking a session plan to its parent series. NULL = standalone
-- plan (the existing default; no backfill required).
-- ---------------------------------------------------------------------------

ALTER TABLE "plans"
	ADD COLUMN IF NOT EXISTS "series_id" uuid;

--> statement-breakpoint

ALTER TABLE "plans"
	ADD CONSTRAINT "plans_series_id_series_id_fk"
	FOREIGN KEY ("series_id") REFERENCES "series"("id")
	ON DELETE no action ON UPDATE no action;

--> statement-breakpoint

-- Partial index — most plans are standalone, so we only index the rows that
-- actually have a series_id. Powers "list all sessions in series X".
CREATE INDEX IF NOT EXISTS "idx_plans_series"
	ON "plans" ("series_id")
	WHERE "series_id" IS NOT NULL;

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- series_subscriptions
-- Per-user opt-in to a series, with progress tracking. One row per
-- (user_id, series_id) — re-subscribing flips status back to 'active'
-- on the existing row rather than inserting a duplicate.
--
-- current_session_index and completed_sessions are denormalized read-path
-- caches; the authoritative completion history is session_completions
-- joined through plans.series_id.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "series_subscriptions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"series_id" uuid NOT NULL,
	"status" text NOT NULL DEFAULT 'active',
	"current_session_index" integer NOT NULL DEFAULT 0,
	"completed_sessions" integer NOT NULL DEFAULT 0,
	"subscribed_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_session_completed_at" timestamp with time zone,
	"unsubscribed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "series_subscriptions_status_check"
		CHECK ("status" IN ('active', 'paused', 'completed', 'cancelled'))
);

--> statement-breakpoint

-- Unique (user_id, series_id) — prevents duplicate subscriptions and gives
-- us a fast lookup for "is this user subscribed to this series?".
CREATE UNIQUE INDEX IF NOT EXISTS "idx_series_subscriptions_user_series"
	ON "series_subscriptions" ("user_id", "series_id");

--> statement-breakpoint

-- "My active series" list — partial index keeps it small as cancelled rows
-- accumulate over time.
CREATE INDEX IF NOT EXISTS "idx_series_subscriptions_user_active"
	ON "series_subscriptions" ("user_id")
	WHERE "status" = 'active';

--> statement-breakpoint

-- Series-level analytics: total subscribers, completion-rate funnels.
CREATE INDEX IF NOT EXISTS "idx_series_subscriptions_series"
	ON "series_subscriptions" ("series_id");

--> statement-breakpoint

-- Sync pulls: WHERE user_id = ? AND updated_at > ?
CREATE INDEX IF NOT EXISTS "idx_series_subscriptions_user_updated"
	ON "series_subscriptions" ("user_id", "updated_at");

--> statement-breakpoint

ALTER TABLE "series_subscriptions"
	ADD CONSTRAINT "series_subscriptions_user_id_users_id_fk"
	FOREIGN KEY ("user_id") REFERENCES "users"("id")
	ON DELETE cascade ON UPDATE no action;

--> statement-breakpoint

ALTER TABLE "series_subscriptions"
	ADD CONSTRAINT "series_subscriptions_series_id_series_id_fk"
	FOREIGN KEY ("series_id") REFERENCES "series"("id")
	ON DELETE cascade ON UPDATE no action;
