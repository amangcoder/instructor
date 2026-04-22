import React from 'react';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import '@testing-library/jest-dom';

// ── Next.js navigation mock ───────────────────────────────────────────────────
// RangePicker uses useRouter and useSearchParams from next/navigation.
// We mock these so the component works in jsdom without a real Next.js runtime.

const mockPush = jest.fn();
let mockSearchParamsString = '';

jest.mock('next/navigation', () => ({
  useRouter: () => ({ push: mockPush }),
  useSearchParams: () => new URLSearchParams(mockSearchParamsString),
}));

import RangePicker from '../RangePicker';

// ── Helpers ───────────────────────────────────────────────────────────────────

function setParams(params: string) {
  mockSearchParamsString = params;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('RangePicker', () => {
  beforeEach(() => {
    mockPush.mockClear();
    mockSearchParamsString = '';
  });

  // ── Rendering ────────────────────────────────────────────────────────────

  it('renders three range buttons', () => {
    render(<RangePicker />);
    expect(screen.getByRole('button', { name: '7d' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '30d' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '90d' })).toBeInTheDocument();
  });

  it('renders a group with accessible label', () => {
    render(<RangePicker />);
    expect(screen.getByRole('group', { name: 'Time range selector' })).toBeInTheDocument();
  });

  // ── Default active state ──────────────────────────────────────────────────

  it('marks 30d as active by default when no ?range= param', () => {
    render(<RangePicker />);
    expect(screen.getByRole('button', { name: '30d' })).toHaveAttribute(
      'aria-pressed',
      'true',
    );
  });

  it('marks 7d and 90d as inactive by default', () => {
    render(<RangePicker />);
    expect(screen.getByRole('button', { name: '7d' })).toHaveAttribute(
      'aria-pressed',
      'false',
    );
    expect(screen.getByRole('button', { name: '90d' })).toHaveAttribute(
      'aria-pressed',
      'false',
    );
  });

  // ── Active state from URL ─────────────────────────────────────────────────

  it('marks 7d as active when ?range=7d', () => {
    setParams('range=7d');
    render(<RangePicker />);
    expect(screen.getByRole('button', { name: '7d' })).toHaveAttribute(
      'aria-pressed',
      'true',
    );
  });

  it('marks 90d as active when ?range=90d', () => {
    setParams('range=90d');
    render(<RangePicker />);
    expect(screen.getByRole('button', { name: '90d' })).toHaveAttribute(
      'aria-pressed',
      'true',
    );
  });

  // ── Click interaction ─────────────────────────────────────────────────────

  it('calls router.push with ?range=7d when 7d button is clicked', async () => {
    const user = userEvent.setup();
    render(<RangePicker />);

    await user.click(screen.getByRole('button', { name: '7d' }));

    expect(mockPush).toHaveBeenCalledTimes(1);
    expect(mockPush).toHaveBeenCalledWith(expect.stringContaining('range=7d'));
  });

  it('calls router.push with ?range=90d when 90d button is clicked', async () => {
    const user = userEvent.setup();
    render(<RangePicker />);

    await user.click(screen.getByRole('button', { name: '90d' }));

    expect(mockPush).toHaveBeenCalledWith(expect.stringContaining('range=90d'));
  });

  it('preserves other search params when updating range', async () => {
    setParams('foo=bar&range=30d');
    const user = userEvent.setup();
    render(<RangePicker />);

    await user.click(screen.getByRole('button', { name: '7d' }));

    const pushedUrl = mockPush.mock.calls[0][0] as string;
    expect(pushedUrl).toContain('foo=bar');
    expect(pushedUrl).toContain('range=7d');
  });

  // ── Active button styling ─────────────────────────────────────────────────

  it('active button has bg-primary class', () => {
    setParams('range=90d');
    render(<RangePicker />);
    const activeBtn = screen.getByRole('button', { name: '90d' });
    expect(activeBtn.className).toMatch(/bg-primary/);
  });

  it('inactive button does not have bg-primary class', () => {
    setParams('range=90d');
    render(<RangePicker />);
    const inactiveBtn = screen.getByRole('button', { name: '7d' });
    // Use classList.contains to check for the exact class token,
    // avoiding false positives from utility classes like hover:bg-primary/10
    expect(inactiveBtn.classList.contains('bg-primary')).toBe(false);
  });
});
