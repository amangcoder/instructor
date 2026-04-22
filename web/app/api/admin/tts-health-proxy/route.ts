import { NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';
import type { TtsHealthResponse } from '@/types/tts-health';

// ────────────────────────────────────────────────────────────────────────────
// GET /api/admin/tts-health-proxy
// ────────────────────────────────────────────────────────────────────────────

/**
 * TTS Health Proxy — Next.js Route Handler
 *
 * Proxies the TTS provider health request to the NestJS backend using
 * server-side httpOnly cookies (access_token). This keeps the admin JWT
 * off the browser and allows the client-side TtsHealthBanner to poll
 * health status via a same-origin fetch.
 *
 * Upstream: GET /admin/analytics/tts/health (NestJS)
 * Downstream: GET /api/admin/tts-health-proxy (browser → Next.js)
 *
 * Error mapping:
 *   AdminApiError UNAUTHORIZED → 401
 *   AdminApiError FORBIDDEN    → 403
 *   Any other error            → 500
 */
export async function GET(): Promise<NextResponse> {
  try {
    const data = await adminFetch<TtsHealthResponse>('/admin/analytics/tts/health');
    return NextResponse.json(data);
  } catch (error) {
    if (error instanceof AdminApiError) {
      const status =
        error.code === 'UNAUTHORIZED'
          ? 401
          : error.code === 'FORBIDDEN'
            ? 403
            : 500;
      return NextResponse.json({ error: error.message }, { status });
    }
    return NextResponse.json(
      { error: 'Failed to fetch TTS health' },
      { status: 500 },
    );
  }
}
