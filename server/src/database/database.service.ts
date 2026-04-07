import { Injectable, Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import Database from 'better-sqlite3';
import { drizzle, BetterSQLite3Database } from 'drizzle-orm/better-sqlite3';
import { existsSync, mkdirSync } from 'fs';
import { join } from 'path';
import * as schema from './schema';

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DatabaseService.name);

  /** Raw better-sqlite3 connection (exposed for WAL checkpoint in SyncService). */
  sqlite!: Database.Database;

  /** Drizzle ORM query builder. */
  db!: BetterSQLite3Database<typeof schema>;

  onModuleInit(): void {
    const dataDir = process.env.DATABASE_DIR ?? join(process.cwd(), 'data');
    if (!existsSync(dataDir)) {
      mkdirSync(dataDir, { recursive: true });
    }
    const dbPath = join(dataDir, 'server.db');

    this.sqlite = new Database(dbPath);
    // WAL mode for better concurrent read performance.
    this.sqlite.pragma('journal_mode = WAL');
    this.sqlite.pragma('foreign_keys = ON');

    this.db = drizzle(this.sqlite, { schema });
    this.createTables();
    this.logger.log(`Database initialized at ${dbPath}`);
  }

  onModuleDestroy(): void {
    this.sqlite?.close();
  }

  private createTables(): void {
    // ── DDL: tables ──────────────────────────────────────────────────────────
    this.sqlite.exec(`
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

    // ── DDL: indexes ─────────────────────────────────────────────────────────
    //
    // These match the Drizzle index definitions in schema.ts exactly so that
    // Drizzle Kit migration output and the runtime createTables() stay in sync.
    //
    // All statements are idempotent (IF NOT EXISTS) so re-running on a DB that
    // already has the index is a no-op.
    this.sqlite.exec(`
      -- otp_records: composite covering index for the two main WHERE patterns:
      --   requestOtp invalidation:  WHERE email = ? AND used = 0
      --   verifyOtp lookup:         WHERE email = ? AND used = 0 AND expires_at > ?
      -- Column order: equality first (email, used), range last (expires_at).
      CREATE INDEX IF NOT EXISTS idx_otp_lookup
        ON otp_records (email, used, expires_at);

      -- otp_records: range scan index for periodic pruneExpiredOtps().
      CREATE INDEX IF NOT EXISTS idx_otp_expires_at
        ON otp_records (expires_at);

      -- refresh_tokens: supports revoking all tokens for a user and FK traversal.
      CREATE INDEX IF NOT EXISTS idx_refresh_user_id
        ON refresh_tokens (user_id);

      -- refresh_tokens: supports periodic cleanup of expired tokens.
      CREATE INDEX IF NOT EXISTS idx_refresh_expires_at
        ON refresh_tokens (expires_at);
    `);

    this.logger.log('Database tables and indexes ensured');
  }
}
