-- Migration: 0001_add_plans_library_tts
-- Adds library_plans, plans, and tts_jobs tables.
-- Drops sync_metadata (superseded by server-side plans architecture).
--
-- Apply with: npm run db:migrate (from server/ directory)
-- Requires DATABASE_URL_DIRECT — see scripts/migrate.sh for details.

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- Drop sync_metadata (no longer used — server-first architecture)
-- ---------------------------------------------------------------------------

DROP TABLE IF EXISTS "sync_metadata";

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- library_plans
-- Curated global plan library (admin-managed).
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "library_plans" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"description" text,
	"category" text NOT NULL,
	"tags" text NOT NULL DEFAULT '',
	"default_voice" text NOT NULL,
	"plan_json" text NOT NULL,
	"locale" text NOT NULL DEFAULT 'enUS',
	"is_published" boolean NOT NULL DEFAULT false,
	"sort_order" integer NOT NULL DEFAULT 0,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

--> statement-breakpoint

CREATE INDEX IF NOT EXISTS "idx_library_plans_category" ON "library_plans" ("category");

--> statement-breakpoint

CREATE INDEX IF NOT EXISTS "idx_library_plans_published" ON "library_plans" ("is_published");

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- plans
-- User-created plans stored server-side for cross-device recovery.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "plans" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"name" text NOT NULL,
	"plan_json" text NOT NULL,
	"source_library_plan_id" uuid,
	"is_active" boolean NOT NULL DEFAULT false,
	"tts_status" text NOT NULL DEFAULT 'none',
	"tts_total" integer NOT NULL DEFAULT 0,
	"tts_completed" integer NOT NULL DEFAULT 0,
	"voice_quality" text NOT NULL DEFAULT 'standard',
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

--> statement-breakpoint

CREATE INDEX IF NOT EXISTS "idx_plans_user_id" ON "plans" ("user_id");

--> statement-breakpoint

ALTER TABLE "plans"
	ADD CONSTRAINT "plans_user_id_users_id_fk"
	FOREIGN KEY ("user_id") REFERENCES "users"("id")
	ON DELETE no action ON UPDATE no action;

--> statement-breakpoint

ALTER TABLE "plans"
	ADD CONSTRAINT "plans_source_library_plan_id_library_plans_id_fk"
	FOREIGN KEY ("source_library_plan_id") REFERENCES "library_plans"("id")
	ON DELETE no action ON UPDATE no action;

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- tts_jobs
-- Per-plan TTS pre-generation job tracking. Cascade-deletes with parent plan.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "tts_jobs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"plan_id" uuid NOT NULL,
	"cache_key" varchar(64) NOT NULL,
	"text" text NOT NULL,
	"voice_id" text NOT NULL,
	"locale" text NOT NULL,
	"provider" text NOT NULL,
	"speech_rate" text NOT NULL DEFAULT '1.0',
	"s3_key" text,
	"status" text NOT NULL DEFAULT 'pending',
	"error" text,
	"attempts" integer NOT NULL DEFAULT 0,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"completed_at" timestamp with time zone
);

--> statement-breakpoint

CREATE INDEX IF NOT EXISTS "idx_tts_jobs_plan_id" ON "tts_jobs" ("plan_id");

--> statement-breakpoint

CREATE INDEX IF NOT EXISTS "idx_tts_jobs_plan_status" ON "tts_jobs" ("plan_id", "status");

--> statement-breakpoint

ALTER TABLE "tts_jobs"
	ADD CONSTRAINT "tts_jobs_plan_id_plans_id_fk"
	FOREIGN KEY ("plan_id") REFERENCES "plans"("id")
	ON DELETE cascade ON UPDATE no action;
