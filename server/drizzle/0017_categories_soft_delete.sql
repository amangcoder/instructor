-- Migration: 0017_categories_soft_delete
-- Adds categories.deleted_at as a true soft-delete tombstone, decoupling
-- "deleted" from "draft" (is_published = false).
--
-- Problem: softDeleteCategory() previously set is_published = false, but the
-- admin list returns drafts (is_published = false) too — so a deleted category
-- was indistinguishable from a draft and reappeared in the admin grid after
-- the post-delete refetch, looking like the delete had failed.
--
-- Solution: Add a nullable deleted_at column. NULL = live; non-NULL = hidden
-- everywhere (admin list, public list, getById). The is_published flag retains
-- its draft-vs-live meaning for live records only.
--
-- Index: rebuild idx_categories_published_sort to also exclude deleted rows
-- so the mobile Discover surface query stays index-only.
--
-- Apply with:  npm run db:migrate   (from server/ directory)

--> statement-breakpoint

ALTER TABLE "categories"
    ADD COLUMN IF NOT EXISTS "deleted_at" timestamp with time zone;

--> statement-breakpoint

DROP INDEX IF EXISTS "idx_categories_published_sort";

--> statement-breakpoint

CREATE INDEX IF NOT EXISTS "idx_categories_published_sort"
    ON "categories" ("sort_order")
    WHERE "is_published" = true AND "deleted_at" IS NULL;
