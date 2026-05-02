import { cookies } from 'next/headers';

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

/**
 * NestJS backend base URL — resolved from environment variable.
 * SECURITY: Never construct from request headers or user input.
 */
const BACKEND_URL = process.env.BACKEND_URL ?? 'http://localhost:3071/api';

// ────────────────────────────────────────────────────────────────────────────
// Error type
// ────────────────────────────────────────────────────────────────────────────

/**
 * Structured error thrown by adminFetch on non-OK responses.
 *
 * The `code` field maps specific HTTP status codes to symbolic names so
 * that callers can branch on error type without parsing status integers.
 *
 *   'UNAUTHORIZED'    — 401: missing or expired token
 *   'FORBIDDEN'       — 403: valid token but insufficient role
 *   'GATEWAY_TIMEOUT' — 504: backend/database query timed out
 *   string            — any other status text for unexpected errors
 */
export class AdminApiError extends Error {
  constructor(
    message: string,
    public readonly code: 'UNAUTHORIZED' | 'FORBIDDEN' | string,
  ) {
    super(message);
    this.name = 'AdminApiError';
  }
}

// ────────────────────────────────────────────────────────────────────────────
// adminFetch
// ────────────────────────────────────────────────────────────────────────────

/**
 * Server-side fetch helper for admin analytics endpoints.
 *
 * Reads the `access_token` httpOnly cookie set by the session handler and
 * forwards it as a Bearer token. Should only be called from React Server
 * Components or Next.js Route Handlers — NOT from client components.
 *
 * URL construction:
 *   BACKEND_URL + path + (range ? '?range=' + range : '')
 *
 * Error handling:
 *   401 → throws AdminApiError with code 'UNAUTHORIZED'
 *   403 → throws AdminApiError with code 'FORBIDDEN'
 *   504 → throws AdminApiError with code 'GATEWAY_TIMEOUT'
 *   non-ok → throws AdminApiError with response statusText as code
 *
 * @param path   Backend path relative to BACKEND_URL (e.g. '/admin/analytics/overview')
 * @param options.range   Optional range query param (e.g. '7d', '30d', '90d')
 * @param options.query   Additional query params — string/number/boolean values; `undefined`/`null` skipped
 * @param options.method  HTTP method (default 'GET')
 * @param options.body    Request body — serialized as JSON when provided
 * @returns      Parsed JSON response typed as T
 */
export async function adminFetch<T>(
  path: string,
  options?: {
    range?: string;
    query?: Record<string, string | number | boolean | undefined | null>;
    method?: 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE';
    body?: unknown;
  },
): Promise<T> {
  const cookieStore = await cookies();
  const accessToken = cookieStore.get('access_token')?.value ?? '';

  const params = new URLSearchParams();
  if (options?.range) params.set('range', options.range);
  if (options?.query) {
    for (const [k, v] of Object.entries(options.query)) {
      if (v !== undefined && v !== null && v !== '') params.set(k, String(v));
    }
  }
  const qs = params.toString();
  const url = BACKEND_URL + path + (qs ? '?' + qs : '');

  let response: Response;
  try {
    response = await fetch(url, {
      method: options?.method ?? 'GET',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: options?.body !== undefined ? JSON.stringify(options.body) : undefined,
      // Disable Next.js caching — admin data should always be fresh
      cache: 'no-store',
    });
  } catch (cause) {
    throw new AdminApiError(
      cause instanceof Error ? cause.message : 'Network error',
      'NETWORK_ERROR',
    );
  }

  if (response.status === 401) {
    throw new AdminApiError('Unauthorized — token missing or expired', 'UNAUTHORIZED');
  }

  if (response.status === 403) {
    throw new AdminApiError('Forbidden — admin role required', 'FORBIDDEN');
  }

  if (response.status === 504) {
    throw new AdminApiError('Database query timed out', 'GATEWAY_TIMEOUT');
  }

  if (!response.ok) {
    throw new AdminApiError(response.statusText || 'Request failed', String(response.status));
  }

  // 204 No Content or an empty body — common for void-returning NestJS handlers
  // (e.g. reorder-plans, delete). response.json() would throw "Unexpected end
  // of JSON input" on these, so short-circuit and return undefined.
  if (response.status === 204) {
    return undefined as T;
  }
  const text = await response.text();
  if (text.length === 0) {
    return undefined as T;
  }
  return JSON.parse(text) as T;
}
