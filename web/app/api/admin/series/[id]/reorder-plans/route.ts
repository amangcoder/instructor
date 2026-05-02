import { NextRequest, NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';

// ────────────────────────────────────────────────────────────────────────────
// PATCH /api/admin/series/[id]/reorder-plans
// ────────────────────────────────────────────────────────────────────────────

/**
 * Series Plan Reorder Proxy — Next.js Route Handler
 *
 * Proxies drag-and-drop plan reorder within a series to the NestJS backend
 * using server-side httpOnly cookies (access_token). This keeps the admin
 * JWT off the browser and allows the series plan list to reorder via a
 * same-origin fetch.
 *
 * Upstream: PATCH /series/:id/reorder-plans (NestJS → 200)
 * Downstream: PATCH /api/admin/series/:id/reorder-plans (browser → Next.js)
 *
 * Expected body: Array<{ planId: string; position: number }>
 *
 * Error mapping:
 *   AdminApiError UNAUTHORIZED → 401
 *   AdminApiError FORBIDDEN    → 403
 *   Any other error            → 500
 */
export async function PATCH(
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
    await adminFetch<unknown>(`/series/${id}/reorder-plans`, {
      method: 'PATCH',
      body,
    });
    return NextResponse.json({ success: true });
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
      { error: 'Failed to reorder plans in series' },
      { status: 500 },
    );
  }
}
