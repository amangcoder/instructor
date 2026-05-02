'use client';

import Link from 'next/link';
import { useCallback, useEffect, useState } from 'react';
import { usePathname, useSearchParams } from 'next/navigation';
import type {
  PlanVoiceRow,
  PlanVoiceStatus,
} from '@/types/plan-voices';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface PlanVoiceJobTableProps {
  rows: PlanVoiceRow[];
  total: number;
  page: number;
  pageSize: number;
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/**
 * Format an ISO timestamp to a human-friendly UTC string.
 * "2026-04-21T14:32:00Z" → "Apr 21, 2026 14:32"
 * Returns "—" for null/invalid inputs.
 */
function formatTimestamp(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  const month = months[d.getUTCMonth()];
  const day = d.getUTCDate();
  const year = d.getUTCFullYear();
  const hours = String(d.getUTCHours()).padStart(2, '0');
  const minutes = String(d.getUTCMinutes()).padStart(2, '0');
  return `${month} ${day}, ${year} ${hours}:${minutes}`;
}

/**
 * Truncate a UUID to its first segment for compact display.
 * "3f2504e0-4f89-11d3-9a0c-0305e82c3301" → "3f2504e0…"
 */
function shortId(id: string): string {
  const seg = id.split('-')[0];
  return seg ? `${seg}…` : id;
}

// ────────────────────────────────────────────────────────────────────────────
// Retry state per row
// ────────────────────────────────────────────────────────────────────────────

type RetryState =
  | { kind: 'idle' }
  | { kind: 'loading' }
  | { kind: 'error'; message: string };

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * PlanVoiceJobTable — client component
 *
 * Displays a paginated table of failed plan_voices TTS jobs with:
 *  - Columns: plan_id, voice, locale, status badge, error_msg, generated_at
 *  - Retry button per row: POST /api/admin/plans/:id/voices/:voiceId/regenerate
 *  - Optimistic status update to 'pending' after successful retry
 *  - URL-driven pagination via the `pvPage` search param
 *    (avoids collision with other page-level params like `range`)
 *
 * Accessibility:
 *  - Semantic <table> with <thead>/<tbody> and scope="col"
 *  - aria-labels on interactive elements
 *  - Status badges use aria-label for screen readers
 *  - Pagination nav has aria-label and disabled buttons are aria-disabled
 */
export default function PlanVoiceJobTable({
  rows: initialRows,
  total,
  page,
  pageSize,
}: PlanVoiceJobTableProps) {
  const pathname = usePathname();
  const searchParams = useSearchParams();

  // Local copy of rows so we can apply optimistic updates without a full
  // page reload. Sync with server data when props change (pagination).
  const [rows, setRows] = useState<PlanVoiceRow[]>(initialRows);
  useEffect(() => {
    setRows(initialRows);
  }, [initialRows]);

  // Per-row retry state (idle | loading | error)
  const [retryState, setRetryState] = useState<Record<string, RetryState>>({});

  // ── Pagination ──────────────────────────────────────────────────────────
  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  const buildPageHref = useCallback(
    (targetPage: number): string => {
      const params = new URLSearchParams(searchParams.toString());
      params.set('pvPage', String(targetPage));
      return `${pathname}?${params.toString()}`;
    },
    [pathname, searchParams],
  );

  // ── Retry handler ───────────────────────────────────────────────────────
  const handleRetry = useCallback(
    async (row: PlanVoiceRow) => {
      setRetryState((prev) => ({ ...prev, [row.id]: { kind: 'loading' } }));

      try {
        const response = await fetch(
          `/api/admin/plans/${row.planId}/voices/${row.voiceId}/regenerate`,
          { method: 'POST' },
        );

        if (!response.ok) {
          const body = await response.json().catch(() => ({}));
          throw new Error(
            (body as { error?: string }).error ??
              `Regeneration failed (HTTP ${response.status})`,
          );
        }

        // Optimistic update: mark this row's status as 'pending'
        setRows((prev) =>
          prev.map((r) =>
            r.id === row.id
              ? { ...r, status: 'pending' as PlanVoiceStatus, errorMsg: null }
              : r,
          ),
        );
        setRetryState((prev) => ({ ...prev, [row.id]: { kind: 'idle' } }));
      } catch (err) {
        const message =
          err instanceof Error ? err.message : 'Failed to queue regeneration';
        setRetryState((prev) => ({
          ...prev,
          [row.id]: { kind: 'error', message },
        }));
      }
    },
    [],
  );

  // ── Render ─────────────────────────────────────────────────────────────
  return (
    <>
      {/* ── Summary ──────────────────────────────────────────────────── */}
      <p className="text-sm text-on-surface-variant mb-4">
        {total.toLocaleString()} failed job{total !== 1 ? 's' : ''} — page{' '}
        {page} of {totalPages}
      </p>

      {/* ── Table ────────────────────────────────────────────────────── */}
      <div className="rounded-xl bg-surface-container shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table
            className="min-w-full divide-y divide-outline-variant"
            aria-label="Failed TTS voice jobs"
          >
            <thead className="bg-surface-variant/30">
              <tr>
                <Th>Plan ID</Th>
                <Th>Voice</Th>
                <Th>Locale</Th>
                <Th>Status</Th>
                <Th>Error</Th>
                <Th>Generated At</Th>
                <Th className="text-right">Actions</Th>
              </tr>
            </thead>
            <tbody className="divide-y divide-outline-variant">
              {rows.length === 0 ? (
                <tr>
                  <td
                    colSpan={7}
                    className="px-4 py-10 text-center text-sm text-on-surface-variant"
                  >
                    No failed TTS jobs found.
                  </td>
                </tr>
              ) : (
                rows.map((row) => {
                  const retry = retryState[row.id] ?? { kind: 'idle' };
                  return (
                    <tr
                      key={row.id}
                      className="hover:bg-surface-variant/20 align-top"
                    >
                      {/* Plan ID — truncated UUID */}
                      <Td>
                        <span
                          className="font-mono text-xs text-on-surface"
                          title={row.planId}
                        >
                          {shortId(row.planId)}
                        </span>
                      </Td>

                      {/* Voice — truncated UUID */}
                      <Td>
                        <span
                          className="font-mono text-xs text-on-surface"
                          title={row.voiceId}
                        >
                          {shortId(row.voiceId)}
                        </span>
                      </Td>

                      {/* Locale */}
                      <Td>
                        <span className="font-mono text-xs text-on-surface">
                          {row.locale}
                        </span>
                      </Td>

                      {/* Status badge */}
                      <Td>
                        <StatusBadge status={row.status} />
                      </Td>

                      {/* Error message */}
                      <Td>
                        {row.errorMsg ? (
                          <span
                            className="block max-w-xs truncate text-xs text-error font-mono"
                            title={row.errorMsg}
                          >
                            {row.errorMsg}
                          </span>
                        ) : (
                          <span className="text-on-surface-variant">—</span>
                        )}
                        {/* Inline retry error */}
                        {retry.kind === 'error' && (
                          <p
                            role="alert"
                            className="mt-1 text-xs text-error"
                          >
                            {retry.message}
                          </p>
                        )}
                      </Td>

                      {/* Generated at */}
                      <Td className="tabular-nums whitespace-nowrap">
                        {formatTimestamp(row.generatedAt)}
                      </Td>

                      {/* Actions */}
                      <Td className="text-right">
                        {row.status === 'failed' ? (
                          <button
                            type="button"
                            onClick={() => handleRetry(row)}
                            disabled={retry.kind === 'loading'}
                            aria-label={`Retry TTS generation for plan ${row.planId} voice ${row.voiceId}`}
                            className="inline-flex items-center gap-1.5 rounded-lg bg-primary px-3 py-1.5 text-xs font-medium text-white hover:bg-primary/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-1 disabled:opacity-60 disabled:cursor-not-allowed min-h-[36px] transition-colors"
                          >
                            {retry.kind === 'loading' ? (
                              <>
                                <span
                                  aria-hidden="true"
                                  className="inline-block h-3 w-3 animate-spin rounded-full border-2 border-white border-t-transparent"
                                />
                                Retrying…
                              </>
                            ) : (
                              'Retry'
                            )}
                          </button>
                        ) : (
                          <span className="text-xs text-on-surface-variant">
                            —
                          </span>
                        )}
                      </Td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── Pagination ───────────────────────────────────────────────── */}
      {totalPages > 1 && (
        <nav
          aria-label="Failed TTS jobs pagination"
          className="mt-4 flex items-center justify-between"
        >
          <PageLink
            disabled={page <= 1}
            href={buildPageHref(page - 1)}
            label="Previous"
          />
          <span className="text-sm text-on-surface-variant">
            {page} / {totalPages}
          </span>
          <PageLink
            disabled={page >= totalPages}
            href={buildPageHref(page + 1)}
            label="Next"
          />
        </nav>
      )}
    </>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Presentational helpers
// ────────────────────────────────────────────────────────────────────────────

function StatusBadge({ status }: { status: PlanVoiceStatus }) {
  const colorClasses: Record<PlanVoiceStatus, string> = {
    pending: 'bg-amber-100 text-amber-900',
    processing: 'bg-blue-100 text-blue-900',
    ready: 'bg-green-100 text-green-900',
    failed: 'bg-red-100 text-red-900',
  };
  const label = status.charAt(0).toUpperCase() + status.slice(1);

  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${colorClasses[status] ?? 'bg-surface-variant text-on-surface-variant'}`}
      aria-label={`Status: ${label}`}
    >
      {label}
    </span>
  );
}

function Th({
  children,
  className = '',
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <th
      scope="col"
      className={`px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-on-surface-variant ${className}`}
    >
      {children}
    </th>
  );
}

function Td({
  children,
  className = '',
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <td className={`px-4 py-3 text-sm text-on-surface-variant ${className}`}>
      {children}
    </td>
  );
}

function PageLink({
  disabled,
  href,
  label,
}: {
  disabled: boolean;
  href: string;
  label: string;
}) {
  if (disabled) {
    return (
      <span
        aria-disabled="true"
        className="rounded-lg border border-outline-variant px-4 py-2 text-sm text-on-surface-variant opacity-50 cursor-not-allowed select-none"
      >
        {label}
      </span>
    );
  }
  return (
    <Link
      href={href}
      className="rounded-lg border border-outline-variant px-4 py-2 text-sm text-on-surface hover:bg-surface-variant/30 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
    >
      {label}
    </Link>
  );
}
