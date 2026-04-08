/**
 * E2E auth flow tests (migrated to DynamoDB + SES + DynamoDBRateLimiter).
 *
 * These tests exercise the full HTTP layer end-to-end without hitting real
 * AWS services. All dependencies (SES email, DynamoDB, rate limiter, JWT)
 * use in-memory implementations so tests run deterministically without
 * any network access.
 *
 * Endpoints tested:
 *   POST /api/auth/request-otp
 *   POST /api/auth/verify-otp
 *   POST /api/auth/refresh
 *   POST /api/auth/logout
 *   Protected endpoints requiring valid JWT
 *
 * OTP capture strategy:
 *   SESEmailService.sendOtpEmail is replaced with an in-memory mock that
 *   captures the 6-digit OTP for each email address. Tests then use the
 *   captured OTP to call verify-otp, mirroring real user behaviour.
 */

import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe, HttpStatus } from '@nestjs/common';
import * as request from 'supertest';
import { App } from 'supertest/types';

// ---------------------------------------------------------------------------
// In-memory DynamoDBService implementation
//
// Provides stateful entity storage without any real AWS calls.
// Implements the full DynamoDBService interface used by AuthService/SyncService.
// ---------------------------------------------------------------------------

class InMemoryDynamoDBService {
  private users = new Map<string, { id: string; email: string; createdAt: Date }>();
  private usersByEmail = new Map<string, { id: string; email: string; createdAt: Date }>();
  private otps = new Map<
    string,
    Array<{ email: string; code: string; attempts: number; used: boolean; expiresAt: Date; sk: string }>
  >();
  private refreshTokens = new Map<
    string,
    { userId: string; tokenHash: string; revoked: boolean; expiresAt: Date; sk: string }
  >();
  private syncMetadata = new Map<string, { userId: string; lastSyncAt: Date | null; sizeBytes: number | null }>();

  async getUserById(userId: string) {
    return this.users.get(userId) ?? null;
  }

  async getUserByEmail(email: string) {
    return this.usersByEmail.get(email) ?? null;
  }

  async createUser(user: { id: string; email: string; createdAt: Date }) {
    this.users.set(user.id, user);
    this.usersByEmail.set(user.email, user);
  }

  async createOtp(email: string, codeHash: string, expiresAt: Date) {
    const existing = this.otps.get(email) ?? [];
    existing.push({
      email,
      code: codeHash,
      attempts: 0,
      used: false,
      expiresAt,
      sk: `${new Date().toISOString()}#${Math.random().toString(36).slice(2)}`,
    });
    this.otps.set(email, existing);
  }

  async getActiveOtps(email: string) {
    const records = this.otps.get(email) ?? [];
    const now = new Date();
    return records.filter((r) => !r.used && r.expiresAt > now);
  }

  async markOtpUsed(email: string, sk: string) {
    const records = this.otps.get(email) ?? [];
    const record = records.find((r) => r.sk === sk);
    if (record) record.used = true;
  }

  async incrementOtpAttempts(email: string, sk: string, currentAttempts: number) {
    const records = this.otps.get(email) ?? [];
    const record = records.find((r) => r.sk === sk);
    if (record) record.attempts = currentAttempts + 1;
  }

  async invalidateOtpsForEmail(email: string) {
    const records = this.otps.get(email) ?? [];
    records.forEach((r) => {
      r.used = true;
    });
  }

  async createRefreshToken(userId: string, tokenHash: string, expiresAt: Date) {
    this.refreshTokens.set(tokenHash, { userId, tokenHash, revoked: false, expiresAt, sk: 'TOKEN' });
  }

  async getRefreshToken(tokenHash: string) {
    const token = this.refreshTokens.get(tokenHash);
    if (!token || token.revoked || token.expiresAt < new Date()) return null;
    return token;
  }

  async revokeRefreshToken(_userId: string, tokenHash: string) {
    const token = this.refreshTokens.get(tokenHash);
    if (token) token.revoked = true;
  }

  async revokeAllRefreshTokens(userId: string) {
    for (const token of this.refreshTokens.values()) {
      if (token.userId === userId) token.revoked = true;
    }
  }

  async getSyncMetadata(userId: string) {
    return this.syncMetadata.get(userId) ?? null;
  }

  async upsertSyncMetadata(userId: string, lastSyncAt: Date, sizeBytes?: number) {
    this.syncMetadata.set(userId, { userId, lastSyncAt, sizeBytes: sizeBytes ?? null });
  }

  clear() {
    this.users.clear();
    this.usersByEmail.clear();
    this.otps.clear();
    this.refreshTokens.clear();
    this.syncMetadata.clear();
  }
}

// ---------------------------------------------------------------------------
// In-memory DynamoDBRateLimitService (fixed-window counter)
// ---------------------------------------------------------------------------

class InMemoryRateLimiter {
  private counters = new Map<string, { count: number; expiresAt: number }>();

  async consume(namespace: string, identifier: string, limit: number, windowSec: number) {
    const key = `${namespace}:${identifier}`;
    const now = Math.floor(Date.now() / 1000);
    const entry = this.counters.get(key);

    if (!entry || entry.expiresAt <= now) {
      this.counters.set(key, { count: 1, expiresAt: now + windowSec });
      return { allowed: true, current: 1, retryAfterSec: 0 };
    }

    if (entry.count >= limit) {
      return { allowed: false, current: entry.count, retryAfterSec: entry.expiresAt - now };
    }

    entry.count++;
    return { allowed: true, current: entry.count, retryAfterSec: 0 };
  }

  async peek(namespace: string, identifier: string, limit: number) {
    const key = `${namespace}:${identifier}`;
    const now = Math.floor(Date.now() / 1000);
    const entry = this.counters.get(key);
    const count = entry && entry.expiresAt > now ? entry.count : 0;
    const allowed = count < limit;
    return {
      allowed,
      current: count,
      retryAfterSec: allowed ? 0 : Math.max(0, (entry?.expiresAt ?? 0) - now),
    };
  }

  async increment(namespace: string, identifier: string, windowSec: number) {
    const key = `${namespace}:${identifier}`;
    const now = Math.floor(Date.now() / 1000);
    const entry = this.counters.get(key);

    if (!entry || entry.expiresAt <= now) {
      this.counters.set(key, { count: 1, expiresAt: now + windowSec });
    } else {
      entry.count++;
    }
  }

  clear() {
    this.counters.clear();
  }
}

// ---------------------------------------------------------------------------
// In-memory SESEmailService — captures OTPs for test inspection
// ---------------------------------------------------------------------------

/** OTPs captured from sendOtpEmail calls: email → latest 6-digit code. */
const capturedOtps = new Map<string, string>();

const mockSendOtpEmail = jest.fn(async (email: string, code: string) => {
  capturedOtps.set(email, code);
});

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

describe('Auth (e2e)', () => {
  let app: INestApplication<App>;
  let inMemoryDynamo: InMemoryDynamoDBService;
  let inMemoryRateLimiter: InMemoryRateLimiter;

  beforeAll(async () => {
    let AppModule: new () => object;
    let DynamoDBService: unknown;
    let SESEmailService: unknown;
    let DynamoDBRateLimitService: unknown;

    try {
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      ({ AppModule } = require('../src/app.module'));
    } catch {
      console.warn(
        '[auth.e2e] AppModule not found — tests will be skipped until TASK-004/005/006/007 are implemented',
      );
      return;
    }

    try {
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      ({ DynamoDBService } = require('../src/dynamodb/dynamodb.service'));
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      ({ SESEmailService } = require('../src/email/ses-email.service'));
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      ({ DynamoDBRateLimitService } = require('../src/ratelimit/dynamodb-ratelimit.service'));
    } catch {
      console.warn('[auth.e2e] New service classes not yet available');
    }

    inMemoryDynamo = new InMemoryDynamoDBService();
    inMemoryRateLimiter = new InMemoryRateLimiter();

    let builder = Test.createTestingModule({
      imports: [AppModule],
    });

    if (DynamoDBService) {
      builder = builder.overrideProvider(DynamoDBService).useValue(inMemoryDynamo);
    }
    if (SESEmailService) {
      builder = builder.overrideProvider(SESEmailService).useValue({ sendOtpEmail: mockSendOtpEmail });
    }
    if (DynamoDBRateLimitService) {
      builder = builder.overrideProvider(DynamoDBRateLimitService).useValue(inMemoryRateLimiter);
    }

    const moduleFixture: TestingModule = await builder.compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    app.setGlobalPrefix('api');
    await app.init();
  });

  afterAll(async () => {
    await app?.close();
  });

  beforeEach(() => {
    capturedOtps.clear();
    mockSendOtpEmail.mockClear();
    inMemoryDynamo?.clear();
    inMemoryRateLimiter?.clear();
  });

  function skipIfNoApp() {
    if (!app) pending('Auth module not implemented yet');
  }

  // ── POST /api/auth/request-otp ─────────────────────────────────────────────

  describe('POST /api/auth/request-otp', () => {
    const email = 'e2e-test@example.com';

    it('returns 200 with {message} for a valid email', async () => {
      skipIfNoApp();
      const res = await request(app.getHttpServer())
        .post('/api/auth/request-otp')
        .send({ email })
        .expect(HttpStatus.OK);

      expect(res.body).toHaveProperty('message');
    });

    it('sends OTP to the provided email address (verifiable via mock sendOtpEmail)', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .post('/api/auth/request-otp')
        .send({ email })
        .expect(HttpStatus.OK);

      // Allow fire-and-forget email to settle
      await new Promise((r) => setImmediate(r));
      expect(mockSendOtpEmail).toHaveBeenCalledWith(email, expect.stringMatching(/^\d{6}$/));
    });

    it('returns 400 for an invalid email format', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .post('/api/auth/request-otp')
        .send({ email: 'not-an-email' })
        .expect(HttpStatus.BAD_REQUEST);
    });

    it('returns 400 when email field is missing', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .post('/api/auth/request-otp')
        .send({})
        .expect(HttpStatus.BAD_REQUEST);
    });

    it('returns 429 on the 4th request within 5 minutes for the same email', async () => {
      skipIfNoApp();
      const rateLimitEmail = 'rate-limit@example.com';

      // First 3 requests should succeed
      for (let i = 0; i < 3; i++) {
        await request(app.getHttpServer())
          .post('/api/auth/request-otp')
          .send({ email: rateLimitEmail })
          .expect(HttpStatus.OK);
      }

      // 4th request should be rate-limited
      await request(app.getHttpServer())
        .post('/api/auth/request-otp')
        .send({ email: rateLimitEmail })
        .expect(HttpStatus.TOO_MANY_REQUESTS);
    });

    it('does NOT reveal whether email is registered (same 200 for new and returning users)', async () => {
      skipIfNoApp();
      const [r1, r2] = await Promise.all([
        request(app.getHttpServer())
          .post('/api/auth/request-otp')
          .send({ email: 'new-user@example.com' }),
        request(app.getHttpServer())
          .post('/api/auth/request-otp')
          .send({ email }),
      ]);
      expect(r1.status).toBe(HttpStatus.OK);
      expect(r2.status).toBe(HttpStatus.OK);
    });
  });

  // ── POST /api/auth/verify-otp ──────────────────────────────────────────────

  describe('POST /api/auth/verify-otp', () => {
    const email = 'verify-test@example.com';
    let otp: string;

    beforeEach(async () => {
      if (!app) return;
      await request(app.getHttpServer())
        .post('/api/auth/request-otp')
        .send({ email });
      await new Promise((r) => setImmediate(r));
      otp = capturedOtps.get(email) ?? '';
    });

    it('returns 200 with accessToken + refreshToken for correct OTP', async () => {
      skipIfNoApp();
      const res = await request(app.getHttpServer())
        .post('/api/auth/verify-otp')
        .send({ email, otp })
        .expect(HttpStatus.OK);

      expect(res.body).toMatchObject({
        accessToken: expect.any(String),
        refreshToken: expect.any(String),
        user: { email },
      });
    });

    it('OTP is exactly 6 digits', async () => {
      skipIfNoApp();
      expect(otp).toMatch(/^\d{6}$/);
    });

    it('returns 401 for incorrect OTP', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .post('/api/auth/verify-otp')
        .send({ email, otp: '000000' })
        .expect(HttpStatus.UNAUTHORIZED);
    });

    it('returns 401 on second use of the same OTP (single-use enforcement)', async () => {
      skipIfNoApp();
      // First use: success
      await request(app.getHttpServer())
        .post('/api/auth/verify-otp')
        .send({ email, otp })
        .expect(HttpStatus.OK);

      // Second use: should fail
      await request(app.getHttpServer())
        .post('/api/auth/verify-otp')
        .send({ email, otp })
        .expect(HttpStatus.UNAUTHORIZED);
    });

    it('returns 400 for missing required fields', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .post('/api/auth/verify-otp')
        .send({ email })
        .expect(HttpStatus.BAD_REQUEST);
    });
  });

  // ── POST /api/auth/refresh ─────────────────────────────────────────────────

  describe('POST /api/auth/refresh', () => {
    const email = 'refresh-test@example.com';

    async function getTokens() {
      await request(app.getHttpServer())
        .post('/api/auth/request-otp')
        .send({ email });
      await new Promise((r) => setImmediate(r));
      const otp = capturedOtps.get(email) ?? '';
      const res = await request(app.getHttpServer())
        .post('/api/auth/verify-otp')
        .send({ email, otp });
      return res.body as { accessToken: string; refreshToken: string };
    }

    it('returns 200 with a new accessToken for a valid refresh token', async () => {
      skipIfNoApp();
      const { refreshToken } = await getTokens();

      const res = await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .send({ refreshToken })
        .expect(HttpStatus.OK);

      expect(res.body.accessToken).toBeTruthy();
    });

    it('returns 401 for an invalid refresh token', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .send({ refreshToken: 'invalid-token-xyz' })
        .expect(HttpStatus.UNAUTHORIZED);
    });

    it('returns 400 when refreshToken field is missing', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .send({})
        .expect(HttpStatus.BAD_REQUEST);
    });
  });

  // ── POST /api/auth/logout ───────────────────────────────────────────────────

  describe('POST /api/auth/logout', () => {
    const email = 'logout-test@example.com';

    async function getTokens() {
      await request(app.getHttpServer())
        .post('/api/auth/request-otp')
        .send({ email });
      await new Promise((r) => setImmediate(r));
      const otp = capturedOtps.get(email) ?? '';
      const res = await request(app.getHttpServer())
        .post('/api/auth/verify-otp')
        .send({ email, otp });
      return res.body as { accessToken: string; refreshToken: string };
    }

    it('returns 200 with {message} when called with a valid refresh token', async () => {
      skipIfNoApp();
      const { refreshToken } = await getTokens();

      const res = await request(app.getHttpServer())
        .post('/api/auth/logout')
        .send({ refreshToken })
        .expect(HttpStatus.OK);

      expect(res.body).toEqual({ message: 'Logged out' });
    });

    it('revokes the refresh token so it cannot be reused', async () => {
      skipIfNoApp();
      const { refreshToken } = await getTokens();

      await request(app.getHttpServer())
        .post('/api/auth/logout')
        .send({ refreshToken })
        .expect(HttpStatus.OK);

      await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .send({ refreshToken })
        .expect(HttpStatus.UNAUTHORIZED);
    });

    it('revokes all tokens when JWT is provided (logout-all)', async () => {
      skipIfNoApp();
      const session1 = await getTokens();

      // Need a second session: re-request OTP for same email
      capturedOtps.delete(email);
      await request(app.getHttpServer())
        .post('/api/auth/request-otp')
        .send({ email });
      await new Promise((r) => setImmediate(r));
      const otp2 = capturedOtps.get(email) ?? '';
      const session2Res = await request(app.getHttpServer())
        .post('/api/auth/verify-otp')
        .send({ email, otp: otp2 });
      const session2 = session2Res.body as { accessToken: string; refreshToken: string };

      // Logout all via JWT bearer
      await request(app.getHttpServer())
        .post('/api/auth/logout')
        .set('Authorization', `Bearer ${session1.accessToken}`)
        .send({})
        .expect(HttpStatus.OK);

      // Both refresh tokens should now be revoked
      await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .send({ refreshToken: session1.refreshToken })
        .expect(HttpStatus.UNAUTHORIZED);

      await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .send({ refreshToken: session2.refreshToken })
        .expect(HttpStatus.UNAUTHORIZED);
    });

    it('returns 200 even with no body (idempotent / no-op)', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .post('/api/auth/logout')
        .send({})
        .expect(HttpStatus.OK);
    });
  });

  // ── Full auth flow + protected endpoint ────────────────────────────────────

  describe('Protected endpoint access', () => {
    const email = 'protected-test@example.com';

    async function loginAndGetToken(): Promise<string> {
      await request(app.getHttpServer())
        .post('/api/auth/request-otp')
        .send({ email });
      await new Promise((r) => setImmediate(r));
      const otp = capturedOtps.get(email) ?? '';
      const res = await request(app.getHttpServer())
        .post('/api/auth/verify-otp')
        .send({ email, otp });
      return (res.body as { accessToken: string }).accessToken;
    }

    it('allows access to protected endpoint with valid JWT', async () => {
      skipIfNoApp();
      const accessToken = await loginAndGetToken();

      const res = await request(app.getHttpServer())
        .post('/api/plans/generate')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ prompt: 'test' });

      // May return 200 (if LLM is mocked) or 502 (if not connected), but NOT 401
      expect(res.status).not.toBe(HttpStatus.UNAUTHORIZED);
    });

    it('returns 401 for protected endpoint without JWT', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .post('/api/plans/generate')
        .send({ prompt: 'test' })
        .expect(HttpStatus.UNAUTHORIZED);
    });

    it('returns 401 for protected endpoint with invalid JWT', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .post('/api/plans/generate')
        .set('Authorization', 'Bearer invalid.jwt.token')
        .send({ prompt: 'test' })
        .expect(HttpStatus.UNAUTHORIZED);
    });
  });

  // ── Rate limiting (3 OTP requests per 5 minutes) ────────────────────────────

  describe('OTP rate limiting', () => {
    it('allows 3 OTP requests for the same email within the window', async () => {
      skipIfNoApp();
      const email = 'rl-test@example.com';

      for (let i = 0; i < 3; i++) {
        await request(app.getHttpServer())
          .post('/api/auth/request-otp')
          .send({ email })
          .expect(HttpStatus.OK);
      }
    });

    it('blocks the 4th OTP request with 429 Too Many Requests', async () => {
      skipIfNoApp();
      const email = 'rl-block@example.com';

      for (let i = 0; i < 3; i++) {
        await request(app.getHttpServer())
          .post('/api/auth/request-otp')
          .send({ email })
          .expect(HttpStatus.OK);
      }

      await request(app.getHttpServer())
        .post('/api/auth/request-otp')
        .send({ email })
        .expect(HttpStatus.TOO_MANY_REQUESTS);
    });

    it('rate limit is per-email — different emails have independent quotas', async () => {
      skipIfNoApp();
      const email1 = 'rl-independent-a@example.com';
      const email2 = 'rl-independent-b@example.com';

      // Exhaust email1
      for (let i = 0; i < 3; i++) {
        await request(app.getHttpServer())
          .post('/api/auth/request-otp')
          .send({ email: email1 })
          .expect(HttpStatus.OK);
      }
      await request(app.getHttpServer())
        .post('/api/auth/request-otp')
        .send({ email: email1 })
        .expect(HttpStatus.TOO_MANY_REQUESTS);

      // email2 should still be allowed
      await request(app.getHttpServer())
        .post('/api/auth/request-otp')
        .send({ email: email2 })
        .expect(HttpStatus.OK);
    });
  });
});
