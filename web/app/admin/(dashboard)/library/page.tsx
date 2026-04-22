import { Suspense } from 'react';
import { adminFetch, AdminApiError } from '@/lib/admin-api';
import StatCard from '@/components/admin/StatCard';
import ChartErrorBoundary from '@/components/admin/ChartErrorBoundary';
import LibraryPlanManager from '@/components/admin/LibraryPlanManager';
import RangePicker from '@/components/admin/RangePicker';
import CategoryBreakdownTable from '@/components/admin/CategoryBreakdownTable';
import type { LibraryResponse, LibraryPlanRow } from '@/types/analytics';
import type { CategoryBreakdownResponse } from '@/types/library-categories';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

interface AdminLibraryPageProps {
  searchParams?: Promise<{ range?: string }>;
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/** Sort library plan rows by totalAdoptions descending. */
function sortByAdoptions(rows: LibraryPlanRow[]): LibraryPlanRow[] {
  return [...rows].sort((a, b) => b.totalAdoptions - a.totalAdoptions);
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * Admin Library Page — server component
 *
 * Fetches library conversion data from /admin/analytics/library (all-time).
 * Also fetches category-level breakdown from /admin/analytics/library/categories
 * filtered by the ?range= URL parameter (default 30d).
 *
 * Renders:
 *   - StatCards: total conversions (totalAdoptions) + unique library plans (publishedCount)
 *   - Styled HTML table sorted by adoption count desc:
 *       columns — Library Plan Name, Category, Adoption Count
 *   - LibraryPlanManager (CRUD)
 *   - Category Breakdown section with RangePicker + CategoryBreakdownTable:
 *       columns — Category, Published Plans, Total Adoptions, Total Sessions, Conversion Rate (%)
 *
 * The table and category section are each wrapped in ChartErrorBoundary.
 */
export default async function AdminLibraryPage({ searchParams }: AdminLibraryPageProps = {}) {
  // ── Resolve range from URL search params ────────────────────────────────
  const params = searchParams ? await searchParams : {};
  const range = (params as { range?: string }).range ?? '30d';

  // ── Fetch all-time library stats ─────────────────────────────────────────
  let data: LibraryResponse | null = null;
  let errorMessage: string | null = null;

  try {
    data = await adminFetch<LibraryResponse>('/admin/analytics/library');
  } catch (err) {
    if (err instanceof AdminApiError) {
      errorMessage = err.message;
    } else {
      errorMessage = 'An unexpected error occurred while loading library data.';
    }
  }

  // ── Fetch category breakdown (range-filtered) ─────────────────────────────
  let categoryData: CategoryBreakdownResponse | null = null;
  let categoryErrorMessage: string | null = null;

  try {
    categoryData = await adminFetch<CategoryBreakdownResponse>(
      '/admin/analytics/library/categories',
      { range },
    );
  } catch (err) {
    if (err instanceof AdminApiError) {
      categoryErrorMessage = err.message;
    } else {
      categoryErrorMessage = 'An unexpected error occurred while loading category data.';
    }
  }

  const sortedRows = data ? sortByAdoptions(data.series) : [];

  return (
    <div>
      {/* ── Page header ──────────────────────────────────────────────────── */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-on-surface">Library</h1>
        <p className="text-sm text-on-surface-variant mt-1">
          Plan adoption and conversion across the library catalogue
        </p>
      </div>

      {/* ── Error state ──────────────────────────────────────────────────── */}
      {errorMessage && (
        <div
          className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-6"
          role="alert"
        >
          <p className="font-medium">Failed to load library data</p>
          <p className="mt-1">{errorMessage}</p>
        </div>
      )}

      {data && (
        <>
          {/* ── Stat cards ─────────────────────────────────────────────── */}
          <div
            className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8"
            role="region"
            aria-label="Library metrics"
          >
            <StatCard
              title="Total Conversions"
              value={data.totals.totalAdoptions}
            />
            <StatCard
              title="Published Library Plans"
              value={data.totals.publishedCount}
            />
          </div>

          {/* ── Library plan conversions table ─────────────────────────── */}
          <section aria-labelledby="library-table-heading">
            <h2
              id="library-table-heading"
              className="text-lg font-semibold text-on-surface mb-4"
            >
              Plan Conversions
            </h2>
            <ChartErrorBoundary>
              <div className="rounded-xl bg-surface-container shadow-sm overflow-hidden">
                <div className="overflow-x-auto">
                  <table
                    className="w-full text-sm"
                    aria-label="Library plan adoption counts sorted by adoption descending"
                  >
                    <thead>
                      <tr className="border-b border-outline-variant bg-surface-container-high">
                        <th
                          scope="col"
                          className="px-6 py-3 text-left text-xs font-semibold text-on-surface-variant uppercase tracking-wider"
                        >
                          Library Plan Name
                        </th>
                        <th
                          scope="col"
                          className="px-6 py-3 text-left text-xs font-semibold text-on-surface-variant uppercase tracking-wider"
                        >
                          Category
                        </th>
                        <th
                          scope="col"
                          className="px-6 py-3 text-right text-xs font-semibold text-on-surface-variant uppercase tracking-wider"
                        >
                          Adoption Count
                        </th>
                      </tr>
                    </thead>
                    <tbody>
                      {sortedRows.map((row) => (
                        <tr
                          key={row.id}
                          className="border-b border-outline-variant/50 hover:bg-primary/5 transition-colors last:border-b-0"
                        >
                          <td className="px-6 py-3 font-medium text-on-surface">
                            {row.name}
                          </td>
                          <td className="px-6 py-3 text-on-surface-variant capitalize">
                            {row.category}
                          </td>
                          <td className="px-6 py-3 text-right tabular-nums font-medium text-on-surface">
                            {row.totalAdoptions.toLocaleString()}
                          </td>
                        </tr>
                      ))}
                      {sortedRows.length === 0 && (
                        <tr>
                          <td
                            colSpan={3}
                            className="px-6 py-8 text-center text-on-surface-variant text-sm"
                          >
                            No library plans found.
                          </td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            </ChartErrorBoundary>
          </section>
        </>
      )}

      {/* ── Loading skeleton ─────────────────────────────────────────────── */}
      {!data && !errorMessage && (
        <div
          className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8"
          role="region"
          aria-label="Loading library metrics"
        >
          <StatCard title="Total Conversions" value={0} loading />
          <StatCard title="Published Library Plans" value={0} loading />
        </div>
      )}

      {/* ── CRUD manager ─────────────────────────────────────────────────── */}
      <LibraryPlanManager />

      {/* ── Category breakdown ───────────────────────────────────────────── */}
      <section aria-labelledby="category-breakdown-heading" className="mt-10">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-4">
          <h2
            id="category-breakdown-heading"
            className="text-lg font-semibold text-on-surface"
          >
            Category Breakdown
          </h2>
          <Suspense fallback={null}>
            <RangePicker />
          </Suspense>
        </div>
        <p className="text-sm text-on-surface-variant mb-4">
          Performance metrics per category for the selected time range
        </p>

        {/* ── Category fetch error ────────────────────────────────────── */}
        {categoryErrorMessage && (
          <div
            className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-4"
            role="alert"
          >
            <p className="font-medium">Failed to load category data</p>
            <p className="mt-1">{categoryErrorMessage}</p>
          </div>
        )}

        <ChartErrorBoundary>
          <CategoryBreakdownTable rows={categoryData?.rows ?? []} />
        </ChartErrorBoundary>
      </section>
    </div>
  );
}
