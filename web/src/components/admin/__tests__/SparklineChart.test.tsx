import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import SparklineChart, { TimeSeriesPoint } from '../SparklineChart';

// ── Helpers ───────────────────────────────────────────────────────────────────

const SAMPLE_POINTS: TimeSeriesPoint[] = [
  { date: '2024-01-01', value: 10 },
  { date: '2024-01-02', value: 25 },
  { date: '2024-01-03', value: 15 },
  { date: '2024-01-04', value: 40 },
  { date: '2024-01-05', value: 30 },
];

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('SparklineChart', () => {
  // ── SVG structure ──────────────────────────────────────────────────────────

  describe('SVG structure', () => {
    it('renders an SVG element', () => {
      const { container } = render(<SparklineChart points={SAMPLE_POINTS} />);
      const svg = container.querySelector('svg');
      expect(svg).toBeInTheDocument();
    });

    it('renders with default width=80 and height=32', () => {
      const { container } = render(<SparklineChart points={SAMPLE_POINTS} />);
      const svg = container.querySelector('svg');
      expect(svg).toHaveAttribute('width', '80');
      expect(svg).toHaveAttribute('height', '32');
    });

    it('renders with custom width and height', () => {
      const { container } = render(
        <SparklineChart points={SAMPLE_POINTS} width={120} height={48} />,
      );
      const svg = container.querySelector('svg');
      expect(svg).toHaveAttribute('width', '120');
      expect(svg).toHaveAttribute('height', '48');
    });

    it('sets viewBox matching width and height', () => {
      const { container } = render(
        <SparklineChart points={SAMPLE_POINTS} width={100} height={40} />,
      );
      const svg = container.querySelector('svg');
      expect(svg).toHaveAttribute('viewBox', '0 0 100 40');
    });
  });

  // ── Polyline rendering ─────────────────────────────────────────────────────

  describe('polyline rendering', () => {
    it('renders a polyline element for a valid points array', () => {
      const { container } = render(<SparklineChart points={SAMPLE_POINTS} />);
      const polyline = container.querySelector('polyline');
      expect(polyline).toBeInTheDocument();
    });

    it('polyline has fill="none" (no fill, outline only)', () => {
      const { container } = render(<SparklineChart points={SAMPLE_POINTS} />);
      const polyline = container.querySelector('polyline');
      expect(polyline).toHaveAttribute('fill', 'none');
    });

    it('applies default color (#3b82f6) as stroke', () => {
      const { container } = render(<SparklineChart points={SAMPLE_POINTS} />);
      const polyline = container.querySelector('polyline');
      expect(polyline).toHaveAttribute('stroke', '#3b82f6');
    });

    it('applies custom color as stroke', () => {
      const { container } = render(
        <SparklineChart points={SAMPLE_POINTS} color="#ef4444" />,
      );
      const polyline = container.querySelector('polyline');
      expect(polyline).toHaveAttribute('stroke', '#ef4444');
    });

    it('polyline points attribute is non-empty', () => {
      const { container } = render(<SparklineChart points={SAMPLE_POINTS} />);
      const polyline = container.querySelector('polyline');
      expect(polyline?.getAttribute('points')).toBeTruthy();
    });

    it('polyline point count matches input points count', () => {
      const { container } = render(<SparklineChart points={SAMPLE_POINTS} />);
      const polyline = container.querySelector('polyline');
      const rawPoints = polyline?.getAttribute('points') ?? '';
      // Each coordinate pair is separated by a space
      const coordPairs = rawPoints.trim().split(/\s+/);
      expect(coordPairs).toHaveLength(SAMPLE_POINTS.length);
    });
  });

  // ── Edge cases ─────────────────────────────────────────────────────────────

  describe('edge cases', () => {
    it('renders SVG but no polyline when points array is empty', () => {
      const { container } = render(<SparklineChart points={[]} />);
      expect(container.querySelector('svg')).toBeInTheDocument();
      expect(container.querySelector('polyline')).not.toBeInTheDocument();
    });

    it('renders without crashing with a single point', () => {
      const { container } = render(
        <SparklineChart points={[{ date: '2024-01-01', value: 5 }]} />,
      );
      expect(container.querySelector('svg')).toBeInTheDocument();
    });

    it('handles all-equal values without crashing (avoids divide-by-zero)', () => {
      const flatPoints: TimeSeriesPoint[] = [
        { date: '2024-01-01', value: 100 },
        { date: '2024-01-02', value: 100 },
        { date: '2024-01-03', value: 100 },
      ];
      const { container } = render(<SparklineChart points={flatPoints} />);
      expect(container.querySelector('polyline')).toBeInTheDocument();
    });
  });

  // ── Accessibility ──────────────────────────────────────────────────────────

  describe('accessibility', () => {
    it('SVG has role="img"', () => {
      render(<SparklineChart points={SAMPLE_POINTS} />);
      expect(screen.getByRole('img')).toBeInTheDocument();
    });

    it('SVG has an aria-label', () => {
      render(<SparklineChart points={SAMPLE_POINTS} />);
      const svg = screen.getByRole('img');
      expect(svg).toHaveAttribute('aria-label');
    });

    it('does not use any external charting library (pure SVG)', () => {
      const { container } = render(<SparklineChart points={SAMPLE_POINTS} />);
      // Should be a standard SVG polyline, not Recharts divs
      expect(container.querySelector('.recharts-wrapper')).not.toBeInTheDocument();
    });
  });
});
