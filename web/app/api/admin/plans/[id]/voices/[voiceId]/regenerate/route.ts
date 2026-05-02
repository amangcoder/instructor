import { NextRequest, NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';

// ────────────────────────────────────────────────────────────────────────────
// POST /api/admin/plans/[id]/voices/[voiceId]/regenerate
// ────────────────────────────────────────────────────────────────────────────

/**
 * Plan Voice Regenerate Proxy — Next.js Route Handler
 *
 * Proxies a TTS voice re-generation request to the NestJS backend using
 * server-side httpOnly cookies (access_token). This keeps the admin JWT
 * off the browser and allows the VoiceGrid Regenerate button to trigger
 * re-synthesis via a same-origin fetch.
 *
 * Upstream: POST /admin/plans/:planId/voices/:voiceId/regenerate (NestJS → 202 { jobId })
 * Downstream: POST /api/admin/plans/:id/voices/:voiceId/regenerate (browser → Next.js)
 *
 * The backend creates a new plan_voices row and queues a TTS synthesis job,
 * setting the status to 'pending'.
 *
 * Error mapping:
 *   AdminApiError UNAUTHORIZED → 401
 *   AdminApiError FORBIDDEN    → 403
 *   Any other error            → 500
 */
export async function POST(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string; voiceId: string }> },
): Promise<NextResponse> {
  const { id, voiceId } = await params;

  try {
    const data = await adminFetch<unknown>(
      `/admin/plans/${id}/voices/${voiceId}/regenerate`,
      { method: 'POST' },
    );
    return NextResponse.json(data, { status: 202 });
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
      { error: 'Failed to queue voice regeneration' },
      { status: 500 },
    );
  }
}
