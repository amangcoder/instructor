import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL ?? 'http://localhost:3071/api';

/**
 * GET /api/admin/app-version
 *
 * Proxy for fetching the current app version configuration.
 * Forwards the request to the NestJS backend with the access_token from cookies.
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const token = req.cookies.get('access_token')?.value ?? null;
  if (!token) {
    return NextResponse.json({ message: 'Unauthorized' }, { status: 401 });
  }

  let res: Response;
  try {
    res = await fetch(`${BACKEND_URL}/admin/app-version`, {
      method: 'GET',
      headers: { Authorization: `Bearer ${token}` },
      cache: 'no-store',
    });
  } catch {
    return NextResponse.json({ message: 'Backend unavailable' }, { status: 503 });
  }

  if (!res.ok) {
    return NextResponse.json({ message: 'Failed to fetch app version config' }, { status: res.status });
  }

  return NextResponse.json(await res.json());
}

/**
 * PATCH /api/admin/app-version
 *
 * Proxy for updating the app version configuration.
 * Forwards the request to the NestJS backend with the access_token from cookies.
 *
 * Expected body:
 * {
 *   ios: { minVersion: string, forceUpdateVersion: string },
 *   android: { minVersion: string, forceUpdateVersion: string },
 *   enabled: boolean
 * }
 *
 * The backend validates:
 *  - forceUpdateVersion >= minVersion for each platform (using AppVersionService.compareVersions)
 *  - Returns 400 Bad Request if validation fails
 *  - Returns 200 OK with updated config on success
 */
export async function PATCH(req: NextRequest): Promise<NextResponse> {
  const token = req.cookies.get('access_token')?.value ?? null;
  if (!token) {
    return NextResponse.json({ message: 'Unauthorized' }, { status: 401 });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ message: 'Invalid request body' }, { status: 400 });
  }

  let res: Response;
  try {
    res = await fetch(`${BACKEND_URL}/admin/app-version`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(body),
      cache: 'no-store',
    });
  } catch {
    return NextResponse.json({ message: 'Backend unavailable' }, { status: 503 });
  }

  const data = await res.json().catch(() => ({}));
  return NextResponse.json(data, { status: res.status });
}
