/**
 * Tests for VoiceGrid component.
 *
 * Tests user interactions (regenerate button, status pills, toasts) and accessibility.
 * REQ-016: Voice grid with status pills
 * AC-019: Regenerate button calls POST endpoint
 */
import React from 'react';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import '@testing-library/jest-dom';

// router.refresh() is invoked from VoiceGrid after mutations — stub it so the
// component renders inside jsdom without an App Router runtime.
jest.mock('next/navigation', () => ({
  useRouter: () => ({ refresh: jest.fn() }),
}));

import VoiceGrid from '../VoiceGrid';
import type { PlanVoice } from '@/types/plan-detail';

// ── Mock fetch ──────────────────────────────────────────────────────────────

const mockFetch = jest.fn();
global.fetch = mockFetch as unknown as typeof fetch;

// ── Test data ───────────────────────────────────────────────────────────────

const MOCK_VOICES: PlanVoice[] = [
  {
    id: 'pv-001',
    planId: 'p1',
    voiceId: 'v1',
    locale: 'en-US',
    status: 'ready',
    audioUrl: 'https://example.com/audio.mp3',
    durationMs: 45000,
    errorMsg: null,
    generatedAt: '2025-03-01T00:00:00Z',
    voice: { displayName: 'Neural Voice A', slug: 'neural-a' },
  },
  {
    id: 'pv-002',
    planId: 'p1',
    voiceId: 'v2',
    locale: 'en-US',
    status: 'failed',
    audioUrl: null,
    durationMs: null,
    errorMsg: 'TTS provider timeout',
    generatedAt: null,
    voice: { displayName: 'Neural Voice B', slug: 'neural-b' },
  },
  {
    id: 'pv-003',
    planId: 'p1',
    voiceId: 'v3',
    locale: 'en-US',
    status: 'processing',
    audioUrl: null,
    durationMs: null,
    errorMsg: null,
    generatedAt: null,
    voice: { displayName: 'Neural Voice C', slug: 'neural-c' },
  },
];

describe('VoiceGrid', () => {
  beforeEach(() => {
    mockFetch.mockReset();
  });

  it('renders empty state when no voices', () => {
    render(<VoiceGrid planId="p1" voices={[]} />);

    expect(screen.getByText('No voices configured for this plan.')).toBeInTheDocument();
  });

  it('renders voice table with all voices', () => {
    render(<VoiceGrid planId="p1" voices={MOCK_VOICES} />);

    expect(screen.getByText('Neural Voice A')).toBeInTheDocument();
    expect(screen.getByText('Neural Voice B')).toBeInTheDocument();
    expect(screen.getByText('Neural Voice C')).toBeInTheDocument();
  });

  it('displays correct status pills (REQ-016)', () => {
    render(<VoiceGrid planId="p1" voices={MOCK_VOICES} />);

    expect(screen.getByText('Ready')).toBeInTheDocument();
    expect(screen.getByText('Failed')).toBeInTheDocument();
    expect(screen.getByText('Processing')).toBeInTheDocument();
  });

  it('shows error message for failed voices', () => {
    render(<VoiceGrid planId="p1" voices={MOCK_VOICES} />);

    expect(screen.getByText('TTS provider timeout')).toBeInTheDocument();
  });

  it('shows duration for ready voices', () => {
    render(<VoiceGrid planId="p1" voices={MOCK_VOICES} />);

    expect(screen.getByText('45.0s')).toBeInTheDocument();
  });

  it('calls regenerate endpoint and updates status optimistically', async () => {
    const user = userEvent.setup();
    const onRegenerated = jest.fn();

    mockFetch.mockResolvedValueOnce({
      ok: true,
      status: 202,
      json: () => Promise.resolve({ jobId: 'job-123' }),
    });

    render(<VoiceGrid planId="p1" voices={MOCK_VOICES} onRegenerated={onRegenerated} />);

    // Click regenerate on the failed voice (Neural Voice B)
    const regenerateButtons = screen.getAllByRole('button', { name: /Regenerate voice/ });
    // Find the button for Neural Voice B
    const voiceBButton = regenerateButtons.find((btn) =>
      btn.getAttribute('aria-label')?.includes('Neural Voice B'),
    );
    expect(voiceBButton).toBeDefined();

    await user.click(voiceBButton!);

    await waitFor(() => {
      expect(mockFetch).toHaveBeenCalledWith(
        '/api/admin/plans/p1/voices/v2/regenerate',
        { method: 'POST' },
      );
    });

    // Status should change to Pending (optimistic update)
    await waitFor(() => {
      const pendingPills = screen.getAllByText('Pending');
      expect(pendingPills.length).toBeGreaterThanOrEqual(1);
    });

    expect(onRegenerated).toHaveBeenCalled();
  });

  it('shows error toast when regeneration fails', async () => {
    const user = userEvent.setup();

    mockFetch.mockResolvedValueOnce({
      ok: false,
      json: () => Promise.resolve({ error: 'Voice not found' }),
    });

    render(<VoiceGrid planId="p1" voices={MOCK_VOICES} />);

    const regenerateButtons = screen.getAllByRole('button', { name: /Regenerate voice/ });
    await user.click(regenerateButtons[0]);

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent('Voice not found');
    });
  });

  it('disables regenerate for processing voices', () => {
    render(<VoiceGrid planId="p1" voices={MOCK_VOICES} />);

    const voiceCButton = screen.getAllByRole('button', { name: /Regenerate voice/ }).find(
      (btn) => btn.getAttribute('aria-label')?.includes('Neural Voice C'),
    );
    expect(voiceCButton).toBeDisabled();
  });

  it('has accessible table label', () => {
    render(<VoiceGrid planId="p1" voices={MOCK_VOICES} />);

    expect(screen.getByRole('table', { name: 'Plan voices status grid' })).toBeInTheDocument();
  });
});
