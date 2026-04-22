import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL ?? 'http://localhost:3071/api';

function getBearerToken(req: NextRequest): string | null {
  return req.cookies.get('access_token')?.value ?? null;
}

export async function GET(req: NextRequest): Promise<NextResponse> {
  const token = getBearerToken(req);
  if (!token) {
    return NextResponse.json({ message: 'Unauthorized' }, { status: 401 });
  }

  let res: Response;
  try {
    res = await fetch(`${BACKEND_URL}/library/plans/all`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: 'no-store',
    });
  } catch {
    return NextResponse.json({ message: 'Backend unavailable' }, { status: 503 });
  }

  if (!res.ok) {
    return NextResponse.json({ message: 'Failed to fetch plans' }, { status: res.status });
  }

  return NextResponse.json(await res.json());
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const token = getBearerToken(req);
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
    res = await fetch(`${BACKEND_URL}/library/plans`, {
      method: 'POST',
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
