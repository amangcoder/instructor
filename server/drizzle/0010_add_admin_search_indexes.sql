-- Migration: 0010_add_admin_search_indexes
-- Adds indexes to support fast admin search and analytics queries:
--   1. idx_users_email_lower — enables fast email search in user admin panel
--   2. idx_deletion_requests_email_lower — enables fast email search in deletion requests
--   3. idx_app_version_config_singleton — enforces single-row constraint on app_version_config
--
-- All indexes use CREATE CONCURRENTLY to avoid table locks on production tables.
-- Note: text_pattern_ops enables efficient LIKE queries with fixed prefixes;
-- for arbitrary ILIKE patterns, consider adding pg_trgm extension if available.

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- users: Email search index (case-insensitive)
-- Supports: WHERE lower(email) LIKE lower('%term%') queries
-- ---------------------------------------------------------------------------

CREATE INDEX CONCURRENTLY IF NOT EXISTS "idx_users_email_lower"
  ON "users" (lower("email") text_pattern_ops);

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- deletion_requests: Email search index (case-insensitive)
-- Supports: WHERE lower(email) LIKE lower('%term%') queries for deletion admin
-- ---------------------------------------------------------------------------

CREATE INDEX CONCURRENTLY IF NOT EXISTS "idx_deletion_requests_email_lower"
  ON "deletion_requests" (lower("email") text_pattern_ops);

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- app_version_config: Singleton constraint via unique index
-- Enforces at most one row in the table at any time.
-- The expression ((true)) is a common pattern: only one row can have true = true.
-- ---------------------------------------------------------------------------

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS "idx_app_version_config_singleton"
  ON "app_version_config" ((true));

--> statement-breakpoint
