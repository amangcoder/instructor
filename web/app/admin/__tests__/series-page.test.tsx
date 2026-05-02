/**
 * Tests for the admin Series page (REQ-015).
 *
 * Verifies:
 *  - Page heading and description are rendered
 *  - Series are fetched from /api/admin/series and grouped by category
 *  - Publish/unpublish toggle calls PATCH /api/admin/series/:id/publish
 *  - Loading and error states are handled correctly
 */

import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import '@testing-library/jest-dom';
import type { AdminSeriesRecord } from '@/types/series';

// ─────────────────────────────────────────────────────────────────────────────
// Mock fetch
// ─────────────────────────────────────────────────────────────────────────────

const mockFetch = jest.fn();
global.fetch = mockFetch;

// ─────────────────────────────────────────────────────────────────────────────
// Mock next/navigation — page calls useRouter() to navigate on row click.
// ─────────────────────────────────────────────────────────────────────────────

const mockRouterPush = jest.fn();
jest.mock('next/navigation', () => ({
  useRouter: () => ({ push: mockRouterPush }),
}));

// ─────────────────────────────────────────────────────────────────────────────
// Fixtures
// ─────────────────────────────────────────────────────────────────────────────

function makeSeries(overrides: Partial<AdminSeriesRecord> = {}): AdminSeriesRecord {
  return {
    id: 'series-1',
    name: 'Mindful Mornings',
    description: 'A 10-day morning routine',
    category: 'meditation',
    categoryId: null,
    tags: '',
    defaultVoice: 'en-US-Standard-A',
    locale: 'enUS',
    isPublished: true,
    sortOrder: 0,
    totalSessions: 10,
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-02T00:00:00Z',
    ...overrides,
  };
}

const FIXTURES: AdminSeriesRecord[] = [
  makeSeries({ id: 'series-1', name: 'Mindful Mornings', category: 'meditation', isPublished: true }),
  makeSeries({ id: 'series-2', name: 'Couch to 5K', category: 'fitness', isPublished: false, totalSessions: 8 }),
  makeSeries({ id: 'series-3', name: 'Deep Sleep', category: 'meditation', isPublished: false }),
];

function okJson(data: unknown, status = 200): Response {
  return { ok: true, status, json: async () => data } as Response;
}

function errorResponse(status: number): Response {
  return { ok: false, status, json: async () => ({ error: `HTTP ${status}` }) } as Response;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

describe('AdminSeriesPage (REQ-015)', () => {
  let AdminSeriesPage: typeof import('../(dashboard)/series/page').default;

  beforeAll(async () => {
    const mod = await import('../(dashboard)/series/page');
    AdminSeriesPage = mod.default;
  });

  beforeEach(() => {
    jest.clearAllMocks();
    mockFetch.mockResolvedValue(okJson(FIXTURES));
  });

  // ── Heading & description ──────────────────────────────────────────────────

  it('renders the "Series" page heading (REQ-015)', async () => {
    render(<AdminSeriesPage />);
    await waitFor(() => {
      expect(screen.getByRole('heading', { level: 1, name: 'Series' })).toBeInTheDocument();
    });
  });

  it('renders the sub-heading description', async () => {
    render(<AdminSeriesPage />);
    await waitFor(() => {
      expect(screen.getByText(/Manage multi-session programs/i)).toBeInTheDocument();
    });
  });

  // ── Data fetching ──────────────────────────────────────────────────────────

  it('fetches from /api/admin/series on mount', async () => {
    render(<AdminSeriesPage />);
    await waitFor(() => {
      expect(mockFetch).toHaveBeenCalledWith('/api/admin/series');
    });
  });

  it('renders series names after successful fetch', async () => {
    render(<AdminSeriesPage />);
    await waitFor(() => {
      expect(screen.getByText('Mindful Mornings')).toBeInTheDocument();
      expect(screen.getByText('Couch to 5K')).toBeInTheDocument();
      expect(screen.getByText('Deep Sleep')).toBeInTheDocument();
    });
  });

  it('groups series by category', async () => {
    render(<AdminSeriesPage />);
    await waitFor(() => {
      expect(screen.getByRole('heading', { level: 2, name: /meditation/i })).toBeInTheDocument();
      expect(screen.getByRole('heading', { level: 2, name: /fitness/i })).toBeInTheDocument();
    });
  });

  it('shows Published badge for published series', async () => {
    render(<AdminSeriesPage />);
    await waitFor(() => {
      const badges = screen.getAllByText('Published');
      expect(badges.length).toBeGreaterThanOrEqual(1);
    });
  });

  it('shows Draft badge for unpublished series', async () => {
    render(<AdminSeriesPage />);
    await waitFor(() => {
      const badges = screen.getAllByText('Draft');
      expect(badges.length).toBeGreaterThanOrEqual(2);
    });
  });

  // ── Publish toggle (REQ-015) ───────────────────────────────────────────────

  it('calls PATCH /api/admin/series/:id/publish when publish button clicked', async () => {
    const user = userEvent.setup();
    // First fetch returns fixtures; second fetch is the PATCH
    mockFetch
      .mockResolvedValueOnce(okJson(FIXTURES))
      .mockResolvedValueOnce(okJson({ ...FIXTURES[2], isPublished: true }));

    render(<AdminSeriesPage />);

    // Wait for data to load, then click Publish on the first draft series
    await waitFor(() => expect(screen.getAllByRole('button', { name: /Publish/i }).length).toBeGreaterThan(0));

    const publishBtn = screen.getAllByRole('button', { name: /Publish Deep Sleep/i })[0];
    await user.click(publishBtn);

    await waitFor(() => {
      expect(mockFetch).toHaveBeenCalledWith(
        `/api/admin/series/series-3/publish`,
        expect.objectContaining({ method: 'PATCH' }),
      );
    });

    const body = JSON.parse((mockFetch.mock.calls[1][1] as RequestInit).body as string);
    expect(body).toEqual({ is_published: true });
  });

  it('calls PATCH with is_published=false when unpublishing', async () => {
    const user = userEvent.setup();
    mockFetch
      .mockResolvedValueOnce(okJson(FIXTURES))
      .mockResolvedValueOnce(okJson({ ...FIXTURES[0], isPublished: false }));

    render(<AdminSeriesPage />);

    await waitFor(() =>
      expect(screen.getByRole('button', { name: /Unpublish Mindful Mornings/i })).toBeInTheDocument(),
    );

    await user.click(screen.getByRole('button', { name: /Unpublish Mindful Mornings/i }));

    await waitFor(() => {
      expect(mockFetch).toHaveBeenCalledWith(
        `/api/admin/series/series-1/publish`,
        expect.objectContaining({ method: 'PATCH' }),
      );
    });

    const body = JSON.parse((mockFetch.mock.calls[1][1] as RequestInit).body as string);
    expect(body).toEqual({ is_published: false });
  });

  // ── Error states ───────────────────────────────────────────────────────────

  it('shows error banner when fetch returns non-ok', async () => {
    mockFetch.mockResolvedValue(errorResponse(500));
    render(<AdminSeriesPage />);
    await waitFor(() => {
      expect(screen.getByRole('alert')).toBeInTheDocument();
    });
  });

  it('shows error banner on network failure', async () => {
    mockFetch.mockRejectedValue(new TypeError('Failed to fetch'));
    render(<AdminSeriesPage />);
    await waitFor(() => {
      expect(screen.getByRole('alert')).toBeInTheDocument();
    });
  });

  // ── Empty state ────────────────────────────────────────────────────────────

  it('shows empty state when no series returned', async () => {
    mockFetch.mockResolvedValue(okJson([]));
    render(<AdminSeriesPage />);
    await waitFor(() => {
      expect(screen.getByText(/No series found/i)).toBeInTheDocument();
    });
  });

  // ── Loading state ──────────────────────────────────────────────────────────

  it('shows loading state while fetching', () => {
    mockFetch.mockImplementation(() => new Promise(() => undefined));
    render(<AdminSeriesPage />);
    expect(screen.getByRole('status', { name: /Loading series/i })).toBeInTheDocument();
  });
});
