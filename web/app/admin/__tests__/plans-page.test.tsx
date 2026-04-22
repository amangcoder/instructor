/**
 * Tests for the admin Plans page.
 *
 * Since this is a React Server Component, we test by calling the page
 * function directly and inspecting the returned element tree.
 *
 * AC-017: Clicking Plans sidebar link loads a page without JS runtime errors
 * AC-018: Range defaults to 30d; page uses range from searchParams
 * AC-019: API errors display visible error messages, not zero-value charts
 * REQ-017: Plans page shows funnel chart and usage distribution
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

// Mock FunnelChart (client component — uses Recharts)
jest.mock('@/components/admin/FunnelChart', () => ({
  __esModule: true,
  default: ({ data }: { data: Array<{ name: string; value: number }> }) => (
    <div data-testid="funnel-chart">
      FunnelChart({data.map((s) => s.name).join(', ')})
    </div>
  ),
}));

// Mock DistributionBarChart (client component — uses Recharts)
jest.mock('@/components/admin/DistributionBarChart', () => ({
  __esModule: true,
  default: ({ xKey, yKey }: { xKey?: string; yKey?: string }) => (
    <div data-testid="distribution-bar-chart">
      DistributionBarChart(x={xKey}, y={yKey})
    </div>
  ),
}));

// Mock DataTableToggle (client component)
jest.mock('@/components/admin/DataTableToggle', () => ({
  __esModule: true,
  default: ({
    data,
    columns,
  }: {
    data: Array<Record<string, unknown>>;
    columns: Array<{ key: string; label: string }>;
  }) => (
    <div data-testid="data-table-toggle">
      DataTableToggle(rows={data.length}, columns={columns.map((c) => c.label).join(', ')})
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

// ── Fixtures ───────────────────────────────────────────────────────────────

function makeFunnelData() {
  return {
    series: [
      {
        stage: 'created',
        label: 'Created',
        count: 500,
        percentOfTop: 100,
        dropOffPercent: null,
      },
      {
        stage: 'tts_started',
        label: 'TTS Started',
        count: 480,
        percentOfTop: 96,
        dropOffPercent: 4,
      },
      {
        stage: 'tts_completed',
        label: 'TTS Completed',
        count: 450,
        percentOfTop: 90,
        dropOffPercent: 6.25,
      },
      {
        stage: 'activated',
        label: 'Activated',
        count: 350,
        percentOfTop: 70,
        dropOffPercent: 22.2,
      },
      {
        stage: 'session_completed',
        label: 'Session Completed',
        count: 200,
        percentOfTop: 40,
        dropOffPercent: 42.9,
      },
    ],
    totals: {
      totalCreated: 500,
      overallConversionPercent: 40,
      activated: 350,
      sessionCompleted: 200,
    },
  };
}

function makeUsageData() {
  return {
    series: [
      { bucket: '0', userCount: 50 },
      { bucket: '1', userCount: 400 },
      { bucket: '2', userCount: 200 },
      { bucket: '3', userCount: 100 },
      { bucket: '4', userCount: 60 },
      { bucket: '5+', userCount: 40 },
    ],
    totals: {
      usersWithPlans: 800,
      usersWithoutPlans: 50,
      avgPlansPerUser: 1.8,
      activePlans: 650,
      dormantPlans: 150,
      totalPlans: 850,
    },
  };
}

// ── Tests ──────────────────────────────────────────────────────────────────

describe('AdminPlansPage', () => {
  let AdminPlansPage: (props: {
    searchParams: Promise<{ range?: string }>;
  }) => Promise<React.JSX.Element>;

  beforeAll(async () => {
    const mod = await import('../(dashboard)/plans/page');
    AdminPlansPage = mod.default;
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  // ── Successful data rendering ────────────────────────────────────────

  it('renders the Plans heading (AC-017)', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeFunnelData())
      .mockResolvedValueOnce(makeUsageData());

    const element = await AdminPlansPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByRole('heading', { name: 'Plans' })).toBeInTheDocument();
  });

  it('renders section headings for both analytics sections (REQ-017)', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeFunnelData())
      .mockResolvedValueOnce(makeUsageData());

    const element = await AdminPlansPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(
      screen.getByRole('heading', { name: 'Plan Funnel' }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole('heading', { name: 'Plan Usage' }),
    ).toBeInTheDocument();
  });

  it('renders the RangePicker component (AC-018)', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeFunnelData())
      .mockResolvedValueOnce(makeUsageData());

    const element = await AdminPlansPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByTestId('range-picker')).toBeInTheDocument();
  });

  it('renders FunnelChart with Created, Activated, TTS Completed stages (REQ-017)', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeFunnelData())
      .mockResolvedValueOnce(makeUsageData());

    const element = await AdminPlansPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByTestId('funnel-chart')).toBeInTheDocument();
    // Mock renders the stage names — verify all three required stages are passed
    expect(screen.getByTestId('funnel-chart').textContent).toContain('Created');
    expect(screen.getByTestId('funnel-chart').textContent).toContain('Activated');
    expect(
      screen.getByTestId('funnel-chart').textContent,
    ).toContain('TTS Completed');
  });

  it('renders funnel StatCards with correct totals', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeFunnelData())
      .mockResolvedValueOnce(makeUsageData());

    const element = await AdminPlansPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByText('Total Created')).toBeInTheDocument();
    expect(screen.getByText('500')).toBeInTheDocument();
    expect(screen.getByText('Overall Conversion %')).toBeInTheDocument();
    expect(screen.getByText('40')).toBeInTheDocument();
  });

  it('renders Plan Completion Rate StatCard as the first metric', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeFunnelData())
      .mockResolvedValueOnce(makeUsageData());

    const element = await AdminPlansPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByText('Plan Completion Rate')).toBeInTheDocument();
    // Expected: (200 / 350) * 100 = 57.14... ≈ 57.1
    expect(screen.getByText('57.1')).toBeInTheDocument();
  });

  it('renders usage StatCards for active, dormant, and total plans', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeFunnelData())
      .mockResolvedValueOnce(makeUsageData());

    const element = await AdminPlansPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByText('Active Plans')).toBeInTheDocument();
    expect(screen.getByText('650')).toBeInTheDocument();
    expect(screen.getByText('Dormant Plans')).toBeInTheDocument();
    expect(screen.getByText('150')).toBeInTheDocument();
    expect(screen.getByText('Total Plans')).toBeInTheDocument();
    expect(screen.getByText('850')).toBeInTheDocument();
  });

  it('renders DistributionBarChart for plans-per-user distribution', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeFunnelData())
      .mockResolvedValueOnce(makeUsageData());

    const element = await AdminPlansPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(
      screen.getByTestId('distribution-bar-chart'),
    ).toBeInTheDocument();
  });

  it('renders "Plans per User Distribution" label above the bar chart', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeFunnelData())
      .mockResolvedValueOnce(makeUsageData());

    const element = await AdminPlansPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(
      screen.getByText('Plans per User Distribution'),
    ).toBeInTheDocument();
  });

  // ── DataTableToggle components ────────────────────────────────────────

  it('renders DataTableToggle beneath FunnelChart with correct columns', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeFunnelData())
      .mockResolvedValueOnce(makeUsageData());

    const element = await AdminPlansPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    const tableToggles = screen.getAllByTestId('data-table-toggle');
    expect(tableToggles).toHaveLength(2);

    // First toggle is for funnel data
    expect(tableToggles[0].textContent).toContain('rows=5');
    expect(tableToggles[0].textContent).toContain('Stage');
    expect(tableToggles[0].textContent).toContain('Count');
    expect(tableToggles[0].textContent).toContain('% of Top');
    expect(tableToggles[0].textContent).toContain('Drop-off %');
  });

  it('renders DataTableToggle beneath DistributionBarChart with correct columns', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeFunnelData())
      .mockResolvedValueOnce(makeUsageData());

    const element = await AdminPlansPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    const tableToggles = screen.getAllByTestId('data-table-toggle');
    expect(tableToggles).toHaveLength(2);

    // Second toggle is for usage data
    expect(tableToggles[1].textContent).toContain('rows=6');
    expect(tableToggles[1].textContent).toContain('Plans per User');
    expect(tableToggles[1].textContent).toContain('User Count');
  });

  // ── Range parameter handling (AC-018) ────────────────────────────────

  it('defaults range to 30d when no searchParam is provided', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeFunnelData())
      .mockResolvedValueOnce(makeUsageData());

    await AdminPlansPage({ searchParams: Promise.resolve({}) });

    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/plans/funnel',
      { range: '30d' },
    );
    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/plans/usage',
      { range: '30d' },
    );
  });

  it('forwards range from searchParams to both fetches', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeFunnelData())
      .mockResolvedValueOnce(makeUsageData());

    await AdminPlansPage({ searchParams: Promise.resolve({ range: '90d' }) });

    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/plans/funnel',
      { range: '90d' },
    );
    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/plans/usage',
      { range: '90d' },
    );
  });

  // ── Error isolation (AC-019, REQ-019) ────────────────────────────────

  it('shows funnel error when funnel endpoint fails, still renders usage section', async () => {
    const { AdminApiError } = await import('@/lib/admin-api');
    mockAdminFetch
      .mockRejectedValueOnce(
        new AdminApiError('Funnel service unavailable', 'INTERNAL'),
      )
      .mockResolvedValueOnce(makeUsageData());

    const element = await AdminPlansPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    // Error shown for funnel section
    const alerts = screen.getAllByRole('alert');
    expect(alerts).toHaveLength(1);
    expect(screen.getByText('Failed to load funnel data')).toBeInTheDocument();
    expect(screen.getByText('Funnel service unavailable')).toBeInTheDocument();

    // Usage section still renders
    expect(screen.getByText('Active Plans')).toBeInTheDocument();
    expect(
      screen.getByTestId('distribution-bar-chart'),
    ).toBeInTheDocument();

    // No funnel chart (error state)
    expect(screen.queryByTestId('funnel-chart')).not.toBeInTheDocument();
  });

  it('shows usage error when usage endpoint fails, still renders funnel section', async () => {
    const { AdminApiError } = await import('@/lib/admin-api');
    mockAdminFetch
      .mockResolvedValueOnce(makeFunnelData())
      .mockRejectedValueOnce(
        new AdminApiError('Usage service unavailable', 'INTERNAL'),
      );

    const element = await AdminPlansPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    // Error shown for usage section
    const alerts = screen.getAllByRole('alert');
    expect(alerts).toHaveLength(1);
    expect(screen.getByText('Failed to load usage data')).toBeInTheDocument();
    expect(screen.getByText('Usage service unavailable')).toBeInTheDocument();

    // Funnel section still renders
    expect(screen.getByTestId('funnel-chart')).toBeInTheDocument();

    // No distribution chart (error state)
    expect(
      screen.queryByTestId('distribution-bar-chart'),
    ).not.toBeInTheDocument();
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

    const element = await AdminPlansPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    const alerts = screen.getAllByRole('alert');
    expect(alerts).toHaveLength(2);
    expect(screen.getByText('Failed to load funnel data')).toBeInTheDocument();
    expect(screen.getByText('Failed to load usage data')).toBeInTheDocument();

    // No charts shown (AC-019: errors show messages, not blank charts)
    expect(screen.queryByTestId('funnel-chart')).not.toBeInTheDocument();
    expect(
      screen.queryByTestId('distribution-bar-chart'),
    ).not.toBeInTheDocument();
  });

  it('shows generic error for unexpected (non-AdminApiError) failures', async () => {
    mockAdminFetch
      .mockRejectedValueOnce(new Error('Database connection lost'))
      .mockResolvedValueOnce(makeUsageData());

    const element = await AdminPlansPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByText('Database connection lost')).toBeInTheDocument();
  });

  // ── Funnel stage ordering ─────────────────────────────────────────────

  it('shows funnel stages in Created → Activated → TTS Completed order', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeFunnelData())
      .mockResolvedValueOnce(makeUsageData());

    const element = await AdminPlansPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    const funnelEl = screen.getByTestId('funnel-chart');
    const content = funnelEl.textContent ?? '';
    const createdIdx = content.indexOf('Created');
    const activatedIdx = content.indexOf('Activated');
    const ttsIdx = content.indexOf('TTS Completed');

    // Verify order: Created → Activated → TTS Completed
    expect(createdIdx).toBeLessThan(activatedIdx);
    expect(activatedIdx).toBeLessThan(ttsIdx);
  });
});
