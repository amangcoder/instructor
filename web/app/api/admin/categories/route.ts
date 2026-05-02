import { NextRequest, NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';

// ────────────────────────────────────────────────────────────────────────────
// GET /api/admin/categories
// ────────────────────────────────────────────────────────────────────────────

/**
 * Categories List Proxy — Next.js Route Handler
 *
 * Proxies admin category listing to the NestJS backend using server-side
 * httpOnly cookies (access_token). Supports optional pagination query params.
 *
 * Upstream: GET /admin/categories (NestJS)
 * Downstream: GET /api/admin/categories (browser → Next.js)
 *
 * Error mapping:
 *   AdminApiError UNAUTHORIZED → 401
 *   AdminApiError FORBIDDEN    → 403
 *   Any other error            → 500
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const { searchParams } = req.nextUrl;
  const page = searchParams.get('page') ?? undefined;
  const pageSize = searchParams.get('pageSize') ?? undefined;

  try {
    const data = await adminFetch<unknown>('/admin/categories', {
      query: {
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
      { error: 'Failed to fetch categories' },
      { status: 500 },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// POST /api/admin/categories
// ────────────────────────────────────────────────────────────────────────────

/**
 * Category Create Proxy — Next.js Route Handler
 *
 * Proxies category creation to the NestJS backend using server-side
 * httpOnly cookies (access_token).
 *
 * Upstream: POST /admin/categories (NestJS)
 * Downstream: POST /api/admin/categories (browser → Next.js)
 *
 * Expected body: { slug: string; name: string; icon?: string; color?: string; sort_order?: number }
 *
 * Error mapping:
 *   AdminApiError UNAUTHORIZED → 401
 *   AdminApiError FORBIDDEN    → 403
 *   Any other error            → 500
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid request body' }, { status: 400 });
  }

  try {
    const data = await adminFetch<unknown>('/admin/categories', {
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
      { error: 'Failed to create category' },
      { status: 500 },
    );
  }
}
