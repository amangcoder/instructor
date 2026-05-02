import { NextRequest, NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';
import type { AdminSeriesRecord } from '@/types/series';

function statusFromError(error: AdminApiError): number {
  if (error.code === 'UNAUTHORIZED') return 401;
  if (error.code === 'FORBIDDEN') return 403;
  return 500;
}

// ────────────────────────────────────────────────────────────────────────────
// GET /api/admin/series
// ────────────────────────────────────────────────────────────────────────────

/**
 * Series List Proxy — Next.js Route Handler
 *
 * Proxies the admin series list (all series, including drafts) to the
 * NestJS backend using server-side httpOnly cookies (access_token).
 * This keeps the admin JWT off the browser and allows the series page to
 * fetch via a same-origin request.
 *
 * Upstream: GET /series/admin/all (NestJS → SeriesRecord[])
 * Downstream: GET /api/admin/series (browser → Next.js)
 */
export async function GET(): Promise<NextResponse> {
  try {
    const data = await adminFetch<AdminSeriesRecord[]>('/series/admin/all');
    return NextResponse.json(data);
  } catch (error) {
    if (error instanceof AdminApiError) {
      return NextResponse.json({ error: error.message }, { status: statusFromError(error) });
    }
    return NextResponse.json(
      { error: 'Failed to fetch series list' },
      { status: 500 },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// POST /api/admin/series
// ────────────────────────────────────────────────────────────────────────────

/**
 * Series Create Proxy — Next.js Route Handler
 *
 * Upstream: POST /series (NestJS SeriesController.create)
 * Downstream: POST /api/admin/series (browser → Next.js)
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid request body' }, { status: 400 });
  }

  try {
    const data = await adminFetch<unknown>('/series', { method: 'POST', body });
    return NextResponse.json(data, { status: 201 });
  } catch (error) {
    if (error instanceof AdminApiError) {
      return NextResponse.json({ error: error.message }, { status: statusFromError(error) });
    }
    return NextResponse.json(
      { error: 'Failed to create series' },
      { status: 500 },
    );
  }
}
