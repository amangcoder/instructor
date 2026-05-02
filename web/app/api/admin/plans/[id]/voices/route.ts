import { NextRequest, NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';

// ────────────────────────────────────────────────────────────────────────────
// POST /api/admin/plans/[id]/voices
// ────────────────────────────────────────────────────────────────────────────

/**
 * Plan Voice Generate Proxy — Next.js Route Handler
 *
 * Proxies a "create + queue" request for a plan voice rendition to the
 * NestJS backend. Used by the admin VoiceGrid empty-state "Generate Voice"
 * button so admins can produce audio for a plan that has no voices yet.
 *
 * Upstream:   POST /admin/plans/:planId/voices       (NestJS → 202 { jobId, ... })
 * Downstream: POST /api/admin/plans/:id/voices       (browser → Next.js)
 *
 * Body: { voiceId?: string; voiceSlug?: string } — at least one required.
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
    return NextResponse.json(
      { error: 'Invalid JSON body' },
      { status: 400 },
    );
  }

  try {
    const data = await adminFetch<unknown>(`/admin/plans/${id}/voices`, {
      method: 'POST',
      body,
    });
    return NextResponse.json(data, { status: 202 });
  } catch (error) {
    if (error instanceof AdminApiError) {
      const status =
        error.code === 'UNAUTHORIZED'
          ? 401
          : error.code === 'FORBIDDEN'
            ? 403
            : error.code === '404'
              ? 404
              : error.code === '400'
                ? 400
                : 500;
      return NextResponse.json({ error: error.message }, { status });
    }
    return NextResponse.json(
      { error: 'Failed to queue voice generation' },
      { status: 500 },
    );
  }
}
