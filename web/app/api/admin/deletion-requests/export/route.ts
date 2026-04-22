import { cookies } from 'next/headers';
import { NextRequest, NextResponse } from 'next/server';

/**
 * Route Handler: GET /api/admin/deletion-requests/export
 *
 * Streams CSV export of deletion request records, proxying the backend endpoint.
 *
 * Query params:
 *   search (optional) — filter by email
 *
 * Response:
 *   Content-Type: text/csv
 *   Content-Disposition: attachment; filename="deletion_requests_export_YYYY-MM-DD.csv"
 *
 * The handler forwards the httpOnly access_token to the backend and streams
 * the CSV response directly to the client without buffering in memory.
 */

const BACKEND_URL = process.env.BACKEND_URL ?? 'http://localhost:3071/api';

async function handleGet(request: NextRequest) {
  const cookieStore = await cookies();
  const accessToken = cookieStore.get('access_token')?.value;

  if (!accessToken) {
    return NextResponse.json(
      { error: 'Unauthorized — token missing or expired' },
      { status: 401 },
    );
  }

  // Extract query params from the request URL
  const { searchParams } = new URL(request.url);
  const search = searchParams.get('search') ?? undefined;

  // Build the backend URL with query params
  const backendParams = new URLSearchParams();
  if (search) backendParams.set('search', search);

  const backendUrl =
    BACKEND_URL +
    '/admin/analytics/deletion-requests/export' +
    (backendParams.toString() ? '?' + backendParams.toString() : '');

  try {
    const backendResponse = await fetch(backendUrl, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        Accept: 'text/csv',
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

    if (!backendResponse.ok) {
      return NextResponse.json(
        { error: backendResponse.statusText || 'Request failed' },
        { status: backendResponse.status },
      );
    }

    // Generate the filename with today's date
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    const filename = `deletion_requests_export_${today}.csv`;

    // Stream the CSV data to the client
    const response = new NextResponse(backendResponse.body, {
      status: 200,
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="${filename}"`,
        'Cache-Control':
          'no-store, no-cache, must-revalidate, proxy-revalidate',
      },
    });

    return response;
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json(
      { error: `Failed to fetch CSV export: ${message}` },
      { status: 500 },
    );
  }
}

export const GET = handleGet;
