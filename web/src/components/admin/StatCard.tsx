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
   */
  delta?: number;
  /**
   * Optional override for the displayed delta string (e.g. '+12.5%').
   */
  deltaLabel?: string;
  /**
   * Direction indicator used when deltaLabel is provided.
   */
  deltaIsPositive?: boolean;
  /**
   * When true, renders a skeleton pulse animation in place of real content.
   */
  loading?: boolean;
  /**
   * Visual variant.
   * 'default' — standard compact card (default).
   * 'hero'    — larger, prominently styled card for the North Star metric.
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
 * Renders a metric card with dark-slate/indigo design system styling.
 *
 * Variants:
 *  - 'default' — bg-slate-800/50 border border-white/8 compact card
 *  - 'hero'    — gradient from-indigo-950/60 to-violet-950/60 larger card
 *
 * Accessibility:
 *  - Decorative arrow characters are aria-hidden
 *  - Delta value has an aria-label describing direction + magnitude
 *  - Skeleton state has aria-busy="true"
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
        className={`rounded-xl animate-pulse ${
          isHero
            ? 'bg-gradient-to-br from-indigo-950/60 to-violet-950/60 border border-indigo-500/20 p-8'
            : 'bg-slate-800/50 border border-white/8 p-5'
        }`}
        aria-busy="true"
        aria-label={`Loading ${title}`}
        role="status"
      >
        {/* Title skeleton */}
        <div className="h-3 bg-slate-700 rounded w-2/5 mb-4" />
        {/* Value skeleton */}
        <div
          className={`bg-slate-700 rounded w-3/5 mb-3 ${
            isHero ? 'h-12' : 'h-8'
          }`}
        />
        {/* Delta skeleton */}
        <div className="h-3 bg-slate-700 rounded w-1/4" />
        {/* Children area skeleton (hero only) */}
        {isHero && (
          <div className="h-12 bg-slate-700 rounded w-full mt-6" />
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
    isPositive = deltaIsPositiveProp ?? true;
    arrowChar = isPositive ? '▲' : '▼';
    deltaDisplayText = deltaLabel;
    deltaAriaLabel = `${isPositive ? 'Increase' : 'Decrease'} of ${deltaLabel} from previous period`;
  } else if (hasDeltaCount) {
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
      className={`rounded-xl ${
        isHero
          ? 'bg-gradient-to-br from-indigo-950/60 to-violet-950/60 border border-indigo-500/20 p-8'
          : 'bg-slate-800/50 border border-white/8 p-5'
      }`}
      role="region"
      aria-label={title}
    >
      {/* Title */}
      <p className={`font-medium uppercase tracking-widest ${
        isHero ? 'text-indigo-300 text-xs' : 'text-slate-400 text-xs'
      }`}>
        {title}
      </p>

      {/* Value */}
      <p
        className={`font-black text-white mt-1 tabular-nums ${
          isHero ? 'text-5xl' : 'text-3xl'
        }`}
      >
        {displayValue}
      </p>

      {/* Delta indicator */}
      {hasDelta && (
        <p
          className={`text-sm font-medium mt-2 flex items-center gap-1 ${
            isPositive ? 'text-emerald-400' : 'text-red-400'
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
