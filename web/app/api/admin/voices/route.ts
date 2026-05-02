import { NextResponse } from 'next/server';
import { adminFetch, AdminApiError } from '@/lib/admin-api';

/**
 * GET /api/admin/voices
 *
 * Proxies the published voice list for admin voice-selector dropdowns
 * (e.g. PlanDetailsEditor's default-voice picker).
 *
 * Upstream:   GET /admin/voices  (NestJS)
 * Downstream: GET /api/admin/voices  (browser → Next.js)
 */
export async function GET(): Promise<NextResponse> {
  try {
    const data = await adminFetch<unknown>('/admin/voices');
    return NextResponse.json(data);
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
      { error: 'Failed to load voices' },
      { status: 500 },
    );
  }
}
