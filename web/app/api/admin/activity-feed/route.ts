import { NextRequest, NextResponse } from 'next/server';

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

/**
 * NestJS backend base URL — resolved from environment variable.
 * SECURITY: Never construct from request headers or user input.
 */
const BACKEND_URL = process.env.BACKEND_URL ?? 'http://localhost:3071/api';

/**
 * Hardcoded backend endpoint for the activity feed.
 * Never derived from request input — prevents SSRF escalation.
 */
const ACTIVITY_ENDPOINT = `${BACKEND_URL}/admin/analytics/overview/activity`;

/** Backend proxy timeout: 10 seconds */
const BACKEND_TIMEOUT_MS = 10_000;

// ────────────────────────────────────────────────────────────────────────────
// GET /api/admin/activity-feed
// ────────────────────────────────────────────────────────────────────────────

/**
 * Route handler proxy for the admin activity feed.
 *
 * Acts as a same-origin proxy so the ActivityFeedWidget (client component)
 * can poll for fresh data without exposing the NestJS backend URL or auth
 * token to browser JavaScript.
 *
 * Flow:
 *   1. Reads the httpOnly `access_token` cookie set by /api/auth/session.
 *   2. Forwards it as a Bearer token to the NestJS backend.
 *   3. Returns the backend's ActivityFeedResponse JSON as-is.
 *
 * Security invariants:
 *   - Backend URL is a hardcoded constant; never constructed from request input.
 *   - Only the Authorization header is forwarded; all browser headers stripped.
 *   - Raw backend error bodies are never relayed to the client.
 *   - No caching — activity data must always be fresh.
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const accessToken = req.cookies.get('access_token')?.value;

  if (!accessToken) {
    return NextResponse.json(
      { error: 'Unauthorized — no active session' },
      { status: 401 },
    );
  }

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), BACKEND_TIMEOUT_MS);

  try {
    const backendRes = await fetch(ACTIVITY_ENDPOINT, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      cache: 'no-store',
      signal: controller.signal,
    });

    if (backendRes.status === 401) {
      return NextResponse.json(
        { error: 'Unauthorized — token missing or expired' },
        { status: 401 },
      );
    }

    if (backendRes.status === 403) {
      return NextResponse.json(
        { error: 'Forbidden — admin role required' },
        { status: 403 },
      );
    }

    if (!backendRes.ok) {
      return NextResponse.json(
        { error: 'Failed to fetch activity feed' },
        { status: backendRes.status >= 500 ? 503 : backendRes.status },
      );
    }

    const data: unknown = await backendRes.json();
    return NextResponse.json(data);
  } catch (err) {
    const isTimeout =
      err instanceof DOMException && err.name === 'AbortError';
    return NextResponse.json(
      {
        error: isTimeout
          ? 'Activity feed request timed out'
          : 'Service temporarily unavailable',
      },
      { status: 503 },
    );
  } finally {
    clearTimeout(timeoutId);
  }
}
