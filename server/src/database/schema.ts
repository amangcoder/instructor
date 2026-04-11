/**
 * Drizzle ORM PostgreSQL schema for Instructor backend.
 *
 * Tables:
 *   - users           — registered user accounts
 *   - otp_records     — email OTP codes (no FK to users: OTPs are created before user exists)
 *   - refresh_tokens  — JWT refresh tokens with revocation support
 *   - sync_metadata   — per-user backup sync state
 *   - plans           — user-created plans stored server-side for cross-device recovery
 *
 * Index strategy:
 *   - otp_records: composite (email, used, expires_at) — equality on email+used, range on expires_at
 *   - refresh_tokens: partial index on (user_id) WHERE revoked = false — much smaller than full
 *     composite index since only 1-2 active tokens exist per user vs 50-100 lifetime tokens
 */

import {
  bigint,
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
// sync_metadata
// ---------------------------------------------------------------------------

export const syncMetadata = pgTable('sync_metadata', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id')
    .references(() => users.id)
    .unique()
    .notNull(),
  lastSyncAt: timestamp('last_sync_at', { withTimezone: true }),
  sizeBytes: bigint('size_bytes', { mode: 'number' }),
});

export type SyncMetadata = typeof syncMetadata.$inferSelect;
export type NewSyncMetadata = typeof syncMetadata.$inferInsert;

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
