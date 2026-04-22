'use client';

import { useState, useMemo } from 'react';
import type { CategoryRow } from '@/types/library-categories';
import EmptyState from '@/components/admin/EmptyState';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

type SortKey = 'category' | 'publishedPlans' | 'totalAdoptions' | 'totalSessions' | 'conversionRate';
type SortDir = 'asc' | 'desc';

interface SortState {
  key: SortKey;
  dir: SortDir;
}

export interface CategoryBreakdownTableProps {
  rows: CategoryRow[];
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/**
 * Format a decimal conversion rate (0..1) as a percentage string with 1 dp.
 * Returns '—' for null values (no adoptions yet).
 */
function formatConversionRate(value: number | null): string {
  if (value === null) return '—';
  return `${(value * 100).toFixed(1)}%`;
}

/**
 * Sort an array of CategoryRow by a given key and direction.
 * String keys sort lexicographically; numeric keys sort numerically.
 * Null conversionRate values are sorted to the bottom in both directions.
 */
function sortRows(rows: CategoryRow[], key: SortKey, dir: SortDir): CategoryRow[] {
  return [...rows].sort((a, b) => {
    let aVal: string | number | null;
    let bVal: string | number | null;

    if (key === 'category') {
      aVal = a.category.toLowerCase();
      bVal = b.category.toLowerCase();
    } else if (key === 'conversionRate') {
      aVal = a.conversionRate;
      bVal = b.conversionRate;
      // Push nulls to the bottom
      if (aVal === null && bVal === null) return 0;
      if (aVal === null) return 1;
      if (bVal === null) return -1;
    } else {
      aVal = a[key] as number;
      bVal = b[key] as number;
    }

    if (aVal === bVal) return 0;

    const ascending = typeof aVal === 'string'
      ? (aVal as string) < (bVal as string) ? -1 : 1
      : (aVal as number) < (bVal as number) ? -1 : 1;

    return dir === 'asc' ? ascending : -ascending;
  });
}

// ────────────────────────────────────────────────────────────────────────────
// Sub-component: Column header button
// ────────────────────────────────────────────────────────────────────────────

interface ColHeaderProps {
  label: string;
  sortKey: SortKey;
  currentSort: SortState;
  align?: 'left' | 'right';
  onSort: (key: SortKey) => void;
}

function ColHeader({ label, sortKey, currentSort, align = 'left', onSort }: ColHeaderProps) {
  const isActive = currentSort.key === sortKey;
  const arrow = isActive ? (currentSort.dir === 'asc' ? ' ▲' : ' ▼') : '';

  return (
    <th
      scope="col"
      className={[
        'px-6 py-3 text-xs font-semibold text-on-surface-variant uppercase tracking-wider',
        align === 'right' ? 'text-right' : 'text-left',
      ].join(' ')}
    >
      <button
        type="button"
        onClick={() => onSort(sortKey)}
        className={[
          'inline-flex items-center gap-1 transition-colors',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-1 rounded',
          isActive ? 'text-primary' : 'hover:text-on-surface',
        ].join(' ')}
        aria-label={`Sort by ${label}${isActive ? `, currently ${currentSort.dir}ending` : ''}`}
      >
        {label}
        {arrow && (
          <span aria-hidden="true" className="text-[10px] leading-none">
            {arrow}
          </span>
        )}
      </button>
    </th>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * CategoryBreakdownTable — client component
 *
 * Renders a sortable table of library plan category metrics.
 *
 * Props:
 *   rows — CategoryRow[] from /admin/analytics/library/categories
 *
 * Columns: Category | Published Plans | Total Adoptions | Total Sessions | Conversion Rate (%)
 *
 * Clicking any column header sorts that column ascending then descending on
 * subsequent clicks (toggle). The active sort column shows a ▲ or ▼ indicator.
 * conversionRate is formatted as a percentage (e.g. '34.2%'); null → '—'.
 *
 * Shows EmptyState if rows is empty.
 *
 * Accessibility:
 *   - Table uses <thead>/<tbody> with proper scope attributes
 *   - Column header buttons have aria-label conveying current sort direction
 *   - Sort indicator arrows are aria-hidden (decorative)
 *   - Empty-state panel has role="status"
 */
export default function CategoryBreakdownTable({ rows }: CategoryBreakdownTableProps) {
  const [sort, setSort] = useState<SortState>({ key: 'category', dir: 'asc' });

  const sortedRows = useMemo(() => sortRows(rows, sort.key, sort.dir), [rows, sort]);

  const handleSort = (key: SortKey) => {
    setSort((prev) => ({
      key,
      dir: prev.key === key && prev.dir === 'asc' ? 'desc' : 'asc',
    }));
  };

  if (rows.length === 0) {
    return <EmptyState message="No category data available." />;
  }

  return (
    <div className="rounded-xl bg-surface-container shadow-sm overflow-hidden">
      <div className="overflow-x-auto">
        <table
          className="w-full text-sm"
          aria-label="Library category breakdown"
        >
          <thead>
            <tr className="border-b border-outline-variant bg-surface-container-high">
              <ColHeader
                label="Category"
                sortKey="category"
                currentSort={sort}
                onSort={handleSort}
              />
              <ColHeader
                label="Published Plans"
                sortKey="publishedPlans"
                currentSort={sort}
                align="right"
                onSort={handleSort}
              />
              <ColHeader
                label="Total Adoptions"
                sortKey="totalAdoptions"
                currentSort={sort}
                align="right"
                onSort={handleSort}
              />
              <ColHeader
                label="Total Sessions"
                sortKey="totalSessions"
                currentSort={sort}
                align="right"
                onSort={handleSort}
              />
              <ColHeader
                label="Conversion Rate (%)"
                sortKey="conversionRate"
                currentSort={sort}
                align="right"
                onSort={handleSort}
              />
            </tr>
          </thead>
          <tbody>
            {sortedRows.map((row) => (
              <tr
                key={row.category}
                className="border-b border-outline-variant/50 hover:bg-primary/5 transition-colors last:border-b-0"
              >
                <td className="px-6 py-3 font-medium text-on-surface capitalize">
                  {row.category}
                </td>
                <td className="px-6 py-3 text-right tabular-nums text-on-surface-variant">
                  {row.publishedPlans.toLocaleString()}
                </td>
                <td className="px-6 py-3 text-right tabular-nums text-on-surface">
                  {row.totalAdoptions.toLocaleString()}
                </td>
                <td className="px-6 py-3 text-right tabular-nums text-on-surface">
                  {row.totalSessions.toLocaleString()}
                </td>
                <td className="px-6 py-3 text-right tabular-nums font-medium text-on-surface">
                  {formatConversionRate(row.conversionRate)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
