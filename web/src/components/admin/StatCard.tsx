import React from 'react';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface StatCardProps {
  /** Card heading (e.g. 'Total Users', 'Plans Created') */
  title: string;
  /** Numeric metric to display, formatted with toLocaleString() unless valueLabel is set */
  value: number;
  /**
   * Optional override for the displayed value string.
   * When provided, renders this string in place of value.toLocaleString().
   * Use for non-integer displays like percentages (e.g. '73.6%').
   */
  valueLabel?: string;
  /**
   * Optional change relative to the previous period (raw count).
   * Positive values show a green ▲ indicator; negative values show red ▼.
   * Takes precedence over deltaLabel if both are provided.
   * Ignored when deltaLabel is provided.
   */
  delta?: number;
  /**
   * Optional override for the displayed delta string (e.g. '+12.5%').
   * When provided, renders this string instead of the computed delta count.
   * Direction is inferred from deltaIsPositive.
   */
  deltaLabel?: string;
  /**
   * Direction indicator used when deltaLabel is provided.
   * true → green ▲ (positive change); false → red ▼ (negative change).
   * Defaults to true when not specified.
   */
  deltaIsPositive?: boolean;
  /**
   * When true, renders a skeleton pulse animation in place of real content.
   * Use while the metric data is loading.
   */
  loading?: boolean;
  /**
   * Visual variant.
   * 'default' — standard compact card (default).
   * 'hero'    — larger, prominently styled card for the North Star metric.
   *             Supports children (e.g. an embedded SparklineChart).
   */
  variant?: 'default' | 'hero';
  /**
   * Optional content rendered below the value/delta (e.g. a SparklineChart).
   * Only visible in the 'hero' variant.
   */
  children?: React.ReactNode;
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * StatCard — server component
 *
 * Renders a metric card with:
 *  - Title (label for the metric)
 *  - Value (formatted number or custom valueLabel string)
 *  - Optional delta indicator (▲ green for positive, ▼ red for negative)
 *  - Optional loading skeleton (pulse animation)
 *  - Optional children (embedded sparkline, etc.) — hero variant only
 *
 * Variants:
 *  - 'default' — compact card for secondary metrics
 *  - 'hero'    — larger prominent card for the North Star metric
 *
 * Styling follows the existing web aesthetic:
 *  - rounded-xl card with shadow-sm
 *  - bg-surface-container (default) / primary-tinted (hero)
 *  - Theme-aware semantic colors for delta (success / error)
 *
 * Accessibility:
 *  - Decorative arrow characters are aria-hidden
 *  - Delta value has an aria-label describing direction + magnitude
 *  - Skeleton state has aria-busy="true" and a visually-hidden status message
 *  - role="region" with aria-label matching the card title
 */
export default function StatCard({
  title,
  value,
  valueLabel,
  delta,
  deltaLabel,
  deltaIsPositive: deltaIsPositiveProp,
  loading = false,
  variant = 'default',
  children,
}: StatCardProps) {
  const isHero = variant === 'hero';

  // ── Loading skeleton ──────────────────────────────────────────────────────
  if (loading) {
    return (
      <div
        className={`rounded-xl shadow-sm animate-pulse ${
          isHero
            ? 'bg-primary/10 border border-primary/20 p-8'
            : 'bg-surface-container p-6'
        }`}
        aria-busy="true"
        aria-label={`Loading ${title}`}
        role="status"
      >
        {/* Title skeleton */}
        <div className="h-3.5 bg-outline-variant/40 rounded w-2/5 mb-4" />
        {/* Value skeleton */}
        <div
          className={`bg-outline-variant/40 rounded w-3/5 mb-3 ${
            isHero ? 'h-12' : 'h-8'
          }`}
        />
        {/* Delta skeleton */}
        <div className="h-3 bg-outline-variant/40 rounded w-1/4" />
        {/* Children area skeleton (hero only) */}
        {isHero && (
          <div className="h-12 bg-outline-variant/40 rounded w-full mt-6" />
        )}
      </div>
    );
  }

  // ── Delta resolution ──────────────────────────────────────────────────────
  const hasDeltaLabel = deltaLabel !== undefined;
  const hasDeltaCount = delta !== undefined;
  const hasDelta = hasDeltaLabel || hasDeltaCount;

  let isPositive = true;
  let arrowChar = '▲';
  let deltaDisplayText = '';
  let deltaAriaLabel = '';

  if (hasDeltaLabel) {
    // Custom label path — direction from deltaIsPositive prop (default: true)
    isPositive = deltaIsPositiveProp ?? true;
    arrowChar = isPositive ? '▲' : '▼';
    deltaDisplayText = deltaLabel;
    deltaAriaLabel = `${isPositive ? 'Increase' : 'Decrease'} of ${deltaLabel} from previous period`;
  } else if (hasDeltaCount) {
    // Raw count path — existing behaviour (backward-compatible)
    isPositive = delta! >= 0;
    const deltaAbs = Math.abs(delta!);
    arrowChar = isPositive ? '▲' : '▼';
    deltaDisplayText = deltaAbs.toLocaleString();
    deltaAriaLabel = `${isPositive ? 'Increase' : 'Decrease'} of ${deltaAbs.toLocaleString()} from previous period`;
  }

  // ── Rendered card ─────────────────────────────────────────────────────────
  const displayValue = valueLabel ?? value.toLocaleString();

  return (
    <div
      className={`rounded-xl shadow-sm ${
        isHero
          ? 'bg-primary/10 border border-primary/20 p-8'
          : 'bg-surface-container p-6'
      }`}
      role="region"
      aria-label={title}
    >
      {/* Title */}
      <p className="text-sm font-medium text-on-surface-variant">{title}</p>

      {/* Value */}
      <p
        className={`font-bold text-on-surface mt-1 tabular-nums ${
          isHero ? 'text-5xl' : 'text-3xl'
        }`}
      >
        {displayValue}
      </p>

      {/* Delta indicator */}
      {hasDelta && (
        <p
          className={`text-sm font-medium mt-2 flex items-center gap-1 ${
            isPositive ? 'text-success' : 'text-error'
          }`}
          aria-label={deltaAriaLabel}
        >
          <span aria-hidden="true">{arrowChar}</span>
          <span>{deltaDisplayText}</span>
        </p>
      )}

      {/* Optional children (sparkline etc.) — hero variant */}
      {isHero && children && (
        <div className="mt-6" aria-hidden="false">
          {children}
        </div>
      )}
    </div>
  );
}
