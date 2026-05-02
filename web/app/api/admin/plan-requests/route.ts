import { NextRequest, NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';

// ────────────────────────────────────────────────────────────────────────────
// GET /api/admin/plan-requests
// ────────────────────────────────────────────────────────────────────────────

/**
 * Plan Requests List Proxy — Next.js Route Handler
 *
 * Backs the admin "Plan Requests" page (REQ-017). Proxies to the NestJS
 * backend's analytics list endpoint and maps `email` → `ownerEmail` so the
 * page's PlanRequest shape lines up with the upstream row.
 *
 * Defaults to status=pending because the UI is the promotion queue —
 * already-processed requests can't be promoted again.
 *
 * Upstream:   GET /admin/analytics/plan-requests
 * Downstream: GET /api/admin/plan-requests
 */

interface UpstreamRow {
  id: string;
  email: string;
  title: string;
  description: string;
  category: string | null;
  status: 'pending' | 'processed' | 'rejected';
  processedAt: string | null;
  createdAt: string;
}

interface UpstreamResponse {
  data: UpstreamRow[];
  total: number;
  page: number;
  pageSize: number;
}

export async function GET(req: NextRequest): Promise<NextResponse> {
  const { searchParams } = req.nextUrl;
  const page = searchParams.get('page') ?? undefined;
  const pageSize = searchParams.get('pageSize') ?? undefined;
  const search = searchParams.get('search') ?? undefined;
  const status = searchParams.get('status') ?? 'pending';

  try {
    const upstream = await adminFetch<UpstreamResponse>(
      '/admin/analytics/plan-requests',
      {
        query: {
          ...(page !== undefined ? { page } : {}),
          ...(pageSize !== undefined ? { pageSize } : {}),
          ...(search !== undefined ? { search } : {}),
          status,
        },
      },
    );

    return NextResponse.json({
      data: upstream.data.map((row) => ({
        id: row.id,
        title: row.title,
        description: row.description,
        ownerEmail: row.email,
        createdAt: row.createdAt,
        updatedAt: row.processedAt ?? row.createdAt,
      })),
      total: upstream.total,
      page: upstream.page,
      pageSize: upstream.pageSize,
    });
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
      { error: 'Failed to fetch plan requests' },
      { status: 500 },
    );
  }
}
