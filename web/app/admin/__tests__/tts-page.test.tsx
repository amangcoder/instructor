/**
 * Tests for the admin TTS analytics page.
 *
 * The page is a React Server Component — we test by calling the async
 * function directly and inspecting the rendered element tree.
 */
import React from 'react';
import { render, screen, within } from '@testing-library/react';
import '@testing-library/jest-dom';
import type {
  TtsVolumeResponse,
  TtsErrorsResponse,
} from '@/types/analytics';

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

// Mock RangePicker (client component using useSearchParams)
jest.mock('@/components/admin/RangePicker', () => ({
  __esModule: true,
  default: () => <div data-testid="range-picker">RangePicker</div>,
}));

// Mock TimeSeriesChart (client component using Recharts)
jest.mock('@/components/admin/TimeSeriesChart', () => ({
  __esModule: true,
  default: ({ yKey }: { yKey?: string }) => (
    <div data-testid={`time-series-chart-${yKey ?? 'value'}`}>TimeSeriesChart</div>
  ),
}));

// Mock StreakBarChart (client component using Recharts)
jest.mock('@/components/admin/StreakBarChart', () => ({
  __esModule: true,
  default: () => <div data-testid="streak-bar-chart">StreakBarChart</div>,
}));

// Mock TtsHealthBanner (client component using fetch + setInterval)
jest.mock('@/components/admin/TtsHealthBanner', () => ({
  __esModule: true,
  default: () => <div data-testid="tts-health-banner">TtsHealthBanner</div>,
}));

// Mock DataTableToggle (client component)
jest.mock('@/components/admin/DataTableToggle', () => ({
  __esModule: true,
  default: ({ data }: { data: unknown[] }) => (
    <div data-testid="data-table-toggle" data-row-count={data.length}>
      DataTableToggle
    </div>
  ),
}));

// ── Fixtures ──────────────────────────────────────────────────────────────────

function makeVolumeData(
  overrides: Partial<TtsVolumeResponse> = {},
): TtsVolumeResponse {
  return {
    series: [{ date: '2026-04-01', value: 120, byProvider: {}, byVoice: [] }],
    totals: {
      totalCompleted: 3600,
      byProvider: { kokoro: 3000, elevenlabs: 600 },
      topVoices: [
        { voiceId: 'af_heart', count: 1500 },
        { voiceId: 'af_sky', count: 1200 },
      ],
    },
    ...overrides,
  };
}

function makeErrorsData(
  overrides: Partial<TtsErrorsResponse> = {},
): TtsErrorsResponse {
  return {
    series: [{ date: '2026-04-01', value: 5, errorRate: 0.04 }],
    totals: {
      totalErrors: 45,
      overallErrorRate: 0.0125,
      topErrors: [
        {
          message: 'Connection timeout after 30s',
          count: 30,
          lastSeen: '2026-04-01T12:00:00Z',
        },
        {
          message: 'Rate limit exceeded',
          count: 15,
          lastSeen: '2026-04-01T10:00:00Z',
        },
      ],
    },
    ...overrides,
  };
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('AdminTtsPage', () => {
  let AdminTtsPage: (props: {
    searchParams: Promise<{ range?: string }>;
  }) => Promise<React.JSX.Element>;

  beforeAll(async () => {
    const mod = await import('../(dashboard)/tts/page');
    AdminTtsPage = mod.default;
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  // ── Health Banner & DataTableToggle ───────────────────────────────────

  it('renders TtsHealthBanner above the charts', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeVolumeData())
      .mockResolvedValueOnce(makeErrorsData());

    const element = await AdminTtsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByTestId('tts-health-banner')).toBeInTheDocument();
  });

  it('renders DataTableToggle beneath volume chart', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeVolumeData())
      .mockResolvedValueOnce(makeErrorsData());

    const element = await AdminTtsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    // Two DataTableToggles should be present: one for volume, one for errors
    const toggles = screen.getAllByTestId('data-table-toggle');
    expect(toggles.length).toBeGreaterThanOrEqual(2);
  });

  it('DataTableToggle receives volume series rows', async () => {
    const volumeData = makeVolumeData();
    mockAdminFetch
      .mockResolvedValueOnce(volumeData)
      .mockResolvedValueOnce(makeErrorsData());

    const element = await AdminTtsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    const toggles = screen.getAllByTestId('data-table-toggle');
    // First toggle should have row count matching volume series length
    expect(toggles[0]).toHaveAttribute(
      'data-row-count',
      String(volumeData.series.length),
    );
  });

  // ── Successful render ─────────────────────────────────────────────────

  it('renders the page heading', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeVolumeData())
      .mockResolvedValueOnce(makeErrorsData());

    const element = await AdminTtsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(
      screen.getByRole('heading', { name: 'TTS Analytics' }),
    ).toBeInTheDocument();
  });

  it('renders the RangePicker', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeVolumeData())
      .mockResolvedValueOnce(makeErrorsData());

    const element = await AdminTtsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByTestId('range-picker')).toBeInTheDocument();
  });

  it('renders TTS Volume section heading', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeVolumeData())
      .mockResolvedValueOnce(makeErrorsData());

    const element = await AdminTtsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(
      screen.getByRole('heading', { name: 'TTS Volume' }),
    ).toBeInTheDocument();
  });

  it('renders TTS Errors section heading', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeVolumeData())
      .mockResolvedValueOnce(makeErrorsData());

    const element = await AdminTtsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(
      screen.getByRole('heading', { name: 'TTS Errors' }),
    ).toBeInTheDocument();
  });

  it('renders provider/voice breakdown table with provider rows', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeVolumeData())
      .mockResolvedValueOnce(makeErrorsData());

    const element = await AdminTtsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    // Provider rows
    expect(screen.getByText('kokoro')).toBeInTheDocument();
    expect(screen.getByText('elevenlabs')).toBeInTheDocument();
    // Voice rows
    expect(screen.getByText('af_heart')).toBeInTheDocument();
    expect(screen.getByText('af_sky')).toBeInTheDocument();
  });

  it('renders error rate stat card', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeVolumeData())
      .mockResolvedValueOnce(makeErrorsData());

    const element = await AdminTtsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByText('Error Rate')).toBeInTheDocument();
  });

  it('renders top error messages table (AC-025)', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeVolumeData())
      .mockResolvedValueOnce(makeErrorsData());

    const element = await AdminTtsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(screen.getByText('Top Error Messages')).toBeInTheDocument();
    expect(
      screen.getByText('Connection timeout after 30s'),
    ).toBeInTheDocument();
    expect(screen.getByText('Rate limit exceeded')).toBeInTheDocument();
  });

  // ── Range parameter ───────────────────────────────────────────────────

  it('passes range to both adminFetch calls', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeVolumeData())
      .mockResolvedValueOnce(makeErrorsData());

    await AdminTtsPage({
      searchParams: Promise.resolve({ range: '7d' }),
    });

    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/tts/volume',
      { range: '7d' },
    );
    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/tts/errors',
      { range: '7d' },
    );
  });

  it('defaults to 30d when no range param', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeVolumeData())
      .mockResolvedValueOnce(makeErrorsData());

    await AdminTtsPage({
      searchParams: Promise.resolve({}),
    });

    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/tts/volume',
      { range: '30d' },
    );
    expect(mockAdminFetch).toHaveBeenCalledWith(
      '/admin/analytics/tts/errors',
      { range: '30d' },
    );
  });

  // ── Partial failure (Promise.allSettled) ──────────────────────────────

  it('renders volume error but still shows errors section when only volume fails', async () => {
    mockAdminFetch
      .mockRejectedValueOnce(new Error('Network error'))
      .mockResolvedValueOnce(makeErrorsData());

    const element = await AdminTtsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    // Volume section shows error
    expect(
      screen.getByText('Failed to load TTS volume data'),
    ).toBeInTheDocument();
    // Errors section still renders
    expect(screen.getByText('Top Error Messages')).toBeInTheDocument();
  });

  it('renders errors error but still shows volume section when only errors fail', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeVolumeData())
      .mockRejectedValueOnce(new Error('Network error'));

    const element = await AdminTtsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    // Errors section shows error
    expect(
      screen.getByText('Failed to load TTS error data'),
    ).toBeInTheDocument();
    // Volume section still renders
    expect(screen.getByText('kokoro')).toBeInTheDocument();
  });

  // ── Empty states ──────────────────────────────────────────────────────

  it('shows empty state when no error messages', async () => {
    mockAdminFetch
      .mockResolvedValueOnce(makeVolumeData())
      .mockResolvedValueOnce(
        makeErrorsData({
          totals: {
            totalErrors: 0,
            overallErrorRate: 0,
            topErrors: [],
          },
        }),
      );

    const element = await AdminTtsPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(
      screen.getByText('No errors recorded for this period.'),
    ).toBeInTheDocument();
  });
});
