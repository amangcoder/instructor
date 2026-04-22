/**
 * Tests for the admin engagement page.
 *
 * The page is a React Server Component — we test by calling the async
 * function directly and inspecting the rendered element tree.
 *
 * All client components (TimeSeriesChart, DataTableToggle, EmptyState,
 * RangePicker, StreakBarChart) are mocked so the test suite runs in
 * a Node / jsdom environment without Recharts or next/navigation.
 */
import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import type { StreaksResponse } from '@/types/analytics';
import type { RetentionResponse, ActiveUsersResponse } from '@/types/retention';

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

// Mock client components that use browser APIs / Recharts
jest.mock('@/components/admin/StreakBarChart', () => ({
  __esModule: true,
  default: ({ data }: { data: unknown[] }) => (
    <div data-testid="streak-bar-chart" data-count={data.length}>
      StreakBarChart
    </div>
  ),
}));

jest.mock('@/components/admin/TimeSeriesChart', () => ({
  __esModule: true,
  default: ({
    data,
    series,
    title,
  }: {
    data: unknown[];
    series?: { dataKey: string; color: string; name: string }[];
    title?: string;
  }) => (
    <div
      data-testid="time-series-chart"
      data-count={data.length}
      data-series-count={series ? series.length : 1}
      aria-label={title ?? 'Time series chart'}
    >
      TimeSeriesChart
    </div>
  ),
}));

jest.mock('@/components/admin/DataTableToggle', () => ({
  __esModule: true,
  default: ({
    data,
    columns,
  }: {
    data: unknown[];
    columns: { key: string; label: string }[];
  }) => (
    <div
      data-testid="data-table-toggle"
      data-row-count={data.length}
      data-col-count={columns.length}
    >
      DataTableToggle
    </div>
  ),
}));

jest.mock('@/components/admin/EmptyState', () => ({
  __esModule: true,
  default: ({ message }: { message: string }) => (
    <div data-testid="empty-state" role="status">
      {message}
    </div>
  ),
}));

jest.mock('@/components/admin/RangePicker', () => ({
  __esModule: true,
  default: () => <div data-testid="range-picker">RangePicker</div>,
}));

// ── Fixtures ──────────────────────────────────────────────────────────────────

function makeStreaksData(
  overrides: Partial<StreaksResponse> = {},
): StreaksResponse {
  return {
    series: [
      { bucket: '0', min: 0, max: 0, userCount: 120 },
      { bucket: '1-2', min: 1, max: 2, userCount: 85 },
      { bucket: '3-6', min: 3, max: 6, userCount: 60 },
      { bucket: '7-13', min: 7, max: 13, userCount: 40 },
      { bucket: '14-29', min: 14, max: 29, userCount: 20 },
      { bucket: '30+', min: 30, max: null, userCount: 10 },
    ],
    totals: {
      usersWithStreaks: 215,
      avgStreak: 4.7,
      medianStreak: 3,
      maxStreak: 45,
      activeStreakUsers: 180,
    },
    ...overrides,
  };
}

function makeRetentionData(): RetentionResponse {
  return {
    d7: { rate: 0.184, deltaPercent: 1.2 },
    d30: { rate: 0.072, deltaPercent: -0.5 },
  };
}

function makeActiveUsersData(): ActiveUsersResponse {
  return {
    dau: [
      { date: '2024-01-01', value: 120 },
      { date: '2024-01-02', value: 135 },
      { date: '2024-01-03', value: 128 },
    ],
    wau: [{ date: '2024-01-01', value: 450 }],
    mau: [{ date: '2024-01-01', value: 1200 }],
  };
}

/**
 * Set up the adminFetch mock to return fixture data for each endpoint.
 * Pass `null` for a key to simulate a failed (rejected) fetch for that endpoint.
 */
function setupMocks(
  overrides: {
    retention?: RetentionResponse | null;
    activeUsers?: ActiveUsersResponse | null;
    streaks?: StreaksResponse | null;
  } = {},
) {
  const retention =
    overrides.retention !== undefined ? overrides.retention : makeRetentionData();
  const activeUsers =
    overrides.activeUsers !== undefined ? overrides.activeUsers : makeActiveUsersData();
  const streaks =
    overrides.streaks !== undefined ? overrides.streaks : makeStreaksData();

  mockAdminFetch.mockImplementation((path: string) => {
    if (path === '/admin/analytics/engagement/retention') {
      return retention !== null
        ? Promise.resolve(retention)
        : Promise.reject(new Error('retention fetch failed'));
    }
    if (path === '/admin/analytics/engagement/active-users') {
      return activeUsers !== null
        ? Promise.resolve(activeUsers)
        : Promise.reject(new Error('active-users fetch failed'));
    }
    if (path === '/admin/analytics/engagement/streaks') {
      return streaks !== null
        ? Promise.resolve(streaks)
        : Promise.reject(new Error('streaks fetch failed'));
    }
    return Promise.reject(new Error(`Unexpected adminFetch call: ${path}`));
  });
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('AdminEngagementPage', () => {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let AdminEngagementPage: (props?: any) => Promise<React.JSX.Element>;

  beforeAll(async () => {
    const mod = await import('../(dashboard)/engagement/page');
    AdminEngagementPage = mod.default;
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  // ── Page heading ──────────────────────────────────────────────────────

  it('renders the page heading', async () => {
    setupMocks();
    const element = await AdminEngagementPage();
    render(element);

    expect(
      screen.getByRole('heading', { name: 'Engagement' }),
    ).toBeInTheDocument();
  });

  // ── Retention stat cards (REQ-004, AC-005) ────────────────────────────

  it('renders D7 Retention stat card with percentage value', async () => {
    setupMocks();
    const element = await AdminEngagementPage();
    render(element);

    expect(
      screen.getByRole('region', { name: 'D7 Retention' }),
    ).toBeInTheDocument();
    // 0.184 * 100 = 18.4 → "18.4%"
    expect(screen.getByText('18.4%')).toBeInTheDocument();
  });

  it('renders D30 Retention stat card with percentage value', async () => {
    setupMocks();
    const element = await AdminEngagementPage();
    render(element);

    expect(
      screen.getByRole('region', { name: 'D30 Retention' }),
    ).toBeInTheDocument();
    // 0.072 * 100 = 7.2 → "7.2%"
    expect(screen.getByText('7.2%')).toBeInTheDocument();
  });

  it('renders D7 Retention positive delta in pp notation', async () => {
    setupMocks();
    const element = await AdminEngagementPage();
    render(element);

    // deltaPercent = 1.2 → "+1.2pp"
    expect(screen.getByText('+1.2pp')).toBeInTheDocument();
  });

  it('renders D30 Retention negative delta in pp notation', async () => {
    setupMocks();
    const element = await AdminEngagementPage();
    render(element);

    // deltaPercent = -0.5 → "-0.5pp"
    expect(screen.getByText('-0.5pp')).toBeInTheDocument();
  });

  it('omits delta indicator when deltaPercent is null', async () => {
    setupMocks({
      retention: {
        d7: { rate: 0.2, deltaPercent: null },
        d30: { rate: 0.05, deltaPercent: null },
      },
    });
    const element = await AdminEngagementPage();
    render(element);

    // No pp-formatted delta should appear
    expect(screen.queryByText(/pp$/)).not.toBeInTheDocument();
  });

  // ── Active users chart (REQ-011) ──────────────────────────────────────

  it('renders TimeSeriesChart for active users', async () => {
    setupMocks();
    const element = await AdminEngagementPage();
    render(element);

    expect(screen.getByTestId('time-series-chart')).toBeInTheDocument();
  });

  it('passes three series (DAU, WAU, MAU) to the TimeSeriesChart', async () => {
    setupMocks();
    const element = await AdminEngagementPage();
    render(element);

    const chart = screen.getByTestId('time-series-chart');
    expect(chart).toHaveAttribute('data-series-count', '3');
  });

  it('passes merged data rows to the TimeSeriesChart', async () => {
    setupMocks();
    const element = await AdminEngagementPage();
    render(element);

    const chart = screen.getByTestId('time-series-chart');
    // DAU has dates: 2024-01-01, 2024-01-02, 2024-01-03
    // WAU/MAU both use 2024-01-01 (overlap) → total unique dates = 3
    expect(chart).toHaveAttribute('data-count', '3');
  });

  // ── RangePicker ──────────────────────────────────────────────────────

  it('renders a RangePicker for the active-users section', async () => {
    setupMocks();
    const element = await AdminEngagementPage();
    render(element);

    expect(screen.getByTestId('range-picker')).toBeInTheDocument();
  });

  it('passes range from searchParams to the active-users fetch', async () => {
    setupMocks();
    await AdminEngagementPage({
      searchParams: Promise.resolve({ range: '7d' }),
    });

    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/engagement/active-users',
      { range: '7d' },
    );
  });

  it('defaults to 30d range when no searchParams provided', async () => {
    setupMocks();
    await AdminEngagementPage();

    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/engagement/active-users',
      { range: '30d' },
    );
  });

  // ── DataTableToggle (REQ-012, AC-011) ─────────────────────────────────

  it('renders two DataTableToggle components when all data is available', async () => {
    setupMocks();
    const element = await AdminEngagementPage();
    render(element);

    const toggles = screen.getAllByTestId('data-table-toggle');
    expect(toggles).toHaveLength(2);
  });

  it('active-users DataTableToggle has four columns (Date, DAU, WAU, MAU)', async () => {
    setupMocks();
    const element = await AdminEngagementPage();
    render(element);

    const toggles = screen.getAllByTestId('data-table-toggle');
    // First toggle is active-users
    expect(toggles[0]).toHaveAttribute('data-col-count', '4');
  });

  it('streak DataTableToggle has four columns (Bucket, Min, Max, Users)', async () => {
    setupMocks();
    const element = await AdminEngagementPage();
    render(element);

    const toggles = screen.getAllByTestId('data-table-toggle');
    // Second toggle is streaks
    expect(toggles[1]).toHaveAttribute('data-col-count', '4');
  });

  // ── EmptyState (AC-012) ───────────────────────────────────────────────

  it('renders EmptyState when active users data is empty', async () => {
    setupMocks({ activeUsers: { dau: [], wau: [], mau: [] } });
    const element = await AdminEngagementPage();
    render(element);

    expect(screen.getAllByTestId('empty-state').length).toBeGreaterThanOrEqual(1);
    expect(
      screen.getAllByText('No data for this period.').length,
    ).toBeGreaterThanOrEqual(1);
  });

  it('hides active-users DataTableToggle when data is empty', async () => {
    setupMocks({ activeUsers: { dau: [], wau: [], mau: [] } });
    const element = await AdminEngagementPage();
    render(element);

    // Only the streak toggle should be present
    const toggles = screen.queryAllByTestId('data-table-toggle');
    expect(toggles).toHaveLength(1);
  });

  it('renders EmptyState when streak series is empty', async () => {
    setupMocks({ streaks: makeStreaksData({ series: [] }) });
    const element = await AdminEngagementPage();
    render(element);

    expect(screen.getByTestId('empty-state')).toBeInTheDocument();
    expect(screen.getByText('No data for this period.')).toBeInTheDocument();
  });

  it('hides streak DataTableToggle when streak series is empty', async () => {
    setupMocks({ streaks: makeStreaksData({ series: [] }) });
    const element = await AdminEngagementPage();
    render(element);

    // Only active-users toggle should be present
    const toggles = screen.queryAllByTestId('data-table-toggle');
    expect(toggles).toHaveLength(1);
  });

  // ── API calls ─────────────────────────────────────────────────────────

  it('fetches retention without any extra options', async () => {
    setupMocks();
    await AdminEngagementPage();

    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/engagement/retention',
    );
    // Must NOT pass a second arg (no range) to retention
    expect(mockAdminFetch).not.toHaveBeenCalledWith(
      '/admin/analytics/engagement/retention',
      expect.anything(),
    );
  });

  it('fetches streaks without any extra options', async () => {
    setupMocks();
    await AdminEngagementPage();

    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/engagement/streaks',
    );
    // Must NOT pass a second arg (no range) to streaks
    expect(mockAdminFetch).not.toHaveBeenCalledWith(
      '/admin/analytics/engagement/streaks',
      expect.anything(),
    );
  });

  // ── Error states ──────────────────────────────────────────────────────

  it('renders error alert when retention fetch fails (AdminApiError)', async () => {
    const { AdminApiError } = await import('@/lib/admin-api');
    mockAdminFetch.mockImplementation((path: string) => {
      if (path === '/admin/analytics/engagement/retention') {
        return Promise.reject(
          new AdminApiError('Forbidden — admin role required', 'FORBIDDEN'),
        );
      }
      if (path === '/admin/analytics/engagement/active-users') {
        return Promise.resolve(makeActiveUsersData());
      }
      if (path === '/admin/analytics/engagement/streaks') {
        return Promise.resolve(makeStreaksData());
      }
      return Promise.reject(new Error(`Unexpected: ${path}`));
    });

    const element = await AdminEngagementPage();
    render(element);

    expect(screen.getByRole('alert')).toBeInTheDocument();
    expect(
      screen.getByText('Failed to load retention data'),
    ).toBeInTheDocument();
    expect(
      screen.getByText('Forbidden — admin role required'),
    ).toBeInTheDocument();
  });

  it('renders error alert when active-users fetch fails', async () => {
    const { AdminApiError } = await import('@/lib/admin-api');
    mockAdminFetch.mockImplementation((path: string) => {
      if (path === '/admin/analytics/engagement/retention') {
        return Promise.resolve(makeRetentionData());
      }
      if (path === '/admin/analytics/engagement/active-users') {
        return Promise.reject(new AdminApiError('Server Error', 'INTERNAL_ERROR'));
      }
      if (path === '/admin/analytics/engagement/streaks') {
        return Promise.resolve(makeStreaksData());
      }
      return Promise.reject(new Error(`Unexpected: ${path}`));
    });

    const element = await AdminEngagementPage();
    render(element);

    expect(screen.getByRole('alert')).toBeInTheDocument();
    expect(
      screen.getByText('Failed to load active users data'),
    ).toBeInTheDocument();
  });

  it('renders generic error message for unexpected errors', async () => {
    mockAdminFetch.mockImplementation((path: string) => {
      if (path === '/admin/analytics/engagement/streaks') {
        return Promise.reject(new Error('DB connection failed'));
      }
      if (path === '/admin/analytics/engagement/retention') {
        return Promise.resolve(makeRetentionData());
      }
      if (path === '/admin/analytics/engagement/active-users') {
        return Promise.resolve(makeActiveUsersData());
      }
      return Promise.reject(new Error(`Unexpected: ${path}`));
    });

    const element = await AdminEngagementPage();
    render(element);

    expect(screen.getByRole('alert')).toBeInTheDocument();
    expect(
      screen.getByText(
        'An unexpected error occurred while loading engagement data.',
      ),
    ).toBeInTheDocument();
  });

  // ── Streak section (original tests preserved) ─────────────────────────

  it('renders active streak users stat card', async () => {
    setupMocks();
    const element = await AdminEngagementPage();
    render(element);

    expect(screen.getByText('Active Streak Users')).toBeInTheDocument();
    expect(screen.getByText('180')).toBeInTheDocument();
  });

  it('renders average streak length stat card', async () => {
    setupMocks();
    const element = await AdminEngagementPage();
    render(element);

    expect(
      screen.getByText('Average Streak Length (days)'),
    ).toBeInTheDocument();
    // Math.round(4.7) = 5
    expect(screen.getByText('5')).toBeInTheDocument();
  });

  it('renders the streak bar chart', async () => {
    setupMocks();
    const element = await AdminEngagementPage();
    render(element);

    expect(screen.getByTestId('streak-bar-chart')).toBeInTheDocument();
  });

  it('renders the streak distribution section heading', async () => {
    setupMocks();
    const element = await AdminEngagementPage();
    render(element);

    expect(
      screen.getByRole('heading', { name: 'Streak Length Distribution' }),
    ).toBeInTheDocument();
  });

  it('passes all series buckets to StreakBarChart', async () => {
    setupMocks();
    const element = await AdminEngagementPage();
    render(element);

    const chart = screen.getByTestId('streak-bar-chart');
    expect(chart).toHaveAttribute('data-count', '6');
  });
});
