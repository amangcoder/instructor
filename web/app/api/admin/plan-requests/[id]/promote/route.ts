import { NextRequest, NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';

// ────────────────────────────────────────────────────────────────────────────
// POST /api/admin/plan-requests/[id]/promote
// ────────────────────────────────────────────────────────────────────────────

/**
 * Plan Request Promote Proxy — Next.js Route Handler
 *
 * Proxies the "Promote to Plan" action to the NestJS backend using
 * server-side httpOnly cookies (access_token). This keeps the admin JWT
 * off the browser and allows the PromoteModal to submit via a same-origin
 * fetch.
 *
 * The backend atomically creates a plan record + N plan_voices rows +
 * queues TTS generation in a single transaction; fully rolls back on error.
 *
 * Upstream: POST /admin/plan-requests/:id/promote (NestJS → 201 { planId })
 * Downstream: POST /api/admin/plan-requests/:id/promote (browser → Next.js)
 *
 * Expected body: { voiceIds: string[]; seriesId?: string; categoryId?: string; position?: number }
 *
 * Error mapping:
 *   AdminApiError UNAUTHORIZED → 401
 *   AdminApiError FORBIDDEN    → 403
 *   Any other error            → 500
 */
export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
): Promise<NextResponse> {
  const { id } = await params;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid request body' }, { status: 400 });
  }

  try {
    const data = await adminFetch<unknown>(`/admin/plan-requests/${id}/promote`, {
      method: 'POST',
      body,
    });
    return NextResponse.json(data, { status: 201 });
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
      { error: 'Failed to promote plan request' },
      { status: 500 },
    );
  }
}
