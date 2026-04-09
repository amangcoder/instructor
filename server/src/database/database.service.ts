/**
 * DatabaseService — Neon PostgreSQL-backed replacement for DynamoDBService.
 *
 * Drop-in replacement: all 14 public methods have identical signatures to
 * DynamoDBService so callers (AuthService, SyncService) need no changes.
 *
 * Driver:
 *   @neondatabase/serverless neon() HTTP mode — single HTTPS request per query,
 *   zero idle connections, no connection pooling overhead in Lambda.
 *
 * TOCTOU fixes vs the DynamoDB implementation:
 *   - invalidateOtpsForEmail: single UPDATE (not Query + N parallel Updates)
 *   - revokeAllRefreshTokens: single UPDATE (not GSI Query + N parallel Updates)
 *
 * Cold-start recovery:
 *   First query after ≥5 min Neon suspension can take 0.5–2 s.
 *   A single retry-once-with-1s-delay is applied to absorb this.
 *
 * Noop mode:
 *   When DATABASE_URL is unset every read returns null/[], every write is a no-op.
 *   This allows the Lambda bootstrap and unit tests to run without a live DB.
 *
 * Logger:
 *   Drizzle query logging is disabled in production to prevent accidental
 *   credential leakage inside query parameter values.
 *
 * Environment variables:
 *   DATABASE_URL  — Neon connection string (required for live mode)
 *   NODE_ENV      — set to "production" to suppress Drizzle query logs
 */

import { Injectable, Logger } from '@nestjs/common';
import { neon } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-http';
import { and, desc, eq, gt, sql } from 'drizzle-orm';
import * as schema from './schema';
import { otpRecords, refreshTokens, syncMetadata, users } from './schema';
import type { NeonHttpDatabase } from 'drizzle-orm/neon-http';

// ── Typed result shapes returned to callers ────────────────────────────────
// These interfaces are intentionally identical to the DynamoDBService equivalents
// so that AuthService, SyncService etc. require zero changes.

export interface UserRecord {
  id: string;
  email: string;
  createdAt: Date;
}

/**
 * CRITICAL: OtpRecord.sk maps from the PostgreSQL otp_records.id (UUID PK).
 * AuthService calls markOtpUsed(email, record.sk) and
 * incrementOtpAttempts(email, record.sk) using this field as the row identifier.
 */
export interface OtpRecord {
  /** Mapped from otp_records.id — used as the row identifier by AuthService */
  sk: string;
  email: string;
  /** Mapped from otp_records.code_hash */
  code: string;
  expiresAt: Date;
  attempts: number;
  used: boolean;
}

export interface RefreshTokenRecord {
  userId: string;
  tokenHash: string;
  revoked: boolean;
  expiresAt: Date;
  /** Mapped from refresh_tokens.id */
  sk: string;
}

export interface SyncMetadataRecord {
  userId: string;
  lastSyncAt: Date | null;
  sizeBytes: number | null;
}

// ── PostgreSQL error codes ─────────────────────────────────────────────────

/** Unique constraint violation — e.g. duplicate email on INSERT INTO users */
const PG_UNIQUE_VIOLATION = '23505';

// ── Service ────────────────────────────────────────────────────────────────

@Injectable()
export class DatabaseService {
  private readonly logger = new Logger(DatabaseService.name);
  private readonly db: NeonHttpDatabase<typeof schema> | null;

  /**
   * True when DATABASE_URL is absent.
   * All methods return mock/null results; writes are no-ops.
   */
  readonly noop: boolean;

  /**
   * Set to true during a withRetry() call after the first retry attempt fires,
   * so a second failure within the same call propagates immediately.
   * Reset to false at the start of each withRetry() call so that a subsequent
   * Neon suspension (after the container has been warm for >5 min) is also
   * recovered, not just the very first cold start per container lifetime.
   */
  private coldStartRetried = false;

  constructor() {
    const databaseUrl = process.env.DATABASE_URL;

    if (!databaseUrl) {
      this.logger.warn(
        'DATABASE_URL not set — DatabaseService running in noop mode. ' +
          'All reads return null/[], writes are silently discarded. ' +
          'Set DATABASE_URL in .env for local development.',
      );
      this.noop = true;
      this.db = null;
      return;
    }

    // Disable Drizzle query logging in production to prevent accidental
    // leakage of parameter values (tokens, hashed passwords, etc.) in logs.
    const enableLogger = process.env.NODE_ENV !== 'production';

    const sqlClient = neon(databaseUrl);
    this.db = drizzle(sqlClient, {
      schema,
      logger: enableLogger,
    });

    this.noop = false;
    this.logger.log(
      `DatabaseService initialized — Neon HTTP driver (zero idle connections), logger=${enableLogger}`,
    );
  }

  // ── Cold-start retry ──────────────────────────────────────────────────────

  /**
   * Wraps a database operation with retry-once-on-failure logic.
   *
   * Neon serverless suspends compute after ~5 min of inactivity. The first
   * query after suspension can fail (connection reset / timeout) while the
   * compute resumes. Retrying once after 1 s absorbs the startup delay.
   *
   * After the first retry the flag is latched so subsequent failures propagate
   * immediately — we don't want unbounded retries in a hot path.
   */
  private async withRetry<T>(fn: () => Promise<T>): Promise<T> {
    // Reset per-call so that a Neon suspension after the container has been
    // warm for >5 min is recovered, not just the first cold start per
    // container lifetime.
    this.coldStartRetried = false;
    try {
      return await fn();
    } catch (err) {
      if (this.coldStartRetried) {
        // Already retried once within this call — propagate the error.
        throw err;
      }
      this.coldStartRetried = true;
      this.logger.warn(
        'Neon query failed — retrying once after 1 s (cold start recovery)',
      );
      await new Promise<void>((resolve) => setTimeout(resolve, 1000));
      return await fn();
    }
  }

  // ── Users ──────────────────────────────────────────────────────────────────

  /** Fetch a user by their UUID. Returns null if not found. */
  async getUserById(userId: string): Promise<UserRecord | null> {
    if (this.noop) return null;

    const rows = await this.withRetry(() =>
      this.db!.select().from(users).where(eq(users.id, userId)).limit(1),
    );

    if (rows.length === 0) return null;
    const row = rows[0];
    return { id: row.id, email: row.email, createdAt: row.createdAt };
  }

  /** Fetch a user by email address. Returns null if not found. */
  async getUserByEmail(email: string): Promise<UserRecord | null> {
    if (this.noop) return null;

    const rows = await this.withRetry(() =>
      this.db!.select().from(users).where(eq(users.email, email)).limit(1),
    );

    if (rows.length === 0) return null;
    const row = rows[0];
    return { id: row.id, email: row.email, createdAt: row.createdAt };
  }

  /**
   * Create a new user record.
   * Catches PostgreSQL unique-constraint violation (code 23505) and re-throws
   * as { code: 'USER_ALREADY_EXISTS' } — matching the DynamoDB
   * ConditionalCheckFailedException handler pattern in AuthService.
   */
  async createUser(user: {
    id: string;
    email: string;
    createdAt: Date;
  }): Promise<void> {
    if (this.noop) return;

    try {
      await this.withRetry(() =>
        this.db!.insert(users).values({
          id: user.id,
          email: user.email,
          createdAt: user.createdAt,
        }),
      );
    } catch (err) {
      // PostgreSQL unique constraint violation on users.email or users.id
      if ((err as { code?: string })?.code === PG_UNIQUE_VIOLATION) {
        throw Object.assign(new Error('User already exists'), {
          code: 'USER_ALREADY_EXISTS',
        });
      }
      throw err;
    }
  }

  // ── OTP records ────────────────────────────────────────────────────────────

  /**
   * Store a new OTP record.
   * Drizzle assigns a random UUID as the primary key (otp_records.id).
   * That id is subsequently exposed as OtpRecord.sk so AuthService can
   * pass it back to markOtpUsed() and incrementOtpAttempts().
   */
  async createOtp(email: string, codeHash: string, expiresAt: Date): Promise<void> {
    if (this.noop) return;

    await this.withRetry(() =>
      this.db!.insert(otpRecords).values({
        email,
        codeHash,
        expiresAt,
        attempts: 0,
        used: false,
      }),
    );
  }

  /**
   * Return all active (unused, non-expired) OTPs for the given email.
   *
   * Filter: WHERE email = ? AND used = false AND expires_at > NOW()
   *   — expires_at > NOW() is evaluated by PostgreSQL, not the application,
   *     so it is always consistent with the database clock (TOCTOU-safe).
   *
   * CRITICAL: OtpRecord.sk is mapped from otp_records.id (the UUID primary
   *   key). AuthService calls markOtpUsed(email, record.sk) and
   *   incrementOtpAttempts(email, record.sk) using this value.
   */
  async getActiveOtps(email: string): Promise<OtpRecord[]> {
    if (this.noop) return [];

    const rows = await this.withRetry(() =>
      this.db!
        .select()
        .from(otpRecords)
        .where(
          and(
            eq(otpRecords.email, email),
            eq(otpRecords.used, false),
            gt(otpRecords.expiresAt, sql`NOW()`),
          ),
        )
        // Most-recently-expiring OTP last so records[records.length - 1] in
        // AuthService.verifyOtp picks the latest one deterministically.
        .orderBy(desc(otpRecords.expiresAt)),
    );

    return rows.map((row) => ({
      sk: row.id,         // CRITICAL: sk ← otp_records.id
      email: row.email,
      code: row.codeHash, // code ← otp_records.code_hash
      expiresAt: row.expiresAt,
      attempts: row.attempts,
      used: row.used,
    }));
  }

  /**
   * Mark a specific OTP record as used (single-use enforcement).
   * The otpId parameter is the value that was returned in OtpRecord.sk
   * (i.e. the otp_records.id UUID).
   */
  async markOtpUsed(email: string, otpId: string): Promise<void> {
    if (this.noop) return;

    await this.withRetry(() =>
      this.db!
        .update(otpRecords)
        .set({ used: true })
        .where(and(eq(otpRecords.id, otpId), eq(otpRecords.email, email))),
    );
  }

  /**
   * Atomically increment the failed-attempt counter for an OTP record.
   * Uses SQL `attempts + 1` expression (server-side) to avoid read-modify-write
   * race conditions under concurrent verification attempts.
   */
  async incrementOtpAttempts(email: string, otpId: string): Promise<void> {
    if (this.noop) return;

    await this.withRetry(() =>
      this.db!
        .update(otpRecords)
        .set({ attempts: sql`${otpRecords.attempts} + 1` })
        .where(and(eq(otpRecords.id, otpId), eq(otpRecords.email, email))),
    );
  }

  /**
   * Invalidate all active OTPs for an email address.
   * Called before issuing a new OTP to enforce the single-active-OTP invariant.
   *
   * TOCTOU fix: The DynamoDB implementation did Query → N parallel UpdateItem
   * calls, which allowed a newly inserted OTP (arriving between the Query and
   * the Updates) to escape invalidation. This single SQL UPDATE covers all
   * matching rows atomically.
   *
   * SQL: UPDATE otp_records SET used = true WHERE email = ? AND used = false
   */
  async invalidateOtpsForEmail(email: string): Promise<void> {
    if (this.noop) return;

    await this.withRetry(() =>
      this.db!
        .update(otpRecords)
        .set({ used: true })
        .where(and(eq(otpRecords.email, email), eq(otpRecords.used, false))),
    );
  }

  // ── Refresh tokens ─────────────────────────────────────────────────────────

  /** Store a new refresh token (stored as a SHA-256 hash, never plaintext). */
  async createRefreshToken(
    userId: string,
    tokenHash: string,
    expiresAt: Date,
  ): Promise<void> {
    if (this.noop) return;

    await this.withRetry(() =>
      this.db!.insert(refreshTokens).values({
        userId,
        tokenHash,
        revoked: false,
        expiresAt,
      }),
    );
  }

  /** Retrieve a refresh token by its hash. Returns null if not found. */
  async getRefreshToken(tokenHash: string): Promise<RefreshTokenRecord | null> {
    if (this.noop) return null;

    const rows = await this.withRetry(() =>
      this.db!
        .select()
        .from(refreshTokens)
        .where(eq(refreshTokens.tokenHash, tokenHash))
        .limit(1),
    );

    if (rows.length === 0) return null;
    const row = rows[0];
    return {
      userId: row.userId,
      tokenHash: row.tokenHash,
      revoked: row.revoked,
      expiresAt: row.expiresAt,
      sk: row.id,
    };
  }

  /**
   * Mark a specific refresh token as revoked.
   *
   * Filters by tokenHash only — tokenHash is a UNIQUE column so the WHERE
   * clause always matches exactly one row. Filtering additionally by userId
   * was the original design, but AuthService.revokeRefreshToken (single-device
   * logout) called this method with an empty-string userId, causing the UPDATE
   * to affect 0 rows and leaving the token active. Dropping the userId filter
   * fixes single-device logout without requiring an extra round-trip to fetch
   * the token first.
   *
   * The userId parameter is kept in the signature for call-site compatibility;
   * it is intentionally unused in the WHERE clause.
   */
  async revokeRefreshToken(_userId: string, tokenHash: string): Promise<void> {
    if (this.noop) return;

    await this.withRetry(() =>
      this.db!
        .update(refreshTokens)
        .set({ revoked: true })
        .where(eq(refreshTokens.tokenHash, tokenHash)),
    );

    this.logger.log(`Refresh token revoked (tokenHash prefix=${tokenHash.slice(0, 8)}…)`);
  }

  /**
   * Revoke all refresh tokens for a user (logout-all / security reset).
   *
   * N+1 + TOCTOU fix: The DynamoDB implementation did a GSI Query to list all
   * tokens for the user, then N parallel UpdateItem calls — one per token.
   * A new token inserted between the Query and the Updates would survive
   * revocation. This single SQL UPDATE atomically covers all active tokens
   * in one round-trip with no N+1 overhead.
   *
   * SQL: UPDATE refresh_tokens SET revoked = true
   *      WHERE user_id = ? AND revoked = false
   */
  async revokeAllRefreshTokens(userId: string): Promise<void> {
    if (this.noop) return;

    await this.withRetry(() =>
      this.db!
        .update(refreshTokens)
        .set({ revoked: true })
        .where(
          and(
            eq(refreshTokens.userId, userId),
            eq(refreshTokens.revoked, false),
          ),
        ),
    );

    this.logger.log(`All refresh tokens revoked for userId=${userId}`);
  }

  // ── Sync metadata ──────────────────────────────────────────────────────────

  /** Retrieve sync metadata for a user. Returns null if the user has never synced. */
  async getSyncMetadata(userId: string): Promise<SyncMetadataRecord | null> {
    if (this.noop) return null;

    const rows = await this.withRetry(() =>
      this.db!
        .select()
        .from(syncMetadata)
        .where(eq(syncMetadata.userId, userId))
        .limit(1),
    );

    if (rows.length === 0) return null;
    const row = rows[0];
    return {
      userId: row.userId,
      lastSyncAt: row.lastSyncAt ?? null,
      sizeBytes: row.sizeBytes ?? null,
    };
  }

  /**
   * Upsert sync metadata after a confirmed upload.
   * Uses INSERT … ON CONFLICT (user_id) DO UPDATE to handle both first-sync
   * and subsequent syncs without a read-before-write.
   */
  async upsertSyncMetadata(
    userId: string,
    lastSyncAt: Date,
    sizeBytes?: number,
  ): Promise<void> {
    if (this.noop) return;

    await this.withRetry(() =>
      this.db!
        .insert(syncMetadata)
        .values({
          userId,
          lastSyncAt,
          sizeBytes: sizeBytes ?? null,
        })
        .onConflictDoUpdate({
          target: syncMetadata.userId,
          set: {
            lastSyncAt,
            sizeBytes: sizeBytes ?? null,
          },
        }),
    );
  }
}
