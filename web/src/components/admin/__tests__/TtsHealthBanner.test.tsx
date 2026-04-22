/**
 * Tests for the TtsHealthBanner component (REQ-007, AC-007).
 *
 * The component is a 'use client' component that polls
 * /api/admin/tts-health-proxy every 60 seconds. We mock global.fetch and
 * use fake timers to control polling behaviour.
 */
import React from 'react';
import { render, screen, act, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import TtsHealthBanner from '../TtsHealthBanner';
import type { TtsHealthResponse } from '@/types/tts-health';

// ── Helpers ───────────────────────────────────────────────────────────────────

function makeHealthResponse(
  overrides: Partial<TtsHealthResponse> = {},
): TtsHealthResponse {
  return {
    providers: [
      {
        provider: 'kokoro',
        status: 'healthy',
        errorRateLast60m: 0.02,
        lastSuccessAt: '2026-04-21T12:00:00Z',
      },
      {
        provider: 'elevenlabs',
        status: 'degraded',
        errorRateLast60m: 0.12,
        lastSuccessAt: '2026-04-21T11:55:00Z',
      },
    ],
    ...overrides,
  };
}

function mockFetchSuccess(data: TtsHealthResponse) {
  global.fetch = jest.fn().mockResolvedValue({
    ok: true,
    json: async () => data,
  } as Response);
}

function mockFetchFailure(status = 500) {
  global.fetch = jest.fn().mockResolvedValue({
    ok: false,
    status,
    json: async () => ({ error: 'Server error' }),
  } as unknown as Response);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('TtsHealthBanner', () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.runOnlyPendingTimers();
    jest.useRealTimers();
    jest.restoreAllMocks();
  });

  // ── Initial render ──────────────────────────────────────────────────────────

  it('renders the section with accessible label', async () => {
    mockFetchSuccess(makeHealthResponse());
    render(<TtsHealthBanner />);

    expect(
      screen.getByRole('region', { name: /TTS Provider Health Status/i }),
    ).toBeInTheDocument();
  });

  it('renders the "Provider Health" heading', async () => {
    mockFetchSuccess(makeHealthResponse());
    render(<TtsHealthBanner />);

    expect(screen.getByText('Provider Health')).toBeInTheDocument();
  });

  it('shows loading indicator while fetching', () => {
    // Keep the fetch pending
    global.fetch = jest.fn().mockReturnValue(new Promise(() => {}));
    render(<TtsHealthBanner />);

    expect(screen.getByText('Loading…')).toBeInTheDocument();
  });

  // ── Successful data ─────────────────────────────────────────────────────────

  it('renders Kokoro and ElevenLabs provider entries (AC-007)', async () => {
    mockFetchSuccess(makeHealthResponse());
    render(<TtsHealthBanner />);

    await waitFor(() => {
      expect(screen.getByText('kokoro')).toBeInTheDocument();
      expect(screen.getByText('elevenlabs')).toBeInTheDocument();
    });
  });

  it('renders status labels for each provider', async () => {
    mockFetchSuccess(makeHealthResponse());
    render(<TtsHealthBanner />);

    await waitFor(() => {
      expect(screen.getByText('Healthy')).toBeInTheDocument();
      expect(screen.getByText('Degraded')).toBeInTheDocument();
    });
  });

  it('renders error rate percentages', async () => {
    mockFetchSuccess(makeHealthResponse());
    render(<TtsHealthBanner />);

    await waitFor(() => {
      // kokoro: 2.0%, elevenlabs: 12.0%
      expect(screen.getByText('2.0%')).toBeInTheDocument();
      expect(screen.getByText('12.0%')).toBeInTheDocument();
    });
  });

  it('renders last success timestamp for each provider', async () => {
    mockFetchSuccess(makeHealthResponse());
    render(<TtsHealthBanner />);

    // After data loads, timestamps should appear (not the no-success fallback)
    await waitFor(() => {
      const noSuccessMessages = screen.queryAllByText(/No success in last 60 min/i);
      expect(noSuccessMessages).toHaveLength(0);
    });
  });

  // ── Status dot colours (AC-007) ─────────────────────────────────────────────

  it('green dot for healthy provider (error rate < 5%)', async () => {
    mockFetchSuccess(
      makeHealthResponse({
        providers: [
          {
            provider: 'kokoro',
            status: 'healthy',
            errorRateLast60m: 0.02,
            lastSuccessAt: '2026-04-21T12:00:00Z',
          },
        ],
      }),
    );
    const { container } = render(<TtsHealthBanner />);

    await waitFor(() => {
      expect(screen.getByText('kokoro')).toBeInTheDocument();
    });

    const greenDot = container.querySelector('.bg-green-500');
    expect(greenDot).toBeInTheDocument();
  });

  it('amber dot for degraded provider (error rate 5–20%)', async () => {
    mockFetchSuccess(
      makeHealthResponse({
        providers: [
          {
            provider: 'elevenlabs',
            status: 'degraded',
            errorRateLast60m: 0.12,
            lastSuccessAt: '2026-04-21T11:55:00Z',
          },
        ],
      }),
    );
    const { container } = render(<TtsHealthBanner />);

    await waitFor(() => {
      expect(screen.getByText('elevenlabs')).toBeInTheDocument();
    });

    const amberDot = container.querySelector('.bg-amber-400');
    expect(amberDot).toBeInTheDocument();
  });

  it('red dot for unknown provider (error rate > 20%)', async () => {
    mockFetchSuccess(
      makeHealthResponse({
        providers: [
          {
            provider: 'kokoro',
            status: 'unknown',
            errorRateLast60m: 0.35,
            lastSuccessAt: null,
          },
        ],
      }),
    );
    const { container } = render(<TtsHealthBanner />);

    await waitFor(() => {
      expect(screen.getByText('kokoro')).toBeInTheDocument();
    });

    const redDot = container.querySelector('.bg-red-500');
    expect(redDot).toBeInTheDocument();
  });

  it('shows "No success in last 60 min" when lastSuccessAt is null', async () => {
    mockFetchSuccess(
      makeHealthResponse({
        providers: [
          {
            provider: 'kokoro',
            status: 'unknown',
            errorRateLast60m: 0.5,
            lastSuccessAt: null,
          },
        ],
      }),
    );
    render(<TtsHealthBanner />);

    await waitFor(() => {
      expect(screen.getByText(/No success in last 60 min/i)).toBeInTheDocument();
    });
  });

  // ── Unknown / no-data state (AC-007) ────────────────────────────────────────

  it('shows Unknown status with grey dot when providers array is empty', async () => {
    mockFetchSuccess({ providers: [] });
    const { container } = render(<TtsHealthBanner />);

    await waitFor(() => {
      expect(
        screen.getByText(/Unknown — no provider data available/i),
      ).toBeInTheDocument();
    });

    const greyDot = container.querySelector('.bg-gray-400');
    expect(greyDot).toBeInTheDocument();
  });

  // ── Error state ─────────────────────────────────────────────────────────────

  it('shows error message when fetch fails', async () => {
    mockFetchFailure(500);
    render(<TtsHealthBanner />);

    await waitFor(() => {
      expect(
        screen.getByText(/Failed to load provider health/i),
      ).toBeInTheDocument();
    });
  });

  it('error message has role="alert"', async () => {
    mockFetchFailure(500);
    render(<TtsHealthBanner />);

    await waitFor(() => {
      expect(screen.getByRole('alert')).toBeInTheDocument();
    });
  });

  // ── Auto-refresh every 60 seconds (REQ-007) ──────────────────────────────────

  it('polls the proxy endpoint on mount', async () => {
    mockFetchSuccess(makeHealthResponse());
    render(<TtsHealthBanner />);

    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalledWith('/api/admin/tts-health-proxy', {
        cache: 'no-store',
      });
    });
  });

  it('auto-refreshes every 60 seconds without a full page reload', async () => {
    mockFetchSuccess(makeHealthResponse());
    render(<TtsHealthBanner />);

    // Wait for initial fetch
    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalledTimes(1);
    });

    // Advance timer by 60s → second poll
    await act(async () => {
      jest.advanceTimersByTime(60_000);
    });

    expect(global.fetch).toHaveBeenCalledTimes(2);

    // Advance timer by another 60s → third poll
    await act(async () => {
      jest.advanceTimersByTime(60_000);
    });

    expect(global.fetch).toHaveBeenCalledTimes(3);
  });

  it('clears the interval when unmounted', async () => {
    const clearIntervalSpy = jest.spyOn(global, 'clearInterval');
    mockFetchSuccess(makeHealthResponse());

    const { unmount } = render(<TtsHealthBanner />);

    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalledTimes(1);
    });

    unmount();

    expect(clearIntervalSpy).toHaveBeenCalled();
  });

  // ── Accessibility ───────────────────────────────────────────────────────────

  it('section has aria-label for screen readers', () => {
    mockFetchSuccess(makeHealthResponse());
    render(<TtsHealthBanner />);

    const section = screen.getByRole('region', {
      name: /TTS Provider Health Status/i,
    });
    expect(section).toBeInTheDocument();
  });

  it('providers are listed in a <ul> with role="list"', async () => {
    mockFetchSuccess(makeHealthResponse());
    render(<TtsHealthBanner />);

    await waitFor(() => {
      expect(screen.getByRole('list', { name: /TTS providers/i })).toBeInTheDocument();
    });
  });

  it('status dots are aria-hidden (communicated via text labels)', async () => {
    mockFetchSuccess(makeHealthResponse());
    const { container } = render(<TtsHealthBanner />);

    await waitFor(() => {
      expect(screen.getByText('kokoro')).toBeInTheDocument();
    });

    // All coloured dots must have aria-hidden="true"
    const dots = container.querySelectorAll(
      '[aria-hidden="true"].rounded-full',
    );
    expect(dots.length).toBeGreaterThan(0);
    dots.forEach((dot) => {
      expect(dot).toHaveAttribute('aria-hidden', 'true');
    });
  });
});
