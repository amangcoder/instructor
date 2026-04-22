import { cookies } from 'next/headers';
import { NextRequest, NextResponse } from 'next/server';

/**
 * Route Handler: GET /api/admin/users/export
 *
 * Streams CSV export of user records, proxying the backend endpoint.
 *
 * Query params:
 *   search (optional) - filter by email/name/username
 *   role (optional) - filter by role ('user' or 'admin')
 *
 * Response:
 *   Content-Type: text/csv
 *   Content-Disposition: attachment; filename="users_export_YYYY-MM-DD.csv"
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
  const role = searchParams.get('role') ?? undefined;

  // Build the backend URL with query params
  const backendParams = new URLSearchParams();
  if (search) backendParams.set('search', search);
  if (role) backendParams.set('role', role);

  const backendUrl =
    BACKEND_URL + '/admin/users/export' + (backendParams.toString() ? '?' + backendParams.toString() : '');

  try {
    // Proxy the request to the backend, forwarding the access token
    const backendResponse = await fetch(backendUrl, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        Accept: 'text/csv',
      },
      cache: 'no-store',
    });

    // Check for auth errors
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
    const filename = `users_export_${today}.csv`;

    // Create a new response that streams the CSV data
    const response = new NextResponse(backendResponse.body, {
      status: 200,
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="${filename}"`,
        // Disable caching for exports
        'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
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
