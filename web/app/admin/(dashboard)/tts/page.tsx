import { Suspense } from 'react';
import { adminFetch, AdminApiError } from '@/lib/admin-api';
import StatCard from '@/components/admin/StatCard';
import RangePicker from '@/components/admin/RangePicker';
import TimeSeriesChart from '@/components/admin/TimeSeriesChart';
import ChartErrorBoundary from '@/components/admin/ChartErrorBoundary';
import TtsHealthBanner from '@/components/admin/TtsHealthBanner';
import DataTableToggle from '@/components/admin/DataTableToggle';
import type {
  TtsVolumeResponse,
  TtsErrorsResponse,
} from '@/types/analytics';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

interface TtsPageProps {
  searchParams: Promise<{ range?: string }>;
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

function errorMessage(err: unknown): string {
  if (err instanceof AdminApiError) return err.message;
  return 'An unexpected error occurred while loading data.';
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * Admin TTS Page — server component
 *
 * Fetches TTS volume and error data in parallel via Promise.allSettled.
 * Renders:
 *   0. TtsHealthBanner (client) — real-time provider health, polls every 60s
 *   1. TTS Volume — TimeSeriesChart (daily request counts) + provider/voice
 *      table + DataTableToggle for raw series data
 *   2. TTS Errors — TimeSeriesChart (daily error counts) + error rate StatCard
 *      + top error messages table + DataTableToggle for raw series data
 *
 * Charts are wrapped in ChartErrorBoundary for render-error safety.
 * RangePicker is wrapped in Suspense (reads useSearchParams).
 */
export default async function AdminTtsPage({ searchParams }: TtsPageProps) {
  const params = await searchParams;
  const range = params.range ?? '30d';

  // ── Parallel fetch ────────────────────────────────────────────────────────
  const [volumeResult, errorsResult] = await Promise.allSettled([
    adminFetch<TtsVolumeResponse>('/admin/analytics/tts/volume', { range }),
    adminFetch<TtsErrorsResponse>('/admin/analytics/tts/errors', { range }),
  ]);

  const volumeData =
    volumeResult.status === 'fulfilled' ? volumeResult.value : null;
  const volumeError =
    volumeResult.status === 'rejected'
      ? errorMessage(volumeResult.reason)
      : null;

  const errorsData =
    errorsResult.status === 'fulfilled' ? errorsResult.value : null;
  const errorsError =
    errorsResult.status === 'rejected'
      ? errorMessage(errorsResult.reason)
      : null;

  // ── Derived values ────────────────────────────────────────────────────────
  const errorRatePct = errorsData
    ? Math.round(errorsData.totals.overallErrorRate * 100)
    : 0;

  // ── Column definitions for DataTableToggle ────────────────────────────────
  const volumeSeriesColumns = [
    { key: 'date', label: 'Date' },
    { key: 'value', label: 'Total Requests' },
  ];

  const errorsSeriesColumns = [
    { key: 'date', label: 'Date' },
    { key: 'value', label: 'Error Count' },
    { key: 'errorRatePct', label: 'Error Rate (%)' },
  ];

  // Map series to plain records for DataTableToggle (errorRate as %)
  const volumeSeriesRows: Record<string, unknown>[] = volumeData
    ? volumeData.series.map((pt) => ({ date: pt.date, value: pt.value }))
    : [];

  const errorsSeriesRows: Record<string, unknown>[] = errorsData
    ? errorsData.series.map((pt) => ({
        date: pt.date,
        value: pt.value,
        errorRatePct: `${(pt.errorRate * 100).toFixed(1)}%`,
      }))
    : [];

  return (
    <div>
      {/* ── Page header ──────────────────────────────────────────────────── */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
        <h1 className="text-2xl font-bold text-on-surface">TTS Analytics</h1>
        <Suspense fallback={null}>
          <RangePicker />
        </Suspense>
      </div>

      {/* ── TTS Health Banner ─────────────────────────────────────────────── */}
      <TtsHealthBanner />

      {/* ══════════════════════════════════════════════════════════════════ */}
      {/* TTS Volume Section                                                 */}
      {/* ══════════════════════════════════════════════════════════════════ */}
      <section aria-labelledby="tts-volume-heading" className="mb-10">
        <h2
          id="tts-volume-heading"
          className="text-lg font-semibold text-on-surface mb-4"
        >
          TTS Volume
        </h2>

        {/* Error state */}
        {volumeError && (
          <div
            className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-4"
            role="alert"
          >
            <p className="font-medium">Failed to load TTS volume data</p>
            <p className="mt-1">{volumeError}</p>
          </div>
        )}

        {volumeData && (
          <>
            {/* Daily request count chart */}
            <div className="rounded-xl bg-surface-container shadow-sm p-6 mb-4">
              <p className="text-sm font-medium text-on-surface-variant mb-3">
                Daily Requests
              </p>
              <ChartErrorBoundary key={range}>
                <TimeSeriesChart
                  data={volumeData.series}
                  xKey="date"
                  yKey="value"
                  color="#3b82f6"
                />
              </ChartErrorBoundary>
            </div>

            {/* Provider / voice breakdown table */}
            <div className="rounded-xl bg-surface-container shadow-sm overflow-hidden">
              <div className="px-6 py-4 border-b border-outline-variant">
                <p className="text-sm font-semibold text-on-surface">
                  Breakdown by Provider &amp; Voice
                </p>
                <p className="text-xs text-on-surface-variant mt-0.5">
                  Total completed:{' '}
                  <span className="font-medium tabular-nums">
                    {volumeData.totals.totalCompleted.toLocaleString()}
                  </span>
                </p>
              </div>
              <div className="overflow-x-auto">
                <table
                  className="w-full text-sm"
                  aria-label="TTS request breakdown by provider and voice"
                >
                  <thead>
                    <tr className="border-b border-outline-variant bg-surface-container-high">
                      <th
                        scope="col"
                        className="px-6 py-3 text-left text-xs font-semibold text-on-surface-variant uppercase tracking-wider"
                      >
                        Provider
                      </th>
                      <th
                        scope="col"
                        className="px-6 py-3 text-left text-xs font-semibold text-on-surface-variant uppercase tracking-wider"
                      >
                        Voice ID
                      </th>
                      <th
                        scope="col"
                        className="px-6 py-3 text-right text-xs font-semibold text-on-surface-variant uppercase tracking-wider"
                      >
                        Request Count
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {/* Provider-level rows from byProvider aggregate */}
                    {Object.entries(volumeData.totals.byProvider).map(
                      ([provider, count]) => (
                        <tr
                          key={`provider-${provider}`}
                          className="border-b border-outline-variant/50 hover:bg-primary/5 transition-colors"
                        >
                          <td className="px-6 py-3 font-medium text-on-surface">
                            {provider}
                          </td>
                          <td className="px-6 py-3 text-on-surface-variant italic">
                            (all voices)
                          </td>
                          <td className="px-6 py-3 text-right tabular-nums font-medium text-on-surface">
                            {count.toLocaleString()}
                          </td>
                        </tr>
                      ),
                    )}
                    {/* Voice-level rows from topVoices */}
                    {volumeData.totals.topVoices.map(({ voiceId, count }) => (
                      <tr
                        key={`voice-${voiceId}`}
                        className="border-b border-outline-variant/50 hover:bg-primary/5 transition-colors last:border-b-0"
                      >
                        <td className="px-6 py-3 text-on-surface-variant">
                          —
                        </td>
                        <td className="px-6 py-3 font-mono text-xs text-on-surface">
                          {voiceId}
                        </td>
                        <td className="px-6 py-3 text-right tabular-nums font-medium text-on-surface">
                          {count.toLocaleString()}
                        </td>
                      </tr>
                    ))}
                    {/* Empty state */}
                    {Object.keys(volumeData.totals.byProvider).length === 0 &&
                      volumeData.totals.topVoices.length === 0 && (
                        <tr>
                          <td
                            colSpan={3}
                            className="px-6 py-8 text-center text-on-surface-variant text-sm"
                          >
                            No TTS volume data for this period.
                          </td>
                        </tr>
                      )}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Daily volume series raw data table */}
            <div className="mt-3">
              <DataTableToggle
                data={volumeSeriesRows}
                columns={volumeSeriesColumns}
              />
            </div>
          </>
        )}
      </section>

      {/* ══════════════════════════════════════════════════════════════════ */}
      {/* TTS Errors Section                                                 */}
      {/* ══════════════════════════════════════════════════════════════════ */}
      <section aria-labelledby="tts-errors-heading">
        <h2
          id="tts-errors-heading"
          className="text-lg font-semibold text-on-surface mb-4"
        >
          TTS Errors
        </h2>

        {/* Error state */}
        {errorsError && (
          <div
            className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-4"
            role="alert"
          >
            <p className="font-medium">Failed to load TTS error data</p>
            <p className="mt-1">{errorsError}</p>
          </div>
        )}

        {errorsData && (
          <>
            {/* Error rate stat card + chart */}
            <div className="grid grid-cols-1 lg:grid-cols-4 gap-4 mb-4">
              <div className="lg:col-span-1">
                <StatCard
                  title="Error Rate"
                  value={errorRatePct}
                  delta={undefined}
                />
                <p className="text-xs text-on-surface-variant mt-1 px-1">
                  % of TTS jobs failed
                </p>
              </div>
              <div className="lg:col-span-3 rounded-xl bg-surface-container shadow-sm p-6">
                <p className="text-sm font-medium text-on-surface-variant mb-3">
                  Daily Error Count
                </p>
                <ChartErrorBoundary key={range}>
                  <TimeSeriesChart
                    data={errorsData.series}
                    xKey="date"
                    yKey="value"
                    color="#ef4444"
                  />
                </ChartErrorBoundary>
              </div>
            </div>

            {/* Top error messages table */}
            <div className="rounded-xl bg-surface-container shadow-sm overflow-hidden">
              <div className="px-6 py-4 border-b border-outline-variant">
                <p className="text-sm font-semibold text-on-surface">
                  Top Error Messages
                </p>
                <p className="text-xs text-on-surface-variant mt-0.5">
                  Total errors:{' '}
                  <span className="font-medium tabular-nums">
                    {errorsData.totals.totalErrors.toLocaleString()}
                  </span>
                </p>
              </div>
              <div className="overflow-x-auto">
                <table
                  className="w-full text-sm"
                  aria-label="Top TTS error messages"
                >
                  <thead>
                    <tr className="border-b border-outline-variant bg-surface-container-high">
                      <th
                        scope="col"
                        className="px-6 py-3 text-left text-xs font-semibold text-on-surface-variant uppercase tracking-wider"
                      >
                        Error Message
                      </th>
                      <th
                        scope="col"
                        className="px-6 py-3 text-right text-xs font-semibold text-on-surface-variant uppercase tracking-wider"
                      >
                        Count
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {errorsData.totals.topErrors.map((err, idx) => (
                      <tr
                        key={idx}
                        className="border-b border-outline-variant/50 hover:bg-primary/5 transition-colors last:border-b-0"
                      >
                        <td className="px-6 py-3 text-on-surface font-mono text-xs max-w-xl truncate">
                          {err.message}
                        </td>
                        <td className="px-6 py-3 text-right tabular-nums font-medium text-error">
                          {err.count.toLocaleString()}
                        </td>
                      </tr>
                    ))}
                    {errorsData.totals.topErrors.length === 0 && (
                      <tr>
                        <td
                          colSpan={2}
                          className="px-6 py-8 text-center text-on-surface-variant text-sm"
                        >
                          No errors recorded for this period.
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Daily error series raw data table */}
            <div className="mt-3">
              <DataTableToggle
                data={errorsSeriesRows}
                columns={errorsSeriesColumns}
              />
            </div>
          </>
        )}
      </section>
    </div>
  );
}
