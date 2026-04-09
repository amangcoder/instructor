-- verify-schema.sql
-- Verifies that all four Instructor tables exist with correct columns, types,
-- and indexes after running drizzle-kit migrate.
--
-- Usage:
--   psql "$DATABASE_URL_DIRECT" -f scripts/verify-schema.sql
--
-- Expected output: 4 table rows, all columns present, all indexes present.

\echo '=== Verifying Instructor PostgreSQL schema ==='
\echo ''

-- ── 1. All four tables must exist ──────────────────────────────────────────

\echo '--- Tables ---'
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('users', 'otp_records', 'refresh_tokens', 'sync_metadata')
ORDER BY table_name;

-- ── 2. Column definitions ──────────────────────────────────────────────────

\echo ''
\echo '--- users columns ---'
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'users'
ORDER BY ordinal_position;

\echo ''
\echo '--- otp_records columns ---'
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'otp_records'
ORDER BY ordinal_position;

\echo ''
\echo '--- refresh_tokens columns ---'
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'refresh_tokens'
ORDER BY ordinal_position;

\echo ''
\echo '--- sync_metadata columns ---'
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'sync_metadata'
ORDER BY ordinal_position;

-- ── 3. Indexes ─────────────────────────────────────────────────────────────

\echo ''
\echo '--- Indexes ---'
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('users', 'otp_records', 'refresh_tokens', 'sync_metadata')
ORDER BY tablename, indexname;

-- ── 4. Constraints (FKs, UNIQUE, PKs) ─────────────────────────────────────

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
  AND tc.table_name IN ('users', 'otp_records', 'refresh_tokens', 'sync_metadata')
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name;

-- ── 5. Quick sanity checks ─────────────────────────────────────────────────

\echo ''
\echo '--- Sanity checks (all counts must be 4) ---'

-- Expect 4
SELECT COUNT(*) AS "tables_count (expect 4)"
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('users', 'otp_records', 'refresh_tokens', 'sync_metadata');

-- Expect 2 FK constraints
SELECT COUNT(*) AS "fk_constraints (expect 2)"
FROM information_schema.table_constraints
WHERE table_schema = 'public'
  AND constraint_type = 'FOREIGN KEY'
  AND table_name IN ('refresh_tokens', 'sync_metadata');

-- Expect partial index on refresh_tokens
SELECT COUNT(*) AS "partial_index_exists (expect 1)"
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'refresh_tokens'
  AND indexname = 'idx_refresh_tokens_active'
  AND indexdef LIKE '%WHERE%';

\echo ''
\echo '=== Schema verification complete ==='
