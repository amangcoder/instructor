import { NextRequest, NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';
import type { AdminSeriesDetail } from '@/types/series';

function statusFromError(error: AdminApiError): number {
  if (error.code === 'UNAUTHORIZED') return 401;
  if (error.code === 'FORBIDDEN') return 403;
  return 500;
}

// ────────────────────────────────────────────────────────────────────────────
// GET /api/admin/series/[id]
// ────────────────────────────────────────────────────────────────────────────

/**
 * Series Detail Proxy — Next.js Route Handler
 *
 * Upstream:   GET /series/:id (NestJS SeriesController.getDetail → SeriesDetail)
 * Downstream: GET /api/admin/series/:id (browser → Next.js)
 */
export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
): Promise<NextResponse> {
  const { id } = await params;

  try {
    const data = await adminFetch<AdminSeriesDetail>(`/series/${id}`);
    return NextResponse.json(data);
  } catch (error) {
    if (error instanceof AdminApiError) {
      return NextResponse.json({ error: error.message }, { status: statusFromError(error) });
    }
    return NextResponse.json(
      { error: 'Failed to fetch series detail' },
      { status: 500 },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// PATCH /api/admin/series/[id]
// ────────────────────────────────────────────────────────────────────────────

/**
 * Series Update Proxy — Next.js Route Handler
 *
 * Upstream: PATCH /series/:id (NestJS SeriesController.update)
 * Downstream: PATCH /api/admin/series/:id (browser → Next.js)
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
    const data = await adminFetch<unknown>(`/series/${id}`, { method: 'PATCH', body });
    return NextResponse.json(data);
  } catch (error) {
    if (error instanceof AdminApiError) {
      return NextResponse.json({ error: error.message }, { status: statusFromError(error) });
    }
    return NextResponse.json(
      { error: 'Failed to update series' },
      { status: 500 },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// DELETE /api/admin/series/[id]
// ────────────────────────────────────────────────────────────────────────────

/**
 * Series Delete Proxy — Next.js Route Handler
 *
 * Upstream: DELETE /series/:id (NestJS SeriesController.delete → 204)
 * Downstream: DELETE /api/admin/series/:id (browser → Next.js)
 */
export async function DELETE(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
): Promise<NextResponse> {
  const { id } = await params;

  try {
    await adminFetch<unknown>(`/series/${id}`, { method: 'DELETE' });
    return new NextResponse(null, { status: 204 });
  } catch (error) {
    if (error instanceof AdminApiError) {
      return NextResponse.json({ error: error.message }, { status: statusFromError(error) });
    }
    return NextResponse.json(
      { error: 'Failed to delete series' },
      { status: 500 },
    );
  }
}
