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
import type { StreakBucket } from '@/types/analytics';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface StreakBarChartProps {
  /** Streak distribution data from the engagement/streaks API */
  data: StreakBucket[];
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * StreakBarChart — client component
 *
 * Renders a Recharts BarChart showing streak length distribution.
 *   X axis: streak length bucket labels (e.g. "0", "1-2", "3-6", "7-13", …)
 *   Y axis: number of users in each bucket
 *
 * Accessibility:
 *   - Wrapper has role="img" with aria-label
 *   - Tooltip provides accessible on-hover data disclosure
 */
export default function StreakBarChart({ data }: StreakBarChartProps) {
  return (
    <div role="img" aria-label="Streak length distribution bar chart">
      <ResponsiveContainer width="100%" height={300}>
        <BarChart
          data={data}
          margin={{ top: 5, right: 20, left: 0, bottom: 5 }}
        >
          <CartesianGrid
            strokeDasharray="3 3"
            stroke="rgba(255,255,255,0.08)"
          />
          <XAxis
            dataKey="bucket"
            tick={{
              fontSize: 12,
              fill: '#94a3b8',
            }}
            axisLine={{ stroke: 'rgba(255,255,255,0.08)' }}
            tickLine={false}
            label={{
              value: 'Streak Length (days)',
              position: 'insideBottom',
              offset: -2,
              fontSize: 11,
              fill: '#94a3b8',
            }}
          />
          <YAxis
            tick={{
              fontSize: 12,
              fill: '#94a3b8',
            }}
            axisLine={false}
            tickLine={false}
            label={{
              value: 'Users',
              angle: -90,
              position: 'insideLeft',
              fontSize: 11,
              fill: '#94a3b8',
            }}
          />
          <Tooltip
            contentStyle={{
              backgroundColor: '#1e293b',
              border: '1px solid rgba(255,255,255,0.08)',
              borderRadius: '8px',
              color: '#f1f5f9',
              fontSize: 13,
            }}
            cursor={{ fill: '#6366f1', opacity: 0.08 }}
            formatter={(value: number) => [
              value.toLocaleString(),
              'Users',
            ]}
            labelFormatter={(label: string) => `Streak: ${label} days`}
          />
          <Bar
            dataKey="userCount"
            fill="#6366f1"
            radius={[4, 4, 0, 0]}
          />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
