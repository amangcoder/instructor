import { adminFetch, AdminApiError } from '@/lib/admin-api';
import CategoryManager from '@/components/admin/CategoryManager';
import type { Category } from '@/types/categories';

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/**
 * Normalise the categories API response — the NestJS endpoint returns a
 * paginated envelope { categories: Category[], total: number }, but accept
 * a flat array or { items: Category[] } shape as well for forward-compat.
 */
function parseCategories(raw: unknown): Category[] {
  if (Array.isArray(raw)) return raw as Category[];
  if (typeof raw === 'object' && raw !== null) {
    const obj = raw as Record<string, unknown>;
    if (Array.isArray(obj.categories)) return obj.categories as Category[];
    if (Array.isArray(obj.items)) return obj.items as Category[];
  }
  return [];
}

// ────────────────────────────────────────────────────────────────────────────
// Page
// ────────────────────────────────────────────────────────────────────────────

/**
 * Admin Categories Page — server component (REQ-014, AC-010, AC-023)
 *
 * Fetches the full category list server-side and passes it as initial
 * data to `CategoryManager` (client component) so that the grid renders
 * without a client-initiated loading state on first paint.
 *
 * If the server-side fetch fails (network error, 401/403) the page still
 * renders — `CategoryManager` will attempt its own fetch on mount and
 * display an appropriate error message if that too fails.
 *
 * Route: /admin/categories
 * Layout: AdminDashboardLayout (auth-gated, sidebar)
 */
export default async function AdminCategoriesPage() {
  let initialCategories: Category[] = [];

  try {
    const raw = await adminFetch<unknown>('/admin/categories');
    initialCategories = parseCategories(raw);
  } catch (err) {
    // Non-blocking: client component will re-fetch and show its own error
    if (!(err instanceof AdminApiError)) {
      console.error('[AdminCategoriesPage] Failed to prefetch categories:', err);
    }
  }

  return (
    <div>
      {/* ── Page header ──────────────────────────────────────────────────── */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-on-surface">Categories</h1>
        <p className="mt-1 text-sm text-on-surface-variant">
          Manage content categories. Drag cards to reorder.
        </p>
      </div>

      {/* ── Category CRUD + DnD grid ──────────────────────────────────────── */}
      <CategoryManager initialCategories={initialCategories} />
    </div>
  );
}
