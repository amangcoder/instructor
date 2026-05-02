import { NextRequest, NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';

// ────────────────────────────────────────────────────────────────────────────
// GET /api/admin/plans/[id]
// ────────────────────────────────────────────────────────────────────────────

/**
 * Plan Detail Proxy — Next.js Route Handler
 *
 * Proxies plan detail fetch to the NestJS backend using server-side
 * httpOnly cookies (access_token).
 *
 * Upstream: GET /admin/plans/:id (NestJS)
 * Downstream: GET /api/admin/plans/:id (browser → Next.js)
 *
 * Error mapping:
 *   AdminApiError UNAUTHORIZED → 401
 *   AdminApiError FORBIDDEN    → 403
 *   Any other error            → 500
 */
export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
): Promise<NextResponse> {
  const { id } = await params;

  try {
    const data = await adminFetch<unknown>(`/admin/plans/${id}`);
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
      { error: 'Failed to fetch plan' },
      { status: 500 },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// PATCH /api/admin/plans/[id]
// ────────────────────────────────────────────────────────────────────────────

/**
 * Plan Update Proxy — Next.js Route Handler
 *
 * Proxies plan update requests to the NestJS backend using server-side
 * httpOnly cookies (access_token). This keeps the admin JWT off the browser.
 *
 * Upstream: PATCH /admin/plans/:id (NestJS)
 * Downstream: PATCH /api/admin/plans/:id (browser → Next.js)
 *
 * Expected body: { parentPlanId?: string|null; position?: number; visibility?: string; isPublished?: boolean }
 *
 * Error mapping:
 *   AdminApiError UNAUTHORIZED → 401
 *   AdminApiError FORBIDDEN    → 403
 *   422 status text            → 422 (depth exceeded)
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
    const data = await adminFetch<unknown>(`/admin/plans/${id}`, {
      method: 'PATCH',
      body,
    });
    return NextResponse.json(data);
  } catch (error) {
    if (error instanceof AdminApiError) {
      // Map 422 specifically for depth validation errors
      const statusCode = parseInt(error.code, 10);
      const status =
        error.code === 'UNAUTHORIZED'
          ? 401
          : error.code === 'FORBIDDEN'
            ? 403
            : statusCode === 422
              ? 422
              : 500;
      return NextResponse.json({ error: error.message }, { status });
    }
    return NextResponse.json(
      { error: 'Failed to update plan' },
      { status: 500 },
    );
  }
}
