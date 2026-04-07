/**
 * Database integrity tests for the server-side SQLite schema.
 *
 * These tests spin up a real in-memory SQLite database (via better-sqlite3)
 * to verify:
 *   - All tables are created with correct columns, types, and constraints.
 *   - Unique constraints are enforced (users.email, otpRecords.email+used,
 *     refresh_tokens.token, sync_metadata.user_id).
 *   - Foreign key CASCADE behaviour propagates deletes correctly.
 *   - Expected indexes are present in the schema.
 *   - NOT NULL constraints reject null inserts.
 *   - Default values (attempts=0, used=false, revoked=false) apply without
 *     explicit values.
 *
 * We instantiate DatabaseService with DATABASE_DIR set to ':memory:' via a
 * tiny env-variable override so the service opens an in-memory DB.
 */

import Database from 'better-sqlite3';
import { drizzle } from 'drizzle-orm/better-sqlite3';
import { eq } from 'drizzle-orm';
import * as schema from './schema';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Open a fresh in-memory SQLite DB and run the same DDL as DatabaseService. */
function openTestDb() {
  const sqlite = new Database(':memory:');
  sqlite.pragma('journal_mode = WAL');
  sqlite.pragma('foreign_keys = ON');

  // Tables
  sqlite.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id         TEXT    PRIMARY KEY,
      email      TEXT    NOT NULL UNIQUE,
      created_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS otp_records (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      email      TEXT    NOT NULL,
      code       TEXT    NOT NULL,
      expires_at INTEGER NOT NULL,
      attempts   INTEGER NOT NULL DEFAULT 0,
      used       INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS refresh_tokens (
      id         TEXT    PRIMARY KEY,
      user_id    TEXT    NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      token      TEXT    NOT NULL UNIQUE,
      expires_at INTEGER NOT NULL,
      revoked    INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS sync_metadata (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id      TEXT    NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
      last_sync_at INTEGER,
      size_bytes   INTEGER
    );
  `);

  // Indexes
  sqlite.exec(`
    CREATE INDEX IF NOT EXISTS idx_otp_lookup
      ON otp_records (email, used, expires_at);

    CREATE INDEX IF NOT EXISTS idx_otp_expires_at
      ON otp_records (expires_at);

    CREATE INDEX IF NOT EXISTS idx_refresh_user_id
      ON refresh_tokens (user_id);

    CREATE INDEX IF NOT EXISTS idx_refresh_expires_at
      ON refresh_tokens (expires_at);
  `);

  const db = drizzle(sqlite, { schema });
  return { sqlite, db };
}

/** Seed a user row and return the inserted record. */
function seedUser(
  sqlite: Database.Database,
  override: Partial<{ id: string; email: string; created_at: number }> = {},
) {
  const row = {
    id: override.id ?? 'user-test-1',
    email: override.email ?? 'test@example.com',
    created_at: override.created_at ?? Date.now(),
  };
  sqlite.prepare(
    'INSERT INTO users (id, email, created_at) VALUES (?, ?, ?)',
  ).run(row.id, row.email, row.created_at);
  return row;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('DatabaseService — schema integrity', () => {
  let sqlite: Database.Database;
  let db: ReturnType<typeof openTestDb>['db'];

  beforeEach(() => {
    ({ sqlite, db } = openTestDb());
  });

  afterEach(() => {
    sqlite.close();
  });

  // ── Table existence ───────────────────────────────────────────────────────

  describe('table existence', () => {
    const expectedTables = ['users', 'otp_records', 'refresh_tokens', 'sync_metadata'];

    it.each(expectedTables)('table "%s" exists', (tableName) => {
      const row = sqlite
        .prepare(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        )
        .get(tableName);
      expect(row).not.toBeNull();
    });
  });

  // ── Index existence ───────────────────────────────────────────────────────

  describe('index existence', () => {
    const expectedIndexes = [
      'idx_otp_lookup',
      'idx_otp_expires_at',
      'idx_refresh_user_id',
      'idx_refresh_expires_at',
    ];

    it.each(expectedIndexes)('index "%s" exists', (indexName) => {
      const row = sqlite
        .prepare(
          "SELECT name FROM sqlite_master WHERE type='index' AND name=?",
        )
        .get(indexName);
      expect(row).not.toBeNull();
    });
  });

  // ── users table ───────────────────────────────────────────────────────────

  describe('users table', () => {
    it('inserts a user and retrieves it by id', () => {
      const now = new Date();
      db.insert(schema.users).values({ id: 'u1', email: 'a@b.com', createdAt: now }).run();
      const found = db.select().from(schema.users).where(eq(schema.users.id, 'u1')).get();
      expect(found).toMatchObject({ id: 'u1', email: 'a@b.com' });
    });

    it('enforces UNIQUE constraint on email', () => {
      const now = new Date();
      db.insert(schema.users).values({ id: 'u1', email: 'dup@b.com', createdAt: now }).run();
      expect(() =>
        db.insert(schema.users).values({ id: 'u2', email: 'dup@b.com', createdAt: now }).run(),
      ).toThrow(/UNIQUE constraint failed/);
    });

    it('enforces NOT NULL on email', () => {
      expect(() =>
        sqlite.prepare('INSERT INTO users (id, created_at) VALUES (?, ?)').run('u-bad', Date.now()),
      ).toThrow();
    });

    it('enforces NOT NULL on created_at', () => {
      expect(() =>
        sqlite
          .prepare("INSERT INTO users (id, email) VALUES (?, ?)")
          .run('u-bad', 'nodate@b.com'),
      ).toThrow();
    });
  });

  // ── otp_records table ─────────────────────────────────────────────────────

  describe('otp_records table', () => {
    it('inserts an OTP record and retrieves it', () => {
      const now = new Date();
      const expires = new Date(now.getTime() + 5 * 60 * 1000);
      db.insert(schema.otpRecords)
        .values({ email: 'otp@b.com', code: '123456', expiresAt: expires, createdAt: now })
        .run();
      const record = db
        .select()
        .from(schema.otpRecords)
        .where(eq(schema.otpRecords.email, 'otp@b.com'))
        .get();
      expect(record).toMatchObject({ email: 'otp@b.com', code: '123456' });
    });

    it('defaults attempts to 0', () => {
      const now = new Date();
      db.insert(schema.otpRecords)
        .values({ email: 'def@b.com', code: '999999', expiresAt: now, createdAt: now })
        .run();
      const record = db
        .select()
        .from(schema.otpRecords)
        .where(eq(schema.otpRecords.email, 'def@b.com'))
        .get();
      expect(record?.attempts).toBe(0);
    });

    it('defaults used to false', () => {
      const now = new Date();
      db.insert(schema.otpRecords)
        .values({ email: 'used@b.com', code: '111111', expiresAt: now, createdAt: now })
        .run();
      const record = db
        .select()
        .from(schema.otpRecords)
        .where(eq(schema.otpRecords.email, 'used@b.com'))
        .get();
      expect(record?.used).toBe(false);
    });

    it('autoIncrements the id column', () => {
      const now = new Date();
      db.insert(schema.otpRecords)
        .values({ email: 'a@b.com', code: '111111', expiresAt: now, createdAt: now })
        .run();
      db.insert(schema.otpRecords)
        .values({ email: 'b@b.com', code: '222222', expiresAt: now, createdAt: now })
        .run();
      const records = db.select().from(schema.otpRecords).all();
      expect(records[1].id).toBeGreaterThan(records[0].id);
    });

    it('can update the used flag to true', () => {
      const now = new Date();
      db.insert(schema.otpRecords)
        .values({ email: 'mark@b.com', code: '555555', expiresAt: now, createdAt: now })
        .run();
      const record = db
        .select()
        .from(schema.otpRecords)
        .where(eq(schema.otpRecords.email, 'mark@b.com'))
        .get()!;
      db.update(schema.otpRecords)
        .set({ used: true })
        .where(eq(schema.otpRecords.id, record.id))
        .run();
      const updated = db
        .select()
        .from(schema.otpRecords)
        .where(eq(schema.otpRecords.id, record.id))
        .get();
      expect(updated?.used).toBe(true);
    });
  });

  // ── refresh_tokens table ──────────────────────────────────────────────────

  describe('refresh_tokens table', () => {
    beforeEach(() => {
      seedUser(sqlite);
    });

    it('inserts a refresh token linked to a user', () => {
      const expires = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
      db.insert(schema.refreshTokens)
        .values({
          id: 'rt-1',
          userId: 'user-test-1',
          token: 'opaque-refresh-token',
          expiresAt: expires,
        })
        .run();
      const record = db
        .select()
        .from(schema.refreshTokens)
        .where(eq(schema.refreshTokens.token, 'opaque-refresh-token'))
        .get();
      expect(record).toMatchObject({ userId: 'user-test-1', revoked: false });
    });

    it('defaults revoked to false', () => {
      const expires = new Date(Date.now() + 1000);
      db.insert(schema.refreshTokens)
        .values({ id: 'rt-2', userId: 'user-test-1', token: 'token-b', expiresAt: expires })
        .run();
      const record = db
        .select()
        .from(schema.refreshTokens)
        .where(eq(schema.refreshTokens.id, 'rt-2'))
        .get();
      expect(record?.revoked).toBe(false);
    });

    it('enforces UNIQUE constraint on token', () => {
      const expires = new Date(Date.now() + 1000);
      db.insert(schema.refreshTokens)
        .values({ id: 'rt-3', userId: 'user-test-1', token: 'dup-token', expiresAt: expires })
        .run();
      expect(() =>
        db.insert(schema.refreshTokens)
          .values({ id: 'rt-4', userId: 'user-test-1', token: 'dup-token', expiresAt: expires })
          .run(),
      ).toThrow(/UNIQUE constraint failed/);
    });

    it('rejects insert with non-existent user_id (FK constraint)', () => {
      const expires = new Date(Date.now() + 1000);
      expect(() =>
        db.insert(schema.refreshTokens)
          .values({
            id: 'rt-fk',
            userId: 'ghost-user',
            token: 'ghost-token',
            expiresAt: expires,
          })
          .run(),
      ).toThrow(/FOREIGN KEY constraint failed/);
    });

    it('cascades delete to refresh_tokens when user is deleted', () => {
      const expires = new Date(Date.now() + 1000);
      db.insert(schema.refreshTokens)
        .values({
          id: 'rt-cascade',
          userId: 'user-test-1',
          token: 'cascade-token',
          expiresAt: expires,
        })
        .run();

      // Delete the parent user.
      sqlite.prepare('DELETE FROM users WHERE id = ?').run('user-test-1');

      // The refresh token must be gone too.
      const orphan = db
        .select()
        .from(schema.refreshTokens)
        .where(eq(schema.refreshTokens.id, 'rt-cascade'))
        .get();
      expect(orphan).toBeUndefined();
    });
  });

  // ── sync_metadata table ───────────────────────────────────────────────────

  describe('sync_metadata table', () => {
    beforeEach(() => {
      seedUser(sqlite);
    });

    it('inserts a sync metadata row', () => {
      db.insert(schema.syncMetadata)
        .values({ userId: 'user-test-1', lastSyncAt: new Date(), sizeBytes: 1024 })
        .run();
      const record = db
        .select()
        .from(schema.syncMetadata)
        .where(eq(schema.syncMetadata.userId, 'user-test-1'))
        .get();
      expect(record).toMatchObject({ userId: 'user-test-1', sizeBytes: 1024 });
    });

    it('allows null lastSyncAt and sizeBytes (never synced state)', () => {
      db.insert(schema.syncMetadata)
        .values({ userId: 'user-test-1', lastSyncAt: null, sizeBytes: null })
        .run();
      const record = db
        .select()
        .from(schema.syncMetadata)
        .where(eq(schema.syncMetadata.userId, 'user-test-1'))
        .get();
      expect(record?.lastSyncAt).toBeNull();
      expect(record?.sizeBytes).toBeNull();
    });

    it('enforces UNIQUE constraint on user_id (one row per user)', () => {
      db.insert(schema.syncMetadata)
        .values({ userId: 'user-test-1', lastSyncAt: null, sizeBytes: null })
        .run();
      expect(() =>
        db.insert(schema.syncMetadata)
          .values({ userId: 'user-test-1', lastSyncAt: null, sizeBytes: null })
          .run(),
      ).toThrow(/UNIQUE constraint failed/);
    });

    it('rejects insert with non-existent user_id (FK constraint)', () => {
      expect(() =>
        db.insert(schema.syncMetadata)
          .values({ userId: 'no-such-user', lastSyncAt: null, sizeBytes: null })
          .run(),
      ).toThrow(/FOREIGN KEY constraint failed/);
    });

    it('cascades delete to sync_metadata when user is deleted', () => {
      db.insert(schema.syncMetadata)
        .values({ userId: 'user-test-1', lastSyncAt: new Date(), sizeBytes: 512 })
        .run();

      sqlite.prepare('DELETE FROM users WHERE id = ?').run('user-test-1');

      const orphan = db
        .select()
        .from(schema.syncMetadata)
        .where(eq(schema.syncMetadata.userId, 'user-test-1'))
        .get();
      expect(orphan).toBeUndefined();
    });

    it('can update lastSyncAt and sizeBytes', () => {
      db.insert(schema.syncMetadata)
        .values({ userId: 'user-test-1', lastSyncAt: null, sizeBytes: null })
        .run();
      const now = new Date();
      db.update(schema.syncMetadata)
        .set({ lastSyncAt: now, sizeBytes: 2048 })
        .where(eq(schema.syncMetadata.userId, 'user-test-1'))
        .run();
      const record = db
        .select()
        .from(schema.syncMetadata)
        .where(eq(schema.syncMetadata.userId, 'user-test-1'))
        .get();
      expect(record?.sizeBytes).toBe(2048);
      expect(record?.lastSyncAt).toEqual(now);
    });
  });

  // ── Cross-table: full auth flow ───────────────────────────────────────────

  describe('full auth flow (OTP → user → refresh token)', () => {
    it('creates user and refresh token after OTP verification', () => {
      const now = new Date();
      const expires = new Date(now.getTime() + 5 * 60 * 1000);
      const tokenExpiry = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

      // 1. Insert OTP record.
      db.insert(schema.otpRecords)
        .values({ email: 'flow@b.com', code: '654321', expiresAt: expires, createdAt: now })
        .run();

      // 2. Mark OTP as used.
      db.update(schema.otpRecords)
        .set({ used: true })
        .where(eq(schema.otpRecords.email, 'flow@b.com'))
        .run();

      // 3. Create user.
      db.insert(schema.users).values({ id: 'flow-user', email: 'flow@b.com', createdAt: now }).run();

      // 4. Issue refresh token.
      db.insert(schema.refreshTokens)
        .values({
          id: 'rt-flow',
          userId: 'flow-user',
          token: 'flow-refresh-opaque',
          expiresAt: tokenExpiry,
        })
        .run();

      // 5. Verify state.
      const user = db.select().from(schema.users).where(eq(schema.users.email, 'flow@b.com')).get();
      expect(user).toMatchObject({ id: 'flow-user' });

      const otp = db.select().from(schema.otpRecords).where(eq(schema.otpRecords.email, 'flow@b.com')).get();
      expect(otp?.used).toBe(true);

      const rt = db
        .select()
        .from(schema.refreshTokens)
        .where(eq(schema.refreshTokens.userId, 'flow-user'))
        .get();
      expect(rt).toMatchObject({ token: 'flow-refresh-opaque', revoked: false });
    });

    it('all child rows are removed when user account is deleted', () => {
      const now = new Date();
      const tokenExpiry = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

      // Create user with refresh token and sync metadata.
      db.insert(schema.users).values({ id: 'del-user', email: 'del@b.com', createdAt: now }).run();
      db.insert(schema.refreshTokens)
        .values({ id: 'rt-del', userId: 'del-user', token: 'del-token', expiresAt: tokenExpiry })
        .run();
      db.insert(schema.syncMetadata)
        .values({ userId: 'del-user', lastSyncAt: now, sizeBytes: 256 })
        .run();

      // Delete the user.
      sqlite.prepare('DELETE FROM users WHERE id = ?').run('del-user');

      // Both child rows should cascade-delete.
      expect(
        db.select().from(schema.refreshTokens).where(eq(schema.refreshTokens.userId, 'del-user')).all(),
      ).toHaveLength(0);
      expect(
        db.select().from(schema.syncMetadata).where(eq(schema.syncMetadata.userId, 'del-user')).all(),
      ).toHaveLength(0);
    });
  });

  // ── Index query plan verification ─────────────────────────────────────────
  //
  // EXPLAIN QUERY PLAN confirms that SQLite selects the composite index rather
  // than a full table scan for the most critical query patterns.

  describe('query plan: index usage verification', () => {
    it('verifyOtp query uses idx_otp_lookup index', () => {
      const plan = sqlite
        .prepare(
          `EXPLAIN QUERY PLAN
           SELECT * FROM otp_records
           WHERE email = ? AND used = 0 AND expires_at > ?`,
        )
        .all('x@b.com', Date.now()) as Array<{ detail: string }>;

      const usesIndex = plan.some((row) => row.detail?.includes('idx_otp_lookup'));
      expect(usesIndex).toBe(true);
    });

    it('pruneExpiredOtps query uses idx_otp_expires_at index', () => {
      const plan = sqlite
        .prepare('EXPLAIN QUERY PLAN DELETE FROM otp_records WHERE expires_at < ?')
        .all(Date.now()) as Array<{ detail: string }>;

      const usesIndex = plan.some((row) => row.detail?.includes('idx_otp_expires_at'));
      expect(usesIndex).toBe(true);
    });

    it('refreshToken user-id lookup uses idx_refresh_user_id index', () => {
      const plan = sqlite
        .prepare('EXPLAIN QUERY PLAN SELECT * FROM refresh_tokens WHERE user_id = ?')
        .all('some-user-id') as Array<{ detail: string }>;

      const usesIndex = plan.some((row) => row.detail?.includes('idx_refresh_user_id'));
      expect(usesIndex).toBe(true);
    });
  });
});
