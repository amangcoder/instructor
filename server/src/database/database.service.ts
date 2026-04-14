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

import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { neon } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-http';
import { and, asc, desc, eq, gt, ilike, or, sql } from 'drizzle-orm';
import { v4 as uuidv4 } from 'uuid';
import * as schema from './schema';
import { libraryPlans, otpRecords, plans, refreshTokens, ttsJobs, users } from './schema';
import type { NeonHttpDatabase } from 'drizzle-orm/neon-http';

// ── Typed result shapes returned to callers ────────────────────────────────

export interface UserRecord {
  id: string;
  email: string;
  name: string | null;
  username: string | null;
  photoUrl: string | null;
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

  /**
   * True when DATABASE_URL is absent.
   * All methods return mock/null results; writes are no-ops.
   */
  readonly noop: boolean;


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
   */
  async withRetry<T>(fn: () => Promise<T>): Promise<T> {
    try {
      return await fn();
    } catch (err) {
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
    return { id: row.id, email: row.email, name: row.name ?? null, username: row.username ?? null, photoUrl: row.photoUrl ?? null, createdAt: row.createdAt };
  }

  /** Fetch a user by email address. Returns null if not found. */
  async getUserByEmail(email: string): Promise<UserRecord | null> {
    if (this.noop) return null;

    const rows = await this.withRetry(() =>
      this.db!.select().from(users).where(eq(users.email, email)).limit(1),
    );

    if (rows.length === 0) return null;
    const row = rows[0];
    return { id: row.id, email: row.email, name: row.name ?? null, username: row.username ?? null, photoUrl: row.photoUrl ?? null, createdAt: row.createdAt };
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
      sk: row.id,
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
      sk: row.id,
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
      const rows = await this.withRetry(() =>
        this.db!
          .update(plans)
          .set({ name, planJson, updatedAt: now })
          .where(and(eq(plans.id, planId), eq(plans.userId, userId)))
          .returning({ id: plans.id, updatedAt: plans.updatedAt }),
      );

      if (rows.length === 0) {
        throw new NotFoundException(
          `Plan ${planId} not found or does not belong to the authenticated user`,
        );
      }

      const row = rows[0];
      this.logger.log(`Plan updated: planId=${row.id}, userId=${userId}`);
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
    if (failed === 0) {
      finalStatus = 'completed';
    } else if (completed > 0) {
      finalStatus = 'partial';
    } else {
      finalStatus = 'failed';
    }

    await this.setTtsStatus(planId, finalStatus, total, completed);
    this.logger.log(`Plan ${planId} TTS finalized: ${finalStatus} (${completed}/${total})`);
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
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    };
  }

  private mapTtsJobRecord(row: typeof ttsJobs.$inferSelect): TtsJobRecord {
    return {
      id: row.id,
      planId: row.planId,
      cacheKey: row.cacheKey,
      text: row.text,
      voiceId: row.voiceId,
      locale: row.locale,
      provider: row.provider,
      speechRate: row.speechRate,
      s3Key: row.s3Key ?? null,
      status: row.status,
      error: row.error ?? null,
      attempts: row.attempts,
      createdAt: row.createdAt,
      completedAt: row.completedAt ?? null,
    };
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
