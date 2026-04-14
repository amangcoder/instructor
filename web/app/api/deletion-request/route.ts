import { NextRequest, NextResponse } from 'next/server';
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

/** RFC 5322-inspired email regex for server-side validation */
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** Maximum allowed request body size (1 KB) */
const MAX_BODY_BYTES = 1_024;

/** NestJS backend base URL, defaulting to local dev */
const BACKEND_URL = process.env.BACKEND_URL ?? 'http://localhost:3071';
const DELETION_ENDPOINT = `${BACKEND_URL}/api/admin/deletion-requests`;

/** API key for NestJS backend authentication */
const API_KEY = process.env.API_KEY ?? '';

/** Fallback support email when the backend is unreachable */
const SUPPORT_EMAIL = process.env.SUPPORT_EMAIL ?? 'support@instructor-app.io';

/** Rate-limit ceiling: requests per IP per window */
const RATE_LIMIT_MAX = 20;

/** Allowed scope values matching the NestJS DeletionRequestDto @IsIn list */
const VALID_SCOPES = new Set(['full_account', 'audio_cache', 'plans']);

/** Backend request timeout (10 seconds) */
const BACKEND_TIMEOUT_MS = 10_000;

// ────────────────────────────────────────────────────────────────────────────
// Distributed rate limiter (Upstash Redis sliding window)
//
// Requires environment variables:
//   UPSTASH_REDIS_REST_URL   — Upstash Redis REST endpoint
//   UPSTASH_REDIS_REST_TOKEN — Upstash Redis REST token
//
// Uses a sliding window of RATE_LIMIT_MAX requests per hour, shared across
// all serverless function instances so limits are enforced globally.
//
// When the Upstash env vars are absent (e.g. local dev), the module falls
// back to a no-op rate limiter that always allows requests rather than
// throwing at import time.
// ────────────────────────────────────────────────────────────────────────────

let ratelimit: Ratelimit | null = null;

try {
  if (process.env.UPSTASH_REDIS_REST_URL && process.env.UPSTASH_REDIS_REST_TOKEN) {
    ratelimit = new Ratelimit({
      redis: Redis.fromEnv(),
      limiter: Ratelimit.slidingWindow(RATE_LIMIT_MAX, '1 h'),
      prefix: 'deletion_request',
    });
  }
} catch {
  // Upstash env vars missing or invalid — fall back to no-op limiter below
  ratelimit = null;
}

/**
 * Returns whether the given IP is within the rate limit window and how many
 * requests remain. Delegates to Upstash Redis for cross-instance enforcement.
 * Falls back to allow-all when Upstash is not configured.
 */
async function checkRateLimit(ip: string): Promise<{ allowed: boolean; remaining: number }> {
  if (!ratelimit) {
    // No-op: allow all requests when Upstash is not configured
    return { allowed: true, remaining: RATE_LIMIT_MAX };
  }
  const { success, remaining } = await ratelimit.limit(ip);
  return { allowed: success, remaining };
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/**
 * Extracts the originating client IP from request headers.
 * Prefers platform-injected headers (x-real-ip, cf-connecting-ip) that
 * cannot be spoofed by the client over the user-controlled X-Forwarded-For.
 * Falls back to the leftmost XFF value for non-Vercel/Cloudflare deployments.
 */
function getClientIp(req: NextRequest): string {
  // Vercel injects x-real-ip; Cloudflare injects cf-connecting-ip.
  // These are set by the edge network and cannot be forged by the client.
  const realIp = req.headers.get('x-real-ip') ?? req.headers.get('cf-connecting-ip');
  if (realIp) return realIp.trim();

  // Fallback for non-Vercel/Cloudflare deployments where a trusted reverse proxy
  // sets X-Forwarded-For. Rate limiting is defense-in-depth here, secondary to
  // the API key protection on the NestJS endpoint.
  const forwarded = req.headers.get('x-forwarded-for');
  if (forwarded) {
    return forwarded.split(',')[0].trim();
  }
  return 'unknown';
}

/** Generic 503 response with a mailto: fallback for service unavailability */
function serviceUnavailableResponse(isTimeout: boolean): NextResponse {
  const mailtoLink =
    `mailto:${SUPPORT_EMAIL}` +
    `?subject=${encodeURIComponent('Data Deletion Request')}` +
    `&body=${encodeURIComponent('Please delete my account data.')}`;

  return NextResponse.json(
    {
      success: false,
      message:
        `Service temporarily unavailable. Please email us directly at ${SUPPORT_EMAIL}.`,
      fallback: mailtoLink,
    },
    {
      status: 503,
      headers: { 'Retry-After': isTimeout ? '30' : '60' },
    },
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Route Handler
// ────────────────────────────────────────────────────────────────────────────

/**
 * POST /api/deletion-request
 *
 * Receives data deletion form submissions from the DeletionForm client
 * component, validates and sanitizes the input, applies per-IP rate limiting,
 * then proxies the sanitized request to the NestJS admin endpoint.
 *
 * Security measures:
 *  - Content-Type enforcement (CSRF mitigation)
 *  - Per-IP rate limiting (20 req/hour)
 *  - Request body size cap (1 KB)
 *  - Server-side email regex validation
 *  - Sanitized body forwarding (never forwards raw client body)
 *  - No forwarding of Authorization, Cookie, Host, or other client headers
 *  - Identical success response for existing and non-existing emails
 *    (prevents user enumeration)
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  // ── Step 1: Content-Type validation (CSRF protection) ────────────────────
  const contentType = req.headers.get('content-type') ?? '';
  if (!contentType.includes('application/json')) {
    return NextResponse.json(
      { success: false, message: 'Unsupported media type.' },
      { status: 415 },
    );
  }

  // ── Step 2: Per-IP rate limiting ─────────────────────────────────────────
  const clientIp = getClientIp(req);
  const { allowed, remaining } = await checkRateLimit(clientIp);

  if (!allowed) {
    return NextResponse.json(
      {
        success: false,
        message: 'Too many requests. Please try again in an hour.',
      },
      {
        status: 429,
        headers: {
          'Retry-After': '3600',
          'X-RateLimit-Limit': String(RATE_LIMIT_MAX),
          'X-RateLimit-Remaining': '0',
        },
      },
    );
  }

  // ── Step 3: Read body with size enforcement ───────────────────────────────
  let rawBody: string;
  try {
    rawBody = await req.text();
  } catch {
    return NextResponse.json(
      { success: false, message: 'Failed to read request body.' },
      { status: 400 },
    );
  }

  if (new TextEncoder().encode(rawBody).length > MAX_BODY_BYTES) {
    return NextResponse.json(
      { success: false, message: 'Request body too large.' },
      { status: 413 },
    );
  }

  // ── Step 4: JSON parsing ──────────────────────────────────────────────────
  let parsed: unknown;
  try {
    parsed = JSON.parse(rawBody);
  } catch {
    return NextResponse.json(
      { success: false, message: 'Invalid JSON body.' },
      { status: 400 },
    );
  }

  // ── Step 5: Structure validation ─────────────────────────────────────────
  if (
    typeof parsed !== 'object' ||
    parsed === null ||
    Array.isArray(parsed)
  ) {
    return NextResponse.json(
      { success: false, message: 'Invalid request body.' },
      { status: 400 },
    );
  }

  const { email, scope, reason: parsedReason } = parsed as Record<string, unknown>;

  // email must be a non-empty string
  if (typeof email !== 'string' || email.trim() === '') {
    return NextResponse.json(
      { success: false, message: 'Invalid request body.' },
      { status: 400 },
    );
  }

  // scope must be a non-empty string or a non-empty array of strings
  const scopeIsValidString = typeof scope === 'string' && scope.trim() !== '';
  const scopeIsValidArray =
    Array.isArray(scope) &&
    scope.length > 0 &&
    (scope as unknown[]).every(
      (item) => typeof item === 'string' && (item as string).trim() !== '',
    );

  if (!scopeIsValidString && !scopeIsValidArray) {
    return NextResponse.json(
      { success: false, message: 'Invalid request body.' },
      { status: 400 },
    );
  }

  // Validate scope values against the backend DTO's allowed list so that
  // mismatched values produce an explicit 400 here rather than being silently
  // promoted to 201 by the anti-enumeration logic below.
  if (scopeIsValidString && !VALID_SCOPES.has((scope as string).trim())) {
    return NextResponse.json(
      { success: false, message: 'Invalid request body.' },
      { status: 400 },
    );
  }
  if (scopeIsValidArray) {
    const allItemsValid = (scope as string[]).every((item) =>
      VALID_SCOPES.has(item.trim()),
    );
    if (!allItemsValid) {
      return NextResponse.json(
        { success: false, message: 'Invalid request body.' },
        { status: 400 },
      );
    }
  }

  // ── Step 6: Server-side email format validation ───────────────────────────
  if (!EMAIL_REGEX.test(email.trim())) {
    // Use a generic message to avoid hinting at the validation rule
    return NextResponse.json(
      { success: false, message: 'Invalid request body.' },
      { status: 400 },
    );
  }

  // ── Step 7: Construct sanitized body (only whitelisted fields) ────────────
  const sanitizedBody: Record<string, unknown> = {
    email: email.trim().toLowerCase(),
    scope,
    requestedAt: new Date().toISOString(),
    // Forward reason only if it is a non-empty string, capped at 1 000 chars
    // to match the DTO MaxLength constraint. Silently discarding user-provided
    // context breaks trust and defeats the purpose of collecting it.
    ...(typeof parsedReason === 'string' && parsedReason.trim()
      ? { reason: parsedReason.trim().slice(0, 1000) }
      : {}),
  };

  // ── Step 8: Forward to NestJS backend with timeout ────────────────────────
  const controller = new AbortController();
  const timeoutId = setTimeout(
    () => controller.abort(),
    BACKEND_TIMEOUT_MS,
  );

  try {
    const backendResponse = await fetch(DELETION_ENDPOINT, {
      method: 'POST',
      // Only forward these three headers — never Authorization, Cookie, Host, etc.
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': API_KEY,
        'X-Forwarded-For': clientIp,
      },
      body: JSON.stringify(sanitizedBody),
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    // ── Step 9: Identical response regardless of backend result ────────────
    // This prevents user-enumeration attacks: both "email found" and
    // "email not found" backend responses return the same 201 to the client.
    if (backendResponse.status < 500) {
      return NextResponse.json(
        {
          success: true,
          message:
            'Your deletion request has been received. We will process it ' +
            'within 30 days in accordance with applicable data protection law.',
        },
        {
          status: 201,
          headers: {
            'X-RateLimit-Remaining': String(remaining),
          },
        },
      );
    }

    // Backend returned a 5xx — treat as service error
    throw new Error(`Backend error: ${backendResponse.status}`);
  } catch (err) {
    clearTimeout(timeoutId);

    const isTimeout =
      err instanceof Error && err.name === 'AbortError';

    // ── Step 10: 503 with mailto: fallback ────────────────────────────────
    return serviceUnavailableResponse(isTimeout);
  }
}
