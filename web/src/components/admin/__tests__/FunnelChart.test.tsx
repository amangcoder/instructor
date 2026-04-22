import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';

// ── Recharts mock ─────────────────────────────────────────────────────────────

jest.mock('recharts', () => ({
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
  BarChart: ({ children }: { children?: React.ReactNode }) => (
    <div data-testid="bar-chart">{children}</div>
  ),
  Bar: ({ children, dataKey }: { children?: React.ReactNode; dataKey?: string }) => (
    <div data-testid="bar" data-key={dataKey}>
      {children}
    </div>
  ),
  XAxis: ({ dataKey }: { dataKey?: string }) => (
    <div data-testid="x-axis" data-key={dataKey} />
  ),
  YAxis: () => <div data-testid="y-axis" />,
  Tooltip: () => <div data-testid="tooltip" />,
  CartesianGrid: () => <div data-testid="cartesian-grid" />,
  Cell: ({ fill }: { fill?: string }) => (
    <div data-testid="cell" data-fill={fill} />
  ),
  LabelList: () => <div data-testid="label-list" />,
}));

import FunnelChart from '../FunnelChart';

const SAMPLE_STAGES = [
  { name: 'Generated', value: 100 },
  { name: 'Saved', value: 60 },
  { name: 'Activated', value: 40 },
];

describe('FunnelChart', () => {
  it('renders without crashing', () => {
    render(<FunnelChart data={SAMPLE_STAGES} />);
    expect(screen.getByTestId('responsive-container')).toBeInTheDocument();
  });

  it('renders with role="img" and aria-label', () => {
    render(<FunnelChart data={SAMPLE_STAGES} />);
    const img = screen.getByRole('img');
    expect(img).toBeInTheDocument();
    expect(img).toHaveAttribute('aria-label', expect.stringContaining('funnel'));
  });

  it('renders a Bar with dataKey="value"', () => {
    render(<FunnelChart data={SAMPLE_STAGES} />);
    expect(screen.getByTestId('bar')).toHaveAttribute('data-key', 'value');
  });

  it('renders Tooltip and CartesianGrid', () => {
    render(<FunnelChart data={SAMPLE_STAGES} />);
    expect(screen.getByTestId('tooltip')).toBeInTheDocument();
    expect(screen.getByTestId('cartesian-grid')).toBeInTheDocument();
  });

  it('renders with empty data without crashing', () => {
    render(<FunnelChart data={[]} />);
    expect(screen.getByTestId('bar-chart')).toBeInTheDocument();
  });

  it('accepts custom color prop', () => {
    // Color is passed to Cell, which is mocked — just check it renders
    render(<FunnelChart data={SAMPLE_STAGES} color="#ef4444" />);
    expect(screen.getByTestId('bar-chart')).toBeInTheDocument();
  });
});
