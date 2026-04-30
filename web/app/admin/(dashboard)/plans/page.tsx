import { Suspense } from 'react';
import { adminFetch, AdminApiError } from '@/lib/admin-api';
import StatCard from '@/components/admin/StatCard';
import FunnelChart, { FunnelStage } from '@/components/admin/FunnelChart';
import DistributionBarChart from '@/components/admin/DistributionBarChart';
import DataTableToggle, { DataTableColumn } from '@/components/admin/DataTableToggle';
import RangePicker from '@/components/admin/RangePicker';
import ChartErrorBoundary from '@/components/admin/ChartErrorBoundary';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

type PlanLifecycleStage =
  | 'created'
  | 'tts_started'
  | 'tts_completed'
  | 'activated'
  | 'session_completed';

interface ApiFunnelStage {
  stage: PlanLifecycleStage;
  label: string;
  count: number;
  percentOfTop: number;
  dropOffPercent: number | null;
}

interface FunnelTotals {
  totalCreated: number;
  overallConversionPercent: number;
  activated: number;
  sessionCompleted: number;
}

interface FunnelResponse {
  series: ApiFunnelStage[];
  totals: FunnelTotals;
}

interface PlansPerUserBucket {
  bucket: string;
  userCount: number;
}

interface PlanUsageTotals {
  usersWithPlans: number;
  usersWithoutPlans: number;
  avgPlansPerUser: number;
  activePlans: number;
  dormantPlans: number;
  totalPlans: number;
}

interface PlanUsageResponse {
  series: PlansPerUserBucket[];
  totals: PlanUsageTotals;
}

interface PlansPageProps {
  searchParams: Promise<{ range?: string }>;
}

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

/**
 * The funnel stages to surface in the Plans Funnel chart, in order.
 * Only these three lifecycle stages are shown (REQ-017).
 */
const FUNNEL_STAGE_ORDER: PlanLifecycleStage[] = [
  'created',
  'activated',
  'tts_completed',
];

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

function getErrorMessage(reason: unknown): string {
  if (reason instanceof AdminApiError) return reason.message;
  if (reason instanceof Error) return reason.message;
  return 'An unexpected error occurred while loading data.';
}

/**
 * Filter and order the funnel series to the three stages shown in the chart.
 * Maps API FunnelStage to the FunnelChart component's FunnelStage interface.
 */
function buildFunnelStages(series: ApiFunnelStage[]): FunnelStage[] {
  return FUNNEL_STAGE_ORDER.flatMap((stageName) => {
    const found = series.find((s) => s.stage === stageName);
    return found ? [{ name: found.label, value: found.count }] : [];
  });
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * Admin Plans Page — server component
 *
 * Renders two independent analytics sections for plan metrics:
 *
 *   1. Plan Funnel   — FunnelChart (Created → Activated → TTS Completed)
 *                      with drop-off percentages between stages
 *   2. Plan Usage    — DistributionBarChart (plans-per-user buckets)
 *                      + StatCards for active / dormant plan counts
 *
 * Both sections are fetched in parallel via Promise.allSettled so that a
 * failure in one section never crashes the other (REQ-019 / AC-019).
 *
 * The RangePicker updates the ?range= URL param which causes this server
 * component to re-render with fresh data (AC-018).
 */
export default async function AdminPlansPage({ searchParams }: PlansPageProps) {
  const params = await searchParams;
  const range = params.range ?? '30d';

  // ── Parallel fetch with per-section error isolation ────────────────────
  const [funnelResult, usageResult] = await Promise.allSettled([
    adminFetch<FunnelResponse>('/admin/analytics/plans/funnel', { range }),
    adminFetch<PlanUsageResponse>('/admin/analytics/plans/usage', { range }),
  ]);

  const funnelData =
    funnelResult.status === 'fulfilled' ? funnelResult.value : null;
  const funnelError =
    funnelResult.status === 'rejected'
      ? getErrorMessage(funnelResult.reason)
      : null;

  const usageData =
    usageResult.status === 'fulfilled' ? usageResult.value : null;
  const usageError =
    usageResult.status === 'rejected'
      ? getErrorMessage(usageResult.reason)
      : null;

  // Build FunnelChart-compatible data from the API series
  const funnelStages: FunnelStage[] = funnelData
    ? buildFunnelStages(funnelData.series)
    : [];

  // Calculate Plan Completion Rate from funnel data
  // Ratio of sessions completed to plans activated, expressed as percentage
  const planCompletionRate =
    funnelData && funnelData.totals.activated > 0
      ? (funnelData.totals.sessionCompleted / funnelData.totals.activated) * 100
      : 0;

  return (
    <div>
      {/* ── Page header ──────────────────────────────────────────────────── */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
        <h1 className="text-2xl font-bold text-on-surface">Plans</h1>
        <Suspense fallback={null}>
          <RangePicker />
        </Suspense>
      </div>

      {/* ── Plan Funnel section ──────────────────────────────────────────── */}
      <section aria-labelledby="funnel-heading" className="mb-10">
        <h2
          id="funnel-heading"
          className="text-lg font-semibold text-on-surface mb-4"
        >
          Plan Funnel
        </h2>

        {/* Section error — shown without affecting Plan Usage section */}
        {funnelError && (
          <div
            className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-4"
            role="alert"
          >
            <p className="font-medium">Failed to load funnel data</p>
            <p className="mt-1">{funnelError}</p>
          </div>
        )}

        {funnelData && (
          <>
            <div
              className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-6"
              role="region"
              aria-label="Plan funnel metrics"
            >
              <StatCard
                title="Plan Completion Rate"
                value={Math.round(planCompletionRate * 10) / 10}
                valueLabel={`${planCompletionRate.toFixed(1)}%`}
              />
              <StatCard
                title="Total Created"
                value={funnelData.totals.totalCreated}
              />
              <StatCard
                title="Overall Conversion %"
                value={Math.round(funnelData.totals.overallConversionPercent)}
              />
            </div>
            <div className="rounded-xl bg-surface-container shadow-sm p-6 mb-6">
              <ChartErrorBoundary key={range}>
                <FunnelChart data={funnelStages} />
              </ChartErrorBoundary>
            </div>
            <DataTableToggle
              data={funnelData.series}
              columns={[
                { key: 'label', label: 'Stage' },
                { key: 'count', label: 'Count' },
                { key: 'percentOfTop', label: '% of Top' },
                { key: 'dropOffPercent', label: 'Drop-off %' },
              ]}
            />
          </>
        )}
      </section>

      {/* ── Plan Usage section ───────────────────────────────────────────── */}
      <section aria-labelledby="usage-heading" className="mb-10">
        <h2
          id="usage-heading"
          className="text-lg font-semibold text-on-surface mb-4"
        >
          Plan Usage
        </h2>

        {/* Section error — shown without affecting Plan Funnel section */}
        {usageError && (
          <div
            className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-4"
            role="alert"
          >
            <p className="font-medium">Failed to load usage data</p>
            <p className="mt-1">{usageError}</p>
          </div>
        )}

        {usageData && (
          <>
            <div
              className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6"
              role="region"
              aria-label="Plan usage metrics"
            >
              <StatCard
                title="Active Plans"
                value={usageData.totals.activePlans}
              />
              <StatCard
                title="Dormant Plans"
                value={usageData.totals.dormantPlans}
              />
              <StatCard
                title="Total Plans"
                value={usageData.totals.totalPlans}
              />
              <StatCard
                title="Users With Plans"
                value={usageData.totals.usersWithPlans}
              />
            </div>
            <div className="rounded-xl bg-surface-container shadow-sm p-6 mb-6">
              <p className="text-sm font-medium text-on-surface-variant mb-4">
                Plans per User Distribution
              </p>
              <ChartErrorBoundary key={range}>
                <DistributionBarChart
                  data={usageData.series}
                  xKey="bucket"
                  yKey="userCount"
                  color="#6366f1"
                />
              </ChartErrorBoundary>
            </div>
            <DataTableToggle
              data={usageData.series}
              columns={[
                { key: 'bucket', label: 'Plans per User' },
                { key: 'userCount', label: 'User Count' },
              ]}
            />
          </>
        )}
      </section>
    </div>
  );
}
