-- Migration: 0003_add_deletion_requests
-- Creates the deletion_requests table for the public data-deletion form.
--
-- Design notes:
--   - No foreign key to users — we intentionally never query the users table
--     when processing deletion requests (email enumeration prevention).
--   - requested_at is supplied by the client; created_at is the server receive time.
--
-- Apply with: npm run db:migrate (from server/ directory)

--> statement-breakpoint

CREATE TABLE IF NOT EXISTS "deletion_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"email" varchar NOT NULL,
	"scope" varchar(50) NOT NULL,
	"reason" text,
	"requested_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
