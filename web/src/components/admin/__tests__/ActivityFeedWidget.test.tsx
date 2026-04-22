/**
 * Tests for the ActivityFeedWidget client component.
 *
 * Uses jest.useFakeTimers() to test auto-refresh behaviour without
 * waiting real time.
 */
import React from 'react';
import { render, screen, act, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import ActivityFeedWidget from '../ActivityFeedWidget';
import type { ActivityFeedResponse } from '@/types/activity-feed';

// ── Global fetch mock ─────────────────────────────────────────────────────────

const mockFetch = jest.fn();
global.fetch = mockFetch;

// ── Helpers ───────────────────────────────────────────────────────────────────

function makeEvent(
  type: 'signup' | 'tts_failure' | 'deletion_request' = 'signup',
  i = 0,
) {
  return {
    type,
    description: `Event ${i}: ${type}`,
    occurredAt: new Date(Date.now() - i * 60_000).toISOString(),
  };
}

function makeActivityData(count = 3): ActivityFeedResponse {
  return {
    events: Array.from({ length: count }, (_, i) =>
      makeEvent(i % 3 === 0 ? 'signup' : i % 3 === 1 ? 'tts_failure' : 'deletion_request', i),
    ),
  };
}

function makeFetchResponse(data: unknown, ok = true, status = 200) {
  return Promise.resolve({
    ok,
    status,
    json: () => Promise.resolve(data),
  } as Response);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('ActivityFeedWidget', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  // ── Initial render with data ──────────────────────────────────────────

  it('renders initial activity events from initialData', () => {
    const initialData = makeActivityData(3);
    render(<ActivityFeedWidget initialData={initialData} />);

    expect(screen.getByText('Event 0: signup')).toBeInTheDocument();
    expect(screen.getByText('Event 1: tts_failure')).toBeInTheDocument();
    expect(screen.getByText('Event 2: deletion_request')).toBeInTheDocument();
  });

  it('renders the section heading "Recent Activity"', () => {
    render(<ActivityFeedWidget initialData={makeActivityData(1)} />);
    expect(screen.getByRole('region', { name: 'Recent Activity' })).toBeInTheDocument();
  });

  it('shows EmptyState when initialData is null', () => {
    render(<ActivityFeedWidget initialData={null} />);
    expect(
      screen.getByText('No recent platform activity to display.'),
    ).toBeInTheDocument();
  });

  it('shows EmptyState when initialData has empty events array', () => {
    render(<ActivityFeedWidget initialData={{ events: [] }} />);
    expect(
      screen.getByText('No recent platform activity to display.'),
    ).toBeInTheDocument();
  });

  // ── Auto-refresh ──────────────────────────────────────────────────────

  it('auto-refreshes after 2 minutes (120 000 ms)', async () => {
    const initialData = makeActivityData(1);
    const refreshedData: ActivityFeedResponse = {
      events: [
        {
          type: 'signup',
          description: 'Refreshed event',
          occurredAt: new Date().toISOString(),
        },
      ],
    };

    mockFetch.mockReturnValue(makeFetchResponse(refreshedData));

    render(<ActivityFeedWidget initialData={initialData} />);

    // Initial state: no fetch yet
    expect(mockFetch).not.toHaveBeenCalled();

    // Advance timer by 2 minutes
    await act(async () => {
      jest.advanceTimersByTime(2 * 60 * 1000);
    });

    await waitFor(() => {
      expect(mockFetch).toHaveBeenCalledWith('/api/admin/activity-feed', {
        cache: 'no-store',
      });
    });

    await waitFor(() => {
      expect(screen.getByText('Refreshed event')).toBeInTheDocument();
    });
  });

  it('does not auto-refresh before 2 minutes have elapsed', async () => {
    render(<ActivityFeedWidget initialData={makeActivityData(1)} />);

    await act(async () => {
      jest.advanceTimersByTime(1 * 60 * 1000); // 1 minute
    });

    expect(mockFetch).not.toHaveBeenCalled();
  });

  it('clears the interval on unmount', async () => {
    const clearIntervalSpy = jest.spyOn(global, 'clearInterval');
    const { unmount } = render(<ActivityFeedWidget initialData={makeActivityData(1)} />);

    unmount();

    expect(clearIntervalSpy).toHaveBeenCalled();
    clearIntervalSpy.mockRestore();
  });

  // ── Refresh errors ────────────────────────────────────────────────────

  it('shows a refresh error banner when the fetch fails', async () => {
    mockFetch.mockRejectedValue(new Error('Network error'));

    render(<ActivityFeedWidget initialData={makeActivityData(1)} />);

    await act(async () => {
      jest.advanceTimersByTime(2 * 60 * 1000);
    });

    await waitFor(() => {
      expect(screen.getByRole('alert')).toBeInTheDocument();
    });
  });

  it('shows refresh error when fetch returns non-OK status', async () => {
    mockFetch.mockReturnValue(makeFetchResponse(null, false, 503));

    render(<ActivityFeedWidget initialData={makeActivityData(1)} />);

    await act(async () => {
      jest.advanceTimersByTime(2 * 60 * 1000);
    });

    await waitFor(() => {
      expect(screen.getByRole('alert')).toBeInTheDocument();
    });

    // Initial data should still be visible despite the error
    expect(screen.getByText('Event 0: signup')).toBeInTheDocument();
  });

  it('clears refresh error on subsequent successful refresh', async () => {
    const refreshedData = makeActivityData(1);
    mockFetch
      .mockRejectedValueOnce(new Error('Network error'))
      .mockReturnValueOnce(makeFetchResponse(refreshedData));

    render(<ActivityFeedWidget initialData={makeActivityData(2)} />);

    // First refresh fails
    await act(async () => {
      jest.advanceTimersByTime(2 * 60 * 1000);
    });
    await waitFor(() => {
      expect(screen.getByRole('alert')).toBeInTheDocument();
    });

    // Second refresh succeeds
    await act(async () => {
      jest.advanceTimersByTime(2 * 60 * 1000);
    });
    await waitFor(() => {
      expect(screen.queryByRole('alert')).not.toBeInTheDocument();
    });
  });

  // ── Accessibility ─────────────────────────────────────────────────────

  it('renders an accessible section with aria-label', () => {
    render(<ActivityFeedWidget initialData={makeActivityData(1)} />);
    expect(
      screen.getByRole('region', { name: 'Recent Activity' }),
    ).toBeInTheDocument();
  });

  it('renders event timestamps with dateTime attribute', () => {
    const now = new Date().toISOString();
    render(
      <ActivityFeedWidget
        initialData={{
          events: [{ type: 'signup', description: 'User signed up', occurredAt: now }],
        }}
      />,
    );

    const timeEl = screen.getByText('User signed up').closest('li')?.querySelector('time');
    expect(timeEl).toHaveAttribute('dateTime', now);
  });

  // ── Event type rendering ──────────────────────────────────────────────

  it('renders all three event types', () => {
    render(
      <ActivityFeedWidget
        initialData={{
          events: [
            { type: 'signup', description: 'New signup', occurredAt: new Date().toISOString() },
            {
              type: 'tts_failure',
              description: 'TTS failed',
              occurredAt: new Date().toISOString(),
            },
            {
              type: 'deletion_request',
              description: 'Deletion requested',
              occurredAt: new Date().toISOString(),
            },
          ],
        }}
      />,
    );

    expect(screen.getByText('New signup')).toBeInTheDocument();
    expect(screen.getByText('TTS failed')).toBeInTheDocument();
    expect(screen.getByText('Deletion requested')).toBeInTheDocument();
  });
});
