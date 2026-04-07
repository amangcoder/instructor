import { Test, TestingModule } from '@nestjs/testing';
import {
  UnauthorizedException,
  TooManyRequestsException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { DatabaseService } from '../database/database.service';

// ---------------------------------------------------------------------------
// Mock nodemailer — prevents network calls in AuthService.onModuleInit()
// ---------------------------------------------------------------------------

const mockSendMail = jest.fn().mockResolvedValue({ messageId: 'test-message-id' });
const mockCreateTransport = jest.fn().mockReturnValue({ sendMail: mockSendMail });

jest.mock('nodemailer', () => ({
  createTransport: (...args: unknown[]) => mockCreateTransport(...args),
  createTestAccount: jest.fn().mockResolvedValue({
    user: 'ethereal@test.com',
    pass: 'ethereal-pass',
  }),
  getTestMessageUrl: jest.fn().mockReturnValue(null),
}));

// ---------------------------------------------------------------------------
// Drizzle ORM mock
// ---------------------------------------------------------------------------

/**
 * Creates a mock DatabaseService where db.db supports Drizzle's fluent
 * query builder chains:
 *   select().from(t).where(c).orderBy(col).all()
 *   select().from(t).where(c).get()
 *   update(t).set(vals).where(c)
 *   insert(t).values(vals)
 *   delete(t).where(c)
 *
 * Configure terminal responses with:
 *   drizzleMock._selectGet.mockResolvedValueOnce(value)
 *   drizzleMock._selectAll.mockResolvedValueOnce(array)
 */
function createDrizzleMock() {
  const selectGetMock = jest.fn().mockResolvedValue(null);
  const selectAllMock = jest.fn().mockResolvedValue([]);

  const selectChain = {
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    get: selectGetMock,
    all: selectAllMock,
  };

  const updateChain = {
    set: jest.fn().mockReturnThis(),
    where: jest.fn().mockResolvedValue(undefined),
  };

  const insertChain = {
    values: jest.fn().mockResolvedValue(undefined),
  };

  const deleteChain = {
    where: jest.fn().mockResolvedValue(undefined),
  };

  const drizzleDb = {
    select: jest.fn().mockReturnValue(selectChain),
    update: jest.fn().mockReturnValue(updateChain),
    insert: jest.fn().mockReturnValue(insertChain),
    delete: jest.fn().mockReturnValue(deleteChain),
  };

  return {
    /** The DatabaseService mock provided to NestJS. */
    db: drizzleDb,

    /** Configure the next .get() return value. */
    _selectGet: selectGetMock,

    /** Configure the next .all() return value. */
    _selectAll: selectAllMock,

    /** Direct access to the chain mocks for assertion. */
    _chains: { select: selectChain, update: updateChain, insert: insertChain, delete: deleteChain },
  };
}

// ---------------------------------------------------------------------------
// JWT service mock
// ---------------------------------------------------------------------------

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

const VALID_OTP_RECORD = {
  id: 1,
  email: 'user@example.com',
  code: '123456',
  expiresAt: new Date(Date.now() + 5 * 60 * 1000),
  attempts: 0,
  used: false,
  createdAt: new Date(),
};

const VALID_REFRESH_TOKEN_RECORD = {
  id: 'rt-1',
  userId: USER.id,
  token: 'valid-refresh-token-abc',
  expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
  revoked: false,
};

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

describe('AuthService', () => {
  let service: AuthService;
  let mockDb: ReturnType<typeof createDrizzleMock>;
  let mockJwt: ReturnType<typeof createMockJwtService>;

  beforeEach(async () => {
    mockDb = createDrizzleMock();
    mockJwt = createMockJwtService();
    mockSendMail.mockClear();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: DatabaseService, useValue: { db: mockDb.db } },
        { provide: JwtService, useValue: mockJwt },
      ],
    }).compile();

    // init() triggers onModuleInit lifecycle hook (initialises nodemailer transporter).
    await module.init();
    service = module.get<AuthService>(AuthService);
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.useRealTimers();
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

    it('inserts a new OTP record into the database', async () => {
      await service.requestOtp('user@example.com');
      expect(mockDb.db.insert).toHaveBeenCalled();
    });

    it('invalidates previous unused OTPs before inserting the new one', async () => {
      await service.requestOtp('user@example.com');
      // First DB write: update existing OTPs to used=true
      expect(mockDb.db.update).toHaveBeenCalled();
    });

    it('fires the OTP email asynchronously (does not throw on slow mail)', async () => {
      // sendMail is fire-and-forget; even if it hangs, requestOtp should resolve
      mockSendMail.mockImplementationOnce(
        () => new Promise((resolve) => setTimeout(() => resolve({ messageId: 'slow' }), 10_000)),
      );
      await expect(service.requestOtp('user@example.com')).resolves.toEqual({
        message: 'OTP sent',
      });
    });

    // ── Rate limiting (in-memory: 3 per 5 minutes per email) ─────────────────

    describe('rate limiting', () => {
      it('allows the first 3 requests without throwing', async () => {
        await service.requestOtp('rate@example.com');
        await service.requestOtp('rate@example.com');
        await service.requestOtp('rate@example.com');
        // All three should resolve
      });

      it('throws TooManyRequestsException on the 4th request within the window', async () => {
        await service.requestOtp('limited@example.com');
        await service.requestOtp('limited@example.com');
        await service.requestOtp('limited@example.com');

        await expect(service.requestOtp('limited@example.com')).rejects.toThrow(
          TooManyRequestsException,
        );
      });

      it('blocks the rate-limited email but allows a different email', async () => {
        // Exhaust limit for email-a
        await service.requestOtp('email-a@example.com');
        await service.requestOtp('email-a@example.com');
        await service.requestOtp('email-a@example.com');

        // email-a is now blocked
        await expect(service.requestOtp('email-a@example.com')).rejects.toThrow(
          TooManyRequestsException,
        );

        // email-b is still allowed
        await expect(service.requestOtp('email-b@example.com')).resolves.toEqual({
          message: 'OTP sent',
        });
      });

      it('resets the rate limit after the time window elapses', async () => {
        jest.useFakeTimers();

        // Exhaust the window
        await service.requestOtp('reset@example.com');
        await service.requestOtp('reset@example.com');
        await service.requestOtp('reset@example.com');
        await expect(service.requestOtp('reset@example.com')).rejects.toThrow(
          TooManyRequestsException,
        );

        // Advance past the 5-minute window
        jest.advanceTimersByTime(5 * 60 * 1001);

        await expect(service.requestOtp('reset@example.com')).resolves.toEqual({
          message: 'OTP sent',
        });
      });

      it('does NOT send email when rate-limited (saves SMTP quota)', async () => {
        await service.requestOtp('quota@example.com');
        await service.requestOtp('quota@example.com');
        await service.requestOtp('quota@example.com');
        await service.requestOtp('quota@example.com').catch(() => null);

        // sendMail was only called 3 times (not 4)
        // Note: sendMail is fire-and-forget so we wait a tick
        await new Promise((r) => setImmediate(r));
        expect(mockSendMail).toHaveBeenCalledTimes(3);
      });
    });
  });

  // ── verifyOtp ──────────────────────────────────────────────────────────────

  describe('verifyOtp', () => {
    const email = 'user@example.com';
    const correctOtp = '123456';

    function setupVerify(
      otpRecords: unknown[] = [VALID_OTP_RECORD],
      user: unknown = USER,
    ) {
      mockDb._selectAll.mockResolvedValueOnce(otpRecords);
      mockDb._selectGet.mockResolvedValueOnce(user);
    }

    it('returns accessToken, refreshToken, and user on correct OTP', async () => {
      setupVerify();
      const result = await service.verifyOtp(email, correctOtp);
      expect(result).toMatchObject({
        accessToken: expect.any(String),
        refreshToken: expect.any(String),
        user: { id: USER.id, email },
      });
    });

    it('marks the OTP as used after successful verification', async () => {
      setupVerify();
      await service.verifyOtp(email, correctOtp);
      expect(mockDb._chains.update.set).toHaveBeenCalledWith(
        expect.objectContaining({ used: true }),
      );
    });

    it('stores a refresh token in the database', async () => {
      setupVerify();
      await service.verifyOtp(email, correctOtp);
      // insert is called for: (possibly user,) refresh token
      expect(mockDb.db.insert).toHaveBeenCalled();
    });

    it('throws UnauthorizedException when no active OTP is found', async () => {
      mockDb._selectAll.mockResolvedValueOnce([]);
      await expect(service.verifyOtp(email, correctOtp)).rejects.toThrow(UnauthorizedException);
    });

    it('throws UnauthorizedException for incorrect OTP code', async () => {
      setupVerify([VALID_OTP_RECORD], USER);
      await expect(service.verifyOtp(email, 'wrong-otp')).rejects.toThrow(UnauthorizedException);
    });

    it('increments attempt count on incorrect OTP', async () => {
      mockDb._selectAll.mockResolvedValueOnce([VALID_OTP_RECORD]);
      await service.verifyOtp(email, '000000').catch(() => null);
      expect(mockDb._chains.update.set).toHaveBeenCalledWith(
        expect.objectContaining({ attempts: 1 }),
      );
    });

    it('throws UnauthorizedException when attempt count is at max (5)', async () => {
      const lockedRecord = { ...VALID_OTP_RECORD, attempts: 5 };
      mockDb._selectAll.mockResolvedValueOnce([lockedRecord]);
      await expect(service.verifyOtp(email, '000000')).rejects.toThrow(UnauthorizedException);
    });

    it('creates a new user if one does not exist yet', async () => {
      mockDb._selectAll.mockResolvedValueOnce([VALID_OTP_RECORD]);
      mockDb._selectGet.mockResolvedValueOnce(null); // user not found
      await service.verifyOtp(email, correctOtp);
      expect(mockDb.db.insert).toHaveBeenCalled();
    });

    it('returns a non-empty user id in the response', async () => {
      setupVerify();
      const result = await service.verifyOtp(email, correctOtp);
      expect(result.user.id).toBeTruthy();
    });
  });

  // ── refreshAccessToken ─────────────────────────────────────────────────────

  describe('refreshAccessToken', () => {
    it('returns a new accessToken for a valid refresh token', async () => {
      mockDb._selectGet.mockResolvedValueOnce(VALID_REFRESH_TOKEN_RECORD);
      mockDb._selectGet.mockResolvedValueOnce(USER);
      const result = await service.refreshAccessToken(VALID_REFRESH_TOKEN_RECORD.token);
      expect(result).toMatchObject({ accessToken: expect.any(String) });
    });

    it('accessToken is a non-empty string', async () => {
      mockDb._selectGet.mockResolvedValueOnce(VALID_REFRESH_TOKEN_RECORD);
      mockDb._selectGet.mockResolvedValueOnce(USER);
      const { accessToken } = await service.refreshAccessToken(VALID_REFRESH_TOKEN_RECORD.token);
      expect(accessToken.length).toBeGreaterThan(0);
    });

    it('throws UnauthorizedException when refresh token is not found', async () => {
      mockDb._selectGet.mockResolvedValueOnce(null);
      await expect(service.refreshAccessToken('unknown-token')).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('throws UnauthorizedException when token is revoked', async () => {
      // The service queries with revoked=false in WHERE clause; if revoked it won't be returned
      mockDb._selectGet.mockResolvedValueOnce(null); // not found (filtered by revoked=false)
      await expect(
        service.refreshAccessToken(VALID_REFRESH_TOKEN_RECORD.token),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('throws UnauthorizedException when user is not found', async () => {
      mockDb._selectGet.mockResolvedValueOnce(VALID_REFRESH_TOKEN_RECORD);
      mockDb._selectGet.mockResolvedValueOnce(null); // user not found
      await expect(
        service.refreshAccessToken(VALID_REFRESH_TOKEN_RECORD.token),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('signs new access token with 15-minute expiry', async () => {
      mockDb._selectGet.mockResolvedValueOnce(VALID_REFRESH_TOKEN_RECORD);
      mockDb._selectGet.mockResolvedValueOnce(USER);
      await service.refreshAccessToken(VALID_REFRESH_TOKEN_RECORD.token);
      const signCall = mockJwt.sign.mock.calls[0];
      expect(signCall[1]).toEqual(expect.objectContaining({ expiresIn: '15m' }));
    });
  });

  // ── pruneExpiredOtps ───────────────────────────────────────────────────────

  describe('pruneExpiredOtps', () => {
    it('deletes expired OTP records from the database', async () => {
      await service.pruneExpiredOtps();
      expect(mockDb.db.delete).toHaveBeenCalled();
    });
  });
});
