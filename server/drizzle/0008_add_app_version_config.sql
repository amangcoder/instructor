-- Migration: 0008_add_app_version_config
-- Creates the app_version_config table for admin-managed version configuration.
-- Stores minimum supported and forced-update versions for iOS and Android separately.
-- A single row is seeded on creation.

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- app_version_config: Admin-managed version configuration
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "app_version_config" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  "ios_min_version" varchar(20),
  "android_min_version" varchar(20),
  "ios_force_version" varchar(20),
  "android_force_version" varchar(20),
  "force_update_enabled" boolean DEFAULT false,
  "updated_at" timestamp WITH TIME ZONE DEFAULT NOW()
);
--> statement-breakpoint

-- Seed a single default row (only insert if table is empty)
INSERT INTO "app_version_config" (
  "ios_min_version",
  "android_min_version",
  "ios_force_version",
  "android_force_version",
  "force_update_enabled"
)
SELECT
  NULL,
  NULL,
  NULL,
  NULL,
  false
WHERE NOT EXISTS (SELECT 1 FROM "app_version_config");
--> statement-breakpoint
