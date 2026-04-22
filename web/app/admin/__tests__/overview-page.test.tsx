/**
 * Tests for the admin overview page.
 *
 * Since this is a React Server Component, we test by calling the page
 * function directly and inspecting the returned element tree.
 */
import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';

// ── Mocks ─────────────────────────────────────────────────────────────────────

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

// Mock RangePicker (client component — requires useSearchParams Suspense boundary)
jest.mock('@/components/admin/RangePicker', () => ({
  __esModule: true,
  default: () => <div data-testid="range-picker">RangePicker</div>,
}));

// Mock SparklineChart (SVG — not required for functional overview tests)
jest.mock('@/components/admin/SparklineChart', () => ({
  __esModule: true,
  default: ({ points }: { points: Array<{ date: string; value: number }> }) => (
    <div data-testid="sparkline-chart" data-points={points.length} />
  ),
}));

// Mock ActivityFeedWidget (client component)
jest.mock('@/components/admin/ActivityFeedWidget', () => ({
  __esModule: true,
  default: ({ initialData }: { initialData: unknown }) => (
    <div data-testid="activity-feed-widget" data-has-data={!!initialData} />
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

// ── Helpers ───────────────────────────────────────────────────────────────────

function makeMetric(current: number, previous: number, deltaPercent: number | null = null) {
  return { current, previous, deltaPercent };
}

function makeSparkline(n: number) {
  return Array.from({ length: n }, (_, i) => ({
    date: `2024-01-${String(i + 1).padStart(2, '0')}`,
    value: Math.round(Math.random() * 100),
  }));
}

/** Build a well-shaped ExtendedOverviewResponse for testing */
function makeOverviewData(overrides: Record<string, unknown> = {}) {
  return {
    series: [],
    totals: {
      totalUsers: makeMetric(1200, 1158, 3.6),
      newSignups: makeMetric(42, 37, 13.5),
      activePlans: makeMetric(320, 305, 4.9),
      totalPlans: makeMetric(450, 435, 3.4),
      ttsJobsCompleted: makeMetric(8900, 8700, 2.3),
      ttsJobsFailed: makeMetric(40, 60, -33.3),
      totalSessions: makeMetric(3400, 3290, 3.3),
      avgSessionDurationMs: makeMetric(180_000, 175_000, 2.9),
      weeklyPlansPlayed: {
        ...makeMetric(3400, 3020, 12.5),
        sparkline: makeSparkline(7),
      },
      planCompletionRate: makeMetric(73.6, 71.2, 3.4),
      ...overrides,
    },
  };
}

function makeActivityData(count = 3) {
  return {
    events: Array.from({ length: count }, (_, i) => ({
      type: 'signup' as const,
      description: `user${i}@example.com signed up`,
      occurredAt: new Date(Date.now() - i * 60_000).toISOString(),
    })),
  };
}

/** Set up mockAdminFetch to return overview + activity data */
function setupMockFetch(
  overviewData = makeOverviewData(),
  activityData = makeActivityData(),
) {
  mockAdminFetch.mockImplementation((path: string) => {
    if (path === '/admin/analytics/overview') {
      return Promise.resolve(overviewData);
    }
    if (path === '/admin/analytics/overview/activity') {
      return Promise.resolve(activityData);
    }
    return Promise.reject(new Error(`Unknown path: ${path}`));
  });
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('AdminOverviewPage', () => {
  let AdminOverviewPage: (props: {
    searchParams: Promise<{ range?: string }>;
  }) => Promise<React.JSX.Element>;

  beforeAll(async () => {
    const mod = await import('../(dashboard)/overview/page');
    AdminOverviewPage = mod.default;
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  // ── Hero card: Weekly Plans Played ────────────────────────────────────

  it('renders Weekly Plans Played as the first / hero stat card', async () => {
    setupMockFetch();

    const element = await AdminOverviewPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByText('Weekly Plans Played')).toBeInTheDocument();

    // The hero card should be rendered with the 'hero' variant (text-5xl value)
    const heroRegion = screen.getByRole('region', { name: 'Weekly Plans Played' });
    expect(heroRegion).toBeInTheDocument();
    // Hero card uses text-5xl for the value paragraph
    const heroValue = heroRegion.querySelector('p.text-5xl');
    expect(heroValue).toBeInTheDocument();
    expect(heroValue?.textContent).toBe('3,400');
  });

  it('renders sparkline inside the Weekly Plans Played hero card', async () => {
    setupMockFetch();

    const element = await AdminOverviewPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    const sparkline = screen.getByTestId('sparkline-chart');
    expect(sparkline).toBeInTheDocument();
    // 7-point sparkline for 7-day data
    expect(sparkline).toHaveAttribute('data-points', '7');
  });

  it('renders DataTableToggle beneath the sparkline with sparkline data', async () => {
    setupMockFetch();

    const element = await AdminOverviewPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    const dataTable = screen.getByTestId('data-table-toggle');
    expect(dataTable).toBeInTheDocument();
    // Should render with 7 rows (7-point sparkline) and 2 columns (date, value)
    expect(dataTable).toHaveAttribute('data-rows', '7');
    expect(dataTable).toHaveAttribute('data-columns', '2');
  });

  it('renders the delta percent for Weekly Plans Played', async () => {
    setupMockFetch();

    const element = await AdminOverviewPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    // deltaPercent of 12.5 should render as '+12.5%'
    expect(screen.getByText('+12.5%')).toBeInTheDocument();
  });

  // ── Plan Completion Rate ──────────────────────────────────────────────

  it('renders Plan Completion Rate stat card with percentage', async () => {
    setupMockFetch();

    const element = await AdminOverviewPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByText('Plan Completion Rate')).toBeInTheDocument();
    // Displayed as "73.6%" not "73.6"
    expect(screen.getByText('73.6%')).toBeInTheDocument();
  });

  // ── Existing stat cards ───────────────────────────────────────────────

  it('renders core stat cards: Total Users, Total Plans, Total TTS Jobs, Total Sessions', async () => {
    setupMockFetch();

    const element = await AdminOverviewPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByText('Total Users')).toBeInTheDocument();
    expect(screen.getByText('1,200')).toBeInTheDocument();

    expect(screen.getByText('Total Plans')).toBeInTheDocument();
    expect(screen.getByText('450')).toBeInTheDocument();

    expect(screen.getByText('Total TTS Jobs')).toBeInTheDocument();
    // ttsJobsCompleted.current + ttsJobsFailed.current = 8900 + 40 = 8940
    expect(screen.getByText('8,940')).toBeInTheDocument();

    expect(screen.getByText('Total Sessions')).toBeInTheDocument();
  });

  it('renders period activity stat cards', async () => {
    setupMockFetch();

    const element = await AdminOverviewPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByText('New Signups')).toBeInTheDocument();
    expect(screen.getByText('Active Plans')).toBeInTheDocument();
    expect(screen.getByText('TTS Failures')).toBeInTheDocument();
    expect(screen.getByText('Avg Session (sec)')).toBeInTheDocument();
  });

  // ── Overview heading ──────────────────────────────────────────────────

  it('renders the Overview heading', async () => {
    setupMockFetch();

    const element = await AdminOverviewPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(
      screen.getByRole('heading', { name: 'Overview' }),
    ).toBeInTheDocument();
  });

  // ── RangePicker ───────────────────────────────────────────────────────

  it('renders the RangePicker', async () => {
    setupMockFetch();

    const element = await AdminOverviewPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByTestId('range-picker')).toBeInTheDocument();
  });

  // ── Range parameter ───────────────────────────────────────────────────

  it('passes range from searchParams to adminFetch for overview', async () => {
    setupMockFetch();

    await AdminOverviewPage({
      searchParams: Promise.resolve({ range: '7d' }),
    });

    expect(mockAdminFetch).toHaveBeenCalledWith('/admin/analytics/overview', {
      range: '7d',
    });
  });

  it('defaults to 7d range when no searchParam is provided', async () => {
    setupMockFetch();

    await AdminOverviewPage({
      searchParams: Promise.resolve({}),
    });

    expect(mockAdminFetch).toHaveBeenCalledWith('/admin/analytics/overview', {
      range: '7d',
    });
  });

  // ── Activity Feed Widget ──────────────────────────────────────────────

  it('renders the ActivityFeedWidget with initialData', async () => {
    setupMockFetch();

    const element = await AdminOverviewPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    const widget = screen.getByTestId('activity-feed-widget');
    expect(widget).toBeInTheDocument();
    expect(widget).toHaveAttribute('data-has-data', 'true');
  });

  it('renders ActivityFeedWidget with null initialData when activity fetch fails', async () => {
    // Overview succeeds, activity fails
    mockAdminFetch.mockImplementation((path: string) => {
      if (path === '/admin/analytics/overview') {
        return Promise.resolve(makeOverviewData());
      }
      return Promise.reject(new Error('Activity unavailable'));
    });

    const element = await AdminOverviewPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    const widget = screen.getByTestId('activity-feed-widget');
    expect(widget).toHaveAttribute('data-has-data', 'false');
  });

  // ── Error state ───────────────────────────────────────────────────────

  it('renders error message when adminFetch throws AdminApiError', async () => {
    const { AdminApiError } = await import('@/lib/admin-api');
    mockAdminFetch.mockImplementation((path: string) => {
      if (path === '/admin/analytics/overview') {
        return Promise.reject(
          new AdminApiError('Unauthorized — token missing or expired', 'UNAUTHORIZED'),
        );
      }
      return Promise.resolve({ events: [] });
    });

    const element = await AdminOverviewPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByRole('alert')).toBeInTheDocument();
    expect(screen.getByText('Failed to load analytics')).toBeInTheDocument();
    expect(
      screen.getByText('Unauthorized — token missing or expired'),
    ).toBeInTheDocument();
  });

  it('renders generic error message for unexpected errors', async () => {
    mockAdminFetch.mockImplementation((path: string) => {
      if (path === '/admin/analytics/overview') {
        return Promise.reject(new Error('Something broke'));
      }
      return Promise.resolve({ events: [] });
    });

    const element = await AdminOverviewPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByRole('alert')).toBeInTheDocument();
    expect(
      screen.getByText(
        'An unexpected error occurred while loading analytics.',
      ),
    ).toBeInTheDocument();
  });

  // ── EmptyState fallback ───────────────────────────────────────────────

  it('renders EmptyState for each stat area when overview fetch fails', async () => {
    const { AdminApiError } = await import('@/lib/admin-api');
    mockAdminFetch.mockImplementation((path: string) => {
      if (path === '/admin/analytics/overview') {
        return Promise.reject(new AdminApiError('Forbidden', 'FORBIDDEN'));
      }
      return Promise.resolve({ events: [] });
    });

    const element = await AdminOverviewPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    // Multiple EmptyState elements should appear — one per stat area
    const emptyStates = screen.getAllByRole('status');
    expect(emptyStates.length).toBeGreaterThanOrEqual(3);
  });

  // ── Zero value handling ───────────────────────────────────────────────

  it('renders stat cards with zero values without crashing', async () => {
    setupMockFetch(makeOverviewData({
      totalUsers: makeMetric(0, 0, null),
      newSignups: makeMetric(0, 0, null),
      totalSessions: makeMetric(0, 0, null),
      weeklyPlansPlayed: { ...makeMetric(0, 0, null), sparkline: [] },
      planCompletionRate: makeMetric(0, 0, null),
    }));

    const element = await AdminOverviewPage({
      searchParams: Promise.resolve({}),
    });
    // Should not throw
    expect(() => render(element)).not.toThrow();
  });
});
