'use client';

import { useRouter, usePathname, useSearchParams } from 'next/navigation';
import { useCallback, useEffect, useRef, useState, useTransition } from 'react';
import Link from 'next/link';
import type { DeletionRequestRow } from '@/types/deletion-requests';
import ProcessConfirmModal from '@/components/admin/ProcessConfirmModal';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface DeletionRequestsTableProps {
  rows: DeletionRequestRow[];
  total: number;
  page: number;
  pageSize: number;
  search: string;
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/**
 * Mask an email address for privacy display.
 * "john@example.com" → "j***@example.com"
 */
function maskEmail(email: string): string {
  const atIndex = email.indexOf('@');
  if (atIndex <= 1) return email; // too short to mask
  return email[0] + '***' + email.slice(atIndex);
}

/**
 * Format an ISO timestamp to a human-friendly string.
 * "2026-04-21T14:32:00Z" → "Apr 21, 2026 14:32"
 */
function formatTimestamp(iso: string): string {
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

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * DeletionRequestsTable — client component
 *
 * Displays a paginated, searchable table of deletion requests with:
 *  - Masked email, IP address, submitted-at, status badge
 *  - "Mark as Processed" button for pending rows
 *  - Debounced search input that filters by email via URL searchParams
 *  - Inline status update after processing (no full page reload)
 *
 * Accessibility:
 *  - Semantic <table> with <thead>/<tbody>
 *  - aria-labels on interactive elements
 *  - Keyboard navigable (Tab, Enter)
 *  - Status badges use aria-label for screen readers
 */
export default function DeletionRequestsTable({
  rows: initialRows,
  total,
  page,
  pageSize,
  search,
}: DeletionRequestsTableProps) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [, startTransition] = useTransition();

  // Local state for inline updates after processing
  const [rows, setRows] = useState(initialRows);

  // Sync rows when server data changes (e.g. pagination / search)
  useEffect(() => {
    setRows(initialRows);
  }, [initialRows]);

  // Track which row is being confirmed for processing
  const [processingId, setProcessingId] = useState<string | null>(null);
  const [processingEmail, setProcessingEmail] = useState<string>('');

  // ── Search with debounce ──────────────────────────────────────────────
  const [searchValue, setSearchValue] = useState(search);

  // Keep refs to navigation objects so the debounce callback always reads
  // the latest values even if they change while the timer is pending.
  const pathnameRef = useRef(pathname);
  const routerRef = useRef(router);
  const searchParamsRef = useRef(searchParams);
  useEffect(() => { pathnameRef.current = pathname; }, [pathname]);
  useEffect(() => { routerRef.current = router; }, [router]);
  useEffect(() => { searchParamsRef.current = searchParams; }, [searchParams]);

  useEffect(() => {
    const handle = setTimeout(() => {
      const params = new URLSearchParams(searchParamsRef.current.toString());
      if (searchValue.trim()) {
        params.set('search', searchValue.trim());
      } else {
        params.delete('search');
      }
      // Reset to page 1 on search change
      params.delete('page');
      startTransition(() => {
        routerRef.current.replace(`${pathnameRef.current}?${params.toString()}`);
      });
    }, 300);

    return () => clearTimeout(handle);
  }, [searchValue]);

  // ── Pagination helpers ────────────────────────────────────────────────
  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  const buildPageHref = useCallback(
    (targetPage: number): string => {
      const params = new URLSearchParams(searchParams.toString());
      params.set('page', String(targetPage));
      return `${pathname}?${params.toString()}`;
    },
    [pathname, searchParams],
  );

  // ── Process handler (called from modal) ───────────────────────────────
  const handleProcessConfirm = useCallback(async () => {
    if (!processingId) return;

    const response = await fetch(
      `/api/admin/deletion-requests/${processingId}/process`,
      { method: 'PATCH' },
    );

    if (!response.ok) {
      const body = await response.json().catch(() => ({}));
      throw new Error(
        (body as { error?: string }).error ?? 'Failed to mark as processed',
      );
    }

    // Update row status inline
    setRows((prev) =>
      prev.map((row) =>
        row.id === processingId
          ? { ...row, status: 'processed' as const, processedAt: new Date().toISOString() }
          : row,
      ),
    );

    // Trigger a soft refresh so the layout re-fetches the sidebar badge count
    startTransition(() => {
      router.refresh();
    });
  }, [processingId, router]);

  return (
    <>
      {/* ── Search input ───────────────────────────────────────────────── */}
      <div className="mb-4">
        <input
          type="search"
          value={searchValue}
          onChange={(e) => setSearchValue(e.target.value)}
          placeholder="Search by email..."
          className="w-full sm:w-80 rounded-lg border border-white/10 bg-slate-800/50 px-3 py-2 text-sm text-white placeholder:text-slate-500 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-400 focus-visible:border-indigo-500"
          aria-label="Search deletion requests by email"
        />
      </div>

      {/* ── Summary ────────────────────────────────────────────────────── */}
      <p className="text-sm text-slate-400 mb-4">
        {total.toLocaleString()} deletion request{total !== 1 ? 's' : ''}
        {search ? ` matching "${search}"` : ''} — page {page} of {totalPages}
      </p>

      {/* ── Table ──────────────────────────────────────────────────────── */}
      <div className="rounded-xl bg-slate-900 border border-white/8 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-white/8">
            <thead className="bg-slate-800/50">
              <tr>
                <Th>Email</Th>
                <Th>IP Address</Th>
                <Th>Submitted</Th>
                <Th>Status</Th>
                <Th className="text-right">Actions</Th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5">
              {rows.length === 0 ? (
                <tr>
                  <td
                    colSpan={5}
                    className="px-4 py-10 text-center text-sm text-slate-400"
                  >
                    {search
                      ? `No deletion requests matching "${search}"`
                      : 'No deletion requests yet'}
                  </td>
                </tr>
              ) : (
                rows.map((row) => (
                  <tr key={row.id} className="hover:bg-white/5 transition-colors duration-150">
                    <Td>
                      <span className="font-medium text-white">
                        {maskEmail(row.email)}
                      </span>
                    </Td>
                    <Td className="tabular-nums">
                      {(row as DeletionRequestRowWithIp).ipAddress ?? '—'}
                    </Td>
                    <Td className="tabular-nums">
                      {formatTimestamp(row.createdAt)}
                    </Td>
                    <Td>
                      <StatusBadge status={row.status} />
                    </Td>
                    <Td className="text-right">
                      {row.status === 'pending' ? (
                        <button
                          type="button"
                          onClick={() => {
                            setProcessingId(row.id);
                            setProcessingEmail(row.email);
                          }}
                          className="inline-flex items-center rounded-lg bg-indigo-600 hover:bg-indigo-500 px-3 py-1.5 text-xs font-medium text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-400 focus-visible:ring-offset-1 min-h-[44px] transition-colors"
                          aria-label={`Mark deletion request from ${maskEmail(row.email)} as processed`}
                        >
                          Mark as Processed
                        </button>
                      ) : (
                        <span className="text-xs text-slate-400">
                          —
                        </span>
                      )}
                    </Td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── Pagination ─────────────────────────────────────────────────── */}
      {totalPages > 1 && (
        <nav
          aria-label="Deletion requests pagination"
          className="mt-4 flex items-center justify-between"
        >
          <PageLink
            disabled={page <= 1}
            href={buildPageHref(page - 1)}
            label="Previous"
          />
          <PageLink
            disabled={page >= totalPages}
            href={buildPageHref(page + 1)}
            label="Next"
          />
        </nav>
      )}

      {/* ── Process confirmation modal ─────────────────────────────────── */}
      <ProcessConfirmModal
        open={processingId !== null}
        email={maskEmail(processingEmail)}
        onConfirm={handleProcessConfirm}
        onClose={() => {
          setProcessingId(null);
          setProcessingEmail('');
        }}
      />
    </>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Extended type to include ipAddress from backend response
// ────────────────────────────────────────────────────────────────────────────

interface DeletionRequestRowWithIp extends DeletionRequestRow {
  ipAddress?: string;
}

// ────────────────────────────────────────────────────────────────────────────
// Presentational helpers
// ────────────────────────────────────────────────────────────────────────────

function StatusBadge({ status }: { status: string }) {
  const isPending = status === 'pending';
  const isProcessed = status === 'processed';

  const colorClasses = isPending
    ? 'bg-amber-500/20 text-amber-400'
    : isProcessed
      ? 'bg-emerald-500/20 text-emerald-400'
      : 'bg-slate-700 text-slate-300';

  const label = isPending
    ? 'Pending'
    : isProcessed
      ? 'Processed'
      : status.charAt(0).toUpperCase() + status.slice(1);

  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${colorClasses}`}
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
      className={`px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-400 ${className}`}
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
    <td className={`px-4 py-3 text-sm text-slate-300 ${className}`}>
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
      <span className="rounded-lg border border-white/8 px-4 py-2 text-sm text-slate-400 opacity-50 cursor-not-allowed">
        {label}
      </span>
    );
  }
  return (
    <Link
      href={href}
      className="rounded-lg border border-white/8 px-4 py-2 text-sm text-white hover:bg-white/5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-400"
    >
      {label}
    </Link>
  );
}
