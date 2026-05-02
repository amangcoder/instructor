/**
 * Tests for VisibilitySelector component.
 *
 * Tests user interactions (select, loading, error states) and accessibility.
 */
import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import '@testing-library/jest-dom';
import VisibilitySelector from '../VisibilitySelector';

// ── Mock fetch ──────────────────────────────────────────────────────────────

const mockFetch = jest.fn();
global.fetch = mockFetch as unknown as typeof fetch;

describe('VisibilitySelector', () => {
  beforeEach(() => {
    mockFetch.mockReset();
  });

  it('renders with initial value selected', () => {
    render(<VisibilitySelector planId="p1" initialValue="public" />);

    const select = screen.getByRole('combobox');
    expect(select).toHaveValue('public');
  });

  it('renders all three visibility options', () => {
    render(<VisibilitySelector planId="p1" initialValue="private" />);

    expect(screen.getByRole('option', { name: 'Private' })).toBeInTheDocument();
    expect(screen.getByRole('option', { name: 'Pending Review' })).toBeInTheDocument();
    expect(screen.getByRole('option', { name: 'Public' })).toBeInTheDocument();
  });

  it('calls PATCH on change and updates value', async () => {
    const user = userEvent.setup();
    const onChanged = jest.fn();

    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve({ success: true }),
    });

    render(
      <VisibilitySelector planId="p1" initialValue="private" onChanged={onChanged} />,
    );

    await user.selectOptions(screen.getByRole('combobox'), 'public');

    await waitFor(() => {
      expect(mockFetch).toHaveBeenCalledWith('/api/admin/plans/p1', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ visibility: 'public' }),
      });
    });

    await waitFor(() => {
      expect(onChanged).toHaveBeenCalledWith('public');
    });
  });

  it('reverts on API failure', async () => {
    const user = userEvent.setup();

    mockFetch.mockResolvedValueOnce({
      ok: false,
      json: () => Promise.resolve({ error: 'Invalid transition' }),
    });

    render(<VisibilitySelector planId="p1" initialValue="private" />);

    await user.selectOptions(screen.getByRole('combobox'), 'public');

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent('Invalid transition');
    });

    // Value should revert to initial
    await waitFor(() => {
      expect(screen.getByRole('combobox')).toHaveValue('private');
    });
  });

  it('reverts on network error', async () => {
    const user = userEvent.setup();

    mockFetch.mockRejectedValueOnce(new Error('Network failure'));

    render(<VisibilitySelector planId="p1" initialValue="public" />);

    await user.selectOptions(screen.getByRole('combobox'), 'private');

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent('Network error');
    });

    await waitFor(() => {
      expect(screen.getByRole('combobox')).toHaveValue('public');
    });
  });

  it('has a visible label', () => {
    render(<VisibilitySelector planId="p1" initialValue="public" />);

    expect(screen.getByLabelText('Visibility')).toBeInTheDocument();
  });
});
