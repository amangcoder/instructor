import { cookies } from 'next/headers';
import { NextRequest, NextResponse } from 'next/server';

/**
 * Route Handler: PATCH /api/admin/deletion-requests/[id]/process
 *
 * Proxies the "mark as processed" action to the NestJS backend.
 * The handler forwards the httpOnly access_token as a Bearer token.
 *
 * Backend endpoint: PATCH /admin/analytics/deletion-requests/:id/process
 *
 * Response:
 *   200 — { success: true }
 *   401 — Unauthorized
 *   403 — Forbidden
 *   404 — Deletion request not found
 */

const BACKEND_URL = process.env.BACKEND_URL ?? 'http://localhost:3071/api';

async function handlePatch(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;

  const cookieStore = await cookies();
  const accessToken = cookieStore.get('access_token')?.value;

  if (!accessToken) {
    return NextResponse.json(
      { error: 'Unauthorized — token missing or expired' },
      { status: 401 },
    );
  }

  // Validate ID format — basic safeguard
  if (!id || id.length > 128) {
    return NextResponse.json(
      { error: 'Invalid deletion request ID' },
      { status: 400 },
    );
  }

  const backendUrl = `${BACKEND_URL}/admin/analytics/deletion-requests/${encodeURIComponent(id)}/process`;

  try {
    const backendResponse = await fetch(backendUrl, {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      cache: 'no-store',
    });

    if (backendResponse.status === 401) {
      return NextResponse.json(
        { error: 'Unauthorized — token missing or expired' },
        { status: 401 },
      );
    }

    if (backendResponse.status === 403) {
      return NextResponse.json(
        { error: 'Forbidden — admin role required' },
        { status: 403 },
      );
    }

    if (backendResponse.status === 404) {
      return NextResponse.json(
        { error: 'Deletion request not found' },
        { status: 404 },
      );
    }

    if (!backendResponse.ok) {
      return NextResponse.json(
        { error: backendResponse.statusText || 'Request failed' },
        { status: backendResponse.status },
      );
    }

    const body = await backendResponse.json();
    return NextResponse.json(body, { status: 200 });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json(
      { error: `Failed to process deletion request: ${message}` },
      { status: 500 },
    );
  }
}

export const PATCH = handlePatch;
