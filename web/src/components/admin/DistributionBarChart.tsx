'use client';

import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
} from 'recharts';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface DistributionBarChartProps {
  /** Array of data points, e.g. [{ bucket: '1', userCount: 400 }] */
  data: Record<string, unknown>[];
  /** Key in each data object to use for the X axis (default: 'bucket') */
  xKey?: string;
  /** Key in each data object to use for the Y axis / bars (default: 'userCount') */
  yKey?: string;
  /** Bar fill color (default: '#3b82f6' — blue-500) */
  color?: string;
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * DistributionBarChart — client component
 *
 * Renders a responsive bar chart for distribution data (e.g. plans-per-user
 * buckets). Unlike FunnelChart, this component shows no drop-off annotations
 * since the data represents a distribution, not a conversion funnel.
 *
 * Features:
 *  - Configurable X/Y data keys (defaults: 'bucket' / 'userCount')
 *  - Configurable bar color (default: blue-500)
 *  - CartesianGrid, XAxis, YAxis, and Tooltip using theme CSS variables
 *  - Rounded bar tops for visual polish
 *
 * Accessibility:
 *  - Wrapper has role="img" with aria-label describing the chart
 *  - Recharts tooltip provides accessible on-hover data disclosure
 */
export default function DistributionBarChart({
  data,
  xKey = 'bucket',
  yKey = 'userCount',
  color = '#3b82f6',
}: DistributionBarChartProps) {
  return (
    <div role="img" aria-label={`Distribution bar chart for ${yKey}`}>
      <ResponsiveContainer width="100%" height={300}>
        <BarChart
          data={data}
          margin={{ top: 5, right: 20, left: 0, bottom: 5 }}
        >
          <CartesianGrid
            strokeDasharray="3 3"
            stroke="var(--color-outline-variant)"
            vertical={false}
          />
          <XAxis
            dataKey={xKey}
            tick={{ fontSize: 12, fill: 'var(--color-on-surface-variant)' }}
            axisLine={{ stroke: 'var(--color-outline-variant)' }}
            tickLine={false}
          />
          <YAxis
            tick={{ fontSize: 12, fill: 'var(--color-on-surface-variant)' }}
            axisLine={false}
            tickLine={false}
          />
          <Tooltip
            contentStyle={{
              backgroundColor: 'var(--color-surface-container)',
              border: '1px solid var(--color-outline-variant)',
              borderRadius: '8px',
              color: 'var(--color-on-surface)',
              fontSize: 13,
            }}
            cursor={{ fill: 'var(--color-primary)', opacity: 0.05 }}
          />
          <Bar dataKey={yKey} fill={color} radius={[4, 4, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
