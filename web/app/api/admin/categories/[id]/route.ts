import { NextRequest, NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';

// ────────────────────────────────────────────────────────────────────────────
// PATCH /api/admin/categories/[id]
// ────────────────────────────────────────────────────────────────────────────

/**
 * Category Update Proxy — Next.js Route Handler
 *
 * Proxies category update requests to the NestJS backend using server-side
 * httpOnly cookies (access_token). This keeps the admin JWT off the browser.
 *
 * Upstream: PATCH /admin/categories/:id (NestJS)
 * Downstream: PATCH /api/admin/categories/:id (browser → Next.js)
 *
 * Expected body: { name?: string; icon?: string; color?: string; is_published?: boolean; sort_order?: number }
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
    const data = await adminFetch<unknown>(`/admin/categories/${id}`, {
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
      { error: 'Failed to update category' },
      { status: 500 },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// DELETE /api/admin/categories/[id]
// ────────────────────────────────────────────────────────────────────────────

/**
 * Category Delete Proxy — Next.js Route Handler
 *
 * Proxies category soft-delete requests to the NestJS backend using
 * server-side httpOnly cookies (access_token). The backend performs a
 * soft-delete (sets is_published=false, marks deleted_at).
 *
 * Upstream: DELETE /admin/categories/:id (NestJS → 204 No Content)
 * Downstream: DELETE /api/admin/categories/:id (browser → Next.js)
 *
 * Error mapping:
 *   AdminApiError UNAUTHORIZED → 401
 *   AdminApiError FORBIDDEN    → 403
 *   Any other error            → 500
 */
export async function DELETE(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
): Promise<NextResponse> {
  const { id } = await params;

  try {
    await adminFetch<unknown>(`/admin/categories/${id}`, {
      method: 'DELETE',
    });
    return new NextResponse(null, { status: 204 });
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
      { error: 'Failed to delete category' },
      { status: 500 },
    );
  }
}
