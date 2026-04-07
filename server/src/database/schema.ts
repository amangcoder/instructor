import { sqliteTable, text, integer, index } from 'drizzle-orm/sqlite-core';

/** Registered users (created on first successful OTP verification). */
export const users = sqliteTable('users', {
  id: text('id').primaryKey(),
  email: text('email').notNull().unique(),
  createdAt: integer('created_at', { mode: 'timestamp' }).notNull(),
});

/**
 * Short-lived one-time passwords sent via email.
 *
 * Hot query patterns requiring indexes:
 *   1. requestOtp cleanup: WHERE email = ? AND used = false
 *   2. verifyOtp lookup:   WHERE email = ? AND used = false AND expires_at > ?
 *   3. pruneExpiredOtps:   WHERE expires_at < ?
 *
 * idx_otp_lookup covers (1) and (2) via prefix matching on (email, used).
 * idx_otp_expires_at covers (3).
 */
export const otpRecords = sqliteTable(
  'otp_records',
  {
    id: integer('id').primaryKey({ autoIncrement: true }),
    email: text('email').notNull(),
    code: text('code').notNull(),
    expiresAt: integer('expires_at', { mode: 'timestamp' }).notNull(),
    attempts: integer('attempts').notNull().default(0),
    used: integer('used', { mode: 'boolean' }).notNull().default(false),
    createdAt: integer('created_at', { mode: 'timestamp' }).notNull(),
  },
  (table) => ({
    /**
     * Composite covering index for the two most common WHERE predicates:
     *   WHERE email = ?                          (requestOtp invalidation)
     *   WHERE email = ? AND used = 0 AND ...     (verifyOtp lookup)
     * Column order: equality columns first (email, used), range last (expiresAt).
     */
    lookupIdx: index('idx_otp_lookup').on(table.email, table.used, table.expiresAt),
    /** Range scan for periodic cleanup of expired OTPs. */
    expiresAtIdx: index('idx_otp_expires_at').on(table.expiresAt),
  }),
);

/**
 * Long-lived refresh tokens (30-day opaque UUIDs stored server-side).
 *
 * Hot query patterns:
 *   1. refreshAccessToken lookup:  WHERE token = ? AND revoked = false AND expires_at > ?
 *      → Covered by the UNIQUE index on `token` (already created implicitly).
 *   2. FK traversal / user token lookup: WHERE user_id = ?
 *      → idx_refresh_user_id covers this.
 *   3. Cleanup of expired tokens:  WHERE expires_at < ?
 *      → idx_refresh_expires_at covers this.
 */
export const refreshTokens = sqliteTable(
  'refresh_tokens',
  {
    id: text('id').primaryKey(),
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    token: text('token').notNull().unique(),
    expiresAt: integer('expires_at', { mode: 'timestamp' }).notNull(),
    revoked: integer('revoked', { mode: 'boolean' }).notNull().default(false),
  },
  (table) => ({
    /** Supports revoking all tokens for a user (e.g. on password reset or logout-all). */
    userIdIdx: index('idx_refresh_user_id').on(table.userId),
    /** Supports periodic cleanup of expired tokens. */
    expiresAtIdx: index('idx_refresh_expires_at').on(table.expiresAt),
  }),
);

/** Per-user sync metadata tracking the last S3 backup. */
export const syncMetadata = sqliteTable('sync_metadata', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  userId: text('user_id')
    .notNull()
    .unique()
    .references(() => users.id, { onDelete: 'cascade' }),
  lastSyncAt: integer('last_sync_at', { mode: 'timestamp' }),
  sizeBytes: integer('size_bytes'),
});
