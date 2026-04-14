-- verify-schema.sql
-- Verifies that all Instructor tables exist with correct columns, types,
-- and indexes after running drizzle-kit migrate.
--
-- Usage:
--   psql "$DATABASE_URL_DIRECT" -f scripts/verify-schema.sql
--
-- Expected output: all tables present, all columns correct, all indexes present.

\echo '=== Verifying Instructor PostgreSQL schema ==='
\echo ''

-- ── 1. All tables must exist ────────────────────────────────────────────────
-- NOTE: sync_metadata was dropped as part of the server-first architecture migration.

\echo '--- Core tables ---'
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'users', 'otp_records', 'refresh_tokens', 'plans',
    'library_plans', 'tts_jobs'
  )
ORDER BY table_name;

-- ── 2. library_plans columns ────────────────────────────────────────────────

\echo ''
\echo '--- library_plans columns ---'
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'library_plans'
ORDER BY ordinal_position;

-- ── 3. tts_jobs columns ─────────────────────────────────────────────────────

\echo ''
\echo '--- tts_jobs columns ---'
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'tts_jobs'
ORDER BY ordinal_position;

-- ── 4. plans table — new columns added in migration ─────────────────────────

\echo ''
\echo '--- plans new columns (source_library_plan_id, is_active, tts_status, tts_total, tts_completed, voice_quality) ---'
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'plans'
  AND column_name IN (
    'source_library_plan_id', 'is_active', 'tts_status',
    'tts_total', 'tts_completed', 'voice_quality'
  )
ORDER BY ordinal_position;

-- ── 5. users columns ─────────────────────────────────────────────────────────

\echo ''
\echo '--- users columns ---'
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'users'
ORDER BY ordinal_position;

-- ── 6. Indexes ──────────────────────────────────────────────────────────────

\echo ''
\echo '--- Indexes ---'
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN (
    'users', 'otp_records', 'refresh_tokens', 'plans',
    'library_plans', 'tts_jobs'
  )
ORDER BY tablename, indexname;

-- ── 7. Constraints (FKs, UNIQUE, PKs) ──────────────────────────────────────

\echo ''
\echo '--- Constraints ---'
SELECT
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name  AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
LEFT JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.table_schema = 'public'
  AND tc.table_name IN (
    'users', 'otp_records', 'refresh_tokens', 'plans',
    'library_plans', 'tts_jobs'
  )
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name;

-- ── 8. Sanity checks ────────────────────────────────────────────────────────

\echo ''
\echo '--- Sanity checks ---'

-- Expect 6 core tables
SELECT COUNT(*) AS "tables_count (expect 6)"
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'users', 'otp_records', 'refresh_tokens', 'plans',
    'library_plans', 'tts_jobs'
  );

-- Expect sync_metadata to be absent (dropped in migration)
SELECT COUNT(*) AS "sync_metadata_absent (expect 0)"
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name = 'sync_metadata';

-- Expect tts_jobs.cache_key UNIQUE index
SELECT COUNT(*) AS "tts_jobs_cache_key_unique (expect 1)"
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'tts_jobs'
  AND indexname LIKE '%cache_key%';

-- Expect library_plans.is_published index
SELECT COUNT(*) AS "library_plans_published_index (expect 1)"
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'library_plans'
  AND indexname LIKE '%published%';

-- Expect 3+ FK constraints on new tables (tts_jobs.plan_id, plans.source_library_plan_id)
SELECT COUNT(*) AS "new_table_fk_constraints (expect >= 2)"
FROM information_schema.table_constraints
WHERE table_schema = 'public'
  AND constraint_type = 'FOREIGN KEY'
  AND table_name IN ('tts_jobs', 'plans');

\echo ''
\echo '=== Schema verification complete ==='
