import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import EmptyState from '../EmptyState';

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('EmptyState', () => {
  // ── Content rendering ──────────────────────────────────────────────────────

  describe('content rendering', () => {
    it('renders the provided message string', () => {
      render(<EmptyState message="No data for the selected period" />);
      expect(screen.getByText('No data for the selected period')).toBeInTheDocument();
    });

    it('renders any arbitrary message', () => {
      render(<EmptyState message="No deletion requests pending" />);
      expect(screen.getByText('No deletion requests pending')).toBeInTheDocument();
    });

    it('message is visible (not hidden)', () => {
      render(<EmptyState message="Nothing to show here" />);
      const msg = screen.getByText('Nothing to show here');
      expect(msg).toBeVisible();
    });
  });

  // ── Styling ────────────────────────────────────────────────────────────────

  describe('styling', () => {
    it('renders a panel with the surface-container class', () => {
      const { container } = render(<EmptyState message="No data" />);
      const panel = container.firstChild as HTMLElement;
      expect(panel.className).toMatch(/bg-surface-container/);
    });

    it('centres content with flex layout', () => {
      const { container } = render(<EmptyState message="No data" />);
      const panel = container.firstChild as HTMLElement;
      expect(panel.className).toMatch(/flex/);
      expect(panel.className).toMatch(/items-center/);
      expect(panel.className).toMatch(/justify-center/);
    });

    it('has rounded-xl for card shape consistency', () => {
      const { container } = render(<EmptyState message="No data" />);
      const panel = container.firstChild as HTMLElement;
      expect(panel.className).toMatch(/rounded-xl/);
    });

    it('uses on-surface-variant text colour class', () => {
      render(<EmptyState message="No data" />);
      const text = screen.getByText('No data');
      expect(text.className).toMatch(/text-on-surface-variant/);
    });
  });

  // ── Accessibility ──────────────────────────────────────────────────────────

  describe('accessibility', () => {
    it('has role="status" for screen-reader announcement', () => {
      render(<EmptyState message="No data for the selected period" />);
      expect(screen.getByRole('status')).toBeInTheDocument();
    });

    it('aria-label on the status container matches the message', () => {
      render(<EmptyState message="No deletion requests found" />);
      const panel = screen.getByRole('status');
      expect(panel).toHaveAttribute('aria-label', 'No deletion requests found');
    });
  });
});
