/**
 * Tests for PublishToggle component.
 *
 * Tests user interactions (toggle, loading, error states) — not implementation details.
 */
import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import '@testing-library/jest-dom';
import PublishToggle from '../PublishToggle';

// ── Mock fetch ──────────────────────────────────────────────────────────────

const mockFetch = jest.fn();
global.fetch = mockFetch as unknown as typeof fetch;

describe('PublishToggle', () => {
  beforeEach(() => {
    mockFetch.mockReset();
  });

  it('renders as draft when initialValue is false', () => {
    render(<PublishToggle planId="p1" initialValue={false} />);
    expect(screen.getByText('Draft')).toBeInTheDocument();
    expect(screen.getByRole('switch')).toHaveAttribute('aria-checked', 'false');
  });

  it('renders as published when initialValue is true', () => {
    render(<PublishToggle planId="p1" initialValue={true} />);
    expect(screen.getByText('Published')).toBeInTheDocument();
    expect(screen.getByRole('switch')).toHaveAttribute('aria-checked', 'true');
  });

  it('toggles to published on click and calls PATCH', async () => {
    const user = userEvent.setup();
    const onToggled = jest.fn();

    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve({ success: true }),
    });

    render(<PublishToggle planId="p1" initialValue={false} onToggled={onToggled} />);

    await user.click(screen.getByRole('switch'));

    await waitFor(() => {
      expect(mockFetch).toHaveBeenCalledWith('/api/admin/plans/p1', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isPublished: true }),
      });
    });

    await waitFor(() => {
      expect(screen.getByText('Published')).toBeInTheDocument();
    });

    expect(onToggled).toHaveBeenCalledWith(true);
  });

  it('shows error message on API failure', async () => {
    const user = userEvent.setup();

    mockFetch.mockResolvedValueOnce({
      ok: false,
      json: () => Promise.resolve({ error: 'Forbidden' }),
    });

    render(<PublishToggle planId="p1" initialValue={false} />);

    await user.click(screen.getByRole('switch'));

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent('Forbidden');
    });

    // State should not change
    expect(screen.getByRole('switch')).toHaveAttribute('aria-checked', 'false');
  });

  it('shows network error on fetch failure', async () => {
    const user = userEvent.setup();

    mockFetch.mockRejectedValueOnce(new Error('Network failure'));

    render(<PublishToggle planId="p1" initialValue={true} />);

    await user.click(screen.getByRole('switch'));

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent('Network error');
    });
  });

  it('has accessible aria-label describing current state', () => {
    render(<PublishToggle planId="p1" initialValue={true} />);
    expect(screen.getByRole('switch')).toHaveAttribute(
      'aria-label',
      'Published — click to unpublish',
    );
  });
});
