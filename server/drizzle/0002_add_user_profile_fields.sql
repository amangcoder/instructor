-- Migration: 0002_add_user_profile_fields
-- Adds optional profile fields (name, username, photo_url) to users table.
--
-- Apply with: npm run db:migrate (from server/ directory)
-- Requires DATABASE_URL_DIRECT — see scripts/migrate.sh for details.

--> statement-breakpoint

ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "name" varchar(100);

--> statement-breakpoint

ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "username" varchar(30);

--> statement-breakpoint

ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "photo_url" text;

--> statement-breakpoint

-- Partial unique index: NULL usernames are not considered duplicates.
CREATE UNIQUE INDEX IF NOT EXISTS "users_username_unique"
  ON "users" ("username")
  WHERE "username" IS NOT NULL;
