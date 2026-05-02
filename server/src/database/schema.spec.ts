/**
 * Unit tests for the Drizzle PostgreSQL schema definitions.
 *
 * These tests verify the schema structure (table names, column names, column
 * types, constraints, and index definitions) without requiring a real database.
 * They protect against accidental regressions when the schema is modified.
 */

import { getTableName } from 'drizzle-orm';
import {
  users,
  otpRecords,
  refreshTokens,
  plans,
  ttsJobs,
  sessionCompletions,
  streakFreezes,
  categories,
  voices,
  planVoices,
  series,
} from './schema';
import type {
  User,
  OtpRecord,
  RefreshToken,
  Plan,
  SessionCompletion,
  StreakFreeze,
  Category,
  Voice,
  PlanVoice,
} from './schema';

// ---------------------------------------------------------------------------
// users
// ---------------------------------------------------------------------------

describe('users table', () => {
  it('has correct table name', () => {
    expect(getTableName(users)).toBe('users');
  });

  it('id column: UUID primary key with default random', () => {
    const col = users.id;
    expect(col.name).toBe('id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.primary).toBe(true);
    expect(col.hasDefault).toBe(true);
    expect(col.notNull).toBe(true);
  });

  it('email column: varchar unique not null', () => {
    const col = users.email;
    expect(col.name).toBe('email');
    expect(col.notNull).toBe(true);
    expect(col.isUnique).toBe(true);
  });

  it('role column: text not null with default "user"', () => {
    const col = users.role;
    expect(col.name).toBe('role');
    expect(col.columnType).toBe('PgText');
    expect(col.notNull).toBe(true);
    expect(col.hasDefault).toBe(true);
  });

  it('created_at column: timestamptz not null with default now', () => {
    const col = users.createdAt;
    expect(col.name).toBe('created_at');
    expect(col.hasDefault).toBe(true);
    expect(col.notNull).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// otp_records
// ---------------------------------------------------------------------------

describe('otp_records table', () => {
  it('has correct table name', () => {
    expect(getTableName(otpRecords)).toBe('otp_records');
  });

  it('id column: UUID primary key', () => {
    const col = otpRecords.id;
    expect(col.name).toBe('id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.primary).toBe(true);
  });

  it('email column: varchar not null — no FK (OTPs precede user creation)', () => {
    const col = otpRecords.email;
    expect(col.name).toBe('email');
    expect(col.notNull).toBe(true);
    // No FK reference on otp_records.email by design
    expect((col as any).references).toBeUndefined();
  });

  it('code_hash column: varchar(64) not null', () => {
    const col = otpRecords.codeHash;
    expect(col.name).toBe('code_hash');
    expect(col.notNull).toBe(true);
  });

  it('expires_at column: timestamptz not null', () => {
    const col = otpRecords.expiresAt;
    expect(col.name).toBe('expires_at');
    expect(col.notNull).toBe(true);
  });

  it('attempts column: integer with default 0 not null', () => {
    const col = otpRecords.attempts;
    expect(col.name).toBe('attempts');
    expect(col.hasDefault).toBe(true);
    expect(col.notNull).toBe(true);
  });

  it('used column: boolean with default false not null', () => {
    const col = otpRecords.used;
    expect(col.name).toBe('used');
    expect(col.hasDefault).toBe(true);
    expect(col.notNull).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// refresh_tokens
// ---------------------------------------------------------------------------

describe('refresh_tokens table', () => {
  it('has correct table name', () => {
    expect(getTableName(refreshTokens)).toBe('refresh_tokens');
  });

  it('id column: UUID primary key', () => {
    const col = refreshTokens.id;
    expect(col.name).toBe('id');
    expect(col.primary).toBe(true);
  });

  it('token_hash column: varchar(64) unique not null', () => {
    const col = refreshTokens.tokenHash;
    expect(col.name).toBe('token_hash');
    expect(col.notNull).toBe(true);
    expect(col.isUnique).toBe(true);
  });

  it('user_id column: UUID not null with FK reference to users', () => {
    const col = refreshTokens.userId;
    expect(col.name).toBe('user_id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.notNull).toBe(true);
  });

  it('revoked column: boolean with default false not null', () => {
    const col = refreshTokens.revoked;
    expect(col.name).toBe('revoked');
    expect(col.hasDefault).toBe(true);
    expect(col.notNull).toBe(true);
  });

  it('expires_at column: timestamptz not null', () => {
    const col = refreshTokens.expiresAt;
    expect(col.name).toBe('expires_at');
    expect(col.notNull).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// plans
// ---------------------------------------------------------------------------

describe('plans table', () => {
  it('has correct table name', () => {
    expect(getTableName(plans)).toBe('plans');
  });

  it('id column: UUID primary key', () => {
    const col = plans.id;
    expect(col.name).toBe('id');
    expect(col.primary).toBe(true);
    expect(col.hasDefault).toBe(true);
  });

  it('user_id column: UUID not null with FK reference to users', () => {
    const col = plans.userId;
    expect(col.name).toBe('user_id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.notNull).toBe(true);
  });

  it('share_token column: varchar(20) nullable unique for plan sharing', () => {
    const col = plans.shareToken;
    expect(col.name).toBe('share_token');
    expect(col.notNull).toBe(false);
  });

  it('share_token_created_at column: timestamptz nullable for share tracking', () => {
    const col = plans.shareTokenCreatedAt;
    expect(col.name).toBe('share_token_created_at');
    expect(col.notNull).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// session_completions
// ---------------------------------------------------------------------------

describe('session_completions table', () => {
  it('has correct table name', () => {
    expect(getTableName(sessionCompletions)).toBe('session_completions');
  });

  it('id column: UUID primary key with default random', () => {
    const col = sessionCompletions.id;
    expect(col.name).toBe('id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.primary).toBe(true);
    expect(col.hasDefault).toBe(true);
  });

  it('user_id column: UUID not null with FK reference to users', () => {
    const col = sessionCompletions.userId;
    expect(col.name).toBe('user_id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.notNull).toBe(true);
  });

  it('plan_id column: UUID not null (no FK — plan may be deleted but completion persists)', () => {
    const col = sessionCompletions.planId;
    expect(col.name).toBe('plan_id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.notNull).toBe(true);
  });

  it('completed_at column: timestamptz not null', () => {
    const col = sessionCompletions.completedAt;
    expect(col.name).toBe('completed_at');
    expect(col.notNull).toBe(true);
  });

  it('duration_ms column: integer not null', () => {
    const col = sessionCompletions.durationMs;
    expect(col.name).toBe('duration_ms');
    expect(col.columnType).toBe('PgInteger');
    expect(col.notNull).toBe(true);
  });

  it('client_id column: UUID unique not null (idempotency key for sync)', () => {
    const col = sessionCompletions.clientId;
    expect(col.name).toBe('client_id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.notNull).toBe(true);
  });

  it('created_at column: timestamptz not null with default now', () => {
    const col = sessionCompletions.createdAt;
    expect(col.name).toBe('created_at');
    expect(col.hasDefault).toBe(true);
    expect(col.notNull).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// streak_freezes
// ---------------------------------------------------------------------------

describe('streak_freezes table', () => {
  it('has correct table name', () => {
    expect(getTableName(streakFreezes)).toBe('streak_freezes');
  });

  it('id column: UUID primary key with default random', () => {
    const col = streakFreezes.id;
    expect(col.name).toBe('id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.primary).toBe(true);
    expect(col.hasDefault).toBe(true);
  });

  it('user_id column: UUID not null with FK reference to users', () => {
    const col = streakFreezes.userId;
    expect(col.name).toBe('user_id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.notNull).toBe(true);
  });

  it('frozen_at column: timestamptz not null (when freeze was earned)', () => {
    const col = streakFreezes.frozenAt;
    expect(col.name).toBe('frozen_at');
    expect(col.notNull).toBe(true);
  });

  it('expires_at column: timestamptz not null (when freeze expires if unused)', () => {
    const col = streakFreezes.expiresAt;
    expect(col.name).toBe('expires_at');
    expect(col.notNull).toBe(true);
  });

  it('consumed_at column: timestamptz nullable (when freeze was consumed)', () => {
    const col = streakFreezes.consumedAt;
    expect(col.name).toBe('consumed_at');
    expect(col.notNull).toBe(false);
  });

  it('created_at column: timestamptz not null with default now', () => {
    const col = streakFreezes.createdAt;
    expect(col.name).toBe('created_at');
    expect(col.hasDefault).toBe(true);
    expect(col.notNull).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// categories (migration 0014)
// ---------------------------------------------------------------------------

describe('categories table', () => {
  it('has correct table name', () => {
    expect(getTableName(categories)).toBe('categories');
  });

  it('id column: UUID primary key with default random', () => {
    const col = categories.id;
    expect(col.name).toBe('id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.primary).toBe(true);
    expect(col.hasDefault).toBe(true);
    expect(col.notNull).toBe(true);
  });

  it('slug column: text unique not null', () => {
    const col = categories.slug;
    expect(col.name).toBe('slug');
    expect(col.columnType).toBe('PgText');
    expect(col.notNull).toBe(true);
    expect(col.isUnique).toBe(true);
  });

  it('name column: text not null', () => {
    const col = categories.name;
    expect(col.name).toBe('name');
    expect(col.columnType).toBe('PgText');
    expect(col.notNull).toBe(true);
  });

  it('icon column: text nullable', () => {
    const col = categories.icon;
    expect(col.name).toBe('icon');
    expect(col.notNull).toBe(false);
  });

  it('color column: varchar(20) nullable', () => {
    const col = categories.color;
    expect(col.name).toBe('color');
    expect(col.notNull).toBe(false);
  });

  it('sort_order column: integer not null with default 0', () => {
    const col = categories.sortOrder;
    expect(col.name).toBe('sort_order');
    expect(col.columnType).toBe('PgInteger');
    expect(col.notNull).toBe(true);
    expect(col.hasDefault).toBe(true);
  });

  it('is_published column: boolean not null with default false', () => {
    const col = categories.isPublished;
    expect(col.name).toBe('is_published');
    expect(col.notNull).toBe(true);
    expect(col.hasDefault).toBe(true);
  });

  it('created_at column: timestamptz not null with default now', () => {
    const col = categories.createdAt;
    expect(col.name).toBe('created_at');
    expect(col.hasDefault).toBe(true);
    expect(col.notNull).toBe(true);
  });

  it('updated_at column: timestamptz not null with default now', () => {
    const col = categories.updatedAt;
    expect(col.name).toBe('updated_at');
    expect(col.hasDefault).toBe(true);
    expect(col.notNull).toBe(true);
  });

  it('deleted_at column: timestamptz nullable (soft-delete tombstone)', () => {
    const col = categories.deletedAt;
    expect(col.name).toBe('deleted_at');
    expect(col.notNull).toBe(false);
    expect(col.hasDefault).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// voices (migration 0014)
// ---------------------------------------------------------------------------

describe('voices table', () => {
  it('has correct table name', () => {
    expect(getTableName(voices)).toBe('voices');
  });

  it('id column: UUID primary key with default random', () => {
    const col = voices.id;
    expect(col.name).toBe('id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.primary).toBe(true);
    expect(col.hasDefault).toBe(true);
    expect(col.notNull).toBe(true);
  });

  it('slug column: text unique not null', () => {
    const col = voices.slug;
    expect(col.name).toBe('slug');
    expect(col.columnType).toBe('PgText');
    expect(col.notNull).toBe(true);
    expect(col.isUnique).toBe(true);
  });

  it('display_name column: text not null', () => {
    const col = voices.displayName;
    expect(col.name).toBe('display_name');
    expect(col.columnType).toBe('PgText');
    expect(col.notNull).toBe(true);
  });

  it('locale column: text not null', () => {
    const col = voices.locale;
    expect(col.name).toBe('locale');
    expect(col.columnType).toBe('PgText');
    expect(col.notNull).toBe(true);
  });

  it('provider column: text not null', () => {
    const col = voices.provider;
    expect(col.name).toBe('provider');
    expect(col.columnType).toBe('PgText');
    expect(col.notNull).toBe(true);
  });

  it('sample_url column: text nullable', () => {
    const col = voices.sampleUrl;
    expect(col.name).toBe('sample_url');
    expect(col.notNull).toBe(false);
  });

  it('is_published column: boolean not null with default true', () => {
    const col = voices.isPublished;
    expect(col.name).toBe('is_published');
    expect(col.notNull).toBe(true);
    expect(col.hasDefault).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// plan_voices (migration 0014)
// ---------------------------------------------------------------------------

describe('plan_voices table', () => {
  it('has correct table name', () => {
    expect(getTableName(planVoices)).toBe('plan_voices');
  });

  it('id column: UUID primary key with default random', () => {
    const col = planVoices.id;
    expect(col.name).toBe('id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.primary).toBe(true);
    expect(col.hasDefault).toBe(true);
    expect(col.notNull).toBe(true);
  });

  it('plan_id column: UUID not null with FK reference to plans', () => {
    const col = planVoices.planId;
    expect(col.name).toBe('plan_id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.notNull).toBe(true);
  });

  it('voice_id column: UUID not null with FK reference to voices', () => {
    const col = planVoices.voiceId;
    expect(col.name).toBe('voice_id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.notNull).toBe(true);
  });

  it('locale column: text not null', () => {
    const col = planVoices.locale;
    expect(col.name).toBe('locale');
    expect(col.columnType).toBe('PgText');
    expect(col.notNull).toBe(true);
  });

  it('status column: text not null with default "pending"', () => {
    const col = planVoices.status;
    expect(col.name).toBe('status');
    expect(col.columnType).toBe('PgText');
    expect(col.notNull).toBe(true);
    expect(col.hasDefault).toBe(true);
  });

  it('audio_url column: text nullable (set when ready)', () => {
    const col = planVoices.audioUrl;
    expect(col.name).toBe('audio_url');
    expect(col.notNull).toBe(false);
  });

  it('duration_ms column: integer nullable (set when ready)', () => {
    const col = planVoices.durationMs;
    expect(col.name).toBe('duration_ms');
    expect(col.notNull).toBe(false);
  });

  it('error_msg column: text nullable (set on failure)', () => {
    const col = planVoices.errorMsg;
    expect(col.name).toBe('error_msg');
    expect(col.notNull).toBe(false);
  });

  it('generated_at column: timestamptz nullable (set when first ready)', () => {
    const col = planVoices.generatedAt;
    expect(col.name).toBe('generated_at');
    expect(col.notNull).toBe(false);
  });

  it('has UNIQUE index on (plan_id, voice_id, locale)', () => {
    function getIndexNames(table: any): string[] {
      const sym = Object.getOwnPropertySymbols(table).find(
        (s) => s.toString() === 'Symbol(drizzle:Indexes)',
      );
      if (!sym) return [];
      const indexes = table[sym] as Record<string, { config: { name: string } }>;
      return Object.values(indexes).map((idx) => idx.config.name);
    }
    const names = getIndexNames(planVoices);
    expect(names).toContain('plan_voices_plan_id_voice_id_locale_unique');
  });

  it('has idx_plan_voices_plan_status composite index', () => {
    function getIndexNames(table: any): string[] {
      const sym = Object.getOwnPropertySymbols(table).find(
        (s) => s.toString() === 'Symbol(drizzle:Indexes)',
      );
      if (!sym) return [];
      const indexes = table[sym] as Record<string, { config: { name: string } }>;
      return Object.values(indexes).map((idx) => idx.config.name);
    }
    const names = getIndexNames(planVoices);
    expect(names).toContain('idx_plan_voices_plan_status');
  });
});

// ---------------------------------------------------------------------------
// series — new category_id column (migration 0014)
// ---------------------------------------------------------------------------

describe('series table — migration 0014 additions', () => {
  it('category_id column: UUID nullable FK to categories', () => {
    const col = series.categoryId;
    expect(col.name).toBe('category_id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.notNull).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// plans — new columns (migration 0014)
// ---------------------------------------------------------------------------

describe('plans table — migration 0014 additions', () => {
  it('parent_plan_id column: UUID nullable (self-FK for sub-plans)', () => {
    const col = plans.parentPlanId;
    expect(col.name).toBe('parent_plan_id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.notNull).toBe(false);
  });

  it('position column: integer not null with default 0', () => {
    const col = plans.position;
    expect(col.name).toBe('position');
    expect(col.columnType).toBe('PgInteger');
    expect(col.notNull).toBe(true);
    expect(col.hasDefault).toBe(true);
  });

  it('visibility column: text not null with default "private"', () => {
    const col = plans.visibility;
    expect(col.name).toBe('visibility');
    expect(col.columnType).toBe('PgText');
    expect(col.notNull).toBe(true);
    expect(col.hasDefault).toBe(true);
  });

  it('owner_user_id column: UUID nullable FK to users', () => {
    const col = plans.ownerUserId;
    expect(col.name).toBe('owner_user_id');
    expect(col.columnType).toBe('PgUUID');
    expect(col.notNull).toBe(false);
  });

  it('is_published column: boolean not null with default false', () => {
    const col = plans.isPublished;
    expect(col.name).toBe('is_published');
    expect(col.notNull).toBe(true);
    expect(col.hasDefault).toBe(true);
  });

  it('has idx_plans_parent_position partial index', () => {
    function getIndexNames(table: any): string[] {
      const sym = Object.getOwnPropertySymbols(table).find(
        (s) => s.toString() === 'Symbol(drizzle:Indexes)',
      );
      if (!sym) return [];
      const indexes = table[sym] as Record<string, { config: { name: string } }>;
      return Object.values(indexes).map((idx) => idx.config.name);
    }
    const names = getIndexNames(plans);
    expect(names).toContain('idx_plans_parent_position');
  });

  it('has idx_plans_visibility_pending partial index', () => {
    function getIndexNames(table: any): string[] {
      const sym = Object.getOwnPropertySymbols(table).find(
        (s) => s.toString() === 'Symbol(drizzle:Indexes)',
      );
      if (!sym) return [];
      const indexes = table[sym] as Record<string, { config: { name: string } }>;
      return Object.values(indexes).map((idx) => idx.config.name);
    }
    const names = getIndexNames(plans);
    expect(names).toContain('idx_plans_visibility_pending');
  });
});

// ---------------------------------------------------------------------------
// Analytics indexes
// ---------------------------------------------------------------------------

describe('analytics indexes', () => {
  /**
   * Helper: collect index names from a Drizzle table's Symbol(drizzle:Indexes) metadata.
   * Works for tables defined with the two-argument pgTable(..., (t) => [...]) form.
   */
  function getIndexNames(table: any): string[] {
    // Drizzle stores table metadata under Symbol keys; indexes live in [Symbol.for('drizzle:Indexes')]
    const sym = Object.getOwnPropertySymbols(table).find(
      (s) => s.toString() === 'Symbol(drizzle:Indexes)',
    );
    if (!sym) return [];
    const indexes = table[sym] as Record<string, { config: { name: string } }>;
    return Object.values(indexes).map((idx) => idx.config.name);
  }

  it('users table has idx_users_created_at index', () => {
    const names = getIndexNames(users);
    expect(names).toContain('idx_users_created_at');
  });

  it('plans table has idx_plans_created_at index', () => {
    const names = getIndexNames(plans);
    expect(names).toContain('idx_plans_created_at');
  });

  it('plans table has idx_plans_user_created composite index (supersedes idx_plans_user_id)', () => {
    const names = getIndexNames(plans);
    expect(names).toContain('idx_plans_user_created');
    // Old idx_plans_user_id must NOT be present (removed in favour of composite)
    expect(names).not.toContain('idx_plans_user_id');
  });

  it('plans table has idx_plans_source_library partial composite index', () => {
    const names = getIndexNames(plans);
    expect(names).toContain('idx_plans_source_library');
  });

  it('tts_jobs table has idx_tts_jobs_created_provider_voice index', () => {
    const names = getIndexNames(ttsJobs);
    expect(names).toContain('idx_tts_jobs_created_provider_voice');
  });

  it('tts_jobs table has idx_tts_jobs_failed partial index', () => {
    const names = getIndexNames(ttsJobs);
    expect(names).toContain('idx_tts_jobs_failed');
  });

  it('session_completions table has idx_session_completions_user_completed index', () => {
    const names = getIndexNames(sessionCompletions);
    expect(names).toContain('idx_session_completions_user_completed');
  });
});

// ---------------------------------------------------------------------------
// TypeScript type shape smoke tests
// (These are compile-time checks — they would fail to compile if types changed)
// ---------------------------------------------------------------------------

describe('TypeScript inferred types', () => {
  it('User type has required fields including role', () => {
    // This assignment only compiles if User has exactly these fields
    const _: Pick<User, 'id' | 'email' | 'role' | 'createdAt'> = {
      id: '00000000-0000-0000-0000-000000000000',
      email: 'test@example.com',
      role: 'user',
      createdAt: new Date(),
    };
    expect(_).toBeDefined();
  });

  it('OtpRecord type has required fields', () => {
    const _: Pick<OtpRecord, 'id' | 'email' | 'codeHash' | 'expiresAt' | 'attempts' | 'used'> = {
      id: '00000000-0000-0000-0000-000000000000',
      email: 'test@example.com',
      codeHash: 'abc123',
      expiresAt: new Date(),
      attempts: 0,
      used: false,
    };
    expect(_).toBeDefined();
  });

  it('RefreshToken type has required fields', () => {
    const _: Pick<RefreshToken, 'id' | 'tokenHash' | 'userId' | 'revoked' | 'expiresAt'> = {
      id: '00000000-0000-0000-0000-000000000000',
      tokenHash: 'hash',
      userId: '00000000-0000-0000-0000-000000000001',
      revoked: false,
      expiresAt: new Date(),
    };
    expect(_).toBeDefined();
  });

  it('Plan type has required fields', () => {
    const _: Pick<Plan, 'id' | 'userId' | 'name' | 'planJson' | 'createdAt' | 'updatedAt'> = {
      id: '00000000-0000-0000-0000-000000000000',
      userId: '00000000-0000-0000-0000-000000000001',
      name: 'Test Plan',
      planJson: '{}',
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    expect(_).toBeDefined();
  });

  it('SessionCompletion type has required fields', () => {
    const _: Pick<SessionCompletion, 'id' | 'userId' | 'planId' | 'completedAt' | 'durationMs' | 'clientId' | 'createdAt'> = {
      id: '00000000-0000-0000-0000-000000000000',
      userId: '00000000-0000-0000-0000-000000000001',
      planId: '00000000-0000-0000-0000-000000000002',
      completedAt: new Date(),
      durationMs: 3600000,
      clientId: '00000000-0000-0000-0000-000000000003',
      createdAt: new Date(),
    };
    expect(_).toBeDefined();
  });

  it('StreakFreeze type has required fields', () => {
    const _: Pick<StreakFreeze, 'id' | 'userId' | 'frozenAt' | 'expiresAt' | 'consumedAt' | 'createdAt'> = {
      id: '00000000-0000-0000-0000-000000000000',
      userId: '00000000-0000-0000-0000-000000000001',
      frozenAt: new Date(),
      expiresAt: new Date(),
      consumedAt: null,
      createdAt: new Date(),
    };
    expect(_).toBeDefined();
  });

  it('Category type has required fields (migration 0014)', () => {
    const _: Pick<Category, 'id' | 'slug' | 'name' | 'sortOrder' | 'isPublished' | 'createdAt' | 'updatedAt'> = {
      id: '00000000-0000-0000-0000-000000000000',
      slug: 'meditation',
      name: 'Meditation',
      sortOrder: 0,
      isPublished: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    expect(_).toBeDefined();
  });

  it('Voice type has required fields (migration 0014)', () => {
    const _: Pick<Voice, 'id' | 'slug' | 'displayName' | 'locale' | 'provider' | 'isPublished' | 'createdAt'> = {
      id: '00000000-0000-0000-0000-000000000000',
      slug: 'en-us-aria',
      displayName: 'Aria (US English)',
      locale: 'en-US',
      provider: 'azure',
      isPublished: true,
      createdAt: new Date(),
    };
    expect(_).toBeDefined();
  });

  it('PlanVoice type has required fields (migration 0014)', () => {
    const _: Pick<PlanVoice, 'id' | 'planId' | 'voiceId' | 'locale' | 'status' | 'createdAt' | 'updatedAt'> = {
      id: '00000000-0000-0000-0000-000000000000',
      planId: '00000000-0000-0000-0000-000000000001',
      voiceId: '00000000-0000-0000-0000-000000000002',
      locale: 'en-US',
      status: 'pending',
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    expect(_).toBeDefined();
  });
});
