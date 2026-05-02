import { NextRequest, NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';

// ────────────────────────────────────────────────────────────────────────────
// GET /api/admin/plan-voices
// ────────────────────────────────────────────────────────────────────────────

/**
 * Plan Voices (Failed Jobs) Proxy — Next.js Route Handler
 *
 * Proxies the failed plan-voice job listing to the NestJS backend using
 * server-side httpOnly cookies (access_token). This keeps the admin JWT
 * off the browser and allows the client-side PlanVoiceJobTable to fetch
 * failed TTS job data via a same-origin request.
 *
 * Upstream: GET /admin/plan-voices?status=failed&page=N&pageSize=N (NestJS)
 * Downstream: GET /api/admin/plan-voices (browser → Next.js)
 *
 * Query params forwarded: status, page, pageSize
 *
 * Error mapping:
 *   AdminApiError UNAUTHORIZED → 401
 *   AdminApiError FORBIDDEN    → 403
 *   Any other error            → 500
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const { searchParams } = req.nextUrl;
  const status = searchParams.get('status') ?? 'failed';
  const page = searchParams.get('page') ?? undefined;
  const pageSize = searchParams.get('pageSize') ?? undefined;

  try {
    const data = await adminFetch<unknown>('/admin/plan-voices', {
      query: {
        status,
        ...(page !== undefined ? { page } : {}),
        ...(pageSize !== undefined ? { pageSize } : {}),
      },
    });
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
      { error: 'Failed to fetch plan voices' },
      { status: 500 },
    );
  }
}
