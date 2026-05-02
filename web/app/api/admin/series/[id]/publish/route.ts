import { NextRequest, NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';

// ────────────────────────────────────────────────────────────────────────────
// PATCH /api/admin/series/[id]/publish
// ────────────────────────────────────────────────────────────────────────────

/**
 * Series Publish Toggle Proxy — Next.js Route Handler
 *
 * Proxies the series publish/unpublish toggle to the NestJS backend using
 * server-side httpOnly cookies (access_token). This keeps the admin JWT
 * off the browser and allows the series list publish toggle to operate
 * via a same-origin fetch.
 *
 * Upstream: PATCH /series/:id/publish (NestJS → SeriesDto)
 * Downstream: PATCH /api/admin/series/:id/publish (browser → Next.js)
 *
 * Expected body: { is_published: boolean }
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
    const data = await adminFetch<unknown>(`/series/${id}/publish`, {
      method: 'PATCH',
      body,
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
      { error: 'Failed to update series publish state' },
      { status: 500 },
    );
  }
}
