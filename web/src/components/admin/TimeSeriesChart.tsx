'use client';

import {
  ResponsiveContainer,
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
  Legend,
} from 'recharts';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

/** Definition for a single series in a multi-line chart */
export interface SeriesDefinition {
  /** Data key to read from each data point (e.g. 'dau', 'wau', 'mau') */
  dataKey: string;
  /** Line stroke colour (hex or CSS colour) */
  color: string;
  /** Human-readable series name shown in the legend */
  name: string;
}

export interface TimeSeriesChartProps {
  /** Array of data points (e.g. [{ date: '2024-01-01', value: 42 }]) */
  data: Record<string, unknown>[];
  /** Key in each data object to use for the X axis (default: 'date') */
  xKey?: string;
  /**
   * Key in each data object to use for the Y axis / line (default: 'value').
   * Ignored when `series` is provided.
   */
  yKey?: string;
  /**
   * Line stroke color (default: '#3b82f6' — blue-500).
   * Ignored when `series` is provided.
   */
  color?: string;
  /** Accessible label describing what the chart shows */
  title?: string;
  /**
   * Optional array of series definitions for multi-line charts.
   * When provided, renders one `<Line>` per entry and adds a legend.
   * When omitted, falls back to single-line mode using `yKey` + `color`.
   */
  series?: SeriesDefinition[];
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * TimeSeriesChart — client component
 *
 * Renders a responsive line chart from a time-series data array using
 * Recharts. The chart fills 100% of its container width at a fixed height
 * of 300px.
 *
 * Features:
 *  - Configurable X/Y data keys (defaults: 'date' / 'value')
 *  - Configurable line color (default: blue-500)
 *  - Multi-series support via optional `series` prop
 *  - CartesianGrid, XAxis, YAxis, and Tooltip using theme CSS variables
 *  - Legend shown automatically when multiple series are present
 *  - No dots on the line for cleaner rendering; activeDot on hover
 *
 * Accessibility:
 *  - Wrapper has role="img" with aria-label describing the chart
 *  - Recharts tooltip provides accessible on-hover data disclosure
 *  - Legend labels provide series identification for screen readers
 */
export default function TimeSeriesChart({
  data,
  xKey = 'date',
  yKey = 'value',
  color = '#3b82f6',
  title,
  series,
}: TimeSeriesChartProps) {
  return (
    <div role="img" aria-label={title ?? 'Time series chart'}>
      <ResponsiveContainer width="100%" height={300}>
        <LineChart
          data={data}
          margin={{ top: 5, right: 20, left: 0, bottom: 5 }}
        >
          <CartesianGrid
            strokeDasharray="3 3"
            stroke="var(--color-outline-variant)"
          />
          <XAxis
            dataKey={xKey}
            tick={{
              fontSize: 12,
              fill: 'var(--color-on-surface-variant)',
            }}
            axisLine={{ stroke: 'var(--color-outline-variant)' }}
            tickLine={false}
          />
          <YAxis
            tick={{
              fontSize: 12,
              fill: 'var(--color-on-surface-variant)',
            }}
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
            cursor={{ stroke: 'var(--color-outline-variant)' }}
          />

          {series ? (
            /* ── Multi-series mode ─────────────────────────────────────── */
            <>
              <Legend
                wrapperStyle={{
                  fontSize: 12,
                  color: 'var(--color-on-surface-variant)',
                  paddingTop: 8,
                }}
              />
              {series.map((s) => (
                <Line
                  key={s.dataKey}
                  type="monotone"
                  dataKey={s.dataKey}
                  name={s.name}
                  stroke={s.color}
                  strokeWidth={2}
                  dot={false}
                  activeDot={{ r: 4, strokeWidth: 0 }}
                />
              ))}
            </>
          ) : (
            /* ── Single-series mode (original API, unchanged) ─────────── */
            <Line
              type="monotone"
              dataKey={yKey}
              stroke={color}
              strokeWidth={2}
              dot={false}
              activeDot={{ r: 4, strokeWidth: 0 }}
            />
          )}
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
