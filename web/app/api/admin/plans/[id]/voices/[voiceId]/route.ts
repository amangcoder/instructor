import { NextRequest, NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';

/**
 * Plan Voice Delete Proxy — Next.js Route Handler
 *
 * Removes a single plan_voice rendition (the (planId, voiceId) row).
 * Idempotent: the upstream returns `{ deleted: 0 }` when no rendition exists.
 *
 * Upstream:   DELETE /admin/plans/:planId/voices/:voiceId  (NestJS)
 * Downstream: DELETE /api/admin/plans/:id/voices/:voiceId  (browser → Next.js)
 */
export async function DELETE(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string; voiceId: string }> },
): Promise<NextResponse> {
  const { id, voiceId } = await params;

  try {
    const data = await adminFetch<unknown>(
      `/admin/plans/${id}/voices/${voiceId}`,
      { method: 'DELETE' },
    );
    return NextResponse.json(data ?? { deleted: 0 });
  } catch (error) {
    if (error instanceof AdminApiError) {
      const status =
        error.code === 'UNAUTHORIZED'
          ? 401
          : error.code === 'FORBIDDEN'
            ? 403
            : error.code === '404'
              ? 404
              : 500;
      return NextResponse.json({ error: error.message }, { status });
    }
    return NextResponse.json(
      { error: 'Failed to delete plan voice' },
      { status: 500 },
    );
  }
}
