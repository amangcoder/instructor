'use client';

import React from 'react';
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
  Cell,
  LabelList,
} from 'recharts';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface FunnelStage {
  /** Stage label (e.g. 'Generated', 'Saved', 'Activated') */
  name: string;
  /** Count of items that reached this stage */
  value: number;
}

export interface FunnelChartProps {
  /** Ordered array of funnel stages (first = widest) */
  data: FunnelStage[];
  /** Bar fill color (default: '#3b82f6' — blue-500) */
  color?: string;
  /** Accessible label describing what the chart shows */
  title?: string;
}

// ────────────────────────────────────────────────────────────────────────────
// Custom drop-off label
// ────────────────────────────────────────────────────────────────────────────

interface DropOffLabelProps {
  x?: number;
  y?: number;
  width?: number;
  value?: number;
  index?: number;
  stages?: FunnelStage[];
}

/**
 * Renders a "−X%" annotation above each bar (except the first) showing the
 * percentage drop-off from the previous stage.
 */
function DropOffLabel({
  x = 0,
  y = 0,
  width = 0,
  value = 0,
  index = 0,
  stages = [],
}: DropOffLabelProps) {
  // First stage has no previous stage to compare against
  if (index === 0 || !stages[index - 1]) return null;

  const prev = stages[index - 1].value;
  if (prev === 0) return null;

  const dropOffPct = Math.round(((prev - value) / prev) * 100);

  return (
    <text
      x={x + width / 2}
      y={y - 6}
      fill="var(--color-on-surface-variant)"
      textAnchor="middle"
      fontSize={11}
      fontWeight={500}
      aria-hidden="true"
    >
      {`−${dropOffPct}%`}
    </text>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * FunnelChart — client component
 *
 * Renders a horizontal bar chart (Recharts layout="horizontal" with
 * descending bar heights) visualising a conversion funnel.
 *
 * Features:
 *  - Bars shown with decreasing opacity to reinforce the funnel metaphor
 *  - Drop-off percentage annotation above each bar except the first
 *  - Count label to the right of each bar via LabelList
 *  - CartesianGrid, Tooltip using theme CSS variables
 *
 * Accessibility:
 *  - Wrapper has role="img" with aria-label
 *  - Drop-off annotations are aria-hidden (decorative; data is in tooltip)
 *  - Color + opacity cues are supplemented by text labels
 */
export default function FunnelChart({
  data,
  color = '#3b82f6',
}: FunnelChartProps) {
  const topValue = data.length > 0 ? data[0].value : 1;

  return (
    <div role="img" aria-label="Plan creation funnel">
      <ResponsiveContainer width="100%" height={300}>
        <BarChart
          data={data}
          margin={{ top: 24, right: 60, left: 8, bottom: 5 }}
        >
          <CartesianGrid
            strokeDasharray="3 3"
            stroke="var(--color-outline-variant)"
            vertical={false}
          />
          <XAxis
            dataKey="name"
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
          <Bar dataKey="value" radius={[4, 4, 0, 0]}>
            {data.map((stage, index) => {
              // Opacity encodes completion rate — first bar is fully opaque
              const opacity =
                topValue > 0
                  ? 0.35 + (stage.value / topValue) * 0.65
                  : 1;
              return (
                <Cell
                  key={`cell-${stage.name}`}
                  fill={color}
                  fillOpacity={opacity}
                />
              );
            })}

            {/* Value labels inside/above each bar */}
            <LabelList
              dataKey="value"
              position="top"
              style={{
                fill: 'var(--color-on-surface-variant)',
                fontSize: 12,
                fontWeight: 500,
              }}
              formatter={(v: number) => v.toLocaleString()}
            />

            {/* Drop-off % annotations — rendered as custom SVG labels */}
            <LabelList
              dataKey="value"
              content={(props) => (
                <DropOffLabel
                  {...props}
                  index={props.index ?? 0}
                  stages={data}
                />
              )}
            />
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
