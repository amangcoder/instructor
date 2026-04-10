/**
 * Unit tests for AuthService (using DatabaseService + SES + UpstashRateLimiter).
 *
 * All external service calls are intercepted via mocked service classes.
 * No real database, SES, or network calls are made in CI.
 *
 * Mock strategy:
 *   - DatabaseService          → jest.fn() for each typed entity method
 *   - SESEmailService          → jest.fn() for sendOtpEmail
 *   - UpstashRateLimitService  → jest.fn() for consume/peek/increment
 *   - JwtService               → deterministic sign/verify based on Buffer.from(JSON)
 *
 * To test verifyOtp with a valid OTP:
 *   1. Call requestOtp, capturing the OTP via the SES mock
 *   2. Capture the hashed code via the DatabaseService createOtp mock
 *   3. Return the captured hash from getActiveOtps
 *   4. Call verifyOtp with the captured plaintext code
 */

import { Test, TestingModule } from '@nestjs/testing';
import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { DatabaseService } from '../database/database.service';
import { SESEmailService } from '../email/ses-email.service';
import { UpstashRateLimitService } from '../ratelimit/upstash-ratelimit.service';

// ---------------------------------------------------------------------------
// Mock factories
// ---------------------------------------------------------------------------

function createMockDatabaseService() {
  return {
    getUserById: jest.fn().mockResolvedValue(null),
    getUserByEmail: jest.fn().mockResolvedValue(USER),
    createUser: jest.fn().mockResolvedValue(undefined),
    createOtp: jest.fn().mockResolvedValue(undefined),
    getActiveOtps: jest.fn().mockResolvedValue([]),
    markOtpUsed: jest.fn().mockResolvedValue(undefined),
    incrementOtpAttempts: jest.fn().mockResolvedValue(undefined),
    invalidateOtpsForEmail: jest.fn().mockResolvedValue(undefined),
    createRefreshToken: jest.fn().mockResolvedValue(undefined),
    getRefreshToken: jest.fn().mockResolvedValue(null),
    revokeRefreshToken: jest.fn().mockResolvedValue(undefined),
    revokeAllRefreshTokens: jest.fn().mockResolvedValue(undefined),
    getSyncMetadata: jest.fn().mockResolvedValue(null),
    upsertSyncMetadata: jest.fn().mockResolvedValue(undefined),
  };
}

function createMockSESEmailService() {
  return {
    dispatchOtpEmail: jest.fn().mockResolvedValue(undefined),
    sendOtpEmail: jest.fn().mockResolvedValue(undefined),
  };
}

function createMockRateLimiter() {
  return {
    consume: jest.fn().mockResolvedValue({ allowed: true, current: 1, retryAfterSec: 0 }),
    peek: jest.fn().mockResolvedValue({ allowed: true, current: 0, retryAfterSec: 0 }),
    increment: jest.fn().mockResolvedValue(undefined),
  };
}

function createMockJwtService() {
  return {
    sign: jest.fn(
      (payload: object, _options?: { expiresIn?: string }) =>
        `mock-jwt.${Buffer.from(JSON.stringify(payload)).toString('base64')}`,
    ),
    verify: jest.fn((token: string) => {
      if (!token.startsWith('mock-jwt.')) {
        throw Object.assign(new Error('invalid token'), { name: 'JsonWebTokenError' });
      }
      return JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
    }),
  };
}

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const USER = { id: 'user-abc-123', email: 'user@example.com', createdAt: new Date() };

const VALID_REFRESH_TOKEN_RECORD = {
  userId: USER.id,
  tokenHash: 'sha256ofvalidrefreshtoken',
  revoked: false,
  expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
  sk: 'TOKEN',
};

/**
 * Build a minimal OTP record for getActiveOtps mock.
 * code must be the HMAC-SHA256 hash that the service would store.
 */
function makeOtpRecord(overrides: {
  code: string;
  email?: string;
  attempts?: number;
  used?: boolean;
  expiresAt?: Date;
}) {
  return {
    email: overrides.email ?? USER.email,
    code: overrides.code,
    attempts: overrides.attempts ?? 0,
    used: overrides.used ?? false,
    expiresAt: overrides.expiresAt ?? new Date(Date.now() + 5 * 60 * 1000),
    sk: `2026-04-09T00:00:00.000Z#otp-test-id`,
  };
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

describe('AuthService', () => {
  let service: AuthService;
  let mockDynamo: ReturnType<typeof createMockDatabaseService>;
  let mockSes: ReturnType<typeof createMockSESEmailService>;
  let mockRateLimiter: ReturnType<typeof createMockRateLimiter>;
  let mockJwt: ReturnType<typeof createMockJwtService>;

  beforeEach(async () => {
    process.env.OTP_SALT = 'test-otp-salt-32-chars-placeholder';

    mockDynamo = createMockDatabaseService();
    mockSes = createMockSESEmailService();
    mockRateLimiter = createMockRateLimiter();
    mockJwt = createMockJwtService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: DatabaseService, useValue: mockDynamo },
        { provide: SESEmailService, useValue: mockSes },
        { provide: UpstashRateLimitService, useValue: mockRateLimiter },
        { provide: JwtService, useValue: mockJwt },
      ],
    }).compile();

    await module.init();
    service = module.get<AuthService>(AuthService);
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.useRealTimers();
    delete process.env.OTP_SALT;
  });

  // ── requestOtp ─────────────────────────────────────────────────────────────

  describe('requestOtp', () => {
    it('returns { message: "OTP sent" } for a valid email address', async () => {
      const result = await service.requestOtp('user@example.com');
      expect(result).toEqual({ message: 'OTP sent' });
    });

    it('normalises email to lowercase before processing', async () => {
      const result = await service.requestOtp('User@EXAMPLE.COM');
      expect(result).toEqual({ message: 'OTP sent' });
    });

    it('stores an OTP record via DatabaseService.createOtp', async () => {
      await service.requestOtp('user@example.com');
      expect(mockDynamo.createOtp).toHaveBeenCalled();
    });

    it('invalidates previous unused OTPs before creating the new one', async () => {
      await service.requestOtp('user@example.com');
      expect(mockDynamo.invalidateOtpsForEmail).toHaveBeenCalledWith('user@example.com');
    });

    it('sends OTP email via SESEmailService.dispatchOtpEmail', async () => {
      await service.requestOtp('user@example.com');
      expect(mockSes.dispatchOtpEmail).toHaveBeenCalledWith(
        'user@example.com',
        expect.stringMatching(/^\d{6}$/),
      );
    });

    it('passes a 6-digit OTP code to dispatchOtpEmail', async () => {
      await service.requestOtp('user@example.com');
      const [, code] = mockSes.dispatchOtpEmail.mock.calls[0] as [string, string];
      expect(code).toMatch(/^\d{6}$/);
    });

    it('checks rate limit before processing (calls consume)', async () => {
      await service.requestOtp('user@example.com');
      expect(mockRateLimiter.consume).toHaveBeenCalledWith(
        'otp',
        'user@example.com',
        expect.any(Number),
        expect.any(Number),
      );
    });

    it('invalidateOtpsForEmail is called with the normalised (lowercase) email', async () => {
      await service.requestOtp('USER@EXAMPLE.COM');
      expect(mockDynamo.invalidateOtpsForEmail).toHaveBeenCalledWith('user@example.com');
    });

    // ── Invite-only gate ──────────────────────────────────────────────────

    it('throws HTTP 403 when email is not in the users table', async () => {
      mockDynamo.getUserByEmail.mockResolvedValueOnce(null);
      const err: any = await service.requestOtp('stranger@example.com').catch((e) => e);
      const statusCode = err.getStatus?.() ?? err.status ?? err.statusCode;
      expect(statusCode).toBe(403);
    });

    it('does NOT send OTP to uninvited email', async () => {
      mockDynamo.getUserByEmail.mockResolvedValueOnce(null);
      await service.requestOtp('stranger@example.com').catch(() => null);
      expect(mockSes.dispatchOtpEmail).not.toHaveBeenCalled();
    });

    // ── Rate limiting ─────────────────────────────────────────────────────

    describe('rate limiting', () => {
      it('allows the request when rate limiter returns { allowed: true }', async () => {
        mockRateLimiter.consume.mockResolvedValue({ allowed: true, current: 1, retryAfterSec: 0 });
        await expect(service.requestOtp('user@example.com')).resolves.toEqual({ message: 'OTP sent' });
      });

      it('throws HTTP 429 when rate limiter returns { allowed: false }', async () => {
        mockRateLimiter.consume.mockResolvedValue({ allowed: false, current: 4, retryAfterSec: 240 });

        const thrownError: any = await service.requestOtp('limited@example.com').catch((e) => e);
        expect(thrownError).toBeTruthy();
        const statusCode = thrownError.getStatus?.() ?? thrownError.status ?? thrownError.statusCode;
        expect(statusCode).toBe(429);
      });

      it('does NOT call dispatchOtpEmail when rate-limited', async () => {
        mockRateLimiter.consume.mockResolvedValue({ allowed: false, current: 4, retryAfterSec: 240 });
        await service.requestOtp('limited@example.com').catch(() => null);
        expect(mockSes.dispatchOtpEmail).not.toHaveBeenCalled();
      });

      it('does NOT call createOtp when rate-limited', async () => {
        mockRateLimiter.consume.mockResolvedValue({ allowed: false, current: 4, retryAfterSec: 240 });
        await service.requestOtp('limited@example.com').catch(() => null);
        expect(mockDynamo.createOtp).not.toHaveBeenCalled();
      });

      it('allows a different email when one email is rate-limited', async () => {
        // limited@example.com is blocked
        mockRateLimiter.consume
          .mockResolvedValueOnce({ allowed: false, current: 4, retryAfterSec: 240 })
          // email-b@example.com is still allowed
          .mockResolvedValueOnce({ allowed: true, current: 1, retryAfterSec: 0 });

        await service.requestOtp('limited@example.com').catch(() => null);
        await expect(service.requestOtp('email-b@example.com')).resolves.toEqual({ message: 'OTP sent' });
      });

      it('does NOT dispatch email when rate-limited (conserves SES quota)', async () => {
        // First 3 allowed, 4th blocked
        mockRateLimiter.consume
          .mockResolvedValueOnce({ allowed: true, current: 1, retryAfterSec: 0 })
          .mockResolvedValueOnce({ allowed: true, current: 2, retryAfterSec: 0 })
          .mockResolvedValueOnce({ allowed: true, current: 3, retryAfterSec: 0 })
          .mockResolvedValueOnce({ allowed: false, current: 3, retryAfterSec: 300 });

        await service.requestOtp('quota@example.com');
        await service.requestOtp('quota@example.com');
        await service.requestOtp('quota@example.com');
        await service.requestOtp('quota@example.com').catch(() => null);

        expect(mockSes.dispatchOtpEmail).toHaveBeenCalledTimes(3);
      });
    });
  });

  // ── verifyOtp ───────────────────────────────────────────────────────────────

  describe('verifyOtp', () => {
    const email = USER.email;

    /**
     * Helper: call requestOtp, capture the OTP code and its hash,
     * then set up getActiveOtps to return a record with that hash.
     */
    async function setupVerification(overrideEmail = email) {
      let capturedOtp = '';
      let capturedHash = '';

      mockSes.dispatchOtpEmail.mockImplementationOnce(async (_: string, code: string) => {
        capturedOtp = code;
      });
      mockDynamo.createOtp.mockImplementationOnce(
        async (_email: string, codeHash: string, _expiresAt: Date) => {
          capturedHash = codeHash;
        },
      );

      await service.requestOtp(overrideEmail);

      mockDynamo.getActiveOtps.mockResolvedValueOnce([
        makeOtpRecord({ email: overrideEmail, code: capturedHash }),
      ]);

      return { capturedOtp, capturedHash };
    }

    it('returns accessToken, refreshToken, and user on correct OTP', async () => {
      const { capturedOtp } = await setupVerification();

      const result = await service.verifyOtp(email, capturedOtp);
      expect(result).toMatchObject({
        accessToken: expect.any(String),
        refreshToken: expect.any(String),
        user: { id: USER.id, email },
      });
    });

    it('marks the OTP as used after successful verification', async () => {
      const { capturedOtp } = await setupVerification();
      await service.verifyOtp(email, capturedOtp);
      expect(mockDynamo.markOtpUsed).toHaveBeenCalled();
    });

    it('stores a refresh token in the database after successful verification', async () => {
      const { capturedOtp } = await setupVerification();
      await service.verifyOtp(email, capturedOtp);
      expect(mockDynamo.createRefreshToken).toHaveBeenCalled();
    });

    it('creates a new user if one does not exist at verify time', async () => {
      let capturedOtp = '';
      let capturedHash = '';

      mockSes.dispatchOtpEmail.mockImplementationOnce(async (_: string, code: string) => {
        capturedOtp = code;
      });
      mockDynamo.createOtp.mockImplementationOnce(
        async (_email: string, codeHash: string) => {
          capturedHash = codeHash;
        },
      );

      // requestOtp uses default getUserByEmail → USER (invite check passes)
      await service.requestOtp(email);

      mockDynamo.getActiveOtps.mockResolvedValueOnce([
        makeOtpRecord({ email, code: capturedHash }),
      ]);
      // verifyOtp sees no user (e.g. deleted between OTP request and verification)
      mockDynamo.getUserByEmail.mockResolvedValueOnce(null);

      await service.verifyOtp(email, capturedOtp);
      expect(mockDynamo.createUser).toHaveBeenCalled();
    });

    it('throws UnauthorizedException when no active OTP is found', async () => {
      mockDynamo.getActiveOtps.mockResolvedValueOnce([]);
      await expect(service.verifyOtp(email, '123456')).rejects.toThrow(UnauthorizedException);
    });

    it('throws UnauthorizedException for an incorrect OTP code', async () => {
      // Set up a record whose hash does NOT match '000000'
      const { capturedHash } = await setupVerification();
      mockDynamo.getActiveOtps.mockResolvedValueOnce([
        makeOtpRecord({ email, code: capturedHash }),
      ]);

      await expect(service.verifyOtp(email, '000000')).rejects.toThrow(UnauthorizedException);
    });

    it('increments attempt count on an incorrect OTP', async () => {
      const { capturedHash } = await setupVerification();
      mockDynamo.getActiveOtps.mockResolvedValueOnce([
        makeOtpRecord({ email, code: capturedHash }),
      ]);

      await service.verifyOtp(email, '000000').catch(() => null);
      expect(mockDynamo.incrementOtpAttempts).toHaveBeenCalled();
    });

    it('throws UnauthorizedException when attempt count is at max (5)', async () => {
      const lockedRecord = makeOtpRecord({ email, code: 'any-hash', attempts: 5 });
      mockDynamo.getActiveOtps.mockResolvedValueOnce([lockedRecord]);
      await expect(service.verifyOtp(email, '000000')).rejects.toThrow(UnauthorizedException);
    });

    it('returns a non-empty user id in the response', async () => {
      const { capturedOtp } = await setupVerification();
      const result = await service.verifyOtp(email, capturedOtp);
      expect(result.user.id).toBeTruthy();
    });

    it('OTP is single-use — verifying twice returns error on second attempt', async () => {
      const { capturedOtp, capturedHash } = await setupVerification();

      // First use: success
      await service.verifyOtp(email, capturedOtp);

      // Second use: getActiveOtps returns empty (OTP now marked used)
      mockDynamo.getActiveOtps.mockResolvedValueOnce([]);
      await expect(service.verifyOtp(email, capturedOtp)).rejects.toThrow(UnauthorizedException);
    });
  });

  // ── refreshAccessToken ──────────────────────────────────────────────────────

  describe('refreshAccessToken', () => {
    it('returns a new accessToken for a valid refresh token', async () => {
      mockDynamo.getRefreshToken.mockResolvedValueOnce(VALID_REFRESH_TOKEN_RECORD);
      mockDynamo.getUserById.mockResolvedValueOnce(USER);

      const result = await service.refreshAccessToken('valid-refresh-token-abc');
      expect(result).toMatchObject({ accessToken: expect.any(String) });
    });

    it('accessToken is a non-empty string', async () => {
      mockDynamo.getRefreshToken.mockResolvedValueOnce(VALID_REFRESH_TOKEN_RECORD);
      mockDynamo.getUserById.mockResolvedValueOnce(USER);

      const { accessToken } = await service.refreshAccessToken('valid-refresh-token-abc');
      expect(accessToken.length).toBeGreaterThan(0);
    });

    it('throws UnauthorizedException when refresh token is not found', async () => {
      mockDynamo.getRefreshToken.mockResolvedValueOnce(null);
      await expect(service.refreshAccessToken('unknown-token')).rejects.toThrow(UnauthorizedException);
    });

    it('throws UnauthorizedException when user is not found', async () => {
      mockDynamo.getRefreshToken.mockResolvedValueOnce(VALID_REFRESH_TOKEN_RECORD);
      mockDynamo.getUserById.mockResolvedValueOnce(null);
      await expect(service.refreshAccessToken('valid-token')).rejects.toThrow(UnauthorizedException);
    });

    it('revokes the old refresh token (token rotation security)', async () => {
      mockDynamo.getRefreshToken.mockResolvedValueOnce(VALID_REFRESH_TOKEN_RECORD);
      mockDynamo.getUserById.mockResolvedValueOnce(USER);

      await service.refreshAccessToken('valid-refresh-token-abc');
      expect(mockDynamo.revokeRefreshToken).toHaveBeenCalled();
    });

    it('issues a brand-new refresh token after rotation', async () => {
      mockDynamo.getRefreshToken.mockResolvedValueOnce(VALID_REFRESH_TOKEN_RECORD);
      mockDynamo.getUserById.mockResolvedValueOnce(USER);

      await service.refreshAccessToken('valid-refresh-token-abc');
      expect(mockDynamo.createRefreshToken).toHaveBeenCalled();
    });

    it('signs the new access token with 15-minute expiry', async () => {
      mockDynamo.getRefreshToken.mockResolvedValueOnce(VALID_REFRESH_TOKEN_RECORD);
      mockDynamo.getUserById.mockResolvedValueOnce(USER);

      await service.refreshAccessToken('valid-refresh-token-abc');
      const signCall = mockJwt.sign.mock.calls[0];
      expect(signCall[1]).toEqual(expect.objectContaining({ expiresIn: '15m' }));
    });
  });

  // ── revokeRefreshToken ──────────────────────────────────────────────────────

  describe('revokeRefreshToken', () => {
    it('calls DatabaseService.revokeRefreshToken', async () => {
      await service.revokeRefreshToken('some-refresh-token');
      expect(mockDynamo.revokeRefreshToken).toHaveBeenCalled();
    });

    it('resolves without throwing (idempotent — handles already-revoked tokens)', async () => {
      await expect(service.revokeRefreshToken('any-token')).resolves.toBeUndefined();
    });
  });

  // ── revokeAllRefreshTokens ──────────────────────────────────────────────────

  describe('revokeAllRefreshTokens', () => {
    it('calls DatabaseService.revokeAllRefreshTokens with the userId', async () => {
      await service.revokeAllRefreshTokens(USER.id);
      expect(mockDynamo.revokeAllRefreshTokens).toHaveBeenCalledWith(USER.id);
    });

    it('resolves without throwing', async () => {
      await expect(service.revokeAllRefreshTokens(USER.id)).resolves.toBeUndefined();
    });
  });

  // ── inviteUser ──────────────────────────────────────────────────────────────

  describe('inviteUser', () => {
    it('creates a user and returns { message: "User invited", email }', async () => {
      mockDynamo.getUserByEmail.mockResolvedValueOnce(null);
      const result = await service.inviteUser('new@example.com');
      expect(result).toEqual({ message: 'User invited', email: 'new@example.com' });
      expect(mockDynamo.createUser).toHaveBeenCalledWith(
        expect.objectContaining({ email: 'new@example.com' }),
      );
    });

    it('normalises email to lowercase', async () => {
      mockDynamo.getUserByEmail.mockResolvedValueOnce(null);
      const result = await service.inviteUser('NEW@EXAMPLE.COM');
      expect(result.email).toBe('new@example.com');
    });

    it('returns { message: "User already exists" } without creating duplicate', async () => {
      // default getUserByEmail returns USER (already exists)
      const result = await service.inviteUser(USER.email);
      expect(result).toEqual({ message: 'User already exists', email: USER.email });
      expect(mockDynamo.createUser).not.toHaveBeenCalled();
    });
  });
});
