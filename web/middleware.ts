import { NextRequest, NextResponse } from 'next/server';

/**
 * NestJS backend base URL — resolved from environment variable.
 * SECURITY: Never construct from request headers or user input.
 */
const BACKEND_URL = process.env.BACKEND_URL ?? 'http://localhost:3071/api';

const IS_PRODUCTION = process.env.NODE_ENV === 'production';

/** Access token cookie lifetime: 15 minutes (matches JWT expiry). */
const ACCESS_TOKEN_MAX_AGE = 900;

/** Refresh token cookie lifetime: 30 days. */
const REFRESH_TOKEN_MAX_AGE = 2_592_000;

/**
 * Refresh proactively when the access token has this many seconds (or fewer)
 * left. Prevents a token from expiring mid-flight between the middleware
 * decision and the downstream backend call.
 */
const REFRESH_LEEWAY_SEC = 60;

/** Backend refresh call timeout. */
const BACKEND_TIMEOUT_MS = 5_000;

/**
 * Decode the `exp` claim of a JWT without verifying its signature. The backend
 * verifies signatures on every authenticated call — this is only used to
 * decide whether the token is close to expiry.
 */
function decodeJwtExp(token: string): number | null {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const payloadJson = Buffer.from(parts[1], 'base64url').toString('utf-8');
    const parsed: unknown = JSON.parse(payloadJson);
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
      return null;
    }
    const exp = (parsed as Record<string, unknown>).exp;
    return typeof exp === 'number' ? exp : null;
  } catch {
    return null;
  }
}

const cookieOptions = {
  httpOnly: true as const,
  path: '/' as const,
  sameSite: 'strict' as const,
  secure: IS_PRODUCTION,
};

/**
 * Replace the inbound `cookie` header with rotated tokens so that the
 * downstream layout / route handler sees fresh values via `cookies()`. Other
 * cookies on the request are preserved.
 */
function rewriteCookieHeader(
  req: NextRequest,
  newAccess: string,
  newRefresh: string,
): Headers {
  const headers = new Headers(req.headers);
  const incoming = req.headers.get('cookie') ?? '';
  const preserved = incoming
    .split(';')
    .map((c) => c.trim())
    .filter(
      (c) =>
        c &&
        !c.startsWith('access_token=') &&
        !c.startsWith('refresh_token='),
    );
  preserved.push(`access_token=${newAccess}`);
  preserved.push(`refresh_token=${newRefresh}`);
  headers.set('cookie', preserved.join('; '));
  return headers;
}

/**
 * Admin session middleware.
 *
 * Runs ahead of every admin page render and every admin API call. If the
 * access_token cookie is missing, expired, or about to expire — and we still
 * have a refresh_token — call the backend `/auth/refresh` endpoint, rotate
 * both cookies, and forward the rotated access_token to the same request so
 * downstream code sees fresh credentials.
 *
 * On any failure (no refresh token, backend error, malformed response) the
 * middleware passes the request through untouched. The downstream layout's
 * existing auth gate will redirect to /admin/login, and the user will see
 * their session end — which is the correct behaviour when the refresh token
 * itself is invalid.
 */
export async function middleware(req: NextRequest): Promise<NextResponse> {
  const accessToken = req.cookies.get('access_token')?.value;
  const refreshToken = req.cookies.get('refresh_token')?.value;

  if (!refreshToken) {
    return NextResponse.next();
  }

  // If the access token is present and not within the leeway window, skip.
  if (accessToken) {
    const exp = decodeJwtExp(accessToken);
    if (exp !== null && Date.now() / 1000 < exp - REFRESH_LEEWAY_SEC) {
      return NextResponse.next();
    }
  }

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), BACKEND_TIMEOUT_MS);

  let backendRes: Response;
  try {
    backendRes = await fetch(`${BACKEND_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken }),
      signal: controller.signal,
    });
  } catch {
    return NextResponse.next();
  } finally {
    clearTimeout(timeoutId);
  }

  if (!backendRes.ok) {
    return NextResponse.next();
  }

  let parsed: unknown;
  try {
    parsed = await backendRes.json();
  } catch {
    return NextResponse.next();
  }

  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    return NextResponse.next();
  }

  const { accessToken: newAccess, refreshToken: newRefresh } = parsed as Record<
    string,
    unknown
  >;
  if (typeof newAccess !== 'string' || typeof newRefresh !== 'string') {
    return NextResponse.next();
  }

  const requestHeaders = rewriteCookieHeader(req, newAccess, newRefresh);
  const response = NextResponse.next({ request: { headers: requestHeaders } });
  response.cookies.set('access_token', newAccess, {
    ...cookieOptions,
    maxAge: ACCESS_TOKEN_MAX_AGE,
  });
  response.cookies.set('refresh_token', newRefresh, {
    ...cookieOptions,
    maxAge: REFRESH_TOKEN_MAX_AGE,
  });
  return response;
}

/**
 * Match every admin page and admin API route, except:
 *   - /admin/login            — no session yet, nothing to refresh
 *   - /api/auth/session       — the explicit session-management endpoint
 *
 * Static assets and Next.js internals are not matched.
 */
export const config = {
  matcher: [
    '/admin/((?!login$|login/).*)',
    '/api/admin/:path*',
  ],
};
