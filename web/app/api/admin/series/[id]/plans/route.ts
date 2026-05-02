import { NextRequest, NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';

/**
 * Series Plan Create Proxy — Next.js Route Handler
 *
 * Upstream:   POST /series/:id/plans (NestJS SeriesController.createPlan → PlanRecord)
 * Downstream: POST /api/admin/series/:id/plans (browser → Next.js)
 *
 * Expected body: { name, description?, planJson, voiceQuality? }
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
    const data = await adminFetch<unknown>(`/series/${id}/plans`, {
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
      { error: 'Failed to create plan in series' },
      { status: 500 },
    );
  }
}
