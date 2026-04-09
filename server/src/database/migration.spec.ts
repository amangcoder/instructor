/**
 * Unit tests for the Drizzle migration files.
 *
 * These tests verify that:
 *   - The migration SQL file exists and contains all four table definitions
 *   - The drizzle meta journal is correctly structured
 *   - Required indexes and constraints are present in the SQL
 *   - Both direct and pooler connection string patterns are documented
 *
 * These tests run without a database connection and are safe to run in CI.
 */

import * as fs from 'fs';
import * as path from 'path';

const DRIZZLE_DIR = path.resolve(__dirname, '../../drizzle');
const MIGRATION_SQL = path.join(DRIZZLE_DIR, '0000_instructor_initial_schema.sql');
const META_JOURNAL = path.join(DRIZZLE_DIR, 'meta', '_journal.json');

// ---------------------------------------------------------------------------
// Migration file existence
// ---------------------------------------------------------------------------

describe('drizzle migration directory', () => {
  it('drizzle/ directory exists', () => {
    expect(fs.existsSync(DRIZZLE_DIR)).toBe(true);
  });

  it('0000_instructor_initial_schema.sql exists', () => {
    expect(fs.existsSync(MIGRATION_SQL)).toBe(true);
  });

  it('meta/_journal.json exists', () => {
    expect(fs.existsSync(META_JOURNAL)).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Migration SQL content
// ---------------------------------------------------------------------------

describe('migration SQL: table definitions', () => {
  let sql: string;

  beforeAll(() => {
    sql = fs.readFileSync(MIGRATION_SQL, 'utf-8');
  });

  it('creates the users table', () => {
    expect(sql).toMatch(/CREATE TABLE.*"users"/i);
  });

  it('creates the otp_records table', () => {
    expect(sql).toMatch(/CREATE TABLE.*"otp_records"/i);
  });

  it('creates the refresh_tokens table', () => {
    expect(sql).toMatch(/CREATE TABLE.*"refresh_tokens"/i);
  });

  it('creates the sync_metadata table', () => {
    expect(sql).toMatch(/CREATE TABLE.*"sync_metadata"/i);
  });
});

describe('migration SQL: users table columns', () => {
  let sql: string;

  beforeAll(() => {
    sql = fs.readFileSync(MIGRATION_SQL, 'utf-8');
  });

  it('id column is uuid primary key with gen_random_uuid()', () => {
    expect(sql).toMatch(/"id"\s+uuid\s+PRIMARY KEY\s+DEFAULT\s+gen_random_uuid\(\)/i);
  });

  it('email column is varchar NOT NULL with UNIQUE constraint', () => {
    expect(sql).toMatch(/"email"\s+varchar\s+NOT NULL/i);
    expect(sql).toMatch(/CONSTRAINT.*users_email_unique.*UNIQUE.*"email"/i);
  });

  it('created_at column is timestamp with time zone NOT NULL with default now()', () => {
    expect(sql).toMatch(/"created_at"\s+timestamp with time zone\s+DEFAULT now\(\)\s+NOT NULL/i);
  });
});

describe('migration SQL: otp_records table', () => {
  let sql: string;

  beforeAll(() => {
    sql = fs.readFileSync(MIGRATION_SQL, 'utf-8');
  });

  it('code_hash column is varchar(64) NOT NULL', () => {
    expect(sql).toMatch(/"code_hash"\s+varchar\(64\)\s+NOT NULL/i);
  });

  it('expires_at column is timestamp with time zone NOT NULL', () => {
    expect(sql).toMatch(/"expires_at"\s+timestamp with time zone\s+NOT NULL/i);
  });

  it('attempts column has default 0', () => {
    expect(sql).toMatch(/"attempts"\s+integer\s+DEFAULT\s+0\s+NOT NULL/i);
  });

  it('used column has default false', () => {
    expect(sql).toMatch(/"used"\s+boolean\s+DEFAULT\s+false\s+NOT NULL/i);
  });

  it('composite index on (email, used, expires_at) exists', () => {
    expect(sql).toMatch(/idx_otp_records_email_used_expires/);
    expect(sql).toMatch(/ON\s+"otp_records"\s+\("email",\s*"used",\s*"expires_at"\)/i);
  });
});

describe('migration SQL: refresh_tokens table', () => {
  let sql: string;

  beforeAll(() => {
    sql = fs.readFileSync(MIGRATION_SQL, 'utf-8');
  });

  it('token_hash column is varchar(64) unique not null', () => {
    expect(sql).toMatch(/"token_hash"\s+varchar\(64\)\s+NOT NULL/i);
    expect(sql).toMatch(/CONSTRAINT.*refresh_tokens_token_hash_unique.*UNIQUE.*"token_hash"/i);
  });

  it('user_id column is uuid not null', () => {
    expect(sql).toMatch(/"user_id"\s+uuid\s+NOT NULL/i);
  });

  it('revoked column has default false', () => {
    expect(sql).toMatch(/"revoked"\s+boolean\s+DEFAULT\s+false\s+NOT NULL/i);
  });

  it('FK constraint from user_id to users.id exists', () => {
    expect(sql).toMatch(/refresh_tokens_user_id_users_id_fk/);
    expect(sql).toMatch(/FOREIGN KEY.*"user_id".*REFERENCES.*"users".*"id"/i);
  });

  it('partial index on active tokens (WHERE revoked = false) exists', () => {
    expect(sql).toMatch(/idx_refresh_tokens_active/);
    expect(sql).toMatch(/WHERE\s+"revoked"\s*=\s*false/i);
  });
});

describe('migration SQL: sync_metadata table', () => {
  let sql: string;

  beforeAll(() => {
    sql = fs.readFileSync(MIGRATION_SQL, 'utf-8');
  });

  it('user_id column is uuid unique not null', () => {
    expect(sql).toMatch(/"user_id"\s+uuid\s+NOT NULL/i);
    expect(sql).toMatch(/sync_metadata_user_id_unique/);
  });

  it('last_sync_at column is nullable timestamp with time zone', () => {
    // last_sync_at must NOT have NOT NULL constraint
    const syncMetaBlock = sql.split('sync_metadata')[1];
    expect(syncMetaBlock).not.toMatch(/"last_sync_at".*NOT NULL/i);
  });

  it('size_bytes column is bigint nullable', () => {
    expect(sql).toMatch(/"size_bytes"\s+bigint/i);
  });

  it('FK constraint from user_id to users.id exists', () => {
    expect(sql).toMatch(/sync_metadata_user_id_users_id_fk/);
    expect(sql).toMatch(/FOREIGN KEY.*"user_id".*REFERENCES.*"users".*"id"/i);
  });
});

// ---------------------------------------------------------------------------
// Meta journal
// ---------------------------------------------------------------------------

describe('drizzle meta journal', () => {
  let journal: any;

  beforeAll(() => {
    const raw = fs.readFileSync(META_JOURNAL, 'utf-8');
    journal = JSON.parse(raw);
  });

  it('journal has version field', () => {
    expect(journal.version).toBeDefined();
  });

  it('journal dialect is postgresql', () => {
    expect(journal.dialect).toBe('postgresql');
  });

  it('journal has at least one entry', () => {
    expect(Array.isArray(journal.entries)).toBe(true);
    expect(journal.entries.length).toBeGreaterThan(0);
  });

  it('first entry has tag 0000_instructor_initial_schema', () => {
    expect(journal.entries[0].tag).toBe('0000_instructor_initial_schema');
  });

  it('first entry has idx 0', () => {
    expect(journal.entries[0].idx).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// .env.example documentation
// ---------------------------------------------------------------------------

describe('.env.example connection string documentation', () => {
  let envExample: string;

  beforeAll(() => {
    const envExamplePath = path.resolve(__dirname, '../../.env.example');
    envExample = fs.existsSync(envExamplePath) ? fs.readFileSync(envExamplePath, 'utf-8') : '';
  });

  it('.env.example file exists', () => {
    const envExamplePath = path.resolve(__dirname, '../../.env.example');
    expect(fs.existsSync(envExamplePath)).toBe(true);
  });

  it('documents DATABASE_URL (pooler connection string)', () => {
    expect(envExample).toMatch(/DATABASE_URL=/);
    expect(envExample).toMatch(/pooler/i);
  });

  it('documents DATABASE_URL_DIRECT (direct connection string)', () => {
    expect(envExample).toMatch(/DATABASE_URL_DIRECT=/);
  });

  it('explains why direct is required for migrations', () => {
    expect(envExample).toMatch(/drizzle-kit/i);
    expect(envExample).toMatch(/direct/i);
  });

  it('warns against using pooler for migrations', () => {
    // The .env.example should explain the migration vs runtime distinction
    expect(envExample).toMatch(/migration/i);
  });
});
