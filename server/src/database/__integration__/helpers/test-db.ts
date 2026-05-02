/**
 * Integration test database helpers.
 *
 * All integration tests in this directory require a real PostgreSQL connection.
 * Set one of the following environment variables before running:
 *
 *   TEST_DATABASE_URL          — dedicated test database (preferred)
 *   DATABASE_URL_DIRECT        — the direct (non-pooled) connection string
 *   DATABASE_URL               — fallback to the main database
 *
 * Tests using these helpers call `describeDb(...)` instead of `describe(...)`.
 * When no database URL is configured the entire suite is skipped automatically.
 *
 * IMPORTANT: Integration tests mutate a real database.
 * Always use a dedicated test database — never run against production.
 *
 * Usage:
 *   import { describeDb, createTestDrizzle, rawSql, generateTestId } from './helpers/test-db';
 */

import { neon } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-http';
import type { NeonHttpDatabase } from 'drizzle-orm/neon-http';
import * as schema from '../../schema';

// ── Environment resolution ─────────────────────────────────────────────────

/**
 * The test database URL resolved in priority order:
 *   1. TEST_DATABASE_URL  — dedicated test database
 *   2. DATABASE_URL_DIRECT — direct (non-pooled) connection
 *   3. DATABASE_URL        — main database (use with caution)
 */
export const TEST_DATABASE_URL: string | undefined =
  process.env.TEST_DATABASE_URL ||
  process.env.DATABASE_URL_DIRECT ||
  process.env.DATABASE_URL;

/** True when a real database is available for integration tests. */
export const HAS_TEST_DB = !!TEST_DATABASE_URL;

// ── Conditional describe wrapper ───────────────────────────────────────────

/**
 * Drop-in replacement for `describe` that skips the entire suite when no
 * test database is configured.  Use this for all integration test groups.
 *
 * Example:
 *   describeDb('CategoryRepository integration', () => { ... });
 */
export const describeDb: jest.Describe = HAS_TEST_DB
  ? describe
  : describe.skip;

// ── Drizzle factory ────────────────────────────────────────────────────────

/**
 * Creates a Drizzle ORM instance connected to the test database.
 * Call once in `beforeAll` and share across tests in the same suite.
 *
 * @throws Error when TEST_DATABASE_URL is not set.
 */
export function createTestDrizzle(): NeonHttpDatabase<typeof schema> {
  if (!TEST_DATABASE_URL) {
    throw new Error(
      'Integration test requires TEST_DATABASE_URL, DATABASE_URL_DIRECT, or DATABASE_URL to be set',
    );
  }
  const sqlFn = neon(TEST_DATABASE_URL);
  return drizzle(sqlFn, { schema, logger: false });
}

// ── Raw SQL helper ─────────────────────────────────────────────────────────

/**
 * Executes a raw SQL string against the test database using the neon HTTP
 * tagged-template API.  Supports parameterized queries ($1, $2, …).
 *
 * Intended for DDL verification (information_schema), EXPLAIN ANALYZE, and
 * schema-state checks that don't fit the Drizzle ORM query builder.
 *
 * @param query  Raw SQL string (use $1, $2 … placeholders for parameters)
 * @param params Optional array of values corresponding to $1, $2 …
 * @returns      Array of plain row objects
 */
export async function rawSql<T = Record<string, unknown>>(
  query: string,
  params: unknown[] = [],
): Promise<T[]> {
  if (!TEST_DATABASE_URL) {
    throw new Error('TEST_DATABASE_URL not set — cannot execute raw SQL in integration test');
  }
  const sqlFn = neon(TEST_DATABASE_URL);
  // neon() accepts a raw string + params array as a fallback to tagged templates
  const rows = await (sqlFn as unknown as (q: string, p: unknown[]) => Promise<T[]>)(
    query,
    params,
  );
  return rows;
}

// ── Unique test ID generator ───────────────────────────────────────────────

/**
 * Generates a unique prefix/identifier for test data.
 * Each call returns a different value, ensuring test runs don't collide.
 *
 * @param suiteName  Short label for the test suite (e.g. "vpub", "cat")
 * @returns          A string safe to use in slugs, emails, and UUIDs
 */
export function generateTestId(suiteName: string): string {
  const timestamp = Date.now();
  const random = Math.floor(Math.random() * 10000);
  return `test-int-${suiteName}-${timestamp}-${random}`;
}

/**
 * Returns a test email address guaranteed to be unique for this test run.
 */
export function testEmail(suiteName: string, suffix: string): string {
  const id = generateTestId(suiteName);
  return `${id}-${suffix}@test.local`;
}

/**
 * Returns a test slug guaranteed to be unique for this test run.
 * Slugs are lowercase and contain only alphanumeric chars + hyphens.
 */
export function testSlug(suiteName: string, label: string): string {
  const id = generateTestId(suiteName);
  return `${id}-${label}`.toLowerCase().replace(/[^a-z0-9-]/g, '-');
}
