import { NextRequest, NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';

// ────────────────────────────────────────────────────────────────────────────
// PATCH /api/admin/categories/reorder
// ────────────────────────────────────────────────────────────────────────────

/**
 * Category Reorder Proxy — Next.js Route Handler
 *
 * Proxies drag-and-drop category reorder requests to the NestJS backend
 * using server-side httpOnly cookies (access_token). This keeps the admin
 * JWT off the browser.
 *
 * Upstream: PATCH /admin/categories/reorder (NestJS)
 * Downstream: PATCH /api/admin/categories/reorder (browser → Next.js)
 *
 * Expected body: Array<{ id: string; sort_order: number }>
 *
 * Error mapping:
 *   AdminApiError UNAUTHORIZED → 401
 *   AdminApiError FORBIDDEN    → 403
 *   Any other error            → 500
 */
export async function PATCH(req: NextRequest): Promise<NextResponse> {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid request body' }, { status: 400 });
  }

  try {
    const data = await adminFetch<unknown>('/admin/categories/reorder', {
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
      { error: 'Failed to reorder categories' },
      { status: 500 },
    );
  }
}
