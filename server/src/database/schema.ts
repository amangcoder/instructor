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
 *   - categories      — content taxonomy top-level nodes for the Discover surface
 *   - voices          — TTS voice registry (provider / locale / slug)
 *   - plan_voices     — per-plan per-voice TTS gate (replaces plans.tts_status gate)
 *
 * Index strategy:
 *   - otp_records: composite (email, used, expires_at) — equality on email+used, range on expires_at
 *   - refresh_tokens: partial index on (user_id) WHERE revoked = false — much smaller than full
 *     composite index since only 1-2 active tokens exist per user vs 50-100 lifetime tokens
 *   - plan_voices: composite (plan_id, status) covers the EXISTS subquery in v_published_plans
 */

import {
  boolean,
  check,
  index,
  integer,
  numeric,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';

// ---------------------------------------------------------------------------
// users
// ---------------------------------------------------------------------------

export const users = pgTable(
  'users',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    email: varchar('email').unique().notNull(),
    name: varchar('name', { length: 100 }),
    username: varchar('username', { length: 30 }).unique(),
    photoUrl: text('photo_url'),
    role: text('role').notNull().default('user'),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    check('users_role_check', sql`${table.role} IN ('user', 'admin')`),
    // Email search index (case-insensitive, for admin panel user search)
    index('idx_users_email_lower').on(sql`lower(${table.email})`),
    // Analytics: daily signup trends and overview counts — range scan by createdAt
    index('idx_users_created_at').on(table.createdAt),
  ],
);

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
// categories
//
// Top-level taxonomy nodes that group series and plans on the Discover
// surface. sort_order drives display order (ascending, lower = first).
// icon and color are optional branding hints for the mobile UI chrome.
// is_published gates whether the category appears in the mobile Discover
// surface; admin always sees all categories regardless.
// ---------------------------------------------------------------------------

export const categories = pgTable(
  'categories',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    slug: text('slug').unique().notNull(),
    name: text('name').notNull(),
    icon: text('icon'),
    color: varchar('color', { length: 20 }),
    sortOrder: integer('sort_order').notNull().default(0),
    isPublished: boolean('is_published').notNull().default(false),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
    // deleted_at is the soft-delete tombstone. NULL = live record; non-NULL = hidden
    // from every read path (admin and public). Distinct from is_published, which
    // gates draft-vs-live visibility for live records.
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
  },
  (table) => [
    // Sort-order scan: ORDER BY sort_order ASC for category list endpoints.
    index('idx_categories_sort_order').on(table.sortOrder),
    // Mobile Discover surface fetches only published, non-deleted categories.
    index('idx_categories_published_sort').on(table.sortOrder).where(sql`${table.isPublished} = true AND ${table.deletedAt} IS NULL`),
  ],
);

export type Category = typeof categories.$inferSelect;
export type NewCategory = typeof categories.$inferInsert;

// ---------------------------------------------------------------------------
// series
//
// A series groups a sequence of plans (e.g. "10 Days to Meditate", "Couch to
// 5K"). Individual sessions live in the plans / library_plans tables and
// reference their series via plans.series_id.
//
// The series row itself only describes the wrapper — name, category, voice,
// publishing flags. Per-session content stays in plans so the existing
// generation, TTS, and sharing pipelines work unchanged.
// ---------------------------------------------------------------------------

export const series = pgTable(
  'series',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    name: text('name').notNull(),
    description: text('description'),
    category: text('category').notNull(),
    tags: text('tags').notNull().default(''),
    defaultVoice: text('default_voice').notNull(),
    locale: text('locale').notNull().default('enUS'),
    isPublished: boolean('is_published').notNull().default(false),
    sortOrder: integer('sort_order').notNull().default(0),
    // Nullable FK to categories — NULL until backfill assigns existing series.
    // The old free-text series.category column is kept until migration 0015.
    categoryId: uuid('category_id').references(() => categories.id, { onDelete: 'set null' }),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    index('idx_series_category').on(table.category),
    index('idx_series_published').on(table.isPublished),
    // Partial index: only series linked to a category use this lookup.
    // Powers "list all series in category X" queries on the Discover surface.
    index('idx_series_category_id').on(table.categoryId).where(sql`${table.categoryId} IS NOT NULL`),
  ],
);

export type Series = typeof series.$inferSelect;
export type NewSeries = typeof series.$inferInsert;

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
    // Series membership — null for standalone plans
    seriesId: uuid('series_id').references(() => series.id),
    isActive: boolean('is_active').notNull().default(false),
    // TTS pre-generation tracking
    ttsStatus: text('tts_status').notNull().default('none'), // none | pending | processing | completed | partial | failed
    ttsTotal: integer('tts_total').notNull().default(0),
    ttsCompleted: integer('tts_completed').notNull().default(0),
    voiceQuality: text('voice_quality').notNull().default('standard'), // standard | studio
    // Plan sharing — optional share token for generating shareable links
    shareToken: varchar('share_token', { length: 20 }).unique(),
    shareTokenCreatedAt: timestamp('share_token_created_at', { withTimezone: true }),
    // Content hierarchy additions (migration 0014) -------------------------
    // Nullable self-FK enabling a sub-plan tree (max depth 3, enforced in service layer).
    // ON DELETE CASCADE: removing a parent removes its entire sub-plan tree.
    parentPlanId: uuid('parent_plan_id').references((): any => plans.id, { onDelete: 'cascade' }),
    // Sort order within a parent plan (sub-plans) or admin-curated top-level list.
    position: integer('position').notNull().default(0),
    // Plan lifecycle: private (author-only) | pending_review (in admin queue) | public (approved)
    // Defaults to 'public' so admin-curated plans are immediately eligible for v_published_plans
    // once is_published=true is set. User-authored plans start as 'private' (set explicitly).
    visibility: text('visibility').notNull().default('public'),
    // Nullable UUID of the plan_request that originated this plan (NULL for user-created plans).
    // UNIQUE constraint makes the promote INSERT idempotent — a retry after a partial failure
    // hits the ON CONFLICT guard and re-uses the already-created plan row.
    planRequestId: uuid('plan_request_id').unique(),
    // Nullable FK to users — set for user-authored plans, NULL for admin-curated plans.
    // ON DELETE SET NULL: deleting a user preserves the plan for admin review.
    ownerUserId: uuid('owner_user_id').references(() => users.id, { onDelete: 'set null' }),
    // Explicit admin publish toggle — requires is_published=true + visibility='public' +
    // at least one plan_voices row with status='ready' for end-user visibility.
    isPublished: boolean('is_published').notNull().default(false),
    // ----------------------------------------------------------------------
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    // CHECK constraint: tts_status must be one of the valid values
    check('plans_tts_status_check', sql`${table.ttsStatus} IN ('none', 'pending', 'processing', 'completed', 'partial', 'failed')`),
    // CHECK constraint: visibility must be one of the valid values
    check('plans_visibility_check', sql`${table.visibility} IN ('private', 'pending_review', 'public')`),
    // Composite index on (userId, createdAt) supersedes the old idx_plans_user_id.
    // Covers all per-user plan list queries and analytics time-range filtering.
    index('idx_plans_user_created').on(table.userId, table.createdAt),
    // Share token queries are by token only (public endpoint: GET /api/plans/shared/:token)
    index('idx_plans_share_token').on(table.shareToken),
    // Analytics: daily plan creation trends — range scan by createdAt across all users
    index('idx_plans_created_at').on(table.createdAt),
    // Analytics: funnel queries scoped to a library plan, with date filtering
    index('idx_plans_source_library').on(table.sourceLibraryPlanId, table.createdAt).where(sql`${table.sourceLibraryPlanId} IS NOT NULL`),
    // Per-series session lookup — partial keeps it small since most plans are standalone
    index('idx_plans_series').on(table.seriesId).where(sql`${table.seriesId} IS NOT NULL`),
    // Sub-plan tree: WHERE parent_plan_id = ? ORDER BY position ASC.
    // Partial keeps index small — most plans are top-level.
    index('idx_plans_parent_position').on(table.parentPlanId, table.position).where(sql`${table.parentPlanId} IS NOT NULL`),
    // Admin plan-requests queue: WHERE visibility = 'pending_review'.
    index('idx_plans_visibility_pending').on(table.visibility).where(sql`${table.visibility} = 'pending_review'`),
    // Unique partial index on plan_request_id — enables idempotent promote re-tries.
    // Partial (WHERE NOT NULL) keeps the index small; most plans are user-created (NULL).
    uniqueIndex('idx_plans_plan_request_id').on(table.planRequestId).where(sql`${table.planRequestId} IS NOT NULL`),
  ],
);

export type Plan = typeof plans.$inferSelect;
export type NewPlan = typeof plans.$inferInsert;

// ---------------------------------------------------------------------------
// series_subscriptions
//
// Tracks a user's opt-in to a series and their progress through it. One row
// per (user, series) — re-subscribing reactivates the same row rather than
// inserting a duplicate, so historical progress is preserved.
//
// Status lifecycle:
//   active     -> user is currently progressing through the series
//   paused     -> user temporarily stopped (kept for resume)
//   completed  -> all sessions done
//   cancelled  -> user opted out; unsubscribed_at set
//
// completedSessions and currentSessionIndex are denormalized read-path caches.
// They're updated when a session completion lands; the source of truth for
// completion history is session_completions joined via plans.series_id.
// ---------------------------------------------------------------------------

export const seriesSubscriptions = pgTable(
  'series_subscriptions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .references(() => users.id, { onDelete: 'cascade' })
      .notNull(),
    seriesId: uuid('series_id')
      .references(() => series.id, { onDelete: 'cascade' })
      .notNull(),
    status: text('status').notNull().default('active'), // active | paused | completed | cancelled
    currentSessionIndex: integer('current_session_index').notNull().default(0),
    completedSessions: integer('completed_sessions').notNull().default(0),
    subscribedAt: timestamp('subscribed_at', { withTimezone: true }).defaultNow().notNull(),
    lastSessionCompletedAt: timestamp('last_session_completed_at', { withTimezone: true }),
    unsubscribedAt: timestamp('unsubscribed_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    check(
      'series_subscriptions_status_check',
      sql`${table.status} IN ('active', 'paused', 'completed', 'cancelled')`,
    ),
    // One subscription row per user/series pair — reactivation updates in place
    uniqueIndex('idx_series_subscriptions_user_series').on(table.userId, table.seriesId),
    // "My active series" — partial index keeps it small (cancelled rows pile up over time)
    index('idx_series_subscriptions_user_active')
      .on(table.userId)
      .where(sql`${table.status} = 'active'`),
    // Series-level analytics: total subscribers, conversion funnels
    index('idx_series_subscriptions_series').on(table.seriesId),
    // Sync pulls: WHERE user_id = ? AND updated_at > ?
    index('idx_series_subscriptions_user_updated').on(table.userId, table.updatedAt),
  ],
);

export type SeriesSubscription = typeof seriesSubscriptions.$inferSelect;
export type NewSeriesSubscription = typeof seriesSubscriptions.$inferInsert;

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
    speechRate: numeric('speech_rate', { precision: 4, scale: 2 }).notNull().default('1.0'),
    s3Key: text('s3_key'),
    status: text('status').notNull().default('pending'), // pending | processing | completed | failed
    error: text('error'),
    attempts: integer('attempts').notNull().default(0),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    completedAt: timestamp('completed_at', { withTimezone: true }),
  },
  (table) => [
    // CHECK constraint: status must be one of the valid values
    check('tts_jobs_status_check', sql`${table.status} IN ('pending', 'processing', 'completed', 'failed')`),
    index('idx_tts_jobs_plan_id').on(table.planId),
    index('idx_tts_jobs_plan_status').on(table.planId, table.status),
    // Analytics: volume by provider/voice over time — leading createdAt for range scans
    index('idx_tts_jobs_created_provider_voice').on(table.createdAt, table.provider, table.voiceId),
    // Analytics: failure monitoring — partial index keeps it small; leading createdAt for range
    index('idx_tts_jobs_failed').on(table.createdAt).where(sql`${table.status} = 'failed'`),
  ],
);

export type TtsJob = typeof ttsJobs.$inferSelect;
export type NewTtsJob = typeof ttsJobs.$inferInsert;

// ---------------------------------------------------------------------------
// voices
//
// Registry of TTS voice profiles. Each row represents a distinct
// (provider, locale, voice-slug) combination that can be associated with
// plans via the plan_voices join table.
// is_published controls whether the voice appears in admin voice-selector
// dropdowns; internal/deprecated voices can be hidden without deletion.
// ---------------------------------------------------------------------------

export const voices = pgTable(
  'voices',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    slug: text('slug').unique().notNull(),
    displayName: text('display_name').notNull(),
    locale: text('locale').notNull(),
    provider: text('provider').notNull(),
    sampleUrl: text('sample_url'),
    isPublished: boolean('is_published').notNull().default(true),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    // Locale-filtered voice lookups: WHERE locale = ? (e.g. 'en-IN', 'en-US').
    index('idx_voices_locale').on(table.locale),
    // Admin voice-selector: WHERE is_published = true — partial keeps it small.
    index('idx_voices_published').on(table.isPublished).where(sql`${table.isPublished} = true`),
  ],
);

export type Voice = typeof voices.$inferSelect;
export type NewVoice = typeof voices.$inferInsert;

// ---------------------------------------------------------------------------
// plan_voices
//
// Per-plan TTS gate table. Each row tracks the synthesis status of one
// (plan, voice, locale) rendition. This table is the authoritative source
// for whether a plan has synthesisable audio and thus whether it is
// visible to end-users (via v_published_plans).
//
// Status lifecycle:
//   pending    → TTS job queued, not yet started
//   processing → TTS worker is actively synthesising this rendition
//   ready      → Synthesis complete; audio_url and duration_ms populated
//   failed     → Synthesis failed; error_msg set; eligible for retry
//
// UNIQUE (plan_id, voice_id, locale) prevents duplicate renditions and
// enables idempotent upserts during backfill and TTS retry operations.
// ON DELETE CASCADE on both FKs: deleting a plan/voice cleans up rows.
// ---------------------------------------------------------------------------

export const planVoices = pgTable(
  'plan_voices',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    planId: uuid('plan_id')
      .references(() => plans.id, { onDelete: 'cascade' })
      .notNull(),
    voiceId: uuid('voice_id')
      .references(() => voices.id, { onDelete: 'cascade' })
      .notNull(),
    locale: text('locale').notNull(),
    status: text('status').notNull().default('pending'), // pending | processing | ready | failed
    audioUrl: text('audio_url'),
    durationMs: integer('duration_ms'),
    errorMsg: text('error_msg'),
    generatedAt: timestamp('generated_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    // CHECK constraint: status must be one of the valid values
    check('plan_voices_status_check', sql`${table.status} IN ('pending', 'processing', 'ready', 'failed')`),
    // UNIQUE (plan_id, voice_id, locale) — prevents duplicate renditions; enables idempotent upserts
    uniqueIndex('plan_voices_plan_id_voice_id_locale_unique').on(table.planId, table.voiceId, table.locale),
    // Composite index (plan_id, status) covers:
    //   • EXISTS subquery in v_published_plans: plan_id = ? AND status = 'ready'
    //   • Admin voice-grid per-plan: WHERE plan_id = ?  (plan_id prefix used alone)
    //   • Status-filtered per-plan: WHERE plan_id = ? AND status = 'failed'
    index('idx_plan_voices_plan_status').on(table.planId, table.status),
    // Status-only index covers cross-plan admin queries and monitoring aggregations.
    index('idx_plan_voices_status').on(table.status),
  ],
);

export type PlanVoice = typeof planVoices.$inferSelect;
export type NewPlanVoice = typeof planVoices.$inferInsert;

// ---------------------------------------------------------------------------
// user_library_links
//
// Lightweight join table tracking which library plans a user has linked to
// their collection. One row per (user, library_plan) pair — strictly a link,
// never a data copy. planJson is always read from library_plans at query time
// so library content updates reach all linked users automatically.
//
// UNIQUE (user_id, library_plan_id) is the primary dedup guarantee.
// ---------------------------------------------------------------------------

export const userLibraryLinks = pgTable(
  'user_library_links',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .references(() => users.id, { onDelete: 'cascade' })
      .notNull(),
    libraryPlanId: uuid('library_plan_id')
      .references(() => libraryPlans.id, { onDelete: 'cascade' })
      .notNull(),
    lastUsedAt: timestamp('last_used_at', { withTimezone: true }),
    addedAt: timestamp('added_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    uniqueIndex('user_library_links_user_library_unique').on(table.userId, table.libraryPlanId),
    index('idx_user_library_links_user_added').on(table.userId, table.addedAt),
  ],
);

export type UserLibraryLink = typeof userLibraryLinks.$inferSelect;
export type NewUserLibraryLink = typeof userLibraryLinks.$inferInsert;

// ---------------------------------------------------------------------------
// deletion_requests
//
// Stores data-deletion requests submitted via the public website form.
// Intentionally has NO foreign key to users — we never query the users table
// during processing (email enumeration prevention). The admin reviews and
// processes requests manually via the notification email.
//
// Admin-facing columns (added in TASK-000 migration):
//   - status: 'pending' | 'processed' (default 'pending')
//   - processedAt: timestamp when admin marked as processed (nullable)
//   - ipAddress: IP of requester (nullable, for audit trail)
// ---------------------------------------------------------------------------

export const deletionRequests = pgTable(
  'deletion_requests',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    email: varchar('email').notNull(),
    scope: varchar('scope', { length: 50 }).notNull(),
    reason: text('reason'),
    requestedAt: timestamp('requested_at', { withTimezone: true }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    status: varchar('status', { length: 20 }).notNull().default('pending'),
    processedAt: timestamp('processed_at', { withTimezone: true }),
    ipAddress: varchar('ip_address'),
  },
  (table) => [
    // CHECK constraint: status must be one of the valid values
    check('deletion_requests_status_check', sql`${table.status} IN ('pending', 'processed')`),
    // Email search index (case-insensitive, for admin panel)
    index('idx_deletion_requests_email_lower').on(sql`lower(${table.email})`),
    // Partial index for efficient pending-request queries (sidebar badge count)
    index('idx_deletion_requests_status')
      .on(table.status)
      .where(sql`${table.status} = 'pending'`),
    // Index for activity feed queries (ORDER BY requested_at DESC)
    index('idx_deletion_requests_created_at').on(table.createdAt),
  ],
);

export type DeletionRequest = typeof deletionRequests.$inferSelect;
export type NewDeletionRequest = typeof deletionRequests.$inferInsert;

// ---------------------------------------------------------------------------
// plan_requests
//
// Stores user-submitted requests for plans/schedules that aren't currently in
// the curated Discover library. Submitted from the in-app "Request a Plan"
// screen. Notifications go to ADMIN_EMAIL; the admin dashboard surfaces
// pending requests.
// ---------------------------------------------------------------------------

export const planRequests = pgTable(
  'plan_requests',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id').references(() => users.id),
    email: varchar('email').notNull(),
    title: varchar('title', { length: 200 }).notNull(),
    description: text('description').notNull(),
    category: varchar('category', { length: 50 }),
    status: varchar('status', { length: 20 }).notNull().default('pending'),
    processedAt: timestamp('processed_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    check('plan_requests_status_check', sql`${table.status} IN ('pending', 'processed', 'rejected')`),
    // Partial index for admin sidebar pending-count badge.
    index('idx_plan_requests_status_pending')
      .on(table.status)
      .where(sql`${table.status} = 'pending'`),
    // Activity feed / list ordering.
    index('idx_plan_requests_created_at').on(table.createdAt),
  ],
);

export type PlanRequest = typeof planRequests.$inferSelect;
export type NewPlanRequest = typeof planRequests.$inferInsert;

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
    // Analytics: engagement/streak queries using PARTITION BY user_id window functions —
    // userId MUST lead so PostgreSQL can seek per-partition without scanning all rows
    index('idx_session_completions_user_completed').on(table.userId, table.completedAt),
    // Analytics: DAU/WAU/MAU range scans — completedAt-only queries cannot use the
    // user-leading composite index above; this standalone index serves them efficiently
    index('idx_session_completions_completed_at').on(table.completedAt),
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
    title: text('title').notNull(), // Captured at schedule time — plan name may drift later
    startUtc: timestamp('start_utc', { withTimezone: true }).notNull(),
    durationMinutes: integer('duration_minutes').notNull(),
    recurrence: text('recurrence').notNull().default('none'), // none | daily | weekdays | weekly
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
  },
  (table) => [
    // CHECK constraint: recurrence must be one of the valid values
    check('plan_triggers_recurrence_check', sql`${table.recurrence} IN ('none', 'daily', 'weekdays', 'weekly')`),
    // Sync pulls: WHERE user_id = ? AND updated_at > ?
    index('idx_plan_triggers_user_updated').on(table.userId, table.updatedAt),
    // Upcoming triggers lookup: WHERE user_id = ? AND deleted_at IS NULL AND start_utc > NOW()
    index('idx_plan_triggers_user_start').on(table.userId, table.startUtc),
  ],
);

export type PlanTrigger = typeof planTriggers.$inferSelect;
export type NewPlanTrigger = typeof planTriggers.$inferInsert;

// ---------------------------------------------------------------------------
// app_version_config
//
// Admin-managed version configuration for iOS and Android minimum supported
// and forced-update versions. A single row is maintained (created during
// migration 0008_add_app_version_config).
//
// Used by: AppVersionAdminService (admin panel) to update version requirements.
// NOT used by: AppVersionService.check() which reads from env vars only for
// blast-radius protection (DB outage should not block app launches).
// ---------------------------------------------------------------------------

export const appVersionConfig = pgTable(
  'app_version_config',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    iosMinVersion: varchar('ios_min_version', { length: 20 }),
    androidMinVersion: varchar('android_min_version', { length: 20 }),
    iosForceVersion: varchar('ios_force_version', { length: 20 }),
    androidForceVersion: varchar('android_force_version', { length: 20 }),
    forceUpdateEnabled: boolean('force_update_enabled').notNull().default(false),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (_table) => [
    // Singleton constraint: enforces at most one row in the table.
    // The expression ((true)) ensures only one row can exist: only one value of true exists.
    uniqueIndex('idx_app_version_config_singleton').on(sql`true`),
  ],
);

export type AppVersionConfig = typeof appVersionConfig.$inferSelect;
export type NewAppVersionConfig = typeof appVersionConfig.$inferInsert;

// ---------------------------------------------------------------------------
// plan_ratings
//
// Stores a user's 1–5 star rating for a library plan.
// One row per (user, plan) — upsert replaces the previous rating.
// Aggregate stats (averageRating, ratingsCount) are computed on read via
// a GROUP BY query to avoid stale denormalized data.
// ---------------------------------------------------------------------------

export const planRatings = pgTable(
  'plan_ratings',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .references(() => users.id, { onDelete: 'cascade' })
      .notNull(),
    planId: uuid('plan_id').notNull(),
    rating: integer('rating').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    check('plan_ratings_value_check', sql`${table.rating} >= 1 AND ${table.rating} <= 5`),
    // One rating per user per plan — enables idempotent upsert on (user_id, plan_id)
    uniqueIndex('idx_plan_ratings_user_plan').on(table.userId, table.planId),
    // Aggregate queries: GROUP BY plan_id for average rating computation
    index('idx_plan_ratings_plan_id').on(table.planId),
  ],
);

export type PlanRating = typeof planRatings.$inferSelect;
export type NewPlanRating = typeof planRatings.$inferInsert;

// ---------------------------------------------------------------------------
// user_favorites
//
// Tracks which library plans a user has marked as a favorite.
// Effectively a "Favorites" named list (as described in requirements).
// One row per (user, plan) — toggle via insert / delete.
// ---------------------------------------------------------------------------

export const userFavorites = pgTable(
  'user_favorites',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .references(() => users.id, { onDelete: 'cascade' })
      .notNull(),
    planId: uuid('plan_id').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    // One favorite per user per plan — enables idempotent insert on conflict
    uniqueIndex('idx_user_favorites_user_plan').on(table.userId, table.planId),
    // User's favorite list ordered by creation time
    index('idx_user_favorites_user_created').on(table.userId, table.createdAt),
  ],
);

export type UserFavorite = typeof userFavorites.$inferSelect;
export type NewUserFavorite = typeof userFavorites.$inferInsert;
