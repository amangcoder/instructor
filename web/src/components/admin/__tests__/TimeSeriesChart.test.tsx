import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';

// ── Recharts mock ─────────────────────────────────────────────────────────────
// Recharts uses ResizeObserver and SVG features unavailable in jsdom.
// We mock only the pieces used by TimeSeriesChart and test the component's
// props contract, accessible markup, and rendering logic instead.

jest.mock('recharts', () => {
  const mockLineChart = ({
    children,
    'data-testid': testId,
  }: {
    children?: React.ReactNode;
    'data-testid'?: string;
  }) => (
    <div data-testid={testId ?? 'line-chart'}>{children}</div>
  );

  return {
    ResponsiveContainer: ({
      children,
      height,
    }: {
      children: React.ReactNode;
      height?: number;
    }) => (
      <div data-testid="responsive-container" data-height={height}>
        {children}
      </div>
    ),
    LineChart: mockLineChart,
    Line: ({
      dataKey,
      stroke,
    }: {
      dataKey?: string;
      stroke?: string;
    }) => <div data-testid="line" data-key={dataKey} data-stroke={stroke} />,
    XAxis: ({ dataKey }: { dataKey?: string }) => (
      <div data-testid="x-axis" data-key={dataKey} />
    ),
    YAxis: () => <div data-testid="y-axis" />,
    Tooltip: () => <div data-testid="tooltip" />,
    CartesianGrid: () => <div data-testid="cartesian-grid" />,
  };
});

import TimeSeriesChart from '../TimeSeriesChart';

const SAMPLE_DATA = [
  { date: '2024-01-01', value: 10 },
  { date: '2024-01-02', value: 20 },
  { date: '2024-01-03', value: 15 },
];

describe('TimeSeriesChart', () => {
  it('renders without crashing with sample data', () => {
    render(<TimeSeriesChart data={SAMPLE_DATA} />);
    expect(screen.getByTestId('responsive-container')).toBeInTheDocument();
  });

  it('renders a ResponsiveContainer at height 300', () => {
    render(<TimeSeriesChart data={SAMPLE_DATA} />);
    expect(screen.getByTestId('responsive-container')).toHaveAttribute(
      'data-height',
      '300',
    );
  });

  it('renders with role="img" wrapper and aria-label', () => {
    render(<TimeSeriesChart data={SAMPLE_DATA} yKey="value" />);
    const img = screen.getByRole('img');
    expect(img).toBeInTheDocument();
    expect(img).toHaveAttribute('aria-label', expect.stringContaining('value'));
  });

  it('passes xKey prop to XAxis', () => {
    render(<TimeSeriesChart data={SAMPLE_DATA} xKey="date" />);
    expect(screen.getByTestId('x-axis')).toHaveAttribute('data-key', 'date');
  });

  it('defaults xKey to "date"', () => {
    render(<TimeSeriesChart data={SAMPLE_DATA} />);
    expect(screen.getByTestId('x-axis')).toHaveAttribute('data-key', 'date');
  });

  it('passes yKey prop to Line', () => {
    render(<TimeSeriesChart data={SAMPLE_DATA} yKey="count" />);
    expect(screen.getByTestId('line')).toHaveAttribute('data-key', 'count');
  });

  it('defaults yKey to "value"', () => {
    render(<TimeSeriesChart data={SAMPLE_DATA} />);
    expect(screen.getByTestId('line')).toHaveAttribute('data-key', 'value');
  });

  it('passes custom color to Line', () => {
    render(<TimeSeriesChart data={SAMPLE_DATA} color="#ef4444" />);
    expect(screen.getByTestId('line')).toHaveAttribute('data-stroke', '#ef4444');
  });

  it('defaults color to #3b82f6', () => {
    render(<TimeSeriesChart data={SAMPLE_DATA} />);
    expect(screen.getByTestId('line')).toHaveAttribute('data-stroke', '#3b82f6');
  });

  it('renders Tooltip and CartesianGrid sub-components', () => {
    render(<TimeSeriesChart data={SAMPLE_DATA} />);
    expect(screen.getByTestId('tooltip')).toBeInTheDocument();
    expect(screen.getByTestId('cartesian-grid')).toBeInTheDocument();
  });

  it('renders with empty data array', () => {
    render(<TimeSeriesChart data={[]} />);
    expect(screen.getByTestId('responsive-container')).toBeInTheDocument();
  });
});
