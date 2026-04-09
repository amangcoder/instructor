-- Migration: 0000_instructor_initial_schema
-- Generated from Drizzle ORM schema: src/database/schema.ts
-- Apply with: npx drizzle-kit migrate (using DIRECT connection string, not pooler)
--
-- Table creation order respects FK constraints:
--   1. users              (no FKs)
--   2. otp_records        (no FKs — OTPs are inserted before user rows exist)
--   3. refresh_tokens     (FK → users)
--   4. sync_metadata      (FK → users)

-- ---------------------------------------------------------------------------
-- users
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "users" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"email" varchar NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "users_email_unique" UNIQUE("email")
);

-- ---------------------------------------------------------------------------
-- otp_records
-- NOTE: No FK on email — OTPs are inserted BEFORE the user row exists.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "otp_records" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"email" varchar NOT NULL,
	"code_hash" varchar(64) NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"attempts" integer DEFAULT 0 NOT NULL,
	"used" boolean DEFAULT false NOT NULL
);

-- Composite index: equality on (email, used) then range on expires_at.
-- Optimal for: WHERE email = ? AND used = false AND expires_at > NOW()
CREATE INDEX IF NOT EXISTS "idx_otp_records_email_used_expires"
	ON "otp_records" ("email", "used", "expires_at");

-- ---------------------------------------------------------------------------
-- refresh_tokens
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "refresh_tokens" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"token_hash" varchar(64) NOT NULL,
	"user_id" uuid NOT NULL,
	"revoked" boolean DEFAULT false NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	CONSTRAINT "refresh_tokens_token_hash_unique" UNIQUE("token_hash")
);

-- Partial index: only active (non-revoked) tokens.
-- Much smaller than a full index since users have 1-2 active vs 50-100 lifetime tokens.
-- Used by: WHERE user_id = ? AND revoked = false
CREATE INDEX IF NOT EXISTS "idx_refresh_tokens_active"
	ON "refresh_tokens" ("user_id")
	WHERE "revoked" = false;

ALTER TABLE "refresh_tokens"
	ADD CONSTRAINT "refresh_tokens_user_id_users_id_fk"
	FOREIGN KEY ("user_id") REFERENCES "users"("id")
	ON DELETE no action ON UPDATE no action;

-- ---------------------------------------------------------------------------
-- sync_metadata
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "sync_metadata" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"last_sync_at" timestamp with time zone,
	"size_bytes" bigint,
	CONSTRAINT "sync_metadata_user_id_unique" UNIQUE("user_id")
);

ALTER TABLE "sync_metadata"
	ADD CONSTRAINT "sync_metadata_user_id_users_id_fk"
	FOREIGN KEY ("user_id") REFERENCES "users"("id")
	ON DELETE no action ON UPDATE no action;
