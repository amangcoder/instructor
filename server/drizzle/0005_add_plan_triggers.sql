-- Migration: 0005_add_plan_triggers
-- Adds the plan_triggers table for scheduled auto-start triggers synced
-- across a user's devices (Android AlarmManager and iOS local notifications
-- are armed client-side from this authoritative server view).
--
-- Apply with: npm run db:migrate (from server/ directory)
-- Requires DATABASE_URL_DIRECT — see scripts/migrate.sh for details.

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- plan_triggers
--
-- Scheduled "start this plan at this time" entries. Each row is authored on
-- one device and pulled by the user's other devices, which then arm their
-- native scheduler so the session fires regardless of which device is awake.
--
-- Idempotency:
--   client_id is a UUID generated on-device. Sync uses (user_id, client_id)
--   upsert with last-write-wins on updated_at so re-uploads are safe and
--   concurrent edits from two devices converge.
--
-- Tombstones:
--   Cancellation is represented by a non-null deleted_at. The row is kept
--   server-side so GET /api/sync/triggers?since=… can tell other devices
--   to cancel the corresponding native alarm.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "plan_triggers" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"plan_id" uuid NOT NULL,
	"client_id" uuid NOT NULL,
	"title" text NOT NULL,
	"start_utc" timestamp with time zone NOT NULL,
	"duration_minutes" integer NOT NULL,
	"recurrence" text DEFAULT 'none' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "plan_triggers_client_id_unique" UNIQUE("client_id")
);

--> statement-breakpoint

-- Sync pull: WHERE user_id = ? AND updated_at > ?
CREATE INDEX IF NOT EXISTS "idx_plan_triggers_user_updated"
	ON "plan_triggers" ("user_id", "updated_at");

--> statement-breakpoint

-- Upcoming triggers: WHERE user_id = ? AND deleted_at IS NULL
--                      AND start_utc > NOW()
CREATE INDEX IF NOT EXISTS "idx_plan_triggers_user_start"
	ON "plan_triggers" ("user_id", "start_utc");

--> statement-breakpoint

-- Foreign key: user_id references users(id). Cascade delete so a deleted
-- account removes all its scheduled triggers atomically.
ALTER TABLE "plan_triggers"
	ADD CONSTRAINT "plan_triggers_user_id_users_id_fk"
	FOREIGN KEY ("user_id") REFERENCES "users"("id")
	ON DELETE cascade ON UPDATE no action;
