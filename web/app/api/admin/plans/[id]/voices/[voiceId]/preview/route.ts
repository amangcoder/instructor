import { NextRequest, NextResponse } from 'next/server';
import { cookies } from 'next/headers';

const BACKEND_URL = process.env.BACKEND_URL ?? 'http://localhost:3071/api';

/**
 * Plan Voice Preview Proxy — Next.js Route Handler
 *
 * Streams the WAV bytes for the plan's first say-step rendered in the chosen
 * voice from the NestJS backend. Powers the admin VoiceGrid Play button so
 * reviewers can audition a rendition without leaving the dashboard.
 *
 * Upstream returns audio/wav (binary), so this route bypasses adminFetch
 * (which assumes JSON) and forwards the body verbatim with the upstream
 * Content-Type and Content-Length headers.
 *
 * Upstream:   POST /admin/plans/:planId/voices/:voiceId/preview  (NestJS)
 * Downstream: POST /api/admin/plans/:id/voices/:voiceId/preview  (browser)
 */
export async function POST(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string; voiceId: string }> },
): Promise<NextResponse> {
  const { id, voiceId } = await params;

  const cookieStore = await cookies();
  const accessToken = cookieStore.get('access_token')?.value ?? '';

  let upstream: Response;
  try {
    upstream = await fetch(
      `${BACKEND_URL}/admin/plans/${id}/voices/${voiceId}/preview`,
      {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}` },
        cache: 'no-store',
      },
    );
  } catch {
    return NextResponse.json(
      { error: 'Failed to reach backend' },
      { status: 502 },
    );
  }

  if (upstream.status === 401) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }
  if (upstream.status === 403) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }
  if (!upstream.ok) {
    const text = await upstream.text().catch(() => '');
    let message = 'Failed to render preview';
    try {
      const body = JSON.parse(text) as { message?: string; error?: string };
      message = body.message ?? body.error ?? message;
    } catch {
      // upstream sent non-JSON error body — keep the generic message
    }
    return NextResponse.json({ error: message }, { status: upstream.status });
  }

  const audio = await upstream.arrayBuffer();
  return new NextResponse(audio, {
    status: 200,
    headers: {
      'Content-Type': upstream.headers.get('Content-Type') ?? 'audio/wav',
      'Content-Length': String(audio.byteLength),
      'Cache-Control': 'private, max-age=300',
    },
  });
}
