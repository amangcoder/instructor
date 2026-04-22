'use client';

import { useRouter, useSearchParams } from 'next/navigation';
import { useCallback } from 'react';

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

type Range = '7d' | '30d' | '90d';

const RANGES: ReadonlyArray<{ label: string; value: Range }> = [
  { label: '7d', value: '7d' },
  { label: '30d', value: '30d' },
  { label: '90d', value: '90d' },
];

/** Default range when no ?range= param is present */
const DEFAULT_RANGE: Range = '30d';

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * RangePicker — client component
 *
 * Renders three segmented buttons (7d / 30d / 90d) that set the ?range=
 * URL search parameter via useRouter().push(), causing the server component
 * above to re-render with the new range.
 *
 * Active button is highlighted with primary background + ring.
 *
 * Accessibility:
 *  - Wrapper has role="group" with aria-label
 *  - Each button uses aria-pressed to convey selected state
 *  - Keyboard navigable via Tab and activated via Enter / Space
 */
export default function RangePicker() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const currentRange = (searchParams.get('range') as Range | null) ?? DEFAULT_RANGE;

  const setRange = useCallback(
    (range: Range) => {
      const params = new URLSearchParams(searchParams.toString());
      params.set('range', range);
      router.push(`?${params.toString()}`);
    },
    [router, searchParams],
  );

  return (
    <div
      className="inline-flex rounded-lg border border-outline-variant bg-surface-container overflow-hidden"
      role="group"
      aria-label="Time range selector"
    >
      {RANGES.map(({ label, value }) => {
        const isActive = currentRange === value;
        return (
          <button
            key={value}
            type="button"
            onClick={() => setRange(value)}
            aria-pressed={isActive}
            className={[
              'px-4 py-2 text-sm font-medium transition-colors',
              'min-h-[44px]',
              'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-inset',
              // Border between adjacent buttons
              'border-r border-outline-variant last:border-r-0',
              isActive
                ? 'bg-primary text-white'
                : 'text-on-surface hover:bg-primary/10',
            ]
              .filter(Boolean)
              .join(' ')}
          >
            {label}
          </button>
        );
      })}
    </div>
  );
}
