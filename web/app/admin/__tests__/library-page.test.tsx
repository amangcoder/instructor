/**
 * Tests for the admin library page.
 *
 * The page is a React Server Component — we test by calling the async
 * function directly and inspecting the rendered element tree.
 */
import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import type { LibraryResponse } from '@/types/analytics';
import type { CategoryBreakdownResponse } from '@/types/library-categories';

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

// Mock RangePicker (client component — uses next/navigation hooks)
jest.mock('@/components/admin/RangePicker', () => ({
  __esModule: true,
  default: () => <div data-testid="range-picker">RangePicker</div>,
}));

// Mock CategoryBreakdownTable (client component — keeps server component tests isolated)
jest.mock('@/components/admin/CategoryBreakdownTable', () => ({
  __esModule: true,
  default: ({ rows }: { rows: unknown[] }) => (
    <div data-testid="category-breakdown-table" data-row-count={rows.length}>
      CategoryBreakdownTable
    </div>
  ),
}));

// Mock LibraryPlanManager (client component — avoids duplicate 'Category' text nodes)
jest.mock('@/components/admin/LibraryPlanManager', () => ({
  __esModule: true,
  default: () => <div data-testid="library-plan-manager">LibraryPlanManager</div>,
}));

// ── Fixtures ──────────────────────────────────────────────────────────────────

function makeLibraryData(
  overrides: Partial<LibraryResponse> = {},
): LibraryResponse {
  return {
    series: [
      {
        id: 'plan-1',
        name: 'Morning Mindfulness',
        category: 'meditation',
        isPublished: true,
        totalAdoptions: 250,
        rangeAdoptions: 80,
        activatedCount: 200,
        sessionCount: 180,
        conversionRate: 0.72,
      },
      {
        id: 'plan-2',
        name: 'HIIT Fundamentals',
        category: 'fitness',
        isPublished: true,
        totalAdoptions: 180,
        rangeAdoptions: 60,
        activatedCount: 150,
        sessionCount: 120,
        conversionRate: 0.67,
      },
      {
        id: 'plan-3',
        name: 'Spanish Basics',
        category: 'language',
        isPublished: true,
        totalAdoptions: 310,
        rangeAdoptions: 100,
        activatedCount: 280,
        sessionCount: 260,
        conversionRate: 0.84,
      },
    ],
    totals: {
      publishedCount: 12,
      totalAdoptions: 740,
      overallConversionRate: 0.74,
    },
    ...overrides,
  };
}

function makeCategoryData(
  overrides: Partial<CategoryBreakdownResponse> = {},
): CategoryBreakdownResponse {
  return {
    rows: [
      {
        category: 'yoga',
        publishedPlans: 4,
        totalAdoptions: 120,
        rangeAdoptions: 30,
        totalSessions: 90,
        conversionRate: 0.75,
      },
      {
        category: 'meditation',
        publishedPlans: 6,
        totalAdoptions: 200,
        rangeAdoptions: 55,
        totalSessions: 160,
        conversionRate: 0.8,
      },
    ],
    ...overrides,
  };
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('AdminLibraryPage', () => {
  let AdminLibraryPage: (props?: {
    searchParams?: Promise<{ range?: string }>;
  }) => Promise<React.JSX.Element>;

  beforeAll(async () => {
    const mod = await import('../(dashboard)/library/page');
    AdminLibraryPage = mod.default;
  });

  beforeEach(() => {
    jest.clearAllMocks();
    // Set up default mock values for both fetch calls
    mockAdminFetch
      .mockResolvedValueOnce(makeLibraryData())       // /admin/analytics/library
      .mockResolvedValueOnce(makeCategoryData());      // /admin/analytics/library/categories
  });

  // ── Successful render ─────────────────────────────────────────────────

  it('renders the page heading', async () => {
    const element = await AdminLibraryPage();
    render(element);

    expect(
      screen.getByRole('heading', { name: 'Library' }),
    ).toBeInTheDocument();
  });

  it('renders the RangePicker for the category section', async () => {
    const element = await AdminLibraryPage();
    render(element);

    expect(screen.getByTestId('range-picker')).toBeInTheDocument();
  });

  it('renders total conversions stat card', async () => {
    const element = await AdminLibraryPage();
    render(element);

    expect(screen.getByText('Total Conversions')).toBeInTheDocument();
    expect(screen.getByText('740')).toBeInTheDocument();
  });

  it('renders published library plans stat card', async () => {
    const element = await AdminLibraryPage();
    render(element);

    expect(screen.getByText('Published Library Plans')).toBeInTheDocument();
    expect(screen.getByText('12')).toBeInTheDocument();
  });

  it('renders the plan conversions table (AC-026)', async () => {
    const element = await AdminLibraryPage();
    render(element);

    // Table headers
    expect(screen.getByText('Library Plan Name')).toBeInTheDocument();
    expect(screen.getByText('Category')).toBeInTheDocument();
    expect(screen.getByText('Adoption Count')).toBeInTheDocument();

    // Plan rows
    expect(screen.getByText('Morning Mindfulness')).toBeInTheDocument();
    expect(screen.getByText('HIIT Fundamentals')).toBeInTheDocument();
    expect(screen.getByText('Spanish Basics')).toBeInTheDocument();
  });

  it('renders plan categories', async () => {
    const element = await AdminLibraryPage();
    render(element);

    expect(screen.getByText('meditation')).toBeInTheDocument();
    expect(screen.getByText('fitness')).toBeInTheDocument();
    expect(screen.getByText('language')).toBeInTheDocument();
  });

  it('renders adoption counts for all plans', async () => {
    const element = await AdminLibraryPage();
    render(element);

    expect(screen.getByText('250')).toBeInTheDocument();
    expect(screen.getByText('180')).toBeInTheDocument();
    expect(screen.getByText('310')).toBeInTheDocument();
  });

  it('renders plans sorted by totalAdoptions descending', async () => {
    const element = await AdminLibraryPage();
    render(element);

    const rows = screen.getAllByRole('row');
    // rows[0] = header, rows[1] = first data row (highest count)
    // Spanish Basics (310) should come first
    expect(rows[1]).toHaveTextContent('Spanish Basics');
    // Morning Mindfulness (250) second
    expect(rows[2]).toHaveTextContent('Morning Mindfulness');
    // HIIT Fundamentals (180) third
    expect(rows[3]).toHaveTextContent('HIIT Fundamentals');
  });

  // ── Category breakdown section ─────────────────────────────────────────

  it('renders the Category Breakdown section heading', async () => {
    const element = await AdminLibraryPage();
    render(element);

    expect(
      screen.getByRole('heading', { name: 'Category Breakdown' }),
    ).toBeInTheDocument();
  });

  it('renders the CategoryBreakdownTable with category rows', async () => {
    const element = await AdminLibraryPage();
    render(element);

    const table = screen.getByTestId('category-breakdown-table');
    expect(table).toBeInTheDocument();
    expect(table).toHaveAttribute('data-row-count', '2');
  });

  it('passes an empty rows array to CategoryBreakdownTable when category fetch fails', async () => {
    mockAdminFetch.mockReset();
    mockAdminFetch
      .mockResolvedValueOnce(makeLibraryData())
      .mockRejectedValueOnce(new Error('Network error'));

    const element = await AdminLibraryPage();
    render(element);

    const table = screen.getByTestId('category-breakdown-table');
    expect(table).toHaveAttribute('data-row-count', '0');
  });

  it('shows category error alert when category fetch throws AdminApiError', async () => {
    mockAdminFetch.mockReset();
    const { AdminApiError } = await import('@/lib/admin-api');
    mockAdminFetch
      .mockResolvedValueOnce(makeLibraryData())
      .mockRejectedValueOnce(new AdminApiError('Forbidden — admin role required', 'FORBIDDEN'));

    const element = await AdminLibraryPage();
    render(element);

    expect(screen.getByText('Failed to load category data')).toBeInTheDocument();
    expect(screen.getByText('Forbidden — admin role required')).toBeInTheDocument();
  });

  // ── API calls ──────────────────────────────────────────────────────────

  it('calls adminFetch with the library endpoint', async () => {
    await AdminLibraryPage();

    expect(mockAdminFetch).toHaveBeenCalledWith('/admin/analytics/library');
  });

  it('calls adminFetch with the categories endpoint and default range', async () => {
    await AdminLibraryPage();

    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/library/categories',
      { range: '30d' },
    );
  });

  it('passes range from searchParams to categories endpoint', async () => {
    mockAdminFetch.mockReset();
    mockAdminFetch
      .mockResolvedValueOnce(makeLibraryData())
      .mockResolvedValueOnce(makeCategoryData());

    await AdminLibraryPage({
      searchParams: Promise.resolve({ range: '7d' }),
    });

    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/library/categories',
      { range: '7d' },
    );
  });

  it('defaults to 30d range when no searchParams range is provided', async () => {
    mockAdminFetch.mockReset();
    mockAdminFetch
      .mockResolvedValueOnce(makeLibraryData())
      .mockResolvedValueOnce(makeCategoryData());

    await AdminLibraryPage({
      searchParams: Promise.resolve({}),
    });

    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/library/categories',
      { range: '30d' },
    );
  });

  // ── Empty state ───────────────────────────────────────────────────────

  it('renders empty state when no library plans', async () => {
    mockAdminFetch.mockReset();
    mockAdminFetch
      .mockResolvedValueOnce(
        makeLibraryData({ series: [], totals: { publishedCount: 0, totalAdoptions: 0, overallConversionRate: null } }),
      )
      .mockResolvedValueOnce(makeCategoryData());

    const element = await AdminLibraryPage();
    render(element);

    expect(screen.getByText('No library plans found.')).toBeInTheDocument();
  });

  // ── Error state ───────────────────────────────────────────────────────

  it('renders error message when adminFetch throws AdminApiError', async () => {
    mockAdminFetch.mockReset();
    const { AdminApiError } = await import('@/lib/admin-api');
    mockAdminFetch
      .mockRejectedValueOnce(
        new AdminApiError('Unauthorized — token missing or expired', 'UNAUTHORIZED'),
      )
      .mockResolvedValueOnce(makeCategoryData());

    const element = await AdminLibraryPage();
    render(element);

    expect(screen.getByRole('alert')).toBeInTheDocument();
    expect(screen.getByText('Failed to load library data')).toBeInTheDocument();
    expect(
      screen.getByText('Unauthorized — token missing or expired'),
    ).toBeInTheDocument();
  });

  it('renders generic error for unexpected errors', async () => {
    mockAdminFetch.mockReset();
    mockAdminFetch
      .mockRejectedValueOnce(new Error('Something went wrong'))
      .mockResolvedValueOnce(makeCategoryData());

    const element = await AdminLibraryPage();
    render(element);

    expect(screen.getByRole('alert')).toBeInTheDocument();
    expect(
      screen.getByText('An unexpected error occurred while loading library data.'),
    ).toBeInTheDocument();
  });
});
