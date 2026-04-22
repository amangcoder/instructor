/**
 * @jest-environment node
 *
 * Tests for the GET and POST /api/auth/session route handlers.
 *
 * POST handler:
 *  - action='verify'  → proxies to backend OTP verify; sets httpOnly cookies on success
 *  - action='logout'  → clears both session cookies (maxAge=0)
 *  - action='login'   → proxies OTP request to backend
 *  - action='refresh' → rotates tokens using refresh_token cookie
 *  - unknown action   → 400
 *
 * GET handler:
 *  - No cookie          → { authenticated: false }
 *  - Malformed cookie   → { authenticated: false }
 *  - Valid JWT cookie   → { authenticated: true, user: { sub, email, role } }
 *  - Token missing claims → { authenticated: false }
 *
 * Security: raw backend error bodies are never relayed; tokens are
 * never exposed in the JSON response body (only in httpOnly cookies).
 */

// ── Mock global fetch before importing the module ─────────────────────────────
const mockFetch = jest.fn();
global.fetch = mockFetch as typeof global.fetch;

import { NextRequest } from 'next/server';
import { POST, GET } from '../route';

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Build a minimal mock JWT token whose payload can be decoded by
 * decodeJwtPayload() in the route handler.
 *
 * The signature is faked — the handler does NOT verify signatures; that
 * is handled by the NestJS backend on every API call.
 */
function buildMockToken(payload: Record<string, unknown>): string {
  const header = Buffer.from(
    JSON.stringify({ alg: 'HS256', typ: 'JWT' }),
  ).toString('base64url');
  const payloadPart = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${header}.${payloadPart}.fake-signature`;
}

function makePostRequest(
  body: Record<string, unknown>,
  cookies?: Record<string, string>,
): NextRequest {
  const headers: Record<string, string> = {
    'content-type': 'application/json',
  };
  if (cookies && Object.keys(cookies).length > 0) {
    headers['cookie'] = Object.entries(cookies)
      .map(([k, v]) => `${k}=${v}`)
      .join('; ');
  }
  return new NextRequest('http://localhost:3072/api/auth/session', {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
}

function makeGetRequest(cookies?: Record<string, string>): NextRequest {
  const headers: Record<string, string> = {};
  if (cookies && Object.keys(cookies).length > 0) {
    headers['cookie'] = Object.entries(cookies)
      .map(([k, v]) => `${k}=${v}`)
      .join('; ');
  }
  return new NextRequest('http://localhost:3072/api/auth/session', {
    method: 'GET',
    headers,
  });
}

// ── Test lifecycle ────────────────────────────────────────────────────────────

beforeEach(() => {
  mockFetch.mockReset();
  jest.clearAllMocks();
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/session
// ─────────────────────────────────────────────────────────────────────────────

describe('POST /api/auth/session', () => {
  // ── action=verify ──────────────────────────────────────────────────────────

  describe('action=verify — success', () => {
    it('returns 200 with success:true on valid backend response', async () => {
      const mockAccessToken = buildMockToken({
        sub: 'user-123',
        email: 'admin@test.com',
        role: 'admin',
      });

      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({
          accessToken: mockAccessToken,
          refreshToken: 'mock-refresh-token',
          user: { sub: 'user-123', email: 'admin@test.com', role: 'admin' },
        }),
      });

      const req = makePostRequest({
        action: 'verify',
        email: 'admin@test.com',
        code: '123456',
      });

      const res = await POST(req);
      expect(res.status).toBe(200);

      const body = (await res.json()) as { success: boolean };
      expect(body.success).toBe(true);
    });

    it('sets access_token httpOnly cookie on successful verify', async () => {
      const mockAccessToken = buildMockToken({
        sub: 'user-123',
        email: 'admin@test.com',
        role: 'admin',
      });

      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({
          accessToken: mockAccessToken,
          refreshToken: 'mock-refresh-token',
          user: { sub: 'user-123', email: 'admin@test.com', role: 'admin' },
        }),
      });

      const req = makePostRequest({
        action: 'verify',
        email: 'admin@test.com',
        code: '123456',
      });

      const res = await POST(req);

      const accessCookie = res.cookies.get('access_token');
      expect(accessCookie).toBeDefined();
      expect(accessCookie?.value).toBe(mockAccessToken);
    });

    it('sets refresh_token httpOnly cookie on successful verify', async () => {
      const mockAccessToken = buildMockToken({
        sub: 'user-123',
        email: 'admin@test.com',
        role: 'admin',
      });
      const mockRefreshToken = 'mock-refresh-token-xyz';

      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({
          accessToken: mockAccessToken,
          refreshToken: mockRefreshToken,
          user: { sub: 'user-123', email: 'admin@test.com', role: 'admin' },
        }),
      });

      const req = makePostRequest({
        action: 'verify',
        email: 'admin@test.com',
        code: '123456',
      });

      const res = await POST(req);

      const refreshCookie = res.cookies.get('refresh_token');
      expect(refreshCookie).toBeDefined();
      expect(refreshCookie?.value).toBe(mockRefreshToken);
    });

    it('does NOT expose tokens in the JSON response body', async () => {
      const mockAccessToken = buildMockToken({
        sub: 'user-123',
        email: 'admin@test.com',
        role: 'admin',
      });

      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({
          accessToken: mockAccessToken,
          refreshToken: 'mock-refresh-token',
          user: { sub: 'user-123', email: 'admin@test.com', role: 'admin' },
        }),
      });

      const req = makePostRequest({
        action: 'verify',
        email: 'admin@test.com',
        code: '123456',
      });

      const res = await POST(req);
      const body = (await res.json()) as Record<string, unknown>;

      // Tokens must never appear in the response body (only in httpOnly cookies)
      expect(body.accessToken).toBeUndefined();
      expect(body.refreshToken).toBeUndefined();
    });
  });

  describe('action=verify — failure', () => {
    it('returns 401 when backend verify rejects the OTP', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 401,
        json: async () => ({ message: 'Invalid OTP' }),
      });

      const req = makePostRequest({
        action: 'verify',
        email: 'admin@test.com',
        code: '000000',
      });

      const res = await POST(req);
      expect(res.status).toBe(401);

      const body = (await res.json()) as { success: boolean };
      expect(body.success).toBe(false);
    });

    it('does NOT relay the raw backend error message to the client', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 401,
        json: async () => ({ message: 'Internal stack trace: ...' }),
      });

      const req = makePostRequest({
        action: 'verify',
        email: 'admin@test.com',
        code: '111111',
      });

      const res = await POST(req);
      const body = (await res.json()) as { message: string };

      // Raw backend error must not be forwarded
      expect(body.message).not.toContain('stack trace');
    });

    it('returns 400 when email is missing from verify body', async () => {
      const req = makePostRequest({ action: 'verify', code: '123456' });
      const res = await POST(req);
      expect(res.status).toBe(400);
    });

    it('returns 400 when code is missing from verify body', async () => {
      const req = makePostRequest({
        action: 'verify',
        email: 'admin@test.com',
      });
      const res = await POST(req);
      expect(res.status).toBe(400);
    });
  });

  // ── action=logout ──────────────────────────────────────────────────────────

  describe('action=logout', () => {
    it('returns 200 with success:true', async () => {
      const req = makePostRequest({ action: 'logout' });
      const res = await POST(req);

      expect(res.status).toBe(200);
      const body = (await res.json()) as { success: boolean };
      expect(body.success).toBe(true);
    });

    it('clears access_token cookie (sets maxAge=0)', async () => {
      const req = makePostRequest({ action: 'logout' });
      const res = await POST(req);

      const accessCookie = res.cookies.get('access_token');
      expect(accessCookie).toBeDefined();
      // Value is cleared (empty string) and maxAge=0 signals browser to delete it
      expect(accessCookie?.value).toBe('');
    });

    it('clears refresh_token cookie (sets maxAge=0)', async () => {
      const req = makePostRequest({ action: 'logout' });
      const res = await POST(req);

      const refreshCookie = res.cookies.get('refresh_token');
      expect(refreshCookie).toBeDefined();
      expect(refreshCookie?.value).toBe('');
    });

    it('does NOT call the backend on logout (client-side cookie clear only)', async () => {
      const req = makePostRequest({ action: 'logout' });
      await POST(req);

      // Logout only clears cookies locally; no backend call is needed
      expect(mockFetch).not.toHaveBeenCalled();
    });
  });

  // ── action=login ───────────────────────────────────────────────────────────

  describe('action=login', () => {
    it('returns 200 when backend OTP request succeeds', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({ success: true, message: 'OTP sent' }),
      });

      const req = makePostRequest({
        action: 'login',
        email: 'admin@test.com',
      });

      const res = await POST(req);
      expect(res.status).toBe(200);
    });

    it('returns 400 when backend rejects the email', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 400,
        json: async () => ({ message: 'Not an admin email' }),
      });

      const req = makePostRequest({
        action: 'login',
        email: 'unknown@test.com',
      });

      const res = await POST(req);
      expect(res.status).toBe(400);
      const body = (await res.json()) as { success: boolean };
      expect(body.success).toBe(false);
    });

    it('returns 400 when email is missing', async () => {
      const req = makePostRequest({ action: 'login' });
      const res = await POST(req);
      expect(res.status).toBe(400);
    });
  });

  // ── validation ────────────────────────────────────────────────────────────

  describe('request validation', () => {
    it('returns 400 for unknown action', async () => {
      const req = makePostRequest({ action: 'unknown_action' });
      const res = await POST(req);
      expect(res.status).toBe(400);

      const body = (await res.json()) as { success: boolean };
      expect(body.success).toBe(false);
    });

    it('returns 400 when body is not a JSON object', async () => {
      const req = new NextRequest('http://localhost:3072/api/auth/session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify([{ action: 'login', email: 'a@b.com' }]),
      });
      const res = await POST(req);
      expect(res.status).toBe(400);
    });

    it('returns 400 when body is unparseable JSON', async () => {
      const req = new NextRequest('http://localhost:3072/api/auth/session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: 'NOT{JSON}',
      });
      const res = await POST(req);
      expect(res.status).toBe(400);
    });
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/auth/session
// ─────────────────────────────────────────────────────────────────────────────

describe('GET /api/auth/session', () => {
  // ── No cookie ─────────────────────────────────────────────────────────────

  it('returns { authenticated: false } when no access_token cookie is present', async () => {
    const req = makeGetRequest();
    const res = await GET(req);

    expect(res.status).toBe(200);
    const body = (await res.json()) as { authenticated: boolean };
    expect(body.authenticated).toBe(false);
  });

  // ── Malformed cookie ──────────────────────────────────────────────────────

  it('returns { authenticated: false } when access_token is not a valid JWT', async () => {
    const req = makeGetRequest({ access_token: 'not-a-jwt-token' });
    const res = await GET(req);

    const body = (await res.json()) as { authenticated: boolean };
    expect(body.authenticated).toBe(false);
  });

  it('returns { authenticated: false } when access_token has only 2 parts', async () => {
    const req = makeGetRequest({ access_token: 'header.payload' });
    const res = await GET(req);

    const body = (await res.json()) as { authenticated: boolean };
    expect(body.authenticated).toBe(false);
  });

  it('returns { authenticated: false } when payload is not valid base64', async () => {
    const req = makeGetRequest({ access_token: 'header.!!!invalid!!!.sig' });
    const res = await GET(req);

    const body = (await res.json()) as { authenticated: boolean };
    expect(body.authenticated).toBe(false);
  });

  // ── Valid token ───────────────────────────────────────────────────────────

  it('returns { authenticated: true, user } when a valid token is present', async () => {
    const mockToken = buildMockToken({
      sub: 'user-123',
      email: 'admin@test.com',
      role: 'admin',
    });

    const req = makeGetRequest({ access_token: mockToken });
    const res = await GET(req);

    expect(res.status).toBe(200);

    const body = (await res.json()) as {
      authenticated: boolean;
      user: { sub: string; email: string; role: string };
    };
    expect(body.authenticated).toBe(true);
    expect(body.user).toEqual({
      sub: 'user-123',
      email: 'admin@test.com',
      role: 'admin',
    });
  });

  it('exposes sub, email, and role from the token payload', async () => {
    const mockToken = buildMockToken({
      sub: 'user-456',
      email: 'superadmin@company.com',
      role: 'admin',
      // Extra claims should be ignored by the response shape
      iat: 1700000000,
      exp: 1700003600,
    });

    const req = makeGetRequest({ access_token: mockToken });
    const res = await GET(req);

    const body = (await res.json()) as {
      authenticated: boolean;
      user: { sub: string; email: string; role: string };
    };
    expect(body.user.sub).toBe('user-456');
    expect(body.user.email).toBe('superadmin@company.com');
    expect(body.user.role).toBe('admin');
  });

  // ── Missing required claims ────────────────────────────────────────────────

  it('returns { authenticated: false } when token is missing the email claim', async () => {
    const tokenNoEmail = buildMockToken({ sub: 'user-123', role: 'admin' });
    const req = makeGetRequest({ access_token: tokenNoEmail });
    const res = await GET(req);

    const body = (await res.json()) as { authenticated: boolean };
    expect(body.authenticated).toBe(false);
  });

  it('returns { authenticated: false } when token is missing the role claim', async () => {
    const tokenNoRole = buildMockToken({
      sub: 'user-123',
      email: 'admin@test.com',
    });
    const req = makeGetRequest({ access_token: tokenNoRole });
    const res = await GET(req);

    const body = (await res.json()) as { authenticated: boolean };
    expect(body.authenticated).toBe(false);
  });

  it('returns { authenticated: false } when token is missing the sub claim', async () => {
    const tokenNoSub = buildMockToken({
      email: 'admin@test.com',
      role: 'admin',
    });
    const req = makeGetRequest({ access_token: tokenNoSub });
    const res = await GET(req);

    const body = (await res.json()) as { authenticated: boolean };
    expect(body.authenticated).toBe(false);
  });

  // ── Does not call backend ─────────────────────────────────────────────────

  it('does not call the backend for GET (decodes token locally)', async () => {
    const mockToken = buildMockToken({
      sub: 'user-123',
      email: 'admin@test.com',
      role: 'admin',
    });

    const req = makeGetRequest({ access_token: mockToken });
    await GET(req);

    // GET must not call the backend — it only decodes the cookie locally
    expect(mockFetch).not.toHaveBeenCalled();
  });
});
