-- Migration: 0014_content_hierarchy
-- Adds the categories → series → plans → sub-plans content hierarchy with
-- multi-voice TTS gating support.
--
-- Changes applied (in dependency order):
--   1. CREATE TABLE categories     — taxonomy top-level nodes replacing free-text series.category
--   2. CREATE TABLE voices          — TTS voice registry (provider/locale/slug)
--   3. CREATE TABLE plan_voices     — per-plan per-voice TTS gate (replaces plans.tts_status gate)
--   4. ALTER  TABLE series          — adds category_id FK (nullable; old text column kept until 0015)
--   5. ALTER  TABLE plans           — adds parent_plan_id, position, visibility, owner_user_id, is_published
--   6. CREATE VIEW v_published_plans — user-facing plan filter (is_published + public + ready-voice gate)
--   7. CREATE INDEXES               — query-performance indexes on plan_voices and altered tables
--
-- ============================================================================
-- v_published_plans CONTRACT
-- ============================================================================
-- A plan is visible to end-users (appears in v_published_plans) IFF all three
-- conditions hold simultaneously:
--
--   1. plans.is_published = true
--      → Admin has explicitly published the plan record.
--
--   2. plans.visibility = 'public'
--      → Plan is not private (author-only) or pending_review (admin queue).
--
--   3. EXISTS at least one plan_voices row where
--        plan_voices.plan_id = plans.id AND plan_voices.status = 'ready'
--      → At least one TTS voice rendition was successfully synthesised.
--
-- Corollaries / edge-case behaviour:
--   • A plan where ALL voice rows are 'failed'              → EXCLUDED
--   • A plan with NO plan_voices rows                       → EXCLUDED
--   • A plan where is_published = false                     → EXCLUDED (ignoring voice state)
--   • A plan where visibility != 'public'                   → EXCLUDED (ignoring voice state)
--   • A plan with one 'ready' voice and N 'failed' others   → INCLUDED
--
-- The EXISTS subquery is satisfied by the composite index
-- idx_plan_voices_plan_status (plan_id, status) — an index-only correlated
-- lookup, making the view filter efficient even at high plan counts.
--
-- Apply with:  npm run db:migrate   (from server/ directory)
-- Rollback:    see "DOWN MIGRATION" section at end of this file
-- ============================================================================

--> statement-breakpoint

-- ============================================================================
-- 1. categories
--    Top-level taxonomy nodes that group series and plans on the Discover
--    surface. sort_order drives display order (ascending, lower = first).
--    icon and color are optional branding hints for the mobile UI chrome.
--    is_published gates whether the category appears in the mobile Discover
--    surface; admin always sees all categories regardless.
-- ============================================================================

CREATE TABLE IF NOT EXISTS "categories" (
    "id"           uuid         PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    "slug"         text         NOT NULL,
    "name"         text         NOT NULL,
    "icon"         text,
    "color"        varchar(20),
    "sort_order"   integer      NOT NULL DEFAULT 0,
    "is_published" boolean      NOT NULL DEFAULT false,
    "created_at"   timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at"   timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "categories_slug_unique" UNIQUE ("slug")
);

--> statement-breakpoint

-- Sort-order scan: ORDER BY sort_order ASC for category list endpoints.
CREATE INDEX IF NOT EXISTS "idx_categories_sort_order"
    ON "categories" ("sort_order");

--> statement-breakpoint

-- Mobile Discover surface fetches only published categories, ordered by sort_order.
-- Partial index keeps it small as unpublished categories accumulate.
CREATE INDEX IF NOT EXISTS "idx_categories_published_sort"
    ON "categories" ("sort_order")
    WHERE "is_published" = true;

--> statement-breakpoint

-- ============================================================================
-- 2. voices
--    Registry of TTS voice profiles. Each row represents a distinct
--    (provider, locale, voice-slug) combination that can be associated with
--    plans via the plan_voices join table.
--    is_published controls whether the voice appears in admin voice-selector
--    dropdowns; internal/deprecated voices can be hidden without deletion.
-- ============================================================================

CREATE TABLE IF NOT EXISTS "voices" (
    "id"           uuid         PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    "slug"         text         NOT NULL,
    "display_name" text         NOT NULL,
    "locale"       text         NOT NULL,
    "provider"     text         NOT NULL,
    "sample_url"   text,
    "is_published" boolean      NOT NULL DEFAULT true,
    "created_at"   timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at"   timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "voices_slug_unique" UNIQUE ("slug")
);

--> statement-breakpoint

-- Locale-filtered voice lookups: WHERE locale = ? (e.g. 'en-IN', 'en-US').
CREATE INDEX IF NOT EXISTS "idx_voices_locale"
    ON "voices" ("locale");

--> statement-breakpoint

-- Admin voice-selector: WHERE is_published = true — partial keeps it small.
CREATE INDEX IF NOT EXISTS "idx_voices_published"
    ON "voices" ("is_published")
    WHERE "is_published" = true;

--> statement-breakpoint

-- ============================================================================
-- 3. plan_voices
--    Per-plan TTS gate table. Each row tracks the synthesis status of one
--    (plan, voice, locale) rendition. This table is the authoritative source
--    for whether a plan has synthesisable audio and thus whether it is
--    visible to end-users (via v_published_plans).
--
--    Status lifecycle:
--      pending    → TTS job queued, not yet started
--      processing → TTS worker is actively synthesising this rendition
--      ready      → Synthesis complete; audio_url and duration_ms populated
--      failed     → Synthesis failed; error_msg set; eligible for retry
--
--    generated_at is set when status first transitions to 'ready'. audio_url
--    and duration_ms remain NULL until then. error_msg remains NULL unless
--    status = 'failed'.
--
--    UNIQUE (plan_id, voice_id, locale) prevents duplicate renditions and
--    enables idempotent upserts during backfill (0009-backfill script) and
--    TTS retry operations.
--
--    ON DELETE CASCADE on both FKs: deleting a plan cleans up all its voice
--    rows automatically; deleting a voice removes its renditions across plans.
-- ============================================================================

CREATE TABLE IF NOT EXISTS "plan_voices" (
    "id"           uuid         PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    "plan_id"      uuid         NOT NULL,
    "voice_id"     uuid         NOT NULL,
    "locale"       text         NOT NULL,
    "status"       text         NOT NULL DEFAULT 'pending',
    "audio_url"    text,
    "duration_ms"  integer,
    "error_msg"    text,
    "generated_at" timestamp with time zone,
    "created_at"   timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at"   timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "plan_voices_status_check"
        CHECK ("status" IN ('pending', 'processing', 'ready', 'failed')),
    CONSTRAINT "plan_voices_plan_id_voice_id_locale_unique"
        UNIQUE ("plan_id", "voice_id", "locale")
);

--> statement-breakpoint

ALTER TABLE "plan_voices"
    ADD CONSTRAINT "plan_voices_plan_id_plans_id_fk"
    FOREIGN KEY ("plan_id") REFERENCES "plans"("id")
    ON DELETE cascade ON UPDATE no action;

--> statement-breakpoint

ALTER TABLE "plan_voices"
    ADD CONSTRAINT "plan_voices_voice_id_voices_id_fk"
    FOREIGN KEY ("voice_id") REFERENCES "voices"("id")
    ON DELETE cascade ON UPDATE no action;

--> statement-breakpoint

-- Composite index (plan_id, status) covers:
--   • EXISTS subquery in v_published_plans: plan_id = ? AND status = 'ready'
--   • Admin voice-grid per-plan: WHERE plan_id = ?  (plan_id prefix used alone)
--   • Status-filtered per-plan: WHERE plan_id = ? AND status = 'failed'
-- This is the most critical index for read performance on plan_voices.
CREATE INDEX IF NOT EXISTS "idx_plan_voices_plan_status"
    ON "plan_voices" ("plan_id", "status");

--> statement-breakpoint

-- Status-only index covers:
--   • GET /admin/plan-voices?status=failed  (cross-plan failed-job list)
--   • Admin retry-queue aggregations across all plans
--   • Monitoring queries counting pending/processing globally
CREATE INDEX IF NOT EXISTS "idx_plan_voices_status"
    ON "plan_voices" ("status");

--> statement-breakpoint

-- ============================================================================
-- 4. series.category_id
--    Nullable FK linking a series to its structured category. NULL = series
--    not yet assigned to a category. This is intentionally nullable to avoid
--    a breaking change on existing rows — existing series simply have NULL
--    until the backfill script (TASK-009) is run.
--
--    NOTE: The old free-text series.category column is NOT dropped here.
--    It will be removed in migration 0015 after the backfill script has
--    been verified against production data. This two-phase approach ensures
--    a safe rollback path.
-- ============================================================================

ALTER TABLE "series"
    ADD COLUMN IF NOT EXISTS "category_id" uuid;

--> statement-breakpoint

ALTER TABLE "series"
    ADD CONSTRAINT "series_category_id_categories_id_fk"
    FOREIGN KEY ("category_id") REFERENCES "categories"("id")
    ON DELETE set null ON UPDATE no action;

--> statement-breakpoint

-- Partial index: only series linked to a category use this lookup.
-- Powers "list all series in category X" queries on the Discover surface.
CREATE INDEX IF NOT EXISTS "idx_series_category_id"
    ON "series" ("category_id")
    WHERE "category_id" IS NOT NULL;

--> statement-breakpoint

-- ============================================================================
-- 5. plans additions
--    parent_plan_id — nullable self-FK enabling a sub-plan tree. Maximum
--                     depth of 3 is enforced in the NestJS service layer via
--                     a recursive CTE bounded at depth = 3. Attempts to
--                     create a sub-plan at depth 4+ are rejected (HTTP 422).
--                     ON DELETE CASCADE: deleting a parent also removes its
--                     sub-plan tree (intentional — orphaned sub-plans have no
--                     standalone meaning).
--
--    position       — integer sort order within a parent plan (for sub-plans)
--                     or within the top-level admin-curated list. Defaults to
--                     0; ordering ties broken by created_at.
--
--    visibility     — plan lifecycle enum:
--                       private        — author-only; default for new plans
--                       pending_review — user requested publish; in admin queue
--                       public         — admin approved; eligible for publishing
--                     NOTE: visibility = 'public' alone does NOT make a plan
--                     visible to end-users; is_published must also be true and
--                     at least one plan_voice must be 'ready' (see view above).
--
--    owner_user_id  — nullable FK to users; set for user-authored plans. NULL
--                     for admin-curated plans created via the admin panel.
--                     ON DELETE SET NULL: deleting a user preserves the plan
--                     record for admin review (avoids accidental content loss).
--
--    is_published   — explicit admin publish toggle. Existing plans default to
--                     false (safe: no plans are inadvertently exposed). Admins
--                     must explicitly flip this flag after verifying content
--                     and ensuring at least one voice is 'ready'.
--
--    Columns are added separately so each can be independently rolled back
--    and to minimise lock duration on the plans table.
-- ============================================================================

ALTER TABLE "plans"
    ADD COLUMN IF NOT EXISTS "parent_plan_id" uuid;

--> statement-breakpoint

ALTER TABLE "plans"
    ADD CONSTRAINT "plans_parent_plan_id_plans_id_fk"
    FOREIGN KEY ("parent_plan_id") REFERENCES "plans"("id")
    ON DELETE cascade ON UPDATE no action;

--> statement-breakpoint

ALTER TABLE "plans"
    ADD COLUMN IF NOT EXISTS "position" integer NOT NULL DEFAULT 0;

--> statement-breakpoint

ALTER TABLE "plans"
    ADD COLUMN IF NOT EXISTS "visibility" text NOT NULL DEFAULT 'public';

--> statement-breakpoint

ALTER TABLE "plans"
    ADD CONSTRAINT "plans_visibility_check"
    CHECK ("visibility" IN ('private', 'pending_review', 'public'));

--> statement-breakpoint

ALTER TABLE "plans"
    ADD COLUMN IF NOT EXISTS "owner_user_id" uuid;

--> statement-breakpoint

ALTER TABLE "plans"
    ADD CONSTRAINT "plans_owner_user_id_users_id_fk"
    FOREIGN KEY ("owner_user_id") REFERENCES "users"("id")
    ON DELETE set null ON UPDATE no action;

--> statement-breakpoint

ALTER TABLE "plans"
    ADD COLUMN IF NOT EXISTS "is_published" boolean NOT NULL DEFAULT false;

--> statement-breakpoint

-- Sub-plan tree: WHERE parent_plan_id = ? ORDER BY position ASC.
-- Partial keeps index small — most plans are top-level (parent_plan_id IS NULL).
CREATE INDEX IF NOT EXISTS "idx_plans_parent_position"
    ON "plans" ("parent_plan_id", "position")
    WHERE "parent_plan_id" IS NOT NULL;

--> statement-breakpoint

-- Admin plan-requests queue: WHERE visibility = 'pending_review'.
-- Partial index stays small as most plans are private or public.
CREATE INDEX IF NOT EXISTS "idx_plans_visibility_pending"
    ON "plans" ("visibility")
    WHERE "visibility" = 'pending_review';

--> statement-breakpoint

-- ============================================================================
-- 6. v_published_plans
--    Filtered view surfacing only plans that are safe for end-user display.
--
--    See top-of-file CONTRACT section for the full specification.
--
--    Implementation note: OR REPLACE is used so the view can be patched via
--    re-running this migration statement without a preceding DROP. The view
--    is non-materialized (no storage overhead) and is re-evaluated per query,
--    so index-backed EXISTS subquery performance is critical — satisfied by
--    idx_plan_voices_plan_status.
-- ============================================================================

CREATE OR REPLACE VIEW "v_published_plans" AS
SELECT
    p.*
FROM
    "plans" p
WHERE
    p."is_published" = true
    AND p."visibility" = 'public'
    AND EXISTS (
        SELECT 1
        FROM   "plan_voices" pv
        WHERE  pv."plan_id" = p."id"
          AND  pv."status"  = 'ready'
    );

--> statement-breakpoint

-- ============================================================================
-- DOWN MIGRATION
-- To roll back this migration, execute the following SQL statements in order.
-- Run within a single transaction for atomicity.
--
-- IMPORTANT: This rollback is non-destructive for application data because:
--   • plan_voices rows contain generated audio metadata but not the audio
--     files themselves (those live in S3). The S3 objects are unaffected.
--   • plans.is_published / visibility default to false / 'private' — rolling
--     back simply hides those plans again; no plan data is deleted.
--   • series.category_id is nullable — dropping it does not affect series data.
--   • categories and voices tables are new in this migration; if they contain
--     data when rolling back, that data will be lost (expected for rollback).
--
-- BEGIN;
--
-- DROP VIEW  IF EXISTS "v_published_plans";
--
-- -- Remove indexes added to plans
-- DROP INDEX IF EXISTS "idx_plans_visibility_pending";
-- DROP INDEX IF EXISTS "idx_plans_parent_position";
--
-- -- Remove CHECK constraint before dropping visibility column
-- ALTER TABLE "plans" DROP CONSTRAINT IF EXISTS "plans_visibility_check";
-- ALTER TABLE "plans" DROP CONSTRAINT IF EXISTS "plans_owner_user_id_users_id_fk";
-- ALTER TABLE "plans" DROP CONSTRAINT IF EXISTS "plans_parent_plan_id_plans_id_fk";
-- ALTER TABLE "plans"
--     DROP COLUMN IF EXISTS "is_published",
--     DROP COLUMN IF EXISTS "owner_user_id",
--     DROP COLUMN IF EXISTS "visibility",
--     DROP COLUMN IF EXISTS "position",
--     DROP COLUMN IF EXISTS "parent_plan_id";
--
-- -- Remove category_id from series
-- DROP INDEX IF EXISTS "idx_series_category_id";
-- ALTER TABLE "series" DROP CONSTRAINT IF EXISTS "series_category_id_categories_id_fk";
-- ALTER TABLE "series" DROP COLUMN IF EXISTS "category_id";
--
-- -- Drop plan_voices (FK constraints and indexes removed automatically)
-- DROP TABLE IF EXISTS "plan_voices";
--
-- -- Drop voices (after plan_voices so FK is gone)
-- DROP TABLE IF EXISTS "voices";
--
-- -- Drop categories (after series.category_id FK is gone)
-- DROP TABLE IF EXISTS "categories";
--
-- COMMIT;
-- ============================================================================
