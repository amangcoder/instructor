/**
 * Tests for the admin Deletion Requests page.
 *
 * The page is a React Server Component — we test by calling the page
 * function directly and inspecting the returned element tree.
 *
 * AC-003: Paginated table shows email (masked), IP, submitted-at, and status badge
 * AC-004: Mark as Processed opens modal; confirming updates row inline
 * REQ-006: Export CSV button present
 * REQ-018: Empty state when list is empty
 */
import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';

// ── Mocks ──────────────────────────────────────────────────────────────────

const mockAdminFetch = jest.fn();

jest.mock('@/lib/admin-api', () => ({
  adminFetch: (...args: unknown[]) => mockAdminFetch(...args),
  AdminApiError: class AdminApiError extends Error {
    code: string;
    constructor(message: string, code: string) {
      super(message);
      this.name = 'AdminApiError';
      this.code = code;
    }
  },
}));

// Mock EmptyState (server component — safe to render)
jest.mock('@/components/admin/EmptyState', () => ({
  __esModule: true,
  default: ({ message }: { message: string }) => (
    <div data-testid="empty-state" role="status" aria-label={message}>
      {message}
    </div>
  ),
}));

// Mock CsvExportButton (client component)
jest.mock('@/components/admin/CsvExportButton', () => ({
  __esModule: true,
  default: ({ exportUrl, filename }: { exportUrl: string; filename: string }) => (
    <button data-testid="csv-export-button" data-export-url={exportUrl} data-filename={filename}>
      Export CSV
    </button>
  ),
}));

// Mock DeletionRequestsTable (client component)
jest.mock('@/components/admin/DeletionRequestsTable', () => ({
  __esModule: true,
  default: ({
    rows,
    total,
    page,
    pageSize,
    search,
  }: {
    rows: unknown[];
    total: number;
    page: number;
    pageSize: number;
    search: string;
  }) => (
    <div
      data-testid="deletion-requests-table"
      data-rows={rows.length}
      data-total={total}
      data-page={page}
      data-page-size={pageSize}
      data-search={search}
    >
      DeletionRequestsTable
    </div>
  ),
}));

// ── Fixtures ───────────────────────────────────────────────────────────────

function makeListResponse(count = 2) {
  const rows = Array.from({ length: count }, (_, i) => ({
    id: `dr-${i + 1}`,
    email: `user${i + 1}@example.com`,
    scope: ['full_account'],
    status: i === 0 ? 'pending' : 'processed',
    reason: null,
    createdAt: '2026-04-21T14:32:00Z',
    processedAt: i === 0 ? null : '2026-04-21T15:00:00Z',
    ipAddress: `192.168.1.${i + 1}`,
  }));

  return {
    data: rows,
    total: count,
    page: 1,
    pageSize: 25,
  };
}

// ── Tests ──────────────────────────────────────────────────────────────────

describe('DeletionRequestsPage', () => {
  let DeletionRequestsPage: (props: {
    searchParams: Promise<{ page?: string; pageSize?: string; search?: string }>;
  }) => Promise<React.JSX.Element>;

  beforeAll(async () => {
    const mod = await import('../(dashboard)/deletion-requests/page');
    DeletionRequestsPage = mod.default;
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  // ── Successful rendering ─────────────────────────────────────────────

  it('renders the Deletion Requests heading', async () => {
    mockAdminFetch.mockResolvedValueOnce(makeListResponse());

    const element = await DeletionRequestsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(
      screen.getByRole('heading', { name: 'Deletion Requests' }),
    ).toBeInTheDocument();
  });

  it('renders the DeletionRequestsTable with correct props (AC-003)', async () => {
    const data = makeListResponse(3);
    mockAdminFetch.mockResolvedValueOnce(data);

    const element = await DeletionRequestsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    const table = screen.getByTestId('deletion-requests-table');
    expect(table).toBeInTheDocument();
    expect(table).toHaveAttribute('data-rows', '3');
    expect(table).toHaveAttribute('data-total', '3');
    expect(table).toHaveAttribute('data-page', '1');
    expect(table).toHaveAttribute('data-page-size', '25');
  });

  it('passes search param to adminFetch and table', async () => {
    mockAdminFetch.mockResolvedValueOnce(makeListResponse());

    const element = await DeletionRequestsPage({
      searchParams: Promise.resolve({ search: 'john' }),
    });
    render(element);

    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/deletion-requests',
      { query: { page: 1, pageSize: 25, search: 'john' } },
    );

    const table = screen.getByTestId('deletion-requests-table');
    expect(table).toHaveAttribute('data-search', 'john');
  });

  it('passes page and pageSize params to adminFetch', async () => {
    mockAdminFetch.mockResolvedValueOnce(makeListResponse());

    await DeletionRequestsPage({
      searchParams: Promise.resolve({ page: '3', pageSize: '10' }),
    });

    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/deletion-requests',
      { query: { page: 3, pageSize: 10, search: undefined } },
    );
  });

  // ── CSV Export (REQ-006) ─────────────────────────────────────────────

  it('renders the CsvExportButton with correct export URL (REQ-006)', async () => {
    mockAdminFetch.mockResolvedValueOnce(makeListResponse());

    const element = await DeletionRequestsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    const csvButton = screen.getByTestId('csv-export-button');
    expect(csvButton).toBeInTheDocument();
    expect(csvButton).toHaveAttribute(
      'data-export-url',
      '/api/admin/deletion-requests/export',
    );
  });

  it('includes search param in CSV export URL', async () => {
    mockAdminFetch.mockResolvedValueOnce(makeListResponse());

    const element = await DeletionRequestsPage({
      searchParams: Promise.resolve({ search: 'test' }),
    });
    render(element);

    const csvButton = screen.getByTestId('csv-export-button');
    expect(csvButton).toHaveAttribute(
      'data-export-url',
      '/api/admin/deletion-requests/export?search=test',
    );
  });

  // ── Empty state (REQ-018) ───────────────────────────────────────────

  it('shows empty state when list is empty and no search (REQ-018)', async () => {
    mockAdminFetch.mockResolvedValueOnce({
      data: [],
      total: 0,
      page: 1,
      pageSize: 25,
    });

    const element = await DeletionRequestsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    const emptyState = screen.getByTestId('empty-state');
    expect(emptyState).toBeInTheDocument();
    expect(emptyState).toHaveTextContent('No deletion requests yet');
  });

  it('shows table (not empty state) when list is empty but search is active', async () => {
    mockAdminFetch.mockResolvedValueOnce({
      data: [],
      total: 0,
      page: 1,
      pageSize: 25,
    });

    const element = await DeletionRequestsPage({
      searchParams: Promise.resolve({ search: 'nonexistent' }),
    });
    render(element);

    // Table should be shown (with "no results" inside) instead of EmptyState
    expect(screen.getByTestId('deletion-requests-table')).toBeInTheDocument();
    expect(screen.queryByTestId('empty-state')).not.toBeInTheDocument();
  });

  // ── Error handling ──────────────────────────────────────────────────

  it('shows error banner when adminFetch fails', async () => {
    const { AdminApiError } = await import('@/lib/admin-api');
    mockAdminFetch.mockRejectedValueOnce(
      new AdminApiError('Unauthorized — token missing or expired', 'UNAUTHORIZED'),
    );

    const element = await DeletionRequestsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    const alert = screen.getByRole('alert');
    expect(alert).toBeInTheDocument();
    expect(
      screen.getByText('Failed to load deletion requests'),
    ).toBeInTheDocument();
    expect(
      screen.getByText('Unauthorized — token missing or expired'),
    ).toBeInTheDocument();
  });

  it('does not render table or empty state when fetch fails', async () => {
    mockAdminFetch.mockRejectedValueOnce(new Error('Network error'));

    const element = await DeletionRequestsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.queryByTestId('deletion-requests-table')).not.toBeInTheDocument();
    expect(screen.queryByTestId('empty-state')).not.toBeInTheDocument();
  });

  // ── Param defaults ─────────────────────────────────────────────────

  it('defaults page to 1 and pageSize to 25 for invalid params', async () => {
    mockAdminFetch.mockResolvedValueOnce(makeListResponse());

    await DeletionRequestsPage({
      searchParams: Promise.resolve({ page: 'abc', pageSize: '-5' }),
    });

    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/deletion-requests',
      { query: { page: 1, pageSize: 25, search: undefined } },
    );
  });
});
