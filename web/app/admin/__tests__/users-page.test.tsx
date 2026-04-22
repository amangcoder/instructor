/**
 * Tests for the admin Users page.
 *
 * Since this is a React Server Component, we test by calling the page
 * function directly and inspecting the returned element tree.
 *
 * AC-017: Clicking Users sidebar link loads a page without JS runtime errors
 * AC-018: Range defaults to 30d; page uses range from searchParams
 * AC-019: API errors display visible error messages, not zero-value charts
 * REQ-017: Users page shows signup trend and activation rate
 * Per-section error isolation: one failed endpoint doesn't crash the whole page
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

// Mock RangePicker (client component — needs useSearchParams)
jest.mock('@/components/admin/RangePicker', () => ({
  __esModule: true,
  default: () => <div data-testid="range-picker">RangePicker</div>,
}));

// Mock TimeSeriesChart (client component — uses Recharts which requires DOM)
jest.mock('@/components/admin/TimeSeriesChart', () => ({
  __esModule: true,
  default: ({ yKey }: { yKey?: string }) => (
    <div data-testid={`time-series-chart-${yKey ?? 'value'}`}>
      TimeSeriesChart({yKey})
    </div>
  ),
}));

// Mock ChartErrorBoundary
jest.mock('@/components/admin/ChartErrorBoundary', () => ({
  __esModule: true,
  default: ({ children }: { children: React.ReactNode }) => (
    <div data-testid="chart-error-boundary">{children}</div>
  ),
}));

// Mock DataTableToggle (client component)
jest.mock('@/components/admin/DataTableToggle', () => ({
  __esModule: true,
  default: ({ data, columns }: { data: unknown[]; columns: unknown[] }) => (
    <div
      data-testid="data-table-toggle"
      data-rows={Array.isArray(data) ? data.length : 0}
      data-columns={Array.isArray(columns) ? columns.length : 0}
    />
  ),
}));

// Mock CsvExportButton
jest.mock('@/components/admin/CsvExportButton', () => ({
  __esModule: true,
  default: () => <div data-testid="csv-export-button">CSV Export</div>,
}));

// ── Fixtures ───────────────────────────────────────────────────────────────

function makeSignupsData() {
  return {
    series: [
      { date: '2026-03-01', value: 12 },
      { date: '2026-03-02', value: 18 },
    ],
    totals: {
      total: 320,
      avgPerDay: 10.6,
      peakDay: 25,
      peakDate: '2026-03-15',
    },
  };
}

function makeActivationData() {
  return {
    series: [
      { date: '2026-03-01', value: 5, rate: 0.42, total: 12 },
      { date: '2026-03-02', value: 8, rate: 0.44, total: 18 },
    ],
    totals: {
      totalSignups: 320,
      totalActivated: 134,
      overallRate: 0.42,
    },
  };
}

// ── Tests ──────────────────────────────────────────────────────────────────

describe('AdminUsersPage', () => {
  let AdminUsersPage: (props: {
    searchParams: Promise<{ range?: string }>;
  }) => Promise<React.JSX.Element>;

  beforeAll(async () => {
    const mod = await import('../(dashboard)/users/page');
    AdminUsersPage = mod.default;
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  // ── Successful data rendering ────────────────────────────────────────

  it('renders the Users heading (AC-017)', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeSignupsData())
      .mockResolvedValueOnce(makeActivationData());

    const element = await AdminUsersPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByRole('heading', { name: 'Users' })).toBeInTheDocument();
  });

  it('renders section headings for both analytics sections (REQ-017)', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeSignupsData())
      .mockResolvedValueOnce(makeActivationData());

    const element = await AdminUsersPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(
      screen.getByRole('heading', { name: 'User Signups' }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole('heading', { name: 'Activation Rate' }),
    ).toBeInTheDocument();
  });

  it('renders the RangePicker component (AC-018)', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeSignupsData())
      .mockResolvedValueOnce(makeActivationData());

    const element = await AdminUsersPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByTestId('range-picker')).toBeInTheDocument();
  });

  it('renders signups StatCards with correct values', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeSignupsData())
      .mockResolvedValueOnce(makeActivationData());

    const element = await AdminUsersPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByText('Total Signups')).toBeInTheDocument();
    expect(screen.getByText('320')).toBeInTheDocument();
    expect(screen.getByText('Daily Average')).toBeInTheDocument();
  });

  it('renders activation StatCards with correct values', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeSignupsData())
      .mockResolvedValueOnce(makeActivationData());

    const element = await AdminUsersPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    // overallRate 0.42 → 42%
    expect(screen.getByText('Activation Rate %')).toBeInTheDocument();
    expect(screen.getByText('42')).toBeInTheDocument();
    expect(screen.getByText('Total Activated')).toBeInTheDocument();
    expect(screen.getByText('134')).toBeInTheDocument();
  });

  it('renders two TimeSeriesChart instances (one per section)', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeSignupsData())
      .mockResolvedValueOnce(makeActivationData());

    const element = await AdminUsersPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByTestId('time-series-chart-value')).toBeInTheDocument();
    expect(
      screen.getByTestId('time-series-chart-ratePct'),
    ).toBeInTheDocument();
  });

  it('renders DataTableToggle beneath signups chart with correct data', async () => {
    const signupsData = makeSignupsData();
    mockAdminFetch
      .mockResolvedValueOnce(signupsData)
      .mockResolvedValueOnce(makeActivationData());

    const element = await AdminUsersPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    const dataTables = screen.getAllByTestId('data-table-toggle');
    // Should have 2 DataTableToggles: one for signups, one for activation rate
    expect(dataTables).toHaveLength(2);
    // First DataTableToggle should have 2 rows (signups series) and 2 columns
    expect(dataTables[0]).toHaveAttribute('data-rows', '2');
    expect(dataTables[0]).toHaveAttribute('data-columns', '2');
  });

  it('renders DataTableToggle beneath activation rate chart with correct data', async () => {
    const activationData = makeActivationData();
    mockAdminFetch
      .mockResolvedValueOnce(makeSignupsData())
      .mockResolvedValueOnce(activationData);

    const element = await AdminUsersPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    const dataTables = screen.getAllByTestId('data-table-toggle');
    // Should have 2 DataTableToggles: one for signups, one for activation rate
    expect(dataTables).toHaveLength(2);
    // Second DataTableToggle should have 2 rows (activation series) and 4 columns
    expect(dataTables[1]).toHaveAttribute('data-rows', '2');
    expect(dataTables[1]).toHaveAttribute('data-columns', '4');
  });

  // ── Range parameter handling (AC-018) ────────────────────────────────

  it('defaults range to 30d when no searchParam is provided', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeSignupsData())
      .mockResolvedValueOnce(makeActivationData());

    await AdminUsersPage({ searchParams: Promise.resolve({}) });

    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/users/signups',
      { range: '30d' },
    );
    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/users/activation',
      { range: '30d' },
    );
  });

  it('forwards range from searchParams to both fetches', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeSignupsData())
      .mockResolvedValueOnce(makeActivationData());

    await AdminUsersPage({ searchParams: Promise.resolve({ range: '7d' }) });

    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/users/signups',
      { range: '7d' },
    );
    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/users/activation',
      { range: '7d' },
    );
  });

  // ── Error isolation (AC-019, REQ-019) ────────────────────────────────

  it('shows signups error when signups endpoint fails, still renders activation section', async () => {
    const { AdminApiError } = await import('@/lib/admin-api');
    mockAdminFetch
      .mockRejectedValueOnce(
        new AdminApiError('Signups service unavailable', 'INTERNAL'),
      )
      .mockResolvedValueOnce(makeActivationData());

    const element = await AdminUsersPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    // Error shown for signups section
    const alerts = screen.getAllByRole('alert');
    expect(alerts).toHaveLength(1);
    expect(screen.getByText('Failed to load signups data')).toBeInTheDocument();
    expect(screen.getByText('Signups service unavailable')).toBeInTheDocument();

    // Activation section still renders
    expect(screen.getByText('Activation Rate %')).toBeInTheDocument();
    expect(screen.getByTestId('time-series-chart-ratePct')).toBeInTheDocument();
  });

  it('shows activation error when activation endpoint fails, still renders signups section', async () => {
    const { AdminApiError } = await import('@/lib/admin-api');
    mockAdminFetch
      .mockResolvedValueOnce(makeSignupsData())
      .mockRejectedValueOnce(
        new AdminApiError('Activation service unavailable', 'INTERNAL'),
      );

    const element = await AdminUsersPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    // Error shown for activation section
    const alerts = screen.getAllByRole('alert');
    expect(alerts).toHaveLength(1);
    expect(
      screen.getByText('Failed to load activation data'),
    ).toBeInTheDocument();
    expect(
      screen.getByText('Activation service unavailable'),
    ).toBeInTheDocument();

    // Signups section still renders
    expect(screen.getByText('Total Signups')).toBeInTheDocument();
    expect(screen.getByTestId('time-series-chart-value')).toBeInTheDocument();
  });

  it('shows error messages for both sections when both endpoints fail (AC-019)', async () => {
    const { AdminApiError } = await import('@/lib/admin-api');
    mockAdminFetch
      .mockRejectedValueOnce(
        new AdminApiError('Forbidden — admin role required', 'FORBIDDEN'),
      )
      .mockRejectedValueOnce(
        new AdminApiError('Forbidden — admin role required', 'FORBIDDEN'),
      );

    const element = await AdminUsersPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    const alerts = screen.getAllByRole('alert');
    expect(alerts).toHaveLength(2);
    expect(screen.getByText('Failed to load signups data')).toBeInTheDocument();
    expect(
      screen.getByText('Failed to load activation data'),
    ).toBeInTheDocument();

    // No zero-value charts shown (AC-019: errors show messages, not blank charts)
    expect(
      screen.queryByTestId('time-series-chart-value'),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByTestId('time-series-chart-ratePct'),
    ).not.toBeInTheDocument();
  });

  it('shows generic error for unexpected (non-AdminApiError) failures', async () => {
    mockAdminFetch
      .mockRejectedValueOnce(new Error('Connection refused'))
      .mockResolvedValueOnce(makeActivationData());

    const element = await AdminUsersPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByText('Connection refused')).toBeInTheDocument();
  });
});
