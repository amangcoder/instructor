'use client';

import { useState } from 'react';
import StatCard from '@/components/admin/StatCard';
import StreakBarChart from '@/components/admin/StreakBarChart';
import type { StreaksResponse } from '@/types/analytics';
import type { RetentionResponse } from '@/types/retention';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface EngagementData {
  streaks: StreaksResponse;
  retention: RetentionResponse;
}

export interface EngagementAccordionProps {
  /**
   * Pre-fetched engagement data from the server.
   * Pass null while loading — the accordion will show skeleton cards.
   */
  initialData: EngagementData | null;
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

function formatRate(rate: number): string {
  return `${(rate * 100).toFixed(1)}%`;
}

function formatDelta(dp: number | null | undefined): string | undefined {
  if (dp === null || dp === undefined) return undefined;
  const sign = dp >= 0 ? '+' : '';
  return `${sign}${dp.toFixed(1)}%`;
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * EngagementAccordion — client component
 *
 * Collapsible section that shows engagement metrics:
 *  - Streak length distribution bar chart
 *  - D7 / D30 cohort retention rate stat cards
 *  - Streak totals (avg streak, users with streaks)
 *
 * Accessibility:
 *  - Toggle button uses aria-expanded / aria-controls
 *  - Chevron icon is aria-hidden
 *  - Content panel has role="region" with id matching aria-controls
 */
export default function EngagementAccordion({ initialData }: EngagementAccordionProps) {
  const [open, setOpen] = useState(false);

  const streakTotals = initialData?.streaks.totals;
  const retention = initialData?.retention;
  const streakSeries = initialData?.streaks.series ?? [];

  return (
    <div className="rounded-xl bg-slate-800/50 border border-white/8 overflow-hidden">
      {/* ── Toggle header ─────────────────────────────────────────────────── */}
      <button
        type="button"
        onClick={() => setOpen((prev) => !prev)}
        aria-expanded={open}
        aria-controls="engagement-panel"
        className="w-full flex items-center justify-between px-6 py-4 text-left hover:bg-white/5 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-400 focus-visible:ring-inset"
      >
        <div className="flex items-center gap-3">
          {/* Chart icon */}
          <span aria-hidden="true" className="text-indigo-400">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              className="w-5 h-5"
            >
              <path d="M3 3v18h18" />
              <path d="m19 9-5 5-4-4-3 3" />
            </svg>
          </span>
          <span className="font-semibold text-white">Engagement Metrics</span>
        </div>

        {/* Chevron — rotates when open */}
        <span
          aria-hidden="true"
          className={`text-slate-400 transition-transform duration-200 ${open ? 'rotate-180' : 'rotate-0'}`}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            className="w-5 h-5"
          >
            <path d="m6 9 6 6 6-6" />
          </svg>
        </span>
      </button>

      {/* ── Expandable content ────────────────────────────────────────────── */}
      {open && (
        <div
          id="engagement-panel"
          role="region"
          aria-label="Engagement Metrics"
          className="px-6 pb-6 space-y-6 border-t border-white/8"
        >
          {/* ── Retention stat cards ──────────────────────────────────────── */}
          <div>
            <h3 className="text-xs font-medium uppercase tracking-widest text-slate-400 mt-5 mb-3">
              Cohort Retention
            </h3>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              {retention ? (
                <>
                  <StatCard
                    title="D7 Retention"
                    value={retention.d7.rate}
                    valueLabel={formatRate(retention.d7.rate)}
                    deltaLabel={formatDelta(retention.d7.deltaPercent)}
                    deltaIsPositive={(retention.d7.deltaPercent ?? 0) >= 0}
                  />
                  <StatCard
                    title="D30 Retention"
                    value={retention.d30.rate}
                    valueLabel={formatRate(retention.d30.rate)}
                    deltaLabel={formatDelta(retention.d30.deltaPercent)}
                    deltaIsPositive={(retention.d30.deltaPercent ?? 0) >= 0}
                  />
                  {streakTotals && (
                    <StatCard
                      title="Avg Streak (days)"
                      value={Math.round(streakTotals.avgStreak)}
                    />
                  )}
                </>
              ) : (
                <>
                  <StatCard title="D7 Retention" value={0} loading />
                  <StatCard title="D30 Retention" value={0} loading />
                  <StatCard title="Avg Streak (days)" value={0} loading />
                </>
              )}
            </div>
          </div>

          {/* ── Streak summary stat cards ────────────────────────────────── */}
          {streakTotals && (
            <div>
              <h3 className="text-xs font-medium uppercase tracking-widest text-slate-400 mb-3">
                Streak Summary
              </h3>
              <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                <StatCard title="Users with Streaks" value={streakTotals.usersWithStreaks} />
                <StatCard title="Active Streak Users" value={streakTotals.activeStreakUsers} />
                <StatCard title="Median Streak" value={streakTotals.medianStreak} />
                <StatCard title="Max Streak" value={streakTotals.maxStreak} />
              </div>
            </div>
          )}

          {/* ── Streak distribution chart ────────────────────────────────── */}
          {streakSeries.length > 0 && (
            <div>
              <h3 className="text-xs font-medium uppercase tracking-widest text-slate-400 mb-3">
                Streak Length Distribution
              </h3>
              <div className="rounded-xl bg-slate-900/60 border border-white/8 p-4">
                <StreakBarChart data={streakSeries} />
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
