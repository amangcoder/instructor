import { Suspense } from 'react';
import { adminFetch, AdminApiError } from '@/lib/admin-api';
import StatCard from '@/components/admin/StatCard';
import RangePicker from '@/components/admin/RangePicker';
import ChartErrorBoundary from '@/components/admin/ChartErrorBoundary';
import StreakBarChart from '@/components/admin/StreakBarChart';
import TimeSeriesChart from '@/components/admin/TimeSeriesChart';
import DataTableToggle from '@/components/admin/DataTableToggle';
import EmptyState from '@/components/admin/EmptyState';
import type { StreaksResponse } from '@/types/analytics';
import type { RetentionResponse, ActiveUsersResponse } from '@/types/retention';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

interface EngagementPageProps {
  searchParams?: Promise<{ range?: string }>;
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/** Extract a user-readable error message from an unknown thrown value. */
function getErrorMessage(err: unknown): string {
  if (err instanceof AdminApiError) return err.message;
  return 'An unexpected error occurred while loading engagement data.';
}

/**
 * Merge DAU / WAU / MAU time-series arrays into a single array of data points
 * keyed by date. All three series are aligned on their dates so Recharts can
 * render them as separate lines on the same chart.
 *
 * Each resulting record has the shape: { date, dau?, wau?, mau? }
 */
function mergeActiveUsers(
  active: ActiveUsersResponse,
): Record<string, unknown>[] {
  const byDate = new Map<string, Record<string, unknown>>();

  for (const pt of active.dau) {
    byDate.set(pt.date, { date: pt.date, dau: pt.value });
  }
  for (const pt of active.wau) {
    const existing = byDate.get(pt.date) ?? { date: pt.date };
    byDate.set(pt.date, { ...existing, wau: pt.value });
  }
  for (const pt of active.mau) {
    const existing = byDate.get(pt.date) ?? { date: pt.date };
    byDate.set(pt.date, { ...existing, mau: pt.value });
  }

  return Array.from(byDate.values()).sort((a, b) =>
    String(a.date).localeCompare(String(b.date)),
  );
}

// ────────────────────────────────────────────────────────────────────────────
// RetentionStatCard — local display component
// ────────────────────────────────────────────────────────────────────────────

/**
 * RetentionStatCard
 *
 * Renders a stat card styled identically to the shared StatCard but displays
 * retention rates as formatted percentages (e.g. "18.4%") and deltas in
 * percentage points (e.g. "+1.2pp"). The shared StatCard only supports raw
 * numeric values so this local variant handles the custom format required
 * by REQ-004 / AC-005.
 *
 * Accessibility:
 *  - role="region" with aria-label so screen readers identify the card
 *  - Decorative arrow indicator is aria-hidden
 *  - Delta paragraph carries a descriptive aria-label
 */
function RetentionStatCard({
  title,
  rateDecimal,
  deltaPercent,
}: {
  title: string;
  /** Retention rate as a decimal (0..1) — displayed as e.g. "18.4%" */
  rateDecimal: number;
  /** Percentage point delta vs prior cohort — displayed as e.g. "+1.2pp" */
  deltaPercent: number | null;
}) {
  const rateFormatted = `${(rateDecimal * 100).toFixed(1)}%`;
  const isPositive = deltaPercent != null && deltaPercent >= 0;
  const deltaFormatted =
    deltaPercent != null
      ? `${isPositive ? '+' : ''}${deltaPercent.toFixed(1)}pp`
      : null;

  return (
    <div
      className="rounded-xl bg-surface-container shadow-sm p-6"
      role="region"
      aria-label={title}
    >
      {/* Title */}
      <p className="text-sm font-medium text-on-surface-variant">{title}</p>

      {/* Rate value */}
      <p className="text-3xl font-bold text-on-surface mt-1 tabular-nums">
        {rateFormatted}
      </p>

      {/* Delta indicator */}
      {deltaFormatted !== null && (
        <p
          className={`text-sm font-medium mt-2 flex items-center gap-1 ${
            isPositive ? 'text-success' : 'text-error'
          }`}
          aria-label={`${isPositive ? 'Increase' : 'Decrease'} of ${Math.abs(deltaPercent!).toFixed(1)} percentage points from previous cohort`}
        >
          <span aria-hidden="true">{isPositive ? '▲' : '▼'}</span>
          <span>{deltaFormatted}</span>
        </p>
      )}
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * Admin Engagement Page — server component
 *
 * Fetches three engagement data sources in parallel (Promise.allSettled so
 * a single failure does not block the others):
 *
 *   1. /admin/analytics/engagement/retention  — D7 / D30 cohort rates (no range)
 *   2. /admin/analytics/engagement/active-users?range=  — DAU / WAU / MAU series
 *   3. /admin/analytics/engagement/streaks  — streak distribution (no range)
 *
 * Renders four sections:
 *   • Cohort Retention — two RetentionStatCards (D7 + D30)
 *   • Active Users — RangePicker + multi-series TimeSeriesChart + DataTableToggle
 *   • Streak metrics — StatCards for active users + avg length
 *   • Streak distribution — StreakBarChart + DataTableToggle
 *
 * Per AC-012 each chart shows an EmptyState when its data array is empty.
 * The DAU/WAU/MAU chart is wrapped in ChartErrorBoundary per TASK-015 spec.
 * RangePicker is present only for the active-users section (streaks has no
 * range parameter).
 */
export default async function AdminEngagementPage({
  searchParams,
}: EngagementPageProps = {}) {
  const params = searchParams ? await searchParams : {};
  const range = params.range ?? '30d';

  // ── Parallel fetch ─────────────────────────────────────────────────────────
  const [retentionResult, activeUsersResult, streaksResult] =
    await Promise.allSettled([
      adminFetch<RetentionResponse>(
        '/admin/analytics/engagement/retention',
      ),
      adminFetch<ActiveUsersResponse>(
        '/admin/analytics/engagement/active-users',
        { range },
      ),
      adminFetch<StreaksResponse>('/admin/analytics/engagement/streaks'),
    ]);

  // ── Unwrap results ─────────────────────────────────────────────────────────
  const retentionData =
    retentionResult.status === 'fulfilled' ? retentionResult.value : null;
  const retentionError =
    retentionResult.status === 'rejected'
      ? getErrorMessage(retentionResult.reason)
      : null;

  const activeUsersData =
    activeUsersResult.status === 'fulfilled' ? activeUsersResult.value : null;
  const activeUsersError =
    activeUsersResult.status === 'rejected'
      ? getErrorMessage(activeUsersResult.reason)
      : null;

  const streaksData =
    streaksResult.status === 'fulfilled' ? streaksResult.value : null;
  const streaksError =
    streaksResult.status === 'rejected'
      ? getErrorMessage(streaksResult.reason)
      : null;

  // ── Derived values ─────────────────────────────────────────────────────────
  const mergedActiveUsersData = activeUsersData
    ? mergeActiveUsers(activeUsersData)
    : [];
  const isActiveUsersEmpty = mergedActiveUsersData.length === 0;

  const streakTableData: Record<string, unknown>[] = (
    streaksData?.series ?? []
  ).map((b) => ({
    bucket: b.bucket,
    min: b.min,
    max: b.max ?? '∞',
    userCount: b.userCount,
  }));

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <div>
      {/* ── Page header ──────────────────────────────────────────────────── */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-on-surface">Engagement</h1>
        <p className="text-sm text-on-surface-variant mt-1">
          User retention, activity trends, and streak distribution
        </p>
      </div>

      {/* ══════════════════════════════════════════════════════════════════ */}
      {/* Cohort Retention Section (no RangePicker)                         */}
      {/* ══════════════════════════════════════════════════════════════════ */}
      <section aria-labelledby="retention-heading" className="mb-10">
        <h2
          id="retention-heading"
          className="text-lg font-semibold text-on-surface mb-4"
        >
          Cohort Retention
        </h2>

        {/* Retention error state */}
        {retentionError && (
          <div
            className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-4"
            role="alert"
          >
            <p className="font-medium">Failed to load retention data</p>
            <p className="mt-1">{retentionError}</p>
          </div>
        )}

        {/* Retention stat cards */}
        {retentionData && (
          <div
            className="grid grid-cols-1 sm:grid-cols-2 gap-4"
            role="region"
            aria-label="Retention metrics"
          >
            <RetentionStatCard
              title="D7 Retention"
              rateDecimal={retentionData.d7.rate}
              deltaPercent={retentionData.d7.deltaPercent}
            />
            <RetentionStatCard
              title="D30 Retention"
              rateDecimal={retentionData.d30.rate}
              deltaPercent={retentionData.d30.deltaPercent}
            />
          </div>
        )}
      </section>

      {/* ══════════════════════════════════════════════════════════════════ */}
      {/* Active Users Section (with RangePicker)                           */}
      {/* ══════════════════════════════════════════════════════════════════ */}
      <section aria-labelledby="active-users-heading" className="mb-10">
        {/* Section header + RangePicker */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-4">
          <h2
            id="active-users-heading"
            className="text-lg font-semibold text-on-surface"
          >
            Daily / Weekly / Monthly Active Users
          </h2>
          {/* RangePicker wrapped in Suspense — reads useSearchParams() */}
          <Suspense fallback={null}>
            <RangePicker />
          </Suspense>
        </div>

        {/* Active users error state */}
        {activeUsersError && (
          <div
            className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-4"
            role="alert"
          >
            <p className="font-medium">Failed to load active users data</p>
            <p className="mt-1">{activeUsersError}</p>
          </div>
        )}

        {/* Chart + DataTableToggle */}
        {activeUsersData && (
          <>
            <div className="rounded-xl bg-surface-container shadow-sm p-6 mb-4">
              {isActiveUsersEmpty ? (
                <EmptyState message="No data for this period." />
              ) : (
                <ChartErrorBoundary key={range}>
                  <TimeSeriesChart
                    data={mergedActiveUsersData}
                    xKey="date"
                    title="Daily, Weekly, and Monthly Active Users"
                    series={[
                      { dataKey: 'dau', color: '#3b82f6', name: 'DAU' },
                      { dataKey: 'wau', color: '#f97316', name: 'WAU' },
                      { dataKey: 'mau', color: '#22c55e', name: 'MAU' },
                    ]}
                  />
                </ChartErrorBoundary>
              )}
            </div>

            {/* DataTableToggle only shown when data is available */}
            {!isActiveUsersEmpty && (
              <DataTableToggle
                data={mergedActiveUsersData}
                columns={[
                  { key: 'date', label: 'Date' },
                  { key: 'dau', label: 'DAU' },
                  { key: 'wau', label: 'WAU' },
                  { key: 'mau', label: 'MAU' },
                ]}
              />
            )}
          </>
        )}
      </section>

      {/* ══════════════════════════════════════════════════════════════════ */}
      {/* Streak Section (no RangePicker)                                   */}
      {/* ══════════════════════════════════════════════════════════════════ */}

      {/* Streak error state */}
      {streaksError && (
        <div
          className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-6"
          role="alert"
        >
          <p className="font-medium">Failed to load streak data</p>
          <p className="mt-1">{streaksError}</p>
        </div>
      )}

      {streaksData && (
        <>
          {/* Streak stat cards */}
          <div
            className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8"
            role="region"
            aria-label="Streak metrics"
          >
            <StatCard
              title="Active Streak Users"
              value={streaksData.totals.activeStreakUsers}
            />
            <StatCard
              title="Average Streak Length (days)"
              value={Math.round(streaksData.totals.avgStreak)}
            />
          </div>

          {/* Streak distribution chart */}
          <section aria-labelledby="streak-distribution-heading">
            <h2
              id="streak-distribution-heading"
              className="text-lg font-semibold text-on-surface mb-4"
            >
              Streak Length Distribution
            </h2>

            <div className="rounded-xl bg-surface-container shadow-sm p-6 mb-4">
              {streaksData.series.length === 0 ? (
                <EmptyState message="No data for this period." />
              ) : (
                <ChartErrorBoundary key="default">
                  <StreakBarChart data={streaksData.series} />
                </ChartErrorBoundary>
              )}
            </div>

            {/* DataTableToggle for streak distribution */}
            {streaksData.series.length > 0 && (
              <DataTableToggle
                data={streakTableData}
                columns={[
                  { key: 'bucket', label: 'Streak Bucket' },
                  { key: 'min', label: 'Min (days)' },
                  { key: 'max', label: 'Max (days)' },
                  { key: 'userCount', label: 'Users' },
                ]}
              />
            )}
          </section>
        </>
      )}

      {/* ── Loading skeleton (when streak data and no error) ────────────── */}
      {!streaksData && !streaksError && (
        <div
          className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8"
          role="region"
          aria-label="Loading engagement metrics"
        >
          <StatCard title="Active Streak Users" value={0} loading />
          <StatCard title="Average Streak Length (days)" value={0} loading />
        </div>
      )}
    </div>
  );
}
