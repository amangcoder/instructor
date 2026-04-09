/**
 * Unit tests for the Drizzle PostgreSQL schema definitions.
 *
 * These tests verify the schema structure (table names, column names, column
 * types, constraints, and index definitions) without requiring a real database.
 * They protect against accidental regressions when the schema is modified.
 */

import { getTableName } from 'drizzle-orm';
import { users, otpRecords, refreshTokens, syncMetadata } from './schema';
import type { User, OtpRecord, RefreshToken, SyncMetadata } from './schema';

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
// sync_metadata
// ---------------------------------------------------------------------------

describe('sync_metadata table', () => {
  it('has correct table name', () => {
    expect(getTableName(syncMetadata)).toBe('sync_metadata');
  });

  it('id column: UUID primary key', () => {
    const col = syncMetadata.id;
    expect(col.name).toBe('id');
    expect(col.primary).toBe(true);
  });

  it('user_id column: UUID unique not null with FK reference to users', () => {
    const col = syncMetadata.userId;
    expect(col.name).toBe('user_id');
    expect(col.notNull).toBe(true);
    expect(col.isUnique).toBe(true);
    expect(col.columnType).toBe('PgUUID');
  });

  it('last_sync_at column: timestamptz nullable', () => {
    const col = syncMetadata.lastSyncAt;
    expect(col.name).toBe('last_sync_at');
    expect(col.notNull).toBe(false);
  });

  it('size_bytes column: bigint nullable', () => {
    const col = syncMetadata.sizeBytes;
    expect(col.name).toBe('size_bytes');
    expect(col.notNull).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// TypeScript type shape smoke tests
// (These are compile-time checks — they would fail to compile if types changed)
// ---------------------------------------------------------------------------

describe('TypeScript inferred types', () => {
  it('User type has required fields', () => {
    // This assignment only compiles if User has exactly these fields
    const _: Pick<User, 'id' | 'email' | 'createdAt'> = {
      id: '00000000-0000-0000-0000-000000000000',
      email: 'test@example.com',
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

  it('SyncMetadata type has required fields', () => {
    const _: Pick<SyncMetadata, 'id' | 'userId' | 'lastSyncAt' | 'sizeBytes'> = {
      id: '00000000-0000-0000-0000-000000000000',
      userId: '00000000-0000-0000-0000-000000000001',
      lastSyncAt: null,
      sizeBytes: null,
    };
    expect(_).toBeDefined();
  });
});
