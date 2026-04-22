import React from 'react';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface TimeSeriesPoint {
  /** ISO date string or label for the data point */
  date: string;
  /** Numeric value at this point in time */
  value: number;
}

export interface SparklineChartProps {
  /** Array of time-series data points to render */
  points: TimeSeriesPoint[];
  /** SVG viewport width in pixels (default: 80) */
  width?: number;
  /** SVG viewport height in pixels (default: 32) */
  height?: number;
  /** Polyline stroke color (default: '#3b82f6' — blue-500) */
  color?: string;
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/**
 * Converts an array of TimeSeriesPoint values into SVG polyline points string.
 * Maps the value range to [padding, height - padding] and spreads x coordinates
 * evenly across [padding, width - padding].
 */
function toPolylinePoints(
  points: TimeSeriesPoint[],
  width: number,
  height: number,
): string {
  if (points.length === 0) return '';
  if (points.length === 1) {
    // Single point — render in the vertical centre
    return `${width / 2},${height / 2}`;
  }

  const padding = 2; // px inset from edges
  const values = points.map((p) => p.value);
  const minVal = Math.min(...values);
  const maxVal = Math.max(...values);
  const range = maxVal - minVal || 1; // Prevent division by zero

  const plotWidth = width - padding * 2;
  const plotHeight = height - padding * 2;

  return points
    .map((p, i) => {
      const x = padding + (i / (points.length - 1)) * plotWidth;
      // Flip Y axis: higher values should appear higher in the SVG
      const y = padding + (1 - (p.value - minVal) / range) * plotHeight;
      return `${x.toFixed(2)},${y.toFixed(2)}`;
    })
    .join(' ');
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * SparklineChart — server component
 *
 * Renders a compact SVG polyline suitable for embedding inside a StatCard or
 * any other context where a full-featured chart would be too heavy.
 *
 * Features:
 *  - No external charting library — pure SVG
 *  - Normalises data values to the SVG viewport automatically
 *  - Configurable size and stroke colour
 *  - Server-safe: no browser APIs or React hooks used
 *
 * Accessibility:
 *  - SVG has role="img" with an aria-label describing its purpose
 *  - Decorative polyline has aria-hidden="true" (conveyed via parent label)
 */
export default function SparklineChart({
  points,
  width = 80,
  height = 32,
  color = '#3b82f6',
}: SparklineChartProps) {
  const polylinePoints = toPolylinePoints(points, width, height);
  const isEmpty = points.length === 0;

  return (
    <svg
      width={width}
      height={height}
      viewBox={`0 0 ${width} ${height}`}
      role="img"
      aria-label="Trend sparkline"
      xmlns="http://www.w3.org/2000/svg"
    >
      {isEmpty ? null : (
        <polyline
          points={polylinePoints}
          fill="none"
          stroke={color}
          strokeWidth={1.5}
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
        />
      )}
    </svg>
  );
}
