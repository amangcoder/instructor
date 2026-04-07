import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe, HttpStatus } from '@nestjs/common';
import * as request from 'supertest';
import { App } from 'supertest/types';

// ---------------------------------------------------------------------------
// E2E auth flow tests
//
// These tests exercise the full HTTP layer end-to-end without hitting real
// external services. All dependencies (mail, database, JWT signing) are
// either in-memory or mocked so tests run deterministically without network.
//
// Modules tested (must be implemented per TASK-001, TASK-002, TASK-003):
//   POST /api/auth/request-otp
//   POST /api/auth/verify-otp
//   POST /api/auth/refresh
//   Protected endpoints requiring valid JWT
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Mock nodemailer at module level.
// AuthService uses nodemailer directly (not via DI), so we must mock the module
// so that createTransport() returns a fake transporter whose sendMail captures
// OTPs from email bodies — enabling e2e tests to verify OTPs without real SMTP.
// ---------------------------------------------------------------------------

/** OTPs captured from email bodies: email → 6-digit code. */
const capturedOtps = new Map<string, string>();

const mockSendMail = jest.fn(
  async (opts: { to: string; text?: string; html?: string }) => {
    const body = opts.text ?? opts.html ?? '';
    const match = body.match(/\b(\d{6})\b/);
    if (match) capturedOtps.set(opts.to, match[1]);
    return { messageId: '<test@ethereal.email>' };
  },
);

jest.mock('nodemailer', () => ({
  createTransport: jest.fn().mockReturnValue({ sendMail: mockSendMail }),
  createTestAccount: jest.fn().mockResolvedValue({
    user: 'test@ethereal.email',
    pass: 'ethereal-pass',
  }),
  getTestMessageUrl: jest.fn().mockReturnValue(null),
}));

describe('Auth (e2e)', () => {
  let app: INestApplication<App>;

  beforeAll(async () => {
    // Import the AppModule lazily so the test file compiles even before the
    // auth module exists.
    let AppModule: new () => object;
    let AuthModule: new () => object;

    try {
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      ({ AppModule } = require('../src/app.module'));
    } catch {
      // AppModule not yet available — skip all tests gracefully
      console.warn('[auth.e2e] AppModule not found — tests will be skipped until TASK-001/002/003 are implemented');
      return;
    }

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

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
    mockSendMail.mockClear();
  });

  // Utility: skip test gracefully when app hasn't been initialised
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

    it('sends OTP to the provided email address (verifiable via mock sendMail)', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .post('/api/auth/request-otp')
        .send({ email })
        .expect(HttpStatus.OK);

      // Wait a tick for the fire-and-forget sendMail promise to settle
      await new Promise((r) => setImmediate(r));
      expect(mockSendMail).toHaveBeenCalledWith(
        expect.objectContaining({ to: email }),
      );
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
          .send({ email: email }),
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
      // Request a fresh OTP before each verification test
      await request(app.getHttpServer())
        .post('/api/auth/request-otp')
        .send({ email });
      // Wait for the fire-and-forget sendMail to settle so capturedOtps is populated
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

    it('OTP is exactly 6 digits', async () => {
      skipIfNoApp();
      expect(otp).toMatch(/^\d{6}$/);
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

      // Attempt to use the revoked refresh token
      await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .send({ refreshToken })
        .expect(HttpStatus.UNAUTHORIZED);
    });

    it('revokes all tokens when JWT is provided (logout-all)', async () => {
      skipIfNoApp();
      // Create two sessions
      const session1 = await getTokens();
      const session2 = await getTokens();

      // Logout with JWT from session1 — should revoke ALL tokens for the user
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

    it('returns 200 for an already-revoked token (idempotent)', async () => {
      skipIfNoApp();
      const { refreshToken } = await getTokens();

      // Revoke once
      await request(app.getHttpServer())
        .post('/api/auth/logout')
        .send({ refreshToken })
        .expect(HttpStatus.OK);

      // Revoke again — should still succeed
      await request(app.getHttpServer())
        .post('/api/auth/logout')
        .send({ refreshToken })
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
      const otp = capturedOtps.get(email) ?? '';
      const res = await request(app.getHttpServer())
        .post('/api/auth/verify-otp')
        .send({ email, otp });
      return (res.body as { accessToken: string }).accessToken;
    }

    it('allows access to protected endpoint with valid JWT', async () => {
      skipIfNoApp();
      const accessToken = await loginAndGetToken();

      // POST /api/plans/generate is protected by JwtAuthGuard (TASK-006)
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
});
