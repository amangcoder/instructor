/**
 * Drizzle ORM PostgreSQL schema for Instructor backend.
 *
 * Tables:
 *   - users           — registered user accounts
 *   - otp_records     — email OTP codes (no FK to users: OTPs are created before user exists)
 *   - refresh_tokens  — JWT refresh tokens with revocation support
 *   - plans           — user-created plans stored server-side for cross-device recovery
 *   - library_plans   — curated global plan library (admin-managed)
 *   - tts_jobs        — per-plan TTS pre-generation job tracking
 *
 * Index strategy:
 *   - otp_records: composite (email, used, expires_at) — equality on email+used, range on expires_at
 *   - refresh_tokens: partial index on (user_id) WHERE revoked = false — much smaller than full
 *     composite index since only 1-2 active tokens exist per user vs 50-100 lifetime tokens
 */

import {
  boolean,
  index,
  integer,
  pgTable,
  text,
  timestamp,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';

// ---------------------------------------------------------------------------
// users
// ---------------------------------------------------------------------------

export const users = pgTable('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  email: varchar('email').unique().notNull(),
  name: varchar('name', { length: 100 }),
  username: varchar('username', { length: 30 }).unique(),
  photoUrl: text('photo_url'),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
});

export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;

// ---------------------------------------------------------------------------
// otp_records
//
// NOTE: No FK on email — OTPs are inserted BEFORE the user row exists.
//       This is intentional: the auth flow is request-OTP → verify-OTP → create-user.
// ---------------------------------------------------------------------------

export const otpRecords = pgTable(
  'otp_records',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    email: varchar('email').notNull(),
    codeHash: varchar('code_hash', { length: 64 }).notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    attempts: integer('attempts').default(0).notNull(),
    used: boolean('used').default(false).notNull(),
  },
  (table) => [
    // Composite index: equality columns first (email, used) then range column (expires_at).
    // PostgreSQL seeks on email+used equality then range-scans expires_at — optimal for
    // getActiveOtps: WHERE email = ? AND used = false AND expires_at > NOW()
    index('idx_otp_records_email_used_expires').on(table.email, table.used, table.expiresAt),
  ],
);

export type OtpRecord = typeof otpRecords.$inferSelect;
export type NewOtpRecord = typeof otpRecords.$inferInsert;

// ---------------------------------------------------------------------------
// refresh_tokens
// ---------------------------------------------------------------------------

export const refreshTokens = pgTable(
  'refresh_tokens',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tokenHash: varchar('token_hash', { length: 64 }).unique().notNull(),
    userId: uuid('user_id')
      .references(() => users.id)
      .notNull(),
    revoked: boolean('revoked').default(false).notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  },
  (table) => [
    // Partial index: only indexes active (non-revoked) tokens.
    // Dramatically smaller than a full composite index on (user_id, revoked) because
    // each user has 1-2 active tokens but 50-100 lifetime tokens.
    // Used by revokeAllRefreshTokens: WHERE user_id = ? AND revoked = false
    index('idx_refresh_tokens_active').on(table.userId).where(sql`${table.revoked} = false`),
  ],
);

export type RefreshToken = typeof refreshTokens.$inferSelect;
export type NewRefreshToken = typeof refreshTokens.$inferInsert;

// ---------------------------------------------------------------------------
// library_plans
//
// Stores the curated global plan library (admin-managed).
// plan_json holds the full plan serialised as JSON TEXT.
// ---------------------------------------------------------------------------

export const libraryPlans = pgTable(
  'library_plans',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    name: text('name').notNull(),
    description: text('description'),
    category: text('category').notNull(),
    tags: text('tags').notNull().default(''),
    defaultVoice: text('default_voice').notNull(),
    planJson: text('plan_json').notNull(),
    locale: text('locale').notNull().default('enUS'),
    isPublished: boolean('is_published').notNull().default(false),
    sortOrder: integer('sort_order').notNull().default(0),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    index('idx_library_plans_category').on(table.category),
    index('idx_library_plans_published').on(table.isPublished),
  ],
);

export type LibraryPlan = typeof libraryPlans.$inferSelect;
export type NewLibraryPlan = typeof libraryPlans.$inferInsert;

// ---------------------------------------------------------------------------
// plans
//
// Stores user-created plans server-side for cross-device recovery.
// plan_json holds the full plan serialised as JSON TEXT (max 512 KB enforced
// at the application layer via @MaxLength(524288) on the DTO).
// ---------------------------------------------------------------------------

export const plans = pgTable(
  'plans',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .references(() => users.id)
      .notNull(),
    name: text('name').notNull(),
    planJson: text('plan_json').notNull(),
    // Library / activation fields
    sourceLibraryPlanId: uuid('source_library_plan_id').references(() => libraryPlans.id),
    isActive: boolean('is_active').notNull().default(false),
    // TTS pre-generation tracking
    ttsStatus: text('tts_status').notNull().default('none'), // none | pending | processing | completed | partial | failed
    ttsTotal: integer('tts_total').notNull().default(0),
    ttsCompleted: integer('tts_completed').notNull().default(0),
    voiceQuality: text('voice_quality').notNull().default('standard'), // standard | studio
    // Plan sharing — optional share token for generating shareable links
    shareToken: varchar('share_token', { length: 20 }).unique(),
    shareTokenCreatedAt: timestamp('share_token_created_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    // Plans are always queried by userId — this index makes list queries O(log n).
    index('idx_plans_user_id').on(table.userId),
    // Share token queries are by token only (public endpoint: GET /api/plans/shared/:token)
    index('idx_plans_share_token').on(table.shareToken),
  ],
);

export type Plan = typeof plans.$inferSelect;
export type NewPlan = typeof plans.$inferInsert;

// ---------------------------------------------------------------------------
// tts_jobs
//
// Per-plan TTS pre-generation job tracking.
// Each row represents one text-voice pair to synthesize.
// Cascade-deletes when the parent plan is deleted.
// ---------------------------------------------------------------------------

export const ttsJobs = pgTable(
  'tts_jobs',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    planId: uuid('plan_id')
      .references(() => plans.id, { onDelete: 'cascade' })
      .notNull(),
    cacheKey: varchar('cache_key', { length: 64 }).notNull(),
    text: text('text').notNull(),
    voiceId: text('voice_id').notNull(),
    locale: text('locale').notNull(),
    provider: text('provider').notNull(),
    speechRate: text('speech_rate').notNull().default('1.0'),
    s3Key: text('s3_key'),
    status: text('status').notNull().default('pending'), // pending | processing | completed | failed
    error: text('error'),
    attempts: integer('attempts').notNull().default(0),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    completedAt: timestamp('completed_at', { withTimezone: true }),
  },
  (table) => [
    index('idx_tts_jobs_plan_id').on(table.planId),
    index('idx_tts_jobs_plan_status').on(table.planId, table.status),
  ],
);

export type TtsJob = typeof ttsJobs.$inferSelect;
export type NewTtsJob = typeof ttsJobs.$inferInsert;

// ---------------------------------------------------------------------------
// deletion_requests
//
// Stores data-deletion requests submitted via the public website form.
// Intentionally has NO foreign key to users — we never query the users table
// during processing (email enumeration prevention). The admin reviews and
// processes requests manually via the notification email.
// ---------------------------------------------------------------------------

export const deletionRequests = pgTable('deletion_requests', {
  id: uuid('id').primaryKey().defaultRandom(),
  email: varchar('email').notNull(),
  scope: varchar('scope', { length: 50 }).notNull(),
  reason: text('reason'),
  requestedAt: timestamp('requested_at', { withTimezone: true }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
});

export type DeletionRequest = typeof deletionRequests.$inferSelect;
export type NewDeletionRequest = typeof deletionRequests.$inferInsert;

// ---------------------------------------------------------------------------
// session_completions
//
// Stores session completion records synced from client.
// Used for cross-device streak consistency and completion history.
// client_id is a UUID generated on the client to ensure idempotency —
// the server uses ON CONFLICT (client_id) DO NOTHING to prevent duplicates.
// ---------------------------------------------------------------------------

export const sessionCompletions = pgTable(
  'session_completions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .references(() => users.id)
      .notNull(),
    planId: uuid('plan_id').notNull(), // No FK — plan may be deleted but completions persist for streak history
    completedAt: timestamp('completed_at', { withTimezone: true }).notNull(),
    durationMs: integer('duration_ms').notNull(),
    clientId: uuid('client_id').unique().notNull(), // Idempotency key — prevents duplicate syncs
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    // Query by userId for cross-device streak queries
    index('idx_session_completions_user_created').on(table.userId, table.createdAt),
    // Query by planId for plan-specific completion history
    index('idx_session_completions_plan_completed').on(table.planId, table.completedAt),
  ],
);

export type SessionCompletion = typeof sessionCompletions.$inferSelect;
export type NewSessionCompletion = typeof sessionCompletions.$inferInsert;

// ---------------------------------------------------------------------------
// streak_freezes
//
// Streak freeze records — users have a max of 2 active freezes.
// Replenished at 1 per 7 consecutive active days.
// ---------------------------------------------------------------------------

export const streakFreezes = pgTable(
  'streak_freezes',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .references(() => users.id)
      .notNull(),
    frozenAt: timestamp('frozen_at', { withTimezone: true }).notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    consumedAt: timestamp('consumed_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    // Query active freezes by userId
    index('idx_streak_freezes_user_id').on(table.userId),
  ],
);

export type StreakFreeze = typeof streakFreezes.$inferSelect;
export type NewStreakFreeze = typeof streakFreezes.$inferInsert;

// ---------------------------------------------------------------------------
// plan_triggers
//
// Scheduled auto-start triggers for plans. Created when a user adds a plan
// to their calendar — the trigger fires the plan session at startUtc (with
// optional recurrence). client_id is a UUID from the device for idempotency
// and cross-device sync; the client stores native alarm/event identifiers
// locally and does not sync them.
//
// Soft-deletes via deleted_at so tombstones propagate to other devices.
// ---------------------------------------------------------------------------

export const planTriggers = pgTable(
  'plan_triggers',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .references(() => users.id)
      .notNull(),
    planId: uuid('plan_id').notNull(), // No FK — plan may be a local library plan not in server plans table
    clientId: uuid('client_id').unique().notNull(), // Idempotency + device-local correlation
    startUtc: timestamp('start_utc', { withTimezone: true }).notNull(),
    durationMinutes: integer('duration_minutes').notNull(),
    recurrence: text('recurrence').notNull().default('none'), // none | daily | weekdays | weekly
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
  },
  (table) => [
    // Sync pulls: WHERE user_id = ? AND updated_at > ?
    index('idx_plan_triggers_user_updated').on(table.userId, table.updatedAt),
    // Upcoming triggers lookup: WHERE user_id = ? AND deleted_at IS NULL AND start_utc > NOW()
    index('idx_plan_triggers_user_start').on(table.userId, table.startUtc),
  ],
);

export type PlanTrigger = typeof planTriggers.$inferSelect;
export type NewPlanTrigger = typeof planTriggers.$inferInsert;
