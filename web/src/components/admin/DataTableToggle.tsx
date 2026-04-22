'use client';

import { useState } from 'react';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface DataTableColumn {
  /** Object key to read from each data row */
  key: string;
  /** Human-readable column header label */
  label: string;
}

export interface DataTableToggleProps {
  /** Rows to display in the table */
  data: Record<string, unknown>[];
  /** Column definitions (key + label) */
  columns: DataTableColumn[];
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * DataTableToggle — client component
 *
 * Renders a "Show data table" button that reveals a styled accessible <table>
 * below it. Clicking again hides the table and updates the button label to
 * "Hide data table".
 *
 * Features:
 *  - Toggle button with aria-expanded for screen-reader state communication
 *  - Full <table> markup with <thead> / <tbody> / <th scope="col">
 *  - Horizontally scrollable on small viewports
 *  - Empty-row handling
 *
 * Accessibility (WCAG 2.1 AA):
 *  - Button uses aria-expanded to convey open/closed state
 *  - Column headers use scope="col" for screen-reader row/column association
 *  - Table cells have a readable string representation of each value
 *  - Keyboard navigable: Tab focuses the button; Enter/Space toggles it
 */
export default function DataTableToggle({ data, columns }: DataTableToggleProps) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div>
      {/* ── Toggle button ──────────────────────────────────────────────────── */}
      <button
        type="button"
        onClick={() => setIsOpen((prev) => !prev)}
        aria-expanded={isOpen}
        className={[
          'inline-flex items-center gap-2',
          'text-sm font-medium text-on-surface-variant',
          'rounded-lg border border-outline-variant px-3 py-2',
          'bg-surface-container hover:bg-surface-container-high',
          'transition-colors',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-1',
          'min-h-[44px]',
        ].join(' ')}
      >
        {/* Chevron indicator */}
        <span
          aria-hidden="true"
          className={`transition-transform duration-200 ${isOpen ? 'rotate-180' : ''}`}
        >
          ▾
        </span>
        {isOpen ? 'Hide data table' : 'Show data table'}
      </button>

      {/* ── Table (conditionally rendered) ────────────────────────────────── */}
      {isOpen && (
        <div className="mt-3 overflow-x-auto rounded-xl border border-outline-variant">
          <table className="w-full text-sm">
            {/* Column headers */}
            <thead className="bg-surface-container-high text-on-surface-variant">
              <tr>
                {columns.map((col) => (
                  <th
                    key={col.key}
                    scope="col"
                    className="px-4 py-2.5 text-left font-medium"
                  >
                    {col.label}
                  </th>
                ))}
              </tr>
            </thead>

            {/* Data rows */}
            <tbody className="divide-y divide-outline-variant bg-surface-container">
              {data.length === 0 ? (
                <tr>
                  <td
                    colSpan={columns.length}
                    className="px-4 py-6 text-center text-on-surface-variant"
                  >
                    No data available
                  </td>
                </tr>
              ) : (
                data.map((row, rowIndex) => (
                  <tr
                    key={rowIndex}
                    className="hover:bg-surface-container-high transition-colors"
                  >
                    {columns.map((col) => (
                      <td
                        key={col.key}
                        className="px-4 py-2.5 text-on-surface tabular-nums"
                      >
                        {row[col.key] !== undefined && row[col.key] !== null
                          ? String(row[col.key])
                          : '—'}
                      </td>
                    ))}
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
