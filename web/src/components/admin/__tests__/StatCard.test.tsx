import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import StatCard from '../StatCard';

describe('StatCard', () => {
  // ── Loading state ──────────────────────────────────────────────────────────

  describe('loading state', () => {
    it('renders skeleton with aria-busy when loading is true', () => {
      render(<StatCard title="Total Users" value={1234} loading />);
      const skeleton = screen.getByRole('status');
      expect(skeleton).toHaveAttribute('aria-busy', 'true');
    });

    it('includes the title in the aria-label of the skeleton', () => {
      render(<StatCard title="Total Users" value={1234} loading />);
      expect(screen.getByLabelText('Loading Total Users')).toBeInTheDocument();
    });

    it('does not render the numeric value when loading', () => {
      render(<StatCard title="Total Users" value={1234} loading />);
      expect(screen.queryByText('1,234')).not.toBeInTheDocument();
    });
  });

  // ── Rendered state ─────────────────────────────────────────────────────────

  describe('rendered state', () => {
    it('renders the title', () => {
      render(<StatCard title="Total Users" value={999} />);
      expect(screen.getByText('Total Users')).toBeInTheDocument();
    });

    it('formats the value with toLocaleString()', () => {
      render(<StatCard title="Plans" value={1234567} />);
      // toLocaleString output varies by locale but will include digit separators
      const valueEl = screen.getByText(/1[,.]?234[,.]?567/);
      expect(valueEl).toBeInTheDocument();
    });

    it('renders zero value', () => {
      render(<StatCard title="Plans" value={0} />);
      expect(screen.getByText('0')).toBeInTheDocument();
    });
  });

  // ── Delta indicator ────────────────────────────────────────────────────────

  describe('delta indicator', () => {
    it('does not render delta when not provided', () => {
      render(<StatCard title="Plans" value={100} />);
      expect(screen.queryByText('▲')).not.toBeInTheDocument();
      expect(screen.queryByText('▼')).not.toBeInTheDocument();
    });

    it('shows green ▲ arrow for positive delta', () => {
      render(<StatCard title="Plans" value={100} delta={12} />);
      const arrow = screen.getByText('▲');
      expect(arrow).toBeInTheDocument();
      // Parent element should have text-success class
      const deltaEl = arrow.closest('p');
      expect(deltaEl?.className).toMatch(/text-success/);
    });

    it('shows red ▼ arrow for negative delta', () => {
      render(<StatCard title="Plans" value={100} delta={-5} />);
      const arrow = screen.getByText('▼');
      expect(arrow).toBeInTheDocument();
      const deltaEl = arrow.closest('p');
      expect(deltaEl?.className).toMatch(/text-error/);
    });

    it('shows ▲ arrow for delta of zero (not negative)', () => {
      render(<StatCard title="Plans" value={100} delta={0} />);
      expect(screen.getByText('▲')).toBeInTheDocument();
    });

    it('aria-label describes the direction and magnitude', () => {
      render(<StatCard title="Users" value={500} delta={25} />);
      const deltaEl = screen.getByText('▲').closest('p');
      expect(deltaEl).toHaveAttribute('aria-label', expect.stringContaining('Increase'));
      expect(deltaEl).toHaveAttribute('aria-label', expect.stringContaining('25'));
    });

    it('aria-label says Decrease for negative delta', () => {
      render(<StatCard title="Users" value={500} delta={-10} />);
      const deltaEl = screen.getByText('▼').closest('p');
      expect(deltaEl).toHaveAttribute('aria-label', expect.stringContaining('Decrease'));
    });

    it('shows absolute value of delta (not negative number)', () => {
      render(<StatCard title="Users" value={500} delta={-30} />);
      expect(screen.getByText('30')).toBeInTheDocument();
      expect(screen.queryByText('-30')).not.toBeInTheDocument();
    });
  });

  // ── Accessibility ──────────────────────────────────────────────────────────

  describe('accessibility', () => {
    it('renders with role="region" and aria-label matching title', () => {
      render(<StatCard title="TTS Volume" value={42} />);
      expect(screen.getByRole('region', { name: 'TTS Volume' })).toBeInTheDocument();
    });
  });
});
