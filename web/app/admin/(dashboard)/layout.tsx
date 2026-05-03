import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import AdminSidebar from '@/components/admin/AdminSidebar';
import { adminFetch, AdminApiError } from '@/lib/admin-api';
import type { PendingCountResponse } from '@/types/deletion-requests';

// ────────────────────────────────────────────────────────────────────────────
// JWT payload decoder (no signature verification — backend handles that)
// ────────────────────────────────────────────────────────────────────────────

/**
 * Decode the payload segment of a JWT without cryptographic verification.
 *
 * The NestJS backend verifies token signatures on every API call.
 * This function is used only to read claims (sub, email, role) for the
 * server-side layout auth gate, avoiding an extra backend round-trip.
 *
 * Returns null if the token is missing, malformed, or unparseable.
 */
function decodeJwtPayload(token: string): Record<string, unknown> | null {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const payloadJson = Buffer.from(parts[1], 'base64url').toString('utf-8');
    const parsed: unknown = JSON.parse(payloadJson);
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
      return null;
    }
    return parsed as Record<string, unknown>;
  } catch {
    return null;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Layout
// ────────────────────────────────────────────────────────────────────────────

/**
 * Admin dashboard layout — server component
 *
 * Auth gate:
 *   1. Reads access_token cookie via cookies()
 *   2. Decodes JWT payload to extract role
 *   3. No cookie → redirect('/admin/login')
 *   4. role !== 'admin' → redirect('/')
 *
 * Renders:
 *   AdminSidebar (w-64, fixed left) + scrollable main content area
 *
 * This layout wraps all authenticated admin pages via the (dashboard)
 * route group. The login page sits outside this group and does not
 * render the sidebar.
 */
export default async function AdminDashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const cookieStore = await cookies();
  const accessToken = cookieStore.get('access_token')?.value;

  // ── No cookie → login page ────────────────────────────────────────────
  if (!accessToken) {
    redirect('/admin/login');
  }

  // ── Decode JWT payload ────────────────────────────────────────────────
  const payload = decodeJwtPayload(accessToken);

  if (!payload) {
    redirect('/admin/login');
  }

  const { role } = payload;

  // ── Non-admin → home page ─────────────────────────────────────────────
  if (typeof role !== 'string' || role !== 'admin') {
    redirect('/');
  }

  // ── Validate JWT expiry ───────────────────────────────────────────────
  const exp = payload.exp;
  if (typeof exp !== 'number' || Date.now() / 1000 >= exp) {
    redirect('/admin/login');
  }

  // ── Fetch pending deletion request count (server-side) ────────────────
  let pendingDeletionCount: number | undefined;
  try {
    const response = await adminFetch<PendingCountResponse>(
      '/admin/analytics/deletion-requests/pending-count',
    );
    pendingDeletionCount = response.count;
  } catch (error) {
    // If fetch fails (e.g., network error, 5xx), log but don't block rendering
    console.error('Failed to fetch pending deletion count:', error);
    // pendingDeletionCount remains undefined — badge will not render
  }

  // Extract admin email from JWT payload
  const adminEmail = typeof payload.email === 'string' ? payload.email : undefined;

  return (
    <div className="flex h-full">
      {/* Skip navigation — first focusable element; targets admin-main-content */}
      <a
        href="#admin-main-content"
        className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-50 focus:px-4 focus:py-2 focus:bg-indigo-600 focus:text-white focus:rounded-lg"
      >
        Skip to main content
      </a>

      <AdminSidebar
        pendingDeletionCount={pendingDeletionCount}
        adminEmail={adminEmail}
      />

      {/* Main content — responsive offset by sidebar width */}
      {/* Desktop (≥ 1024px): ml-64 for full sidebar (w-64 = 16rem)
           Mobile (< 1024px): ml-[60px] for icon-only rail */}
      <main
        className="flex-1 ml-[60px] lg:ml-64 overflow-y-auto"
        id="admin-main-content"
        role="main"
        aria-label="Admin content"
      >
        <div className="p-6 lg:p-8 max-w-7xl mx-auto">
          {children}
        </div>
      </main>
    </div>
  );
}
