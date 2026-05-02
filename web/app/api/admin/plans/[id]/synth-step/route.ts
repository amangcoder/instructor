import { NextRequest, NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';

/**
 * Per-Step Synthesis Proxy — Next.js Route Handler
 *
 * Triggers TTS synthesis for a single say-step against a chosen voice and
 * primes the shared cache. Used by the inline "Synth" button next to each
 * say row in the admin step list.
 *
 * Upstream:   POST /admin/plans/:planId/synth-step  (NestJS)
 * Downstream: POST /api/admin/plans/:id/synth-step  (browser → Next.js)
 *
 * Body: { stepId: string; voiceId?: string; voiceSlug?: string }
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
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }

  try {
    const data = await adminFetch<unknown>(
      `/admin/plans/${id}/synth-step`,
      { method: 'POST', body },
    );
    return NextResponse.json(data);
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
      { error: 'Failed to synthesize step' },
      { status: 500 },
    );
  }
}
