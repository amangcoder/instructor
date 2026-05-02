/**
 * DatabaseService — Neon PostgreSQL-backed replacement for DynamoDBService.
 *
 * Drop-in replacement: all public methods have identical signatures to
 * DynamoDBService so callers (AuthService) need no changes.
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

import { ConflictException, Injectable, Logger, NotFoundException, Optional, Inject } from '@nestjs/common';
import { neon } from '@neondatabase/serverless';
import { drizzle as drizzleNeon } from 'drizzle-orm/neon-http';
import { drizzle as drizzlePg } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import { and, asc, desc, eq, gt, ilike, isNull, or, sql } from 'drizzle-orm';
import { v4 as uuidv4 } from 'uuid';
import * as schema from './schema';
import { categories, deletionRequests, libraryPlans, otpRecords, planTriggers, plans, refreshTokens, series, seriesSubscriptions, sessionCompletions, ttsJobs, users } from './schema';
import type { NeonHttpDatabase } from 'drizzle-orm/neon-http';
import type { AppConfig } from '../config/app-config.interface';

/**
 * Drizzle's query-builder surface (.select / .insert / .update / .delete /
 * .transaction) is identical across the neon-http and node-postgres adapters,
 * so callers see the same shape regardless of which driver is wired up at
 * runtime. We expose the Neon type to keep all existing call sites and
 * downstream type annotations unchanged.
 */
export type AppDb = NeonHttpDatabase<typeof schema>;

/**
 * Returns true if the URL points at a Neon HTTP endpoint.
 * Neon hostnames contain ".neon.tech"; local/standard Postgres URLs do not.
 */
function isNeonUrl(url: string): boolean {
  return /\.neon\.tech([:/?]|$)/i.test(url);
}

// ── Typed result shapes returned to callers ────────────────────────────────

export interface UserRecord {
  id: string;
  email: string;
  name: string | null;
  username: string | null;
  photoUrl: string | null;
  role: string;
  createdAt: Date;
}

/**
 * OtpRecord represents a one-time password record.
 * The id field maps from the PostgreSQL otp_records.id (UUID primary key).
 * AuthService uses this id as the row identifier for operations like markOtpUsed and incrementOtpAttempts.
 */
export interface OtpRecord {
  /** Mapped from otp_records.id — the UUID primary key */
  id: string;
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
  /** Mapped from refresh_tokens.id — the UUID primary key */
  id: string;
}

export interface PlanRecord {
  planId: string;
  userId: string;
  name: string;
  planJson: string;
  isActive: boolean;
  ttsStatus: string;
  ttsTotal: number;
  ttsCompleted: number;
  voiceQuality: string;
  sourceLibraryPlanId: string | null;
  seriesId: string | null;
  shareToken: string | null;
  shareTokenCreatedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface PlanSummaryRecord {
  planId: string;
  name: string;
  planJson: string;
  isActive: boolean;
  ttsStatus: string;
  ttsTotal: number;
  ttsCompleted: number;
  voiceQuality: string;
  shareToken: string | null;
  shareTokenCreatedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface SavePlanResult {
  planId: string;
  updatedAt: Date;
}

export interface LibraryPlanSummaryRecord {
  id: string;
  name: string;
  description: string | null;
  category: string;
  tags: string;
  defaultVoice: string;
  locale: string;
  stepCount: number;
  totalDurationSeconds: number;
  sortOrder: number;
}

export interface LibraryPlanRecord {
  id: string;
  name: string;
  description: string | null;
  category: string;
  tags: string;
  defaultVoice: string;
  planJson: string;
  locale: string;
  isPublished: boolean;
  sortOrder: number;
}

export interface CategoryRecord {
  id: string;
  slug: string;
  name: string;
  icon: string | null;
  color: string | null;
  sortOrder: number;
  isPublished: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface SeriesRecord {
  id: string;
  name: string;
  description: string | null;
  category: string;
  /** FK to categories.id — null until backfill assigns existing series (migration 0015). */
  categoryId: string | null;
  tags: string;
  defaultVoice: string;
  locale: string;
  isPublished: boolean;
  sortOrder: number;
  totalSessions: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface SeriesSubscriptionRecord {
  id: string;
  userId: string;
  seriesId: string;
  status: 'active' | 'paused' | 'completed' | 'cancelled';
  currentSessionIndex: number;
  completedSessions: number;
  subscribedAt: Date;
  lastSessionCompletedAt: Date | null;
  unsubscribedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface TtsJobRecord {
  id: string;
  planId: string;
  cacheKey: string;
  text: string;
  voiceId: string;
  locale: string;
  provider: string;
  speechRate: string;
  s3Key: string | null;
  status: string;
  error: string | null;
  attempts: number;
  createdAt: Date;
  completedAt: Date | null;
}

export interface TtsPregenStatusRecord {
  status: string;
  total: number;
  completed: number;
  failed: number;
  ready: boolean;
  /** Timestamp of the last write to this plan row — used for stale-job detection. */
  updatedAt: Date;
}

// ── PostgreSQL error codes ─────────────────────────────────────────────────

/** Unique constraint violation — e.g. duplicate email on INSERT INTO users */
const PG_UNIQUE_VIOLATION = '23505';

// ── Service ────────────────────────────────────────────────────────────────

@Injectable()
export class DatabaseService {
  private readonly logger = new Logger(DatabaseService.name);
  private readonly db: NeonHttpDatabase<typeof schema> | null;
  private readonly usingNeon: boolean;

  /**
   * True when DATABASE_URL is absent.
   * All methods return mock/null results; writes are no-ops.
   */
  readonly noop: boolean;


  constructor(
    @Optional() @Inject('APP_CONFIG') config?: AppConfig,
  ) {
    const databaseUrl = config?.databaseUrl || process.env.DATABASE_URL;

    if (!databaseUrl) {
      this.logger.warn(
        'DATABASE_URL not set — DatabaseService running in noop mode. ' +
          'All reads return null/[], writes are silently discarded. ' +
          'Set DATABASE_URL in .env for local development.',
      );
      this.noop = true;
      this.db = null;
      this.usingNeon = false;
      return;
    }

    // Disable Drizzle query logging in production to prevent accidental
    // leakage of parameter values (tokens, hashed passwords, etc.) in logs.
    const nodeEnv = config?.nodeEnv ?? process.env.NODE_ENV;
    const enableLogger = nodeEnv !== 'production';

    this.usingNeon = isNeonUrl(databaseUrl);
    if (this.usingNeon) {
      const sqlClient = neon(databaseUrl);
      this.db = drizzleNeon(sqlClient, { schema, logger: enableLogger });
    } else {
      // node-postgres's drizzle instance has the same query-builder surface
      // as the neon-http one; the cast lets callers keep their existing types.
      const pool = new Pool({ connectionString: databaseUrl });
      this.db = drizzlePg(pool, { schema, logger: enableLogger }) as unknown as NeonHttpDatabase<typeof schema>;
    }

    this.noop = false;
    this.logger.log(
      `DatabaseService initialized — ${this.usingNeon ? 'Neon HTTP' : 'node-postgres'} driver, logger=${enableLogger}`,
    );
  }

  // ── Direct DB access ──────────────────────────────────────────────────────

  /**
   * Returns the underlying Drizzle database instance for direct query access.
   * Intended for use by AdminAnalyticsService which needs complex aggregation
   * queries that don't fit the method-per-operation pattern.
   *
   * @throws Error if the service is running in noop mode (DATABASE_URL not set).
   */
  getDb(): NeonHttpDatabase<typeof schema> {
    if (this.noop) throw new Error('Database not configured');
    return this.db!;
  }

  // ── Cold-start retry ──────────────────────────────────────────────────────

  /**
   * Wraps a database operation with retry-once-on-failure logic.
   *
   * Neon serverless suspends compute after ~5 min of inactivity. The first
   * query after suspension can fail (connection reset / timeout) while the
   * compute resumes. Retrying once after 1 s absorbs the startup delay.
   */
  async withRetry<T>(fn: () => Promise<T>): Promise<T> {
    try {
      return await fn();
    } catch (err) {
      // Postgres surfaces a 5-char SQLSTATE on every server-side error
      // (constraint violations, FK errors, etc.). Those are deterministic —
      // a retry will produce the same failure, so fail fast. Only retry
      // when the error has no SQLSTATE (network/connection-level failure).
      const pgCode = (err as { code?: string }).code;
      if (typeof pgCode === 'string' && /^[0-9A-Z]{5}$/.test(pgCode)) {
        throw err;
      }
      const cause = (err as { cause?: unknown }).cause;
      this.logger.warn(
        `DB query failed — retrying once after 1 s (cold start recovery). ` +
        `error=${(err as Error)?.message ?? err} ` +
        `cause=${cause instanceof Error ? cause.message : JSON.stringify(cause)}`,
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
    return { id: row.id, email: row.email, name: row.name ?? null, username: row.username ?? null, photoUrl: row.photoUrl ?? null, role: row.role, createdAt: row.createdAt };
  }

  /** Fetch a user by email address. Returns null if not found. */
  async getUserByEmail(email: string): Promise<UserRecord | null> {
    if (this.noop) return null;

    const rows = await this.withRetry(() =>
      this.db!.select().from(users).where(eq(users.email, email)).limit(1),
    );

    if (rows.length === 0) return null;
    const row = rows[0];
    return { id: row.id, email: row.email, name: row.name ?? null, username: row.username ?? null, photoUrl: row.photoUrl ?? null, role: row.role, createdAt: row.createdAt };
  }

  /**
   * Create a new user record.
   * Catches PostgreSQL unique-constraint violation (code 23505) and re-throws
   * as { code: 'USER_ALREADY_EXISTS' }.
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
      if ((err as { code?: string })?.code === PG_UNIQUE_VIOLATION) {
        throw Object.assign(new Error('User already exists'), {
          code: 'USER_ALREADY_EXISTS',
        });
      }
      throw err;
    }
  }

  /**
   * Update mutable profile fields for an existing user.
   * Throws { code: 'USERNAME_TAKEN' } on unique constraint violation.
   */
  async updateUserProfile(
    userId: string,
    data: { name?: string | null; username?: string | null; photoUrl?: string | null },
  ): Promise<void> {
    if (this.noop) return;

    const updates: Partial<typeof users.$inferInsert> = {};
    if ('name' in data) updates.name = data.name ?? null;
    if ('username' in data) updates.username = data.username ?? null;
    if ('photoUrl' in data) updates.photoUrl = data.photoUrl ?? null;

    if (Object.keys(updates).length === 0) return;

    try {
      await this.withRetry(() =>
        this.db!.update(users).set(updates).where(eq(users.id, userId)),
      );
    } catch (err) {
      if ((err as { code?: string })?.code === PG_UNIQUE_VIOLATION) {
        throw Object.assign(new Error('Username already taken'), {
          code: 'USERNAME_TAKEN',
        });
      }
      throw err;
    }
  }

  // ── OTP records ────────────────────────────────────────────────────────────

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
   * Ordered ascending by expiresAt so records[records.length - 1] is the
   * most-recently-created (longest TTL remaining) OTP.
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
        // Ascending: most-recently-expiring OTP last, so records[records.length - 1]
        // in AuthService.verifyOtp picks the OTP with the longest remaining TTL.
        .orderBy(asc(otpRecords.expiresAt)),
    );

    return rows.map((row) => ({
      id: row.id,
      email: row.email,
      code: row.codeHash,
      expiresAt: row.expiresAt,
      attempts: row.attempts,
      used: row.used,
    }));
  }

  async markOtpUsed(email: string, otpId: string): Promise<void> {
    if (this.noop) return;

    await this.withRetry(() =>
      this.db!
        .update(otpRecords)
        .set({ used: true })
        .where(and(eq(otpRecords.id, otpId), eq(otpRecords.email, email))),
    );
  }

  async incrementOtpAttempts(email: string, otpId: string): Promise<void> {
    if (this.noop) return;

    await this.withRetry(() =>
      this.db!
        .update(otpRecords)
        .set({ attempts: sql`${otpRecords.attempts} + 1` })
        .where(and(eq(otpRecords.id, otpId), eq(otpRecords.email, email))),
    );
  }

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
      id: row.id,
    };
  }

  /**
   * Mark a specific refresh token as revoked.
   * Filters by tokenHash only (UNIQUE column). The userId parameter is
   * kept for call-site compatibility but intentionally unused in the WHERE clause.
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

  // ── Plans ──────────────────────────────────────────────────────────────────

  async savePlan(
    userId: string,
    name: string,
    planJson: string,
    planId?: string,
  ): Promise<SavePlanResult> {
    if (this.noop) {
      return { planId: planId ?? uuidv4(), updatedAt: new Date() };
    }

    const now = new Date();

    if (planId) {
      const updated = await this.withRetry(() =>
        this.db!
          .update(plans)
          .set({ name, planJson, updatedAt: now })
          .where(and(eq(plans.id, planId), eq(plans.userId, userId)))
          .returning({ id: plans.id, updatedAt: plans.updatedAt }),
      );

      if (updated.length > 0) {
        const row = updated[0];
        this.logger.log(`Plan updated: planId=${row.id}, userId=${userId}`);
        return { planId: row.id, updatedAt: row.updatedAt };
      }

      // No row owned by this user — either the plan doesn't exist anywhere
      // (offline-first client uploading a locally-created plan) or the id
      // collides with another user's plan. INSERT with the supplied id; on
      // PK conflict, surface a 409 to the client.
      const inserted = await this.withRetry(() =>
        this.db!
          .insert(plans)
          .values({ id: planId, userId, name, planJson, createdAt: now, updatedAt: now })
          .onConflictDoNothing({ target: plans.id })
          .returning({ id: plans.id, updatedAt: plans.updatedAt }),
      );

      if (inserted.length === 0) {
        throw new ConflictException(
          `Plan ${planId} already exists and is owned by another user`,
        );
      }

      const row = inserted[0];
      this.logger.log(`Plan inserted with client id: planId=${row.id}, userId=${userId}`);
      return { planId: row.id, updatedAt: row.updatedAt };
    }

    const rows = await this.withRetry(() =>
      this.db!
        .insert(plans)
        .values({ userId, name, planJson, createdAt: now, updatedAt: now })
        .returning({ id: plans.id, updatedAt: plans.updatedAt }),
    );

    const row = rows[0];
    this.logger.log(`Plan created: planId=${row.id}, userId=${userId}`);
    return { planId: row.id, updatedAt: row.updatedAt };
  }

  /** Fetch a single plan by ID for the authenticated user (IDOR-safe). */
  async getPlanById(planId: string, userId: string): Promise<PlanRecord | null> {
    if (this.noop) return null;

    const rows = await this.withRetry(() =>
      this.db!
        .select()
        .from(plans)
        .where(and(eq(plans.id, planId), eq(plans.userId, userId)))
        .limit(1),
    );

    if (rows.length === 0) return null;
    return this.mapPlanRecord(rows[0]);
  }

  /**
   * Delete a user account and all associated data.
   * Order: refresh_tokens → plans (cascades tts_jobs) → otp_records → users.
   */
  async deleteUser(userId: string, email: string): Promise<void> {
    if (this.noop) return;

    await this.withRetry(() =>
      this.db!.delete(refreshTokens).where(eq(refreshTokens.userId, userId)),
    );
    await this.withRetry(() =>
      this.db!.delete(plans).where(eq(plans.userId, userId)),
    );
    await this.withRetry(() =>
      this.db!.delete(otpRecords).where(eq(otpRecords.email, email)),
    );
    await this.withRetry(() =>
      this.db!.delete(users).where(eq(users.id, userId)),
    );

    this.logger.log(`User deleted: userId=${userId}, email=${email}`);
  }

  /** Delete a plan for the authenticated user. Cascade-deletes tts_jobs. */
  async deletePlan(planId: string, userId: string): Promise<void> {
    if (this.noop) return;

    const rows = await this.withRetry(() =>
      this.db!
        .delete(plans)
        .where(and(eq(plans.id, planId), eq(plans.userId, userId)))
        .returning({ id: plans.id }),
    );

    if (rows.length === 0) {
      throw new NotFoundException(
        `Plan ${planId} not found or does not belong to the authenticated user`,
      );
    }

    this.logger.log(`Plan deleted: planId=${planId}, userId=${userId}`);
  }

  /** Copy a library plan into the user's plans. */
  async copyLibraryPlanToUser(
    libraryPlanId: string,
    userId: string,
    voiceQuality: string,
  ): Promise<{ planId: string }> {
    if (this.noop) return { planId: uuidv4() };

    const libraryRows = await this.withRetry(() =>
      this.db!
        .select()
        .from(libraryPlans)
        .where(eq(libraryPlans.id, libraryPlanId))
        .limit(1),
    );

    if (libraryRows.length === 0) {
      throw new NotFoundException(`Library plan ${libraryPlanId} not found`);
    }

    const lp = libraryRows[0];
    const now = new Date();

    const rows = await this.withRetry(() =>
      this.db!
        .insert(plans)
        .values({
          userId,
          name: lp.name,
          planJson: lp.planJson,
          sourceLibraryPlanId: libraryPlanId,
          isActive: false,
          ttsStatus: 'none',
          ttsTotal: 0,
          ttsCompleted: 0,
          voiceQuality,
          createdAt: now,
          updatedAt: now,
        })
        .returning({ id: plans.id }),
    );

    const planId = rows[0].id;
    this.logger.log(`Library plan ${libraryPlanId} copied → planId=${planId}, userId=${userId}`);
    return { planId };
  }

  /**
   * Activate a plan: deactivates all others for the user, sets this one active,
   * and sets ttsStatus='pending' for studio voice quality.
   */
  async activatePlan(
    planId: string,
    userId: string,
    voiceQuality: string,
  ): Promise<void> {
    if (this.noop) return;

    const ownershipCheck = await this.withRetry(() =>
      this.db!
        .select({ id: plans.id })
        .from(plans)
        .where(and(eq(plans.id, planId), eq(plans.userId, userId)))
        .limit(1),
    );

    if (ownershipCheck.length === 0) {
      throw new NotFoundException(
        `Plan ${planId} not found or does not belong to the authenticated user`,
      );
    }

    const now = new Date();

    // Deactivate all plans for this user.
    await this.withRetry(() =>
      this.db!
        .update(plans)
        .set({ isActive: false, updatedAt: now })
        .where(eq(plans.userId, userId)),
    );

    // Activate the target plan.
    const ttsStatus = voiceQuality === 'studio' ? 'pending' : 'none';
    await this.withRetry(() =>
      this.db!
        .update(plans)
        .set({ isActive: true, voiceQuality, ttsStatus, updatedAt: now })
        .where(eq(plans.id, planId)),
    );

    this.logger.log(`Plan activated: planId=${planId}, voiceQuality=${voiceQuality}`);
  }

  /** Update TTS pre-generation status fields on a plan. */
  async setTtsStatus(
    planId: string,
    status: string,
    total?: number,
    completed?: number,
  ): Promise<void> {
    if (this.noop) return;

    const updates: Partial<typeof plans.$inferInsert> = {
      ttsStatus: status,
      updatedAt: new Date(),
    };
    if (total !== undefined) updates.ttsTotal = total;
    if (completed !== undefined) updates.ttsCompleted = completed;

    await this.withRetry(() =>
      this.db!.update(plans).set(updates).where(eq(plans.id, planId)),
    );
  }

  /** Atomically increment ttsCompleted counter. */
  async incrementTtsCompleted(planId: string): Promise<void> {
    if (this.noop) return;

    await this.withRetry(() =>
      this.db!
        .update(plans)
        .set({
          ttsCompleted: sql`${plans.ttsCompleted} + 1`,
          updatedAt: new Date(),
        })
        .where(eq(plans.id, planId)),
    );
  }

  /**
   * List all plan summaries for the authenticated user (REQ-030).
   * Returns full fields including ttsStatus, isActive, voiceQuality.
   */
  async listPlans(userId: string): Promise<PlanSummaryRecord[]> {
    if (this.noop) return [];

    const rows = await this.withRetry(() =>
      this.db!
        .select({
          id: plans.id,
          name: plans.name,
          planJson: plans.planJson,
          isActive: plans.isActive,
          ttsStatus: plans.ttsStatus,
          ttsTotal: plans.ttsTotal,
          ttsCompleted: plans.ttsCompleted,
          voiceQuality: plans.voiceQuality,
          shareToken: plans.shareToken,
          shareTokenCreatedAt: plans.shareTokenCreatedAt,
          createdAt: plans.createdAt,
          updatedAt: plans.updatedAt,
        })
        .from(plans)
        .where(eq(plans.userId, userId))
        .orderBy(desc(plans.updatedAt)),
    );

    return rows.map((row) => ({
      planId: row.id,
      name: row.name,
      planJson: row.planJson,
      isActive: row.isActive,
      ttsStatus: row.ttsStatus,
      ttsTotal: row.ttsTotal,
      ttsCompleted: row.ttsCompleted,
      voiceQuality: row.voiceQuality,
      shareToken: row.shareToken ?? null,
      shareTokenCreatedAt: row.shareTokenCreatedAt ?? null,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    }));
  }

  // ── Library plans ──────────────────────────────────────────────────────────

  async listLibraryPlans(
    page: number,
    category?: string,
    search?: string,
  ): Promise<{ plans: LibraryPlanSummaryRecord[]; total: number }> {
    if (this.noop) return { plans: [], total: 0 };

    const PAGE_SIZE = 20;
    const offset = (page - 1) * PAGE_SIZE;

    const conditions = [eq(libraryPlans.isPublished, true)];
    if (category) conditions.push(eq(libraryPlans.category, category));
    if (search) {
      conditions.push(
        or(
          ilike(libraryPlans.name, `%${search}%`),
          ilike(libraryPlans.description, `%${search}%`),
        )!,
      );
    }

    const whereClause = and(...conditions);

    const [rows, countRows] = await Promise.all([
      this.withRetry(() =>
        this.db!
          .select({
            id: libraryPlans.id,
            name: libraryPlans.name,
            description: libraryPlans.description,
            category: libraryPlans.category,
            tags: libraryPlans.tags,
            defaultVoice: libraryPlans.defaultVoice,
            locale: libraryPlans.locale,
            planJson: libraryPlans.planJson,
            sortOrder: libraryPlans.sortOrder,
          })
          .from(libraryPlans)
          .where(whereClause)
          .orderBy(libraryPlans.sortOrder)
          .limit(PAGE_SIZE)
          .offset(offset),
      ),
      this.withRetry(() =>
        this.db!
          .select({ count: sql<number>`count(*)::int` })
          .from(libraryPlans)
          .where(whereClause),
      ),
    ]);

    return {
      plans: rows.map((row) => ({
        id: row.id,
        name: row.name,
        description: row.description,
        category: row.category,
        tags: row.tags,
        defaultVoice: row.defaultVoice,
        locale: row.locale,
        stepCount: this.countSteps(row.planJson),
        totalDurationSeconds: this.calcTotalDurationSeconds(row.planJson),
        sortOrder: row.sortOrder,
      })),
      total: countRows[0]?.count ?? 0,
    };
  }

  async getLibraryPlanById(id: string): Promise<LibraryPlanRecord | null> {
    if (this.noop) return null;

    const rows = await this.withRetry(() =>
      this.db!
        .select()
        .from(libraryPlans)
        .where(eq(libraryPlans.id, id))
        .limit(1),
    );

    if (rows.length === 0) return null;
    const row = rows[0];
    return {
      id: row.id,
      name: row.name,
      description: row.description,
      category: row.category,
      tags: row.tags,
      defaultVoice: row.defaultVoice,
      planJson: row.planJson,
      locale: row.locale,
      isPublished: row.isPublished,
      sortOrder: row.sortOrder,
    };
  }

  async createLibraryPlan(data: {
    name: string;
    description?: string;
    category: string;
    tags: string;
    defaultVoice: string;
    planJson: string;
    locale: string;
    isPublished: boolean;
    sortOrder: number;
  }): Promise<{ id: string }> {
    if (this.noop) return { id: uuidv4() };

    const now = new Date();
    const rows = await this.withRetry(() =>
      this.db!
        .insert(libraryPlans)
        .values({ ...data, createdAt: now, updatedAt: now })
        .returning({ id: libraryPlans.id }),
    );

    this.logger.log(`Library plan created: id=${rows[0].id}, name="${data.name}"`);
    return { id: rows[0].id };
  }

  async listAllLibraryPlans(): Promise<LibraryPlanRecord[]> {
    if (this.noop) return [];

    const rows = await this.withRetry(() =>
      this.db!
        .select()
        .from(libraryPlans)
        .orderBy(asc(libraryPlans.sortOrder), asc(libraryPlans.createdAt)),
    );

    return rows.map((row) => ({
      id: row.id,
      name: row.name,
      description: row.description,
      category: row.category,
      tags: row.tags,
      defaultVoice: row.defaultVoice,
      planJson: row.planJson,
      locale: row.locale,
      isPublished: row.isPublished,
      sortOrder: row.sortOrder,
    }));
  }

  async updateLibraryPlan(
    id: string,
    data: Partial<{
      name: string;
      description: string;
      category: string;
      tags: string;
      defaultVoice: string;
      planJson: string;
      locale: string;
      isPublished: boolean;
      sortOrder: number;
    }>,
  ): Promise<LibraryPlanRecord | null> {
    if (this.noop) return null;

    const rows = await this.withRetry(() =>
      this.db!
        .update(libraryPlans)
        .set({ ...data, updatedAt: new Date() })
        .where(eq(libraryPlans.id, id))
        .returning(),
    );

    if (rows.length === 0) return null;
    const row = rows[0];
    this.logger.log(`Library plan updated: id=${id}`);
    return {
      id: row.id,
      name: row.name,
      description: row.description,
      category: row.category,
      tags: row.tags,
      defaultVoice: row.defaultVoice,
      planJson: row.planJson,
      locale: row.locale,
      isPublished: row.isPublished,
      sortOrder: row.sortOrder,
    };
  }

  async deleteLibraryPlan(id: string): Promise<boolean> {
    if (this.noop) return false;

    const rows = await this.withRetry(() =>
      this.db!
        .delete(libraryPlans)
        .where(eq(libraryPlans.id, id))
        .returning({ id: libraryPlans.id }),
    );

    const deleted = rows.length > 0;
    if (deleted) this.logger.log(`Library plan deleted: id=${id}`);
    return deleted;
  }

  // ── Categories ──────────────────────────────────────────────────────────────

  async listPublishedCategories(): Promise<CategoryRecord[]> {
    if (this.noop) return [];

    const rows = await this.withRetry(() =>
      this.db!
        .select()
        .from(categories)
        .where(and(eq(categories.isPublished, true), isNull(categories.deletedAt)))
        .orderBy(asc(categories.sortOrder), asc(categories.createdAt)),
    );

    return rows.map((row) => ({
      id: row.id,
      slug: row.slug,
      name: row.name,
      icon: row.icon,
      color: row.color,
      sortOrder: row.sortOrder,
      isPublished: row.isPublished,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    }));
  }

  async listAllCategories(page: number = 1, pageSize: number = 20): Promise<{ categories: CategoryRecord[]; total: number }> {
    if (this.noop) return { categories: [], total: 0 };

    const offset = (page - 1) * pageSize;

    // Soft-deleted rows (deleted_at IS NOT NULL) are excluded from both count
    // and paginated results so they vanish from the admin grid after delete.
    const countResult = await this.withRetry(() =>
      this.db!
        .select({ count: sql<number>`count(*)` })
        .from(categories)
        .where(isNull(categories.deletedAt)),
    );
    const total = countResult[0]?.count ?? 0;

    const rows = await this.withRetry(() =>
      this.db!
        .select()
        .from(categories)
        .where(isNull(categories.deletedAt))
        .orderBy(asc(categories.sortOrder), asc(categories.createdAt))
        .limit(pageSize)
        .offset(offset),
    );

    const categoryRecords = rows.map((row) => ({
      id: row.id,
      slug: row.slug,
      name: row.name,
      icon: row.icon,
      color: row.color,
      sortOrder: row.sortOrder,
      isPublished: row.isPublished,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    }));

    return { categories: categoryRecords, total };
  }

  async getCategoryById(id: string): Promise<CategoryRecord | null> {
    if (this.noop) return null;

    const rows = await this.withRetry(() =>
      this.db!
        .select()
        .from(categories)
        .where(and(eq(categories.id, id), isNull(categories.deletedAt)))
        .limit(1),
    );

    if (rows.length === 0) return null;

    const row = rows[0];
    return {
      id: row.id,
      slug: row.slug,
      name: row.name,
      icon: row.icon,
      color: row.color,
      sortOrder: row.sortOrder,
      isPublished: row.isPublished,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    };
  }

  async createCategory(data: {
    slug: string;
    name: string;
    icon?: string | null;
    color?: string | null;
    sortOrder?: number;
    isPublished?: boolean;
  }): Promise<{ id: string }> {
    if (this.noop) return { id: uuidv4() };

    const now = new Date();
    let rows;
    try {
      rows = await this.withRetry(() =>
        this.db!
          .insert(categories)
          .values({
            slug: data.slug,
            name: data.name,
            icon: data.icon ?? null,
            color: data.color ?? null,
            sortOrder: data.sortOrder ?? 0,
            isPublished: data.isPublished ?? false,
            createdAt: now,
            updatedAt: now,
          })
          .returning({ id: categories.id }),
      );
    } catch (err) {
      if ((err as { code?: string })?.code === PG_UNIQUE_VIOLATION) {
        throw new ConflictException(
          `Category slug "${data.slug}" already exists`,
        );
      }
      throw err;
    }

    this.logger.log(`Category created: id=${rows[0].id}, slug="${data.slug}"`);
    return { id: rows[0].id };
  }

  async updateCategory(
    id: string,
    data: Partial<{
      slug: string;
      name: string;
      icon: string | null;
      color: string | null;
      sortOrder: number;
      isPublished: boolean;
    }>,
  ): Promise<CategoryRecord | null> {
    if (this.noop) return null;

    const rows = await this.withRetry(() =>
      this.db!
        .update(categories)
        .set({ ...data, updatedAt: new Date() })
        .where(and(eq(categories.id, id), isNull(categories.deletedAt)))
        .returning(),
    );

    if (rows.length === 0) return null;

    const row = rows[0];
    this.logger.log(`Category updated: id=${id}`);
    return {
      id: row.id,
      slug: row.slug,
      name: row.name,
      icon: row.icon,
      color: row.color,
      sortOrder: row.sortOrder,
      isPublished: row.isPublished,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    };
  }

  async softDeleteCategory(id: string): Promise<boolean> {
    if (this.noop) return true;

    const now = new Date();
    // Stamp deleted_at AND clear is_published so the row is hidden from both
    // the public surface (which filters on is_published) and the admin grid
    // (which now filters on deleted_at). Re-deleting an already-deleted row
    // is a no-op and returns false (rows.length === 0).
    const rows = await this.withRetry(() =>
      this.db!
        .update(categories)
        .set({ deletedAt: now, isPublished: false, updatedAt: now })
        .where(and(eq(categories.id, id), isNull(categories.deletedAt)))
        .returning({ id: categories.id }),
    );

    const deleted = rows.length > 0;
    if (deleted) this.logger.log(`Category soft-deleted: id=${id}`);
    return deleted;
  }

  async reorderCategories(
    items: Array<{ id: string; sortOrder: number }>,
  ): Promise<void> {
    if (this.noop) return;
    if (items.length === 0) return;

    const now = new Date();

    // Batch update all categories in a single query
    await this.withRetry(() =>
      Promise.all(
        items.map((item) =>
          this.db!
            .update(categories)
            .set({ sortOrder: item.sortOrder, updatedAt: now })
            .where(eq(categories.id, item.id)),
        ),
      ),
    );

    this.logger.log(`Categories reordered: ${items.length} items`);
  }

  // ── Series ─────────────────────────────────────────────────────────────────

  async listPublishedSeries(categorySlug?: string): Promise<SeriesRecord[]> {
    if (this.noop) return [];

    const rows = await this.withRetry(() => {
      if (categorySlug) {
        return this.db!
          .select({ series })
          .from(series)
          .innerJoin(categories, eq(series.categoryId, categories.id))
          .where(
            and(
              eq(series.isPublished, true),
              eq(categories.slug, categorySlug),
              isNull(categories.deletedAt),
            ),
          )
          .orderBy(asc(series.sortOrder), asc(series.createdAt))
          .then((rs) => rs.map((r) => r.series));
      }
      return this.db!
        .select()
        .from(series)
        .where(eq(series.isPublished, true))
        .orderBy(asc(series.sortOrder), asc(series.createdAt));
    });
    return Promise.all(rows.map((row) => this.mapSeriesRow(row)));
  }

  async listAllSeries(): Promise<SeriesRecord[]> {
    if (this.noop) return [];

    const rows = await this.withRetry(() =>
      this.db!
        .select()
        .from(series)
        .orderBy(asc(series.sortOrder), asc(series.createdAt)),
    );
    return Promise.all(rows.map((row) => this.mapSeriesRow(row)));
  }

  async getSeriesById(id: string): Promise<SeriesRecord | null> {
    if (this.noop) return null;

    const rows = await this.withRetry(() =>
      this.db!.select().from(series).where(eq(series.id, id)).limit(1),
    );
    if (rows.length === 0) return null;
    return this.mapSeriesRow(rows[0]);
  }

  async createSeries(data: {
    name: string;
    description?: string | null;
    category: string;
    /** FK to categories.id — optional during rollout while categoryId is being backfilled. */
    categoryId?: string | null;
    tags: string;
    defaultVoice: string;
    locale: string;
    isPublished: boolean;
    sortOrder: number;
  }): Promise<{ id: string }> {
    if (this.noop) return { id: uuidv4() };

    const now = new Date();
    const rows = await this.withRetry(() =>
      this.db!
        .insert(series)
        .values({
          ...data,
          description: data.description ?? null,
          createdAt: now,
          updatedAt: now,
        })
        .returning({ id: series.id }),
    );
    this.logger.log(`Series created: id=${rows[0].id}, name="${data.name}"`);
    return { id: rows[0].id };
  }

  async updateSeries(
    id: string,
    data: Partial<{
      name: string;
      description: string | null;
      category: string;
      /** FK to categories.id — optional during rollout while categoryId is being backfilled. */
      categoryId: string | null;
      tags: string;
      defaultVoice: string;
      locale: string;
      isPublished: boolean;
      sortOrder: number;
    }>,
  ): Promise<SeriesRecord | null> {
    if (this.noop) return null;

    const rows = await this.withRetry(() =>
      this.db!
        .update(series)
        .set({ ...data, updatedAt: new Date() })
        .where(eq(series.id, id))
        .returning(),
    );
    if (rows.length === 0) return null;
    this.logger.log(`Series updated: id=${id}`);
    return this.mapSeriesRow(rows[0]);
  }

  async deleteSeries(id: string): Promise<boolean> {
    if (this.noop) return false;

    const rows = await this.withRetry(() =>
      this.db!.delete(series).where(eq(series.id, id)).returning({ id: series.id }),
    );
    const deleted = rows.length > 0;
    if (deleted) this.logger.log(`Series deleted: id=${id}`);
    return deleted;
  }

  /**
   * List all plans in a series, ordered by position (ascending) then createdAt
   * as a stable tiebreaker. The position field is updated by reorderSeriesPlans
   * when an admin drag-drops sessions; newly created sessions default to position=0.
   */
  async listPlansInSeries(seriesId: string): Promise<PlanRecord[]> {
    if (this.noop) return [];

    const rows = await this.withRetry(() =>
      this.db!
        .select()
        .from(plans)
        .where(eq(plans.seriesId, seriesId))
        .orderBy(asc(plans.position), asc(plans.createdAt)),
    );
    return rows.map((row) => this.mapPlanRecord(row));
  }

  /**
   * Bulk-update the position field for plan rows that belong to a series.
   *
   * Each item is applied only when plans.series_id matches seriesId, so a
   * rogue planId from a different series is silently ignored — preventing
   * cross-series position pollution.
   *
   * Runs all updates inside a single withRetry wrapper so a transient
   * connection error retries the whole batch.
   */
  async reorderSeriesPlans(
    seriesId: string,
    items: Array<{ planId: string; position: number }>,
  ): Promise<void> {
    if (this.noop) return;
    if (items.length === 0) return;

    const now = new Date();

    await this.withRetry(() =>
      Promise.all(
        items.map((item) =>
          this.db!
            .update(plans)
            .set({ position: item.position, updatedAt: now })
            .where(and(eq(plans.id, item.planId), eq(plans.seriesId, seriesId))),
        ),
      ),
    );

    this.logger.log(`Series plans reordered: seriesId=${seriesId} count=${items.length}`);
  }

  // ── Series subscriptions ───────────────────────────────────────────────────

  async getSubscription(
    userId: string,
    seriesId: string,
  ): Promise<SeriesSubscriptionRecord | null> {
    if (this.noop) return null;

    const rows = await this.withRetry(() =>
      this.db!
        .select()
        .from(seriesSubscriptions)
        .where(
          and(
            eq(seriesSubscriptions.userId, userId),
            eq(seriesSubscriptions.seriesId, seriesId),
          ),
        )
        .limit(1),
    );
    if (rows.length === 0) return null;
    return this.mapSubscriptionRow(rows[0]);
  }

  async listUserSubscriptions(
    userId: string,
    activeOnly = false,
  ): Promise<SeriesSubscriptionRecord[]> {
    if (this.noop) return [];

    const where = activeOnly
      ? and(
          eq(seriesSubscriptions.userId, userId),
          eq(seriesSubscriptions.status, 'active'),
        )
      : eq(seriesSubscriptions.userId, userId);

    const rows = await this.withRetry(() =>
      this.db!
        .select()
        .from(seriesSubscriptions)
        .where(where)
        .orderBy(desc(seriesSubscriptions.updatedAt)),
    );
    return rows.map((row) => this.mapSubscriptionRow(row));
  }

  /**
   * Idempotent subscribe: re-subscribing a cancelled/paused user flips status
   * back to 'active' on the existing row, preserving prior progress.
   */
  async subscribeToSeries(
    userId: string,
    seriesId: string,
  ): Promise<SeriesSubscriptionRecord> {
    if (this.noop) {
      const now = new Date();
      return {
        id: uuidv4(),
        userId,
        seriesId,
        status: 'active',
        currentSessionIndex: 0,
        completedSessions: 0,
        subscribedAt: now,
        lastSessionCompletedAt: null,
        unsubscribedAt: null,
        createdAt: now,
        updatedAt: now,
      };
    }

    const existing = await this.getSubscription(userId, seriesId);
    const now = new Date();

    if (existing) {
      const rows = await this.withRetry(() =>
        this.db!
          .update(seriesSubscriptions)
          .set({ status: 'active', unsubscribedAt: null, updatedAt: now })
          .where(eq(seriesSubscriptions.id, existing.id))
          .returning(),
      );
      this.logger.log(
        `Series subscription reactivated: user=${userId} series=${seriesId}`,
      );
      return this.mapSubscriptionRow(rows[0]);
    }

    const rows = await this.withRetry(() =>
      this.db!
        .insert(seriesSubscriptions)
        .values({
          userId,
          seriesId,
          status: 'active',
          currentSessionIndex: 0,
          completedSessions: 0,
          subscribedAt: now,
          createdAt: now,
          updatedAt: now,
        })
        .returning(),
    );
    this.logger.log(`Series subscription created: user=${userId} series=${seriesId}`);
    return this.mapSubscriptionRow(rows[0]);
  }

  async setSubscriptionStatus(
    userId: string,
    seriesId: string,
    status: 'active' | 'paused' | 'completed' | 'cancelled',
  ): Promise<SeriesSubscriptionRecord | null> {
    if (this.noop) return null;

    const now = new Date();
    const updates: Record<string, unknown> = { status, updatedAt: now };
    if (status === 'cancelled') updates.unsubscribedAt = now;
    if (status === 'active') updates.unsubscribedAt = null;

    const rows = await this.withRetry(() =>
      this.db!
        .update(seriesSubscriptions)
        .set(updates)
        .where(
          and(
            eq(seriesSubscriptions.userId, userId),
            eq(seriesSubscriptions.seriesId, seriesId),
          ),
        )
        .returning(),
    );
    if (rows.length === 0) return null;
    this.logger.log(
      `Series subscription status: user=${userId} series=${seriesId} status=${status}`,
    );
    return this.mapSubscriptionRow(rows[0]);
  }

  /**
   * Bump progress after a session completes. Flips to 'completed' once
   * completedSessions >= totalSessions.
   */
  async recordSessionProgress(
    userId: string,
    seriesId: string,
    sessionIndex: number,
  ): Promise<SeriesSubscriptionRecord | null> {
    if (this.noop) return null;

    const sub = await this.getSubscription(userId, seriesId);
    if (!sub) return null;

    const seriesRow = await this.getSeriesById(seriesId);
    const total = seriesRow?.totalSessions ?? 0;
    const newCompleted = total > 0
      ? Math.min(total, sub.completedSessions + 1)
      : sub.completedSessions + 1;
    const newIndex = Math.max(sub.currentSessionIndex, sessionIndex + 1);
    const isComplete = total > 0 && newCompleted >= total;
    const now = new Date();

    const rows = await this.withRetry(() =>
      this.db!
        .update(seriesSubscriptions)
        .set({
          currentSessionIndex: newIndex,
          completedSessions: newCompleted,
          lastSessionCompletedAt: now,
          status: isComplete ? 'completed' : sub.status,
          updatedAt: now,
        })
        .where(eq(seriesSubscriptions.id, sub.id))
        .returning(),
    );
    return this.mapSubscriptionRow(rows[0]);
  }

  // ── TTS jobs ───────────────────────────────────────────────────────────────

  async createTtsJobs(
    jobs: {
      planId: string;
      cacheKey: string;
      text: string;
      voiceId: string;
      locale: string;
      provider: string;
      speechRate: string;
    }[],
  ): Promise<{ id: string; cacheKey: string }[]> {
    if (this.noop || jobs.length === 0) return [];

    const now = new Date();
    const rows = await this.withRetry(() =>
      this.db!
        .insert(ttsJobs)
        .values(jobs.map((j) => ({ ...j, status: 'pending', attempts: 0, createdAt: now })))
        .returning({ id: ttsJobs.id, cacheKey: ttsJobs.cacheKey }),
    );

    return rows;
  }

  /** Fetch TTS jobs by their IDs. */
  async getTtsJobsByIds(jobIds: string[]): Promise<TtsJobRecord[]> {
    if (this.noop || jobIds.length === 0) return [];

    // Use inArray equivalent via sql template for UUID array.
    const placeholders = jobIds.map((_, i) => `$${i + 1}`).join(', ');
    const rows = await this.withRetry(() =>
      this.db!
        .select()
        .from(ttsJobs)
        .where(sql`${ttsJobs.id} IN (${sql.join(jobIds.map((id) => sql`${id}::uuid`), sql`, `)})`),
    );

    return rows.map((row) => this.mapTtsJobRecord(row));
  }

  async updateTtsJobStatus(
    jobId: string,
    status: string,
    s3Key?: string,
    error?: string,
  ): Promise<void> {
    if (this.noop) return;

    const updates: Partial<typeof ttsJobs.$inferInsert> & Record<string, unknown> = {
      status,
      attempts: sql`${ttsJobs.attempts} + 1` as any,
    };
    if (s3Key !== undefined) updates.s3Key = s3Key;
    if (error !== undefined) updates.error = error;
    if (status === 'completed') updates.completedAt = new Date();

    await this.withRetry(() =>
      this.db!
        .update(ttsJobs)
        .set(updates as any)
        .where(eq(ttsJobs.id, jobId)),
    );
  }

  /** Get TTS pre-generation status summary for a plan. */
  async getPlanTtsStatus(planId: string): Promise<TtsPregenStatusRecord> {
    if (this.noop) {
      return { status: 'none', total: 0, completed: 0, failed: 0, ready: false, updatedAt: new Date(0) };
    }

    const planRows = await this.withRetry(() =>
      this.db!
        .select({
          ttsStatus: plans.ttsStatus,
          ttsTotal: plans.ttsTotal,
          ttsCompleted: plans.ttsCompleted,
          updatedAt: plans.updatedAt,
        })
        .from(plans)
        .where(eq(plans.id, planId))
        .limit(1),
    );

    if (planRows.length === 0) {
      return { status: 'none', total: 0, completed: 0, failed: 0, ready: false, updatedAt: new Date(0) };
    }

    const plan = planRows[0];

    const failedRows = await this.withRetry(() =>
      this.db!
        .select({ count: sql<number>`count(*)::int` })
        .from(ttsJobs)
        .where(and(eq(ttsJobs.planId, planId), eq(ttsJobs.status, 'failed'))),
    );

    const failed = failedRows[0]?.count ?? 0;
    const ready = plan.ttsStatus === 'completed' || plan.ttsStatus === 'partial';

    return {
      status: plan.ttsStatus,
      total: plan.ttsTotal,
      completed: plan.ttsCompleted,
      failed,
      ready,
      updatedAt: plan.updatedAt,
    };
  }

  /** Get all completed TTS jobs for a plan (for audio URL generation). */
  async getCompletedTtsJobs(planId: string): Promise<TtsJobRecord[]> {
    if (this.noop) return [];

    const rows = await this.withRetry(() =>
      this.db!
        .select()
        .from(ttsJobs)
        .where(and(eq(ttsJobs.planId, planId), eq(ttsJobs.status, 'completed'))),
    );

    return rows.map((row) => this.mapTtsJobRecord(row));
  }

  /**
   * Mark all pending (unstarted) TTS jobs for a plan as failed.
   * Called when a stale plan is detected so finalizePlanTtsStatus() can
   * compute the correct partial/failed outcome.
   */
  async failStalePendingJobs(planId: string): Promise<void> {
    if (this.noop) return;
    await this.withRetry(() =>
      this.db!
        .update(ttsJobs)
        .set({ status: 'failed', error: 'Job abandoned — worker did not complete' })
        .where(and(eq(ttsJobs.planId, planId), eq(ttsJobs.status, 'pending'))),
    );
  }

  /**
   * After all TTS jobs complete, compute and save final plan ttsStatus.
   */
  async finalizePlanTtsStatus(planId: string): Promise<void> {
    if (this.noop) return;

    const countRows = await this.withRetry(() =>
      this.db!
        .select({
          total: sql<number>`count(*)::int`,
          completed: sql<number>`sum(case when ${ttsJobs.status} = 'completed' then 1 else 0 end)::int`,
          failed: sql<number>`sum(case when ${ttsJobs.status} = 'failed' then 1 else 0 end)::int`,
        })
        .from(ttsJobs)
        .where(eq(ttsJobs.planId, planId)),
    );

    const { total, completed, failed } = countRows[0] ?? { total: 0, completed: 0, failed: 0 };

    let finalStatus: string;
    if (failed === 0 && completed === total) {
      finalStatus = 'completed';
    } else if (completed > 0) {
      finalStatus = 'partial';
    } else {
      finalStatus = 'failed';
    }

    await this.setTtsStatus(planId, finalStatus, total, completed);
    this.logger.log(`Plan ${planId} TTS finalized: ${finalStatus} (${completed}/${total})`);
  }

  // ── Deletion requests ──────────────────────────────────────────────────────

  /** Persist a data-deletion request row. */
  async insertDeletionRequest(params: {
    id: string;
    email: string;
    scope: string;
    reason: string | null;
    requestedAt: Date;
    createdAt: Date;
  }): Promise<void> {
    if (this.noop) return;

    await this.withRetry(() =>
      this.db!.insert(deletionRequests).values(params),
    );
    this.logger.log(`Deletion request logged: id=${params.id}, scope=${params.scope}`);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  private mapPlanRecord(row: typeof plans.$inferSelect): PlanRecord {
    return {
      planId: row.id,
      userId: row.userId,
      name: row.name,
      planJson: row.planJson,
      isActive: row.isActive,
      ttsStatus: row.ttsStatus,
      ttsTotal: row.ttsTotal,
      ttsCompleted: row.ttsCompleted,
      voiceQuality: row.voiceQuality,
      sourceLibraryPlanId: row.sourceLibraryPlanId ?? null,
      seriesId: row.seriesId ?? null,
      shareToken: row.shareToken ?? null,
      shareTokenCreatedAt: row.shareTokenCreatedAt ?? null,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    };
  }

  private async mapSeriesRow(row: typeof series.$inferSelect): Promise<SeriesRecord> {
    // Cache: count plans pointing to this series. The partial index
    // idx_plans_series keeps this cheap.
    const countRows = await this.withRetry(() =>
      this.db!
        .select({ count: sql<number>`count(*)::int` })
        .from(plans)
        .where(eq(plans.seriesId, row.id)),
    );
    const totalSessions = Number(countRows[0]?.count ?? 0);

    return {
      id: row.id,
      name: row.name,
      description: row.description ?? null,
      category: row.category,
      categoryId: row.categoryId ?? null,
      tags: row.tags,
      defaultVoice: row.defaultVoice,
      locale: row.locale,
      isPublished: row.isPublished,
      sortOrder: row.sortOrder,
      totalSessions,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    };
  }

  private mapSubscriptionRow(
    row: typeof seriesSubscriptions.$inferSelect,
  ): SeriesSubscriptionRecord {
    return {
      id: row.id,
      userId: row.userId,
      seriesId: row.seriesId,
      status: row.status as SeriesSubscriptionRecord['status'],
      currentSessionIndex: row.currentSessionIndex,
      completedSessions: row.completedSessions,
      subscribedAt: row.subscribedAt,
      lastSessionCompletedAt: row.lastSessionCompletedAt ?? null,
      unsubscribedAt: row.unsubscribedAt ?? null,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    };
  }

  private mapTtsJobRecord(row: typeof ttsJobs.$inferSelect): TtsJobRecord {
    // After migration 0011, speechRate is NUMERIC(4,2), not TEXT.
    // Convert to string with 2 decimal places (toFixed(2)) for cache key consistency
    // with Flutter client's hash_utils.dart fullParamCacheKey().
    const speechRateStr =
      typeof row.speechRate === 'number'
        ? (row.speechRate as number).toFixed(2)
        : String(row.speechRate);

    return {
      id: row.id,
      planId: row.planId,
      cacheKey: row.cacheKey,
      text: row.text,
      voiceId: row.voiceId,
      locale: row.locale,
      provider: row.provider,
      speechRate: speechRateStr,
      s3Key: row.s3Key ?? null,
      status: row.status,
      error: row.error ?? null,
      attempts: row.attempts,
      createdAt: row.createdAt,
      completedAt: row.completedAt ?? null,
    };
  }

  // ── Plan sharing ───────────────────────────────────────────────────────────

  /**
   * Update a plan's share token.
   * Sets both share_token and share_token_created_at.
   */
  async updatePlanShareToken(planId: string, shareToken: string): Promise<void> {
    if (this.noop) return;

    await this.withRetry(() =>
      this.db!
        .update(plans)
        .set({
          shareToken,
          shareTokenCreatedAt: new Date(),
        })
        .where(eq(plans.id, planId)),
    );
  }

  /**
   * Get a shared plan by share token (no auth required).
   * Returns plan metadata and steps for the public shared endpoint.
   */
  async getSharedPlan(
    shareToken: string,
  ): Promise<{
    name: string;
    description?: string;
    steps?: unknown[];
    stepCount: number;
    estimatedDurationMs: number;
  } | null> {
    if (this.noop) return null;

    const rows = await this.withRetry(() =>
      this.db!
        .select({ planJson: plans.planJson, name: plans.name })
        .from(plans)
        .where(eq(plans.shareToken, shareToken))
        .limit(1),
    );

    if (rows.length === 0) return null;

    const { planJson, name } = rows[0];
    try {
      const parsed = JSON.parse(planJson) as {
        description?: string;
        steps?: unknown[];
        estimatedDurationMs?: number;
      };
      return {
        name,
        description: parsed.description,
        steps: parsed.steps,
        stepCount: Array.isArray(parsed.steps) ? parsed.steps.length : 0,
        estimatedDurationMs: parsed.estimatedDurationMs ?? 0,
      };
    } catch {
      return {
        name,
        stepCount: 0,
        estimatedDurationMs: 0,
      };
    }
  }

  /**
   * Revoke a plan's share token (set it to NULL).
   * Only the plan owner can revoke.
   */
  async revokePlanShareToken(userId: string, planId: string): Promise<boolean> {
    if (this.noop) return true;

    const result = await this.withRetry(() =>
      this.db!
        .update(plans)
        .set({
          shareToken: null,
          shareTokenCreatedAt: null,
        })
        .where(and(eq(plans.id, planId), eq(plans.userId, userId))),
    );

    return result.rowCount > 0;
  }

  // ── Session completions ────────────────────────────────────────────────────

  /**
   * Upsert session completions (idempotent via client_id).
   * Returns the count of completions successfully synced.
   */
  async upsertSessionCompletions(
    userId: string,
    completions: Array<{
      planId: string;
      completedAt: Date;
      durationMs: number;
      clientId: string;
    }>,
  ): Promise<number> {
    if (this.noop) return 0;
    if (completions.length === 0) return 0;

    const rows = completions.map((c) => ({
      userId,
      planId: c.planId,
      completedAt: c.completedAt,
      durationMs: c.durationMs,
      clientId: c.clientId,
    }));

    await this.withRetry(() =>
      this.db!.insert(sessionCompletions).values(rows).onConflictDoNothing(),
    );

    // Return the count of rows we attempted to insert
    // (some may have been skipped due to client_id conflicts)
    return completions.length;
  }

  /**
   * Get session completions for a user since a given timestamp.
   */
  async getSessionCompletions(
    userId: string,
    since?: Date,
  ): Promise<
    Array<{
      id: string;
      planId: string;
      completedAt: Date;
      durationMs: number;
    }>
  > {
    if (this.noop) return [];

    const whereConditions = since
      ? and(eq(sessionCompletions.userId, userId), gt(sessionCompletions.completedAt, since))
      : eq(sessionCompletions.userId, userId);

    return await this.withRetry(() =>
      this.db!
        .select({
          id: sessionCompletions.id,
          planId: sessionCompletions.planId,
          completedAt: sessionCompletions.completedAt,
          durationMs: sessionCompletions.durationMs,
        })
        .from(sessionCompletions)
        .where(whereConditions)
        .orderBy(sessionCompletions.completedAt),
    );
  }

  // ── plan_triggers ──────────────────────────────────────────────────────────

  /**
   * Upsert a batch of plan-trigger rows by (user_id, client_id).
   *
   * Last-write-wins on updatedAt: if the incoming row is older than what's
   * already stored, the row is left untouched. This lets two devices push
   * stale edits without clobbering more recent local changes.
   *
   * Returns the server-authoritative view of every incoming row (post-merge),
   * so the client can record each row's server id + updated_at and clear
   * its dirty flag.
   */
  async upsertPlanTriggers(
    userId: string,
    triggers: Array<{
      clientId: string;
      planId: string;
      title: string;
      startUtc: Date;
      durationMinutes: number;
      recurrence: string;
      deletedAt: Date | null;
      updatedAt: Date;
    }>,
  ): Promise<
    Array<{
      id: string;
      clientId: string;
      planId: string;
      title: string;
      startUtc: Date;
      durationMinutes: number;
      recurrence: string;
      deletedAt: Date | null;
      updatedAt: Date;
    }>
  > {
    if (this.noop || triggers.length === 0) return [];

    const rows = triggers.map((t) => ({
      userId,
      clientId: t.clientId,
      planId: t.planId,
      title: t.title,
      startUtc: t.startUtc,
      durationMinutes: t.durationMinutes,
      recurrence: t.recurrence,
      deletedAt: t.deletedAt,
      updatedAt: t.updatedAt,
    }));

    // onConflictDoUpdate with a WHERE clause enforces last-write-wins: we only
    // overwrite when the incoming updatedAt is strictly newer than the stored
    // value. For a fresh insert the conflict clause is unused.
    await this.withRetry(() =>
      this.db!
        .insert(planTriggers)
        .values(rows)
        .onConflictDoUpdate({
          target: planTriggers.clientId,
          set: {
            planId: sql`EXCLUDED.plan_id`,
            title: sql`EXCLUDED.title`,
            startUtc: sql`EXCLUDED.start_utc`,
            durationMinutes: sql`EXCLUDED.duration_minutes`,
            recurrence: sql`EXCLUDED.recurrence`,
            deletedAt: sql`EXCLUDED.deleted_at`,
            updatedAt: sql`EXCLUDED.updated_at`,
          },
          setWhere: sql`${planTriggers.updatedAt} < EXCLUDED.updated_at`,
        }),
    );

    // Read back the final server-authoritative rows. Returning these lets the
    // client write back serverId + updatedAt in a single round-trip instead of
    // issuing a second GET.
    const clientIds = triggers.map((t) => t.clientId);
    const merged = await this.withRetry(() =>
      this.db!
        .select({
          id: planTriggers.id,
          clientId: planTriggers.clientId,
          planId: planTriggers.planId,
          title: planTriggers.title,
          startUtc: planTriggers.startUtc,
          durationMinutes: planTriggers.durationMinutes,
          recurrence: planTriggers.recurrence,
          deletedAt: planTriggers.deletedAt,
          updatedAt: planTriggers.updatedAt,
        })
        .from(planTriggers)
        .where(
          and(
            eq(planTriggers.userId, userId),
            sql`${planTriggers.clientId} = ANY(${clientIds})`,
          ),
        ),
    );

    return merged;
  }

  /**
   * Fetch plan triggers for a user changed since the optional timestamp,
   * including tombstones so clients can propagate deletes.
   */
  async getPlanTriggers(
    userId: string,
    since?: Date,
  ): Promise<
    Array<{
      id: string;
      clientId: string;
      planId: string;
      title: string;
      startUtc: Date;
      durationMinutes: number;
      recurrence: string;
      deletedAt: Date | null;
      updatedAt: Date;
    }>
  > {
    if (this.noop) return [];

    const whereCond = since
      ? and(eq(planTriggers.userId, userId), gt(planTriggers.updatedAt, since))
      : eq(planTriggers.userId, userId);

    return await this.withRetry(() =>
      this.db!
        .select({
          id: planTriggers.id,
          clientId: planTriggers.clientId,
          planId: planTriggers.planId,
          title: planTriggers.title,
          startUtc: planTriggers.startUtc,
          durationMinutes: planTriggers.durationMinutes,
          recurrence: planTriggers.recurrence,
          deletedAt: planTriggers.deletedAt,
          updatedAt: planTriggers.updatedAt,
        })
        .from(planTriggers)
        .where(whereCond)
        .orderBy(asc(planTriggers.updatedAt)),
    );
  }

  private countSteps(planJson: string): number {
    try {
      const parsed = JSON.parse(planJson) as { steps?: unknown[] };
      return Array.isArray(parsed.steps) ? parsed.steps.length : 0;
    } catch {
      return 0;
    }
  }

  private calcTotalDurationSeconds(planJson: string): number {
    try {
      const parsed = JSON.parse(planJson) as {
        steps?: { runtimeType?: string; duration?: number; estimatedDuration?: number }[];
      };
      if (!Array.isArray(parsed.steps)) return 0;
      const totalMicros = parsed.steps.reduce((sum, step) => {
        if (step.runtimeType === 'wait' && typeof step.duration === 'number') {
          return sum + step.duration;
        }
        if (step.runtimeType === 'say' && typeof step.estimatedDuration === 'number') {
          return sum + step.estimatedDuration;
        }
        return sum;
      }, 0);
      return Math.round(totalMicros / 1_000_000);
    } catch {
      return 0;
    }
  }
}
