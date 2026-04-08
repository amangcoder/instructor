import { Test, TestingModule } from '@nestjs/testing';
import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { JwtAuthGuard } from './jwt-auth.guard';
import { OptionalAuthGuard } from './optional-auth.guard';

function createMockJwtService() {
  return {
    verify: jest.fn(),
  };
}

/**
 * Builds a minimal NestJS ExecutionContext mock for HTTP requests.
 * Caller can override headers on the returned request object.
 */
function createMockContext(headers: Record<string, string> = {}): ExecutionContext {
  const request = { headers, user: undefined as unknown };
  return {
    switchToHttp: () => ({
      getRequest: () => request,
      getResponse: () => ({}),
    }),
    getClass: () => null,
    getHandler: () => null,
    getArgs: () => [],
    getArgByIndex: () => null,
    switchToRpc: () => null,
    switchToWs: () => null,
    getType: () => 'http',
  } as unknown as ExecutionContext;
}

/** A decoded JWT payload used in test assertions. */
const VALID_PAYLOAD = { sub: 'user-123', email: 'user@example.com', iat: 1_700_000_000 };

/** A valid mock JWT string (checked by the mock verify function). */
const VALID_TOKEN = 'valid-jwt-token';

/** Build an Authorization header value. */
const bearer = (token: string) => `Bearer ${token}`;

// ---------------------------------------------------------------------------
// JwtAuthGuard tests
// ---------------------------------------------------------------------------

describe('JwtAuthGuard', () => {
  let guard: JwtAuthGuard;
  let mockJwtService: ReturnType<typeof createMockJwtService>;

  beforeEach(async () => {
    mockJwtService = createMockJwtService();
    mockJwtService.verify.mockReturnValue(VALID_PAYLOAD);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        JwtAuthGuard,
        { provide: JwtService, useValue: mockJwtService },
      ],
    }).compile();

    guard = module.get<JwtAuthGuard>(JwtAuthGuard);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  // ── Happy path ─────────────────────────────────────────────────────────────

  describe('valid token', () => {
    it('returns true when a valid Bearer token is present', async () => {
      const ctx = createMockContext({ authorization: bearer(VALID_TOKEN) });
      const result = await guard.canActivate(ctx);
      expect(result).toBe(true);
    });

    it('injects decoded user into request object', async () => {
      const ctx = createMockContext({ authorization: bearer(VALID_TOKEN) });
      await guard.canActivate(ctx);
      const req = ctx.switchToHttp().getRequest<{ user: typeof VALID_PAYLOAD }>();
      expect(req.user).toMatchObject({ sub: 'user-123', email: 'user@example.com' });
    });

    it('calls JwtService.verify with the extracted token', async () => {
      const ctx = createMockContext({ authorization: bearer(VALID_TOKEN) });
      await guard.canActivate(ctx);
      // The guard calls jwt.verify(token) with no extra options —
      // the secret is already bound via JwtModule.registerAsync in AuthModule.
      expect(mockJwtService.verify).toHaveBeenCalledWith(VALID_TOKEN);
    });

    it('requires exact-case "Bearer " prefix (case-sensitive)', async () => {
      // extractBearer uses startsWith('Bearer ') — lowercase 'bearer' is rejected
      const ctx = createMockContext({ authorization: `bearer ${VALID_TOKEN}` });
      await expect(guard.canActivate(ctx)).rejects.toThrow(UnauthorizedException);
    });
  });

  // ── Missing header ──────────────────────────────────────────────────────────

  describe('missing Authorization header', () => {
    it('throws UnauthorizedException when header is absent', async () => {
      const ctx = createMockContext({});
      await expect(guard.canActivate(ctx)).rejects.toThrow(UnauthorizedException);
    });

    it('does NOT call verify when header is absent', async () => {
      const ctx = createMockContext({});
      await guard.canActivate(ctx).catch(() => null);
      expect(mockJwtService.verify).not.toHaveBeenCalled();
    });
  });

  // ── Invalid token format ────────────────────────────────────────────────────

  describe('malformed token', () => {
    it('throws UnauthorizedException for a non-Bearer Authorization header', async () => {
      const ctx = createMockContext({ authorization: 'Basic dXNlcjpwYXNz' });
      await expect(guard.canActivate(ctx)).rejects.toThrow(UnauthorizedException);
    });

    it('throws UnauthorizedException when Bearer token is empty', async () => {
      const ctx = createMockContext({ authorization: 'Bearer ' });
      await expect(guard.canActivate(ctx)).rejects.toThrow(UnauthorizedException);
    });

    it('throws UnauthorizedException when JwtService.verify throws JsonWebTokenError', async () => {
      mockJwtService.verify.mockImplementationOnce(() => {
        throw Object.assign(new Error('invalid signature'), { name: 'JsonWebTokenError' });
      });
      const ctx = createMockContext({ authorization: bearer('bad.token.here') });
      await expect(guard.canActivate(ctx)).rejects.toThrow(UnauthorizedException);
    });
  });

  // ── Expired token ───────────────────────────────────────────────────────────

  describe('expired token', () => {
    it('throws UnauthorizedException with 401 when token is expired', async () => {
      mockJwtService.verify.mockImplementationOnce(() => {
        throw Object.assign(new Error('jwt expired'), { name: 'TokenExpiredError' });
      });
      const ctx = createMockContext({ authorization: bearer('expired.token.here') });
      const error = await guard.canActivate(ctx).catch((e: UnauthorizedException) => e);
      expect(error).toBeInstanceOf(UnauthorizedException);
    });
  });
});

// ---------------------------------------------------------------------------
// OptionalAuthGuard tests
// ---------------------------------------------------------------------------

describe('OptionalAuthGuard', () => {
  let guard: OptionalAuthGuard;
  let mockJwtService: ReturnType<typeof createMockJwtService>;

  beforeEach(async () => {
    mockJwtService = createMockJwtService();
    mockJwtService.verify.mockReturnValue(VALID_PAYLOAD);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OptionalAuthGuard,
        { provide: JwtService, useValue: mockJwtService },
      ],
    }).compile();

    guard = module.get<OptionalAuthGuard>(OptionalAuthGuard);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('returns true for anonymous requests (no Authorization header)', async () => {
    const ctx = createMockContext({});
    const result = await guard.canActivate(ctx);
    expect(result).toBe(true);
  });

  it('does not inject user for anonymous requests', async () => {
    const ctx = createMockContext({});
    await guard.canActivate(ctx);
    const req = ctx.switchToHttp().getRequest<{ user: unknown }>();
    expect(req.user).toBeUndefined();
  });

  it('returns true and populates user when valid token is present', async () => {
    const ctx = createMockContext({ authorization: bearer(VALID_TOKEN) });
    const result = await guard.canActivate(ctx);
    expect(result).toBe(true);
    const req = ctx.switchToHttp().getRequest<{ user: typeof VALID_PAYLOAD }>();
    expect(req.user).toMatchObject({ sub: 'user-123' });
  });

  it('returns true (not throws) for invalid token in optional mode', async () => {
    mockJwtService.verify.mockImplementationOnce(() => {
      throw Object.assign(new Error('invalid token'), { name: 'JsonWebTokenError' });
    });
    const ctx = createMockContext({ authorization: bearer('invalid.token') });
    // Should not throw — just silently skip the user injection
    await expect(guard.canActivate(ctx)).resolves.toBe(true);
    const req = ctx.switchToHttp().getRequest<{ user: unknown }>();
    expect(req.user).toBeUndefined();
  });
});
