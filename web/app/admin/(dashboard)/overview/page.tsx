import { Suspense } from 'react';
import { adminFetch, AdminApiError } from '@/lib/admin-api';
import StatCard from '@/components/admin/StatCard';
import RangePicker from '@/components/admin/RangePicker';
import SparklineChart from '@/components/admin/SparklineChart';
import DataTableToggle from '@/components/admin/DataTableToggle';
import EmptyState from '@/components/admin/EmptyState';
import ActivityFeedWidget from '@/components/admin/ActivityFeedWidget';
import type { ExtendedOverviewResponse } from '@/types/analytics';
import type { ActivityFeedResponse } from '@/types/activity-feed';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

interface OverviewPageProps {
  searchParams: Promise<{ range?: string }>;
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/**
 * Format a deltaPercent value (e.g. 12.5) as a signed percentage string
 * (e.g. '+12.5%'). Returns undefined when the value is null/undefined so
 * the StatCard omits the delta indicator entirely.
 */
function formatDeltaPercent(dp: number | null | undefined): string | undefined {
  if (dp === null || dp === undefined) return undefined;
  const sign = dp >= 0 ? '+' : '';
  return `${sign}${dp.toFixed(1)}%`;
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * Admin Overview Page — server component
 *
 * Renders the admin overview dashboard with:
 *   Hero card — Weekly Plans Played (North Star metric) with sparkline
 *   Row 1    — Total Users, Total Plans, Total TTS Jobs, Total Sessions
 *   Row 2    — New Signups, Active Plans, TTS Failures, Avg Session Duration
 *   Row 3    — Plan Completion Rate
 *   Feed     — Recent Activity (last 10 platform events)
 *
 * Data is fetched server-side via adminFetch in parallel.
 * Errors are caught and displayed inline — never crash the page.
 * Each stat card area shows EmptyState when data fails to load.
 *
 * The RangePicker component is wrapped in Suspense because it reads
 * useSearchParams(), which requires a Suspense boundary in Next.js 14+.
 */
export default async function AdminOverviewPage({
  searchParams,
}: OverviewPageProps) {
  const params = await searchParams;
  const range = params.range ?? '7d';

  // Fetch overview and activity feed in parallel
  let data: ExtendedOverviewResponse | null = null;
  let errorMessage: string | null = null;
  let activityData: ActivityFeedResponse | null = null;

  const [overviewResult, activityResult] = await Promise.allSettled([
    adminFetch<ExtendedOverviewResponse>('/admin/analytics/overview', { range }),
    adminFetch<ActivityFeedResponse>('/admin/analytics/overview/activity'),
  ]);

  if (overviewResult.status === 'fulfilled') {
    data = overviewResult.value;
  } else {
    const err = overviewResult.reason;
    if (err instanceof AdminApiError) {
      errorMessage = err.message;
    } else {
      errorMessage = 'An unexpected error occurred while loading analytics.';
    }
  }

  if (activityResult.status === 'fulfilled') {
    activityData = activityResult.value;
  }
  // Activity fetch errors are silently absorbed — the widget renders EmptyState

  const totals = data?.totals;
  const weeklyPlansPlayed = totals?.weeklyPlansPlayed;

  return (
    <div>
      {/* ── Page header ──────────────────────────────────────────────────── */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
        <h1 className="text-2xl font-bold text-on-surface">Overview</h1>
        <Suspense fallback={null}>
          <RangePicker />
        </Suspense>
      </div>

      {/* ── Error state ──────────────────────────────────────────────────── */}
      {errorMessage && (
        <div
          className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-6"
          role="alert"
        >
          <p className="font-medium">Failed to load analytics</p>
          <p className="mt-1">{errorMessage}</p>
        </div>
      )}

      {/* ── Metrics ──────────────────────────────────────────────────────── */}
      <div className="space-y-4" aria-label="Key metrics">

        {/* ── Hero card: Weekly Plans Played ─────────────────────────────── */}
        <section aria-label="North Star metric">
          {data && totals ? (
            weeklyPlansPlayed ? (
              <>
                <StatCard
                  variant="hero"
                  title="Weekly Plans Played"
                  value={weeklyPlansPlayed.current}
                  deltaLabel={formatDeltaPercent(weeklyPlansPlayed.deltaPercent)}
                  deltaIsPositive={(weeklyPlansPlayed.deltaPercent ?? 0) >= 0}
                >
                  {weeklyPlansPlayed.sparkline.length > 0 && (
                    <div className="flex items-end gap-3">
                      <SparklineChart
                        points={weeklyPlansPlayed.sparkline}
                        width={200}
                        height={48}
                        color="#4ade80"
                      />
                      <span className="text-xs text-on-surface-variant pb-1">
                        {weeklyPlansPlayed.sparkline.length}-day trend
                      </span>
                    </div>
                  )}
                </StatCard>

                {/* ── Data table toggle for sparkline ──────────────────────── */}
                {weeklyPlansPlayed.sparkline.length > 0 && (
                  <div className="mt-4">
                    <DataTableToggle
                      data={weeklyPlansPlayed.sparkline}
                      columns={[
                        { key: 'date', label: 'Date' },
                        { key: 'value', label: 'Plans Played' },
                      ]}
                    />
                  </div>
                )}
              </>
            ) : (
              <EmptyState message="Weekly Plans Played data is unavailable for this period." />
            )
          ) : errorMessage ? (
            <EmptyState message="Weekly Plans Played could not be loaded." />
          ) : (
            /* Loading skeleton */
            <StatCard variant="hero" title="Weekly Plans Played" value={0} loading />
          )}
        </section>

        {/* ── Row 1: Core totals ─────────────────────────────────────────── */}
        <div
          role="region"
          aria-label="Totals"
        >
          {data && totals ? (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <StatCard
                title="Total Users"
                value={totals.totalUsers.current}
                delta={totals.totalUsers.current - totals.totalUsers.previous}
              />
              <StatCard
                title="Total Plans"
                value={totals.totalPlans.current}
                delta={totals.totalPlans.current - totals.totalPlans.previous}
              />
              <StatCard
                title="Total TTS Jobs"
                value={
                  totals.ttsJobsCompleted.current + totals.ttsJobsFailed.current
                }
                delta={
                  totals.ttsJobsCompleted.current -
                  totals.ttsJobsCompleted.previous
                }
              />
              <StatCard
                title="Total Sessions"
                value={totals.totalSessions.current}
                delta={
                  totals.totalSessions.current - totals.totalSessions.previous
                }
              />
            </div>
          ) : errorMessage ? (
            <EmptyState message="Core totals could not be loaded." />
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <StatCard title="Total Users" value={0} loading />
              <StatCard title="Total Plans" value={0} loading />
              <StatCard title="Total TTS Jobs" value={0} loading />
              <StatCard title="Total Sessions" value={0} loading />
            </div>
          )}
        </div>

        {/* ── Row 2: Period activity ─────────────────────────────────────── */}
        <div
          role="region"
          aria-label="Period activity"
        >
          {data && totals ? (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <StatCard
                title="New Signups"
                value={totals.newSignups.current}
                delta={totals.newSignups.current - totals.newSignups.previous}
              />
              <StatCard
                title="Active Plans"
                value={totals.activePlans.current}
                delta={totals.activePlans.current - totals.activePlans.previous}
              />
              <StatCard
                title="TTS Failures"
                value={totals.ttsJobsFailed.current}
                delta={
                  totals.ttsJobsFailed.current - totals.ttsJobsFailed.previous
                }
              />
              <StatCard
                title="Avg Session (sec)"
                value={Math.round(totals.avgSessionDurationMs.current / 1000)}
                delta={Math.round(
                  (totals.avgSessionDurationMs.current -
                    totals.avgSessionDurationMs.previous) /
                    1000,
                )}
              />
            </div>
          ) : errorMessage ? (
            <EmptyState message="Period activity metrics could not be loaded." />
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <StatCard title="New Signups" value={0} loading />
              <StatCard title="Active Plans" value={0} loading />
              <StatCard title="TTS Failures" value={0} loading />
              <StatCard title="Avg Session (sec)" value={0} loading />
            </div>
          )}
        </div>

        {/* ── Row 3: Plan Completion Rate ────────────────────────────────── */}
        <div
          role="region"
          aria-label="Completion rates"
        >
          {data && totals ? (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <StatCard
                title="Plan Completion Rate"
                value={totals.planCompletionRate.current}
                valueLabel={`${totals.planCompletionRate.current.toFixed(1)}%`}
                deltaLabel={formatDeltaPercent(
                  totals.planCompletionRate.deltaPercent,
                )}
                deltaIsPositive={
                  (totals.planCompletionRate.deltaPercent ?? 0) >= 0
                }
              />
            </div>
          ) : errorMessage ? (
            <EmptyState message="Plan completion rate could not be loaded." />
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <StatCard title="Plan Completion Rate" value={0} loading />
            </div>
          )}
        </div>
      </div>

      {/* ── Activity Feed ─────────────────────────────────────────────────── */}
      <div className="mt-6">
        <ActivityFeedWidget initialData={activityData} />
      </div>
    </div>
  );
}
