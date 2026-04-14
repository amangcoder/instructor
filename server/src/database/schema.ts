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
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    // Plans are always queried by userId — this index makes list queries O(log n).
    index('idx_plans_user_id').on(table.userId),
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
