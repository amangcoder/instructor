-- Migration: 0013_add_plan_requests
-- Adds the plan_requests table — user-submitted requests for plans or
-- schedules that aren't yet in the Discover library. Surfaced on the admin
-- dashboard and notified via email.
--
-- Apply with: npm run db:migrate (from server/ directory)

--> statement-breakpoint

CREATE TABLE IF NOT EXISTS "plan_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid,
	"email" varchar NOT NULL,
	"title" varchar(200) NOT NULL,
	"description" text NOT NULL,
	"category" varchar(50),
	"status" varchar(20) NOT NULL DEFAULT 'pending',
	"processed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "plan_requests_status_check"
		CHECK ("status" IN ('pending', 'processed', 'rejected'))
);

--> statement-breakpoint

ALTER TABLE "plan_requests"
	ADD CONSTRAINT "plan_requests_user_id_users_id_fk"
	FOREIGN KEY ("user_id") REFERENCES "users"("id")
	ON DELETE set null ON UPDATE no action;

--> statement-breakpoint

CREATE INDEX IF NOT EXISTS "idx_plan_requests_status_pending"
	ON "plan_requests" ("status")
	WHERE "status" = 'pending';

--> statement-breakpoint

CREATE INDEX IF NOT EXISTS "idx_plan_requests_created_at"
	ON "plan_requests" ("created_at");
