import { NextRequest, NextResponse } from 'next/server';

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

/**
 * NestJS backend base URL — hardcoded from environment variable.
 * SECURITY: Never construct this from request headers or user input.
 */
const BACKEND_URL = process.env.BACKEND_URL ?? 'http://localhost:3071/api';

/** Secure flag is only set in production to allow local HTTP dev. */
const IS_PRODUCTION = process.env.NODE_ENV === 'production';

/** Access token cookie lifetime: 15 minutes (matches JWT expiry). */
const ACCESS_TOKEN_MAX_AGE = 900;

/** Refresh token cookie lifetime: 30 days. */
const REFRESH_TOKEN_MAX_AGE = 2_592_000;

/** Backend proxy timeout: 10 seconds. */
const BACKEND_TIMEOUT_MS = 10_000;

// ────────────────────────────────────────────────────────────────────────────
// Allowlisted backend endpoints
// ────────────────────────────────────────────────────────────────────────────
//
// These are the ONLY paths this handler will ever proxy to.
// They are hardcoded constants — never derived from request input.
//
const ENDPOINTS = {
  login: `${BACKEND_URL}/auth/request-otp`,
  verify: `${BACKEND_URL}/auth/verify-otp`,
  refresh: `${BACKEND_URL}/auth/refresh`,
} as const;

// ────────────────────────────────────────────────────────────────────────────
// Fixed client-facing error messages
// ────────────────────────────────────────────────────────────────────────────
//
// Raw backend responses are never relayed to the client; they may contain
// stack traces or other implementation details. All errors map to one of
// these fixed strings.
//
const ERR = {
  INVALID_ACTION: 'Invalid action.',
  INVALID_BODY: 'Invalid request body.',
  MISSING_EMAIL: 'Email is required.',
  MISSING_CODE: 'Verification code is required.',
  MISSING_REFRESH_TOKEN: 'No active session.',
  AUTH_FAILED: 'Authentication failed.',
  REFRESH_FAILED: 'Session refresh failed.',
  UNAVAILABLE: 'Service temporarily unavailable. Please try again later.',
} as const;

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/**
 * Proxy a POST request to a hardcoded backend endpoint.
 *
 * SECURITY: Only forwards Content-Type and the sanitized body.
 * Never forwards Authorization, Cookie, Host, Origin, or any other
 * browser header to prevent header injection and SSRF escalation.
 */
async function proxyPost(
  url: string,
  body: Record<string, string>,
): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), BACKEND_TIMEOUT_MS);
  try {
    return await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeoutId);
  }
}

/**
 * Shared cookie options applied to both session tokens.
 * httpOnly:    Prevents JavaScript access (mitigates XSS token theft).
 * path:        Available for all routes.
 * sameSite:    Strict — no cross-site transmission (CSRF protection).
 * secure:      HTTPS only in production; relaxed for local dev.
 * maxAge:      Caller-supplied lifetime in seconds.
 */
function tokenCookieOptions(maxAge: number): {
  httpOnly: true;
  path: '/';
  sameSite: 'strict';
  secure: boolean;
  maxAge: number;
} {
  return {
    httpOnly: true,
    path: '/',
    sameSite: 'strict',
    secure: IS_PRODUCTION,
    maxAge,
  };
}

/**
 * Decode the payload segment of a JWT without cryptographic verification.
 *
 * The NestJS backend verifies token signatures on every API call.
 * This function is used only to extract claims (sub, email, role) from an
 * already-issued token so the Next.js layout can read session state without
 * an extra backend round-trip.
 *
 * Returns null if the token is missing, malformed, or unparseable.
 */
function decodeJwtPayload(token: string): Record<string, unknown> | null {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    // base64url → UTF-8 string
    const payloadJson = Buffer.from(parts[1], 'base64url').toString('utf-8');
    const parsed: unknown = JSON.parse(payloadJson);
    if (
      typeof parsed !== 'object' ||
      parsed === null ||
      Array.isArray(parsed)
    ) {
      return null;
    }
    return parsed as Record<string, unknown>;
  } catch {
    return null;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// POST /api/auth/session
// ────────────────────────────────────────────────────────────────────────────

/**
 * Session management handler.
 *
 * Accepts a JSON body with an `action` discriminator field:
 *
 *   action='login'   → Request an OTP for the given email address.
 *   action='verify'  → Submit email + OTP code; receives tokens and sets
 *                      httpOnly session cookies.
 *   action='refresh' → Rotate both tokens using the refresh_token cookie.
 *   action='logout'  → Clear both session cookies (maxAge=0).
 *
 * Security invariants:
 *   - Backend URL is a hardcoded constant; it is never constructed from
 *     request headers or body fields.
 *   - Only whitelisted paths are proxied (ENDPOINTS map above).
 *   - Only Content-Type is forwarded to the backend; all other browser
 *     headers are stripped.
 *   - Raw backend error bodies are never relayed; all errors map to the
 *     fixed ERR strings above.
 *   - Tokens are stored exclusively in httpOnly cookies set server-side;
 *     they are never exposed in the JSON response body.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  // ── Parse and validate JSON body ─────────────────────────────────────────
  let parsed: unknown;
  try {
    parsed = await req.json();
  } catch {
    return NextResponse.json(
      { success: false, message: ERR.INVALID_BODY },
      { status: 400 },
    );
  }

  if (
    typeof parsed !== 'object' ||
    parsed === null ||
    Array.isArray(parsed)
  ) {
    return NextResponse.json(
      { success: false, message: ERR.INVALID_BODY },
      { status: 400 },
    );
  }

  const body = parsed as Record<string, unknown>;
  const { action } = body;

  switch (action) {
    // ── login: request an OTP for the given email ─────────────────────────
    case 'login': {
      const { email } = body;
      if (typeof email !== 'string' || email.trim() === '') {
        return NextResponse.json(
          { success: false, message: ERR.MISSING_EMAIL },
          { status: 400 },
        );
      }

      let backendRes: Response;
      try {
        backendRes = await proxyPost(ENDPOINTS.login, {
          email: email.trim().toLowerCase(),
        });
      } catch {
        return NextResponse.json(
          { success: false, message: ERR.UNAVAILABLE },
          { status: 503 },
        );
      }

      if (!backendRes.ok) {
        // Map all backend errors to a fixed client message
        const status = backendRes.status >= 500 ? 503 : 400;
        return NextResponse.json(
          { success: false, message: ERR.AUTH_FAILED },
          { status },
        );
      }

      return NextResponse.json({ success: true });
    }

    // ── verify: validate OTP and set session cookies ───────────────────────
    case 'verify': {
      const { email, code } = body;

      if (typeof email !== 'string' || email.trim() === '') {
        return NextResponse.json(
          { success: false, message: ERR.MISSING_EMAIL },
          { status: 400 },
        );
      }
      if (typeof code !== 'string' || code.trim() === '') {
        return NextResponse.json(
          { success: false, message: ERR.MISSING_CODE },
          { status: 400 },
        );
      }

      let verifyRes: Response;
      try {
        verifyRes = await proxyPost(ENDPOINTS.verify, {
          email: email.trim().toLowerCase(),
          otp: code.trim(),
        });
      } catch {
        return NextResponse.json(
          { success: false, message: ERR.UNAVAILABLE },
          { status: 503 },
        );
      }

      if (!verifyRes.ok) {
        const status = verifyRes.status >= 500 ? 503 : 401;
        return NextResponse.json(
          { success: false, message: ERR.AUTH_FAILED },
          { status },
        );
      }

      let verifyData: unknown;
      try {
        verifyData = await verifyRes.json();
      } catch {
        return NextResponse.json(
          { success: false, message: ERR.AUTH_FAILED },
          { status: 502 },
        );
      }

      if (
        typeof verifyData !== 'object' ||
        verifyData === null ||
        Array.isArray(verifyData)
      ) {
        return NextResponse.json(
          { success: false, message: ERR.AUTH_FAILED },
          { status: 502 },
        );
      }

      const {
        accessToken,
        refreshToken,
        user,
      } = verifyData as Record<string, unknown>;

      if (
        typeof accessToken !== 'string' ||
        typeof refreshToken !== 'string'
      ) {
        return NextResponse.json(
          { success: false, message: ERR.AUTH_FAILED },
          { status: 502 },
        );
      }

      // Tokens go into httpOnly cookies — never into the response body.
      // Allowlist only safe fields before forwarding the user object to the browser.
      const safeUser = {
        email: typeof (user as Record<string, unknown>)?.email === 'string'
          ? (user as Record<string, string>).email
          : undefined,
        role: typeof (user as Record<string, unknown>)?.role === 'string'
          ? (user as Record<string, string>).role
          : 'user',
      };
      const response = NextResponse.json({ success: true, user: safeUser });
      response.cookies.set(
        'access_token',
        accessToken,
        tokenCookieOptions(ACCESS_TOKEN_MAX_AGE),
      );
      response.cookies.set(
        'refresh_token',
        refreshToken,
        tokenCookieOptions(REFRESH_TOKEN_MAX_AGE),
      );
      return response;
    }

    // ── refresh: rotate both tokens ────────────────────────────────────────
    case 'refresh': {
      const existingRefreshToken = req.cookies.get('refresh_token')?.value;
      if (!existingRefreshToken) {
        return NextResponse.json(
          { success: false, message: ERR.MISSING_REFRESH_TOKEN },
          { status: 401 },
        );
      }

      let refreshRes: Response;
      try {
        refreshRes = await proxyPost(ENDPOINTS.refresh, {
          refreshToken: existingRefreshToken,
        });
      } catch {
        return NextResponse.json(
          { success: false, message: ERR.UNAVAILABLE },
          { status: 503 },
        );
      }

      if (!refreshRes.ok) {
        const status = refreshRes.status >= 500 ? 503 : 401;
        return NextResponse.json(
          { success: false, message: ERR.REFRESH_FAILED },
          { status },
        );
      }

      let refreshData: unknown;
      try {
        refreshData = await refreshRes.json();
      } catch {
        return NextResponse.json(
          { success: false, message: ERR.REFRESH_FAILED },
          { status: 502 },
        );
      }

      if (
        typeof refreshData !== 'object' ||
        refreshData === null ||
        Array.isArray(refreshData)
      ) {
        return NextResponse.json(
          { success: false, message: ERR.REFRESH_FAILED },
          { status: 502 },
        );
      }

      const {
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        user: refreshedUser,
      } = refreshData as Record<string, unknown>;

      if (
        typeof newAccessToken !== 'string' ||
        typeof newRefreshToken !== 'string'
      ) {
        return NextResponse.json(
          { success: false, message: ERR.REFRESH_FAILED },
          { status: 502 },
        );
      }

      // Allowlist only safe fields before forwarding the user object to the browser.
      const safeRefreshedUser = {
        email: typeof (refreshedUser as Record<string, unknown>)?.email === 'string'
          ? (refreshedUser as Record<string, string>).email
          : undefined,
        role: typeof (refreshedUser as Record<string, unknown>)?.role === 'string'
          ? (refreshedUser as Record<string, string>).role
          : 'user',
      };
      const response = NextResponse.json({ success: true, user: safeRefreshedUser });
      response.cookies.set(
        'access_token',
        newAccessToken,
        tokenCookieOptions(ACCESS_TOKEN_MAX_AGE),
      );
      response.cookies.set(
        'refresh_token',
        newRefreshToken,
        tokenCookieOptions(REFRESH_TOKEN_MAX_AGE),
      );
      return response;
    }

    // ── logout: clear both session cookies ─────────────────────────────────
    case 'logout': {
      const response = NextResponse.json({ success: true });
      response.cookies.set(
        'access_token',
        '',
        tokenCookieOptions(0),
      );
      response.cookies.set(
        'refresh_token',
        '',
        tokenCookieOptions(0),
      );
      return response;
    }

    // ── unknown action ──────────────────────────────────────────────────────
    default:
      return NextResponse.json(
        { success: false, message: ERR.INVALID_ACTION },
        { status: 400 },
      );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// GET /api/auth/session
// ────────────────────────────────────────────────────────────────────────────

/**
 * Returns the current session state by decoding the access_token cookie.
 *
 * IMPORTANT: This does NOT cryptographically verify the JWT signature.
 * The signature is verified by the NestJS backend on every authenticated
 * API request. This endpoint is used only for fast session-state checks
 * in the Next.js admin layout (e.g., redirect unauthenticated visitors
 * to /admin/login without a backend round-trip).
 *
 * Responses:
 *   { authenticated: true,  user: { sub, email, role } }  — valid cookie
 *   { authenticated: false }                               — missing / malformed
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const accessToken = req.cookies.get('access_token')?.value;

  if (!accessToken) {
    return NextResponse.json({ authenticated: false });
  }

  const payload = decodeJwtPayload(accessToken);

  if (!payload) {
    return NextResponse.json({ authenticated: false });
  }

  const { sub, email, role } = payload;

  // All three claims must be present strings for a valid admin session
  if (
    typeof sub !== 'string' ||
    typeof email !== 'string' ||
    typeof role !== 'string'
  ) {
    return NextResponse.json({ authenticated: false });
  }

  return NextResponse.json({
    authenticated: true,
    user: { sub, email, role },
  });
}
