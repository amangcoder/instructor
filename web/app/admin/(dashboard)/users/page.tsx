import { Suspense } from 'react';
import { adminFetch, AdminApiError } from '@/lib/admin-api';
import StatCard from '@/components/admin/StatCard';
import TimeSeriesChart from '@/components/admin/TimeSeriesChart';
import RangePicker from '@/components/admin/RangePicker';
import ChartErrorBoundary from '@/components/admin/ChartErrorBoundary';
import DataTableToggle from '@/components/admin/DataTableToggle';
import CsvExportButton from '@/components/admin/CsvExportButton';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

interface TimeSeriesPoint {
  date: string;
  value: number;
}

interface TimeSeriesRatePoint {
  date: string;
  value: number;
  /** Activation rate as a decimal 0..1 */
  rate: number;
  total: number;
}

interface SignupsTotals {
  total: number;
  avgPerDay: number;
  peakDay: number;
  peakDate: string;
}

interface SignupsResponse {
  series: TimeSeriesPoint[];
  totals: SignupsTotals;
}

interface ActivationTotals {
  totalSignups: number;
  totalActivated: number;
  /** Overall activation rate for the range (decimal 0..1) */
  overallRate: number;
}

interface ActivationResponse {
  series: TimeSeriesRatePoint[];
  totals: ActivationTotals;
}

interface UsersPageProps {
  searchParams: Promise<{ range?: string }>;
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

function getErrorMessage(reason: unknown): string {
  if (reason instanceof AdminApiError) return reason.message;
  if (reason instanceof Error) return reason.message;
  return 'An unexpected error occurred while loading data.';
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * Admin Users Page — server component
 *
 * Renders two independent analytics sections for user metrics:
 *
 *   1. User Signups  — daily signup trend chart + total count StatCard
 *   2. Activation Rate — daily activation % chart + overall rate StatCard
 *
 * Both sections are fetched in parallel via Promise.allSettled so that a
 * failure in one section never crashes the other (REQ-019 / AC-019).
 *
 * The RangePicker updates the ?range= URL param which causes this server
 * component to re-render with fresh data (AC-018).
 */
export default async function AdminUsersPage({ searchParams }: UsersPageProps) {
  const params = await searchParams;
  const range = params.range ?? '30d';

  // ── Parallel fetch with per-section error isolation ────────────────────
  const [signupsResult, activationResult] = await Promise.allSettled([
    adminFetch<SignupsResponse>('/admin/analytics/users/signups', { range }),
    adminFetch<ActivationResponse>('/admin/analytics/users/activation', { range }),
  ]);

  const signupsData =
    signupsResult.status === 'fulfilled' ? signupsResult.value : null;
  const signupsError =
    signupsResult.status === 'rejected'
      ? getErrorMessage(signupsResult.reason)
      : null;

  const activationData =
    activationResult.status === 'fulfilled' ? activationResult.value : null;
  const activationError =
    activationResult.status === 'rejected'
      ? getErrorMessage(activationResult.reason)
      : null;

  // Transform activation series: rate (0..1) → percentage integer for chart
  const activationSeries =
    activationData?.series.map((p) => ({
      ...p,
      ratePct: Math.round(p.rate * 100),
    })) ?? [];

  return (
    <div>
      {/* ── Page header ──────────────────────────────────────────────────── */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
        <h1 className="text-2xl font-bold text-on-surface">Users</h1>
        <div className="flex flex-col sm:flex-row sm:items-center gap-4">
          <Suspense fallback={null}>
            <RangePicker />
          </Suspense>
          <CsvExportButton exportUrl="/api/admin/users/export" filename="users_export" />
        </div>
      </div>

      {/* ── User Signups section ─────────────────────────────────────────── */}
      <section aria-labelledby="signups-heading" className="mb-10">
        <h2
          id="signups-heading"
          className="text-lg font-semibold text-on-surface mb-4"
        >
          User Signups
        </h2>

        {/* Section error — shown without affecting Activation Rate section */}
        {signupsError && (
          <div
            className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-4"
            role="alert"
          >
            <p className="font-medium">Failed to load signups data</p>
            <p className="mt-1">{signupsError}</p>
          </div>
        )}

        {signupsData && (
          <>
            <div
              className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-6"
              role="region"
              aria-label="User signups metrics"
            >
              <StatCard
                title="Total Signups"
                value={signupsData.totals.total}
              />
              <StatCard
                title="Daily Average"
                value={Math.round(signupsData.totals.avgPerDay)}
              />
            </div>
            <div className="rounded-xl bg-surface-container shadow-sm p-6">
              <ChartErrorBoundary>
                <TimeSeriesChart
                  data={signupsData.series}
                  xKey="date"
                  yKey="value"
                />
              </ChartErrorBoundary>
            </div>

            {/* ── Data table toggle for signups ──────────────────────────── */}
            <div className="mt-4">
              <DataTableToggle
                data={signupsData.series}
                columns={[
                  { key: 'date', label: 'Date' },
                  { key: 'value', label: 'Signups' },
                ]}
              />
            </div>
          </>
        )}
      </section>

      {/* ── Activation Rate section ──────────────────────────────────────── */}
      <section aria-labelledby="activation-heading" className="mb-10">
        <h2
          id="activation-heading"
          className="text-lg font-semibold text-on-surface mb-4"
        >
          Activation Rate
        </h2>

        {/* Section error — shown without affecting User Signups section */}
        {activationError && (
          <div
            className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-4"
            role="alert"
          >
            <p className="font-medium">Failed to load activation data</p>
            <p className="mt-1">{activationError}</p>
          </div>
        )}

        {activationData && (
          <>
            <div
              className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-6"
              role="region"
              aria-label="Activation rate metrics"
            >
              <StatCard
                title="Activation Rate %"
                value={Math.round(activationData.totals.overallRate * 100)}
              />
              <StatCard
                title="Total Activated"
                value={activationData.totals.totalActivated}
              />
            </div>
            <div className="rounded-xl bg-surface-container shadow-sm p-6">
              <ChartErrorBoundary>
                <TimeSeriesChart
                  data={activationSeries}
                  xKey="date"
                  yKey="ratePct"
                  color="#10b981"
                />
              </ChartErrorBoundary>
            </div>

            {/* ── Data table toggle for activation rate ──────────────────── */}
            <div className="mt-4">
              <DataTableToggle
                data={activationSeries}
                columns={[
                  { key: 'date', label: 'Date' },
                  { key: 'ratePct', label: 'Activation Rate (%)' },
                  { key: 'value', label: 'Activated Count' },
                  { key: 'total', label: 'Total Signups' },
                ]}
              />
            </div>
          </>
        )}
      </section>
    </div>
  );
}
