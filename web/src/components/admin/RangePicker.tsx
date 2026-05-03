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
 * Renders a segmented control (7d / 30d / 90d) that sets the ?range=
 * URL search parameter via useRouter().replace().
 *
 * Accessibility:
 *  - Wrapper has role="group" with aria-label
 *  - Each button uses aria-pressed to convey selected state
 *  - Keyboard navigable via Tab, activated via Enter / Space
 */
export default function RangePicker() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const currentRange = (searchParams.get('range') as Range | null) ?? DEFAULT_RANGE;

  const setRange = useCallback(
    (range: Range) => {
      const params = new URLSearchParams(searchParams.toString());
      params.set('range', range);
      router.replace(`?${params.toString()}`);
    },
    [router, searchParams],
  );

  return (
    <div
      className="inline-flex border border-white/10 bg-slate-800/50 rounded-xl overflow-hidden p-0.5 gap-0.5"
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
              'px-4 py-1.5 text-sm font-medium rounded-lg transition-colors',
              'focus-visible:outline-none focus-visible:outline-2 focus-visible:outline-indigo-400 focus-visible:outline-offset-2',
              isActive
                ? 'bg-indigo-600 text-white'
                : 'text-slate-400 hover:text-white hover:bg-white/5',
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
