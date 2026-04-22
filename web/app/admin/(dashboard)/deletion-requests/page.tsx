import { adminFetch, AdminApiError } from '@/lib/admin-api';
import EmptyState from '@/components/admin/EmptyState';
import CsvExportButton from '@/components/admin/CsvExportButton';
import DeletionRequestsTable from '@/components/admin/DeletionRequestsTable';
import type { DeletionRequestListResponse } from '@/types/deletion-requests';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

interface PageProps {
  searchParams: Promise<{
    page?: string;
    pageSize?: string;
    search?: string;
  }>;
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

const DEFAULT_PAGE_SIZE = 25;

function parsePositiveInt(raw: string | undefined, fallback: number): number {
  const n = Number.parseInt(raw ?? '', 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

function getErrorMessage(reason: unknown): string {
  if (reason instanceof AdminApiError) return reason.message;
  if (reason instanceof Error) return reason.message;
  return 'An unexpected error occurred while loading deletion requests.';
}

// ────────────────────────────────────────────────────────────────────────────
// Page — Server Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * Admin Deletion Requests Page — server component
 *
 * Fetches a paginated list of deletion requests from the backend and renders
 * them in a client-side table with search, status badges, and a
 * "Mark as Processed" action per pending row.
 *
 * Fulfils REQ-003 / AC-003 / AC-004.
 */
export default async function DeletionRequestsPage({
  searchParams,
}: PageProps) {
  const params = await searchParams;
  const page = parsePositiveInt(params.page, 1);
  const pageSize = parsePositiveInt(params.pageSize, DEFAULT_PAGE_SIZE);
  const search = params.search ?? '';

  // ── Fetch deletion requests from backend ──────────────────────────────
  let data: DeletionRequestListResponse | null = null;
  let error: string | null = null;

  try {
    data = await adminFetch<DeletionRequestListResponse>(
      '/admin/analytics/deletion-requests',
      {
        query: {
          page,
          pageSize,
          search: search || undefined,
        },
      },
    );
  } catch (reason) {
    error = getErrorMessage(reason);
  }

  // ── Build CSV export URL ──────────────────────────────────────────────
  const exportParams = new URLSearchParams();
  if (search) exportParams.set('search', search);
  const exportUrl = `/api/admin/deletion-requests/export${exportParams.toString() ? '?' + exportParams.toString() : ''}`;

  return (
    <div>
      {/* ── Header ─────────────────────────────────────────────────────── */}
      <div className="flex flex-col gap-4 mb-8">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <h1 className="text-2xl font-bold text-on-surface">
            Deletion Requests
          </h1>
          <CsvExportButton
            exportUrl={exportUrl}
            filename={`deletion_requests_export_${new Date().toISOString().slice(0, 10)}`}
          />
        </div>
      </div>

      {/* ── Error banner ──────────────────────────────────────────────── */}
      {error && (
        <div
          className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-6"
          role="alert"
        >
          <p className="font-medium">Failed to load deletion requests</p>
          <p className="mt-1">{error}</p>
        </div>
      )}

      {/* ── Empty state ───────────────────────────────────────────────── */}
      {data && data.data.length === 0 && !search && (
        <EmptyState message="No deletion requests yet" />
      )}

      {/* ── Table (only rendered when we have data or search is active) ─ */}
      {data && (data.data.length > 0 || search) && (
        <DeletionRequestsTable
          rows={data.data}
          total={data.total}
          page={data.page}
          pageSize={data.pageSize}
          search={search}
        />
      )}
    </div>
  );
}
