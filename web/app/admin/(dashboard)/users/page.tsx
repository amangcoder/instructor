import { Suspense } from 'react';
import { adminFetch, AdminApiError } from '@/lib/admin-api';
import StatCard from '@/components/admin/StatCard';
import TimeSeriesChart from '@/components/admin/TimeSeriesChart';
import RangePicker from '@/components/admin/RangePicker';
import ChartErrorBoundary from '@/components/admin/ChartErrorBoundary';
import DataTableToggle from '@/components/admin/DataTableToggle';
import CsvExportButton from '@/components/admin/CsvExportButton';
import ContentTabBar from '@/components/admin/ContentTabBar';
import UsersListSection from '@/components/admin/UsersListSection';
import DeletionRequestsTable from '@/components/admin/DeletionRequestsTable';
import EmptyState from '@/components/admin/EmptyState';
import type { PendingCountResponse, DeletionRequestListResponse } from '@/types/deletion-requests';

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
  overallRate: number;
}

interface ActivationResponse {
  series: TimeSeriesRatePoint[];
  totals: ActivationTotals;
}

interface UsersPageProps {
  searchParams: Promise<{ range?: string; tab?: string; search?: string; page?: string; pageSize?: string }>;
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
 * Admin Users Page — server component with tabbed layout
 *
 * Three tabs:
 *  1. Analytics — signups + activation rate sections
 *  2. User List — UsersListSection component
 *  3. Deletion Requests — DeletionRequestsTable with amber badge
 */
export default async function AdminUsersPage({ searchParams }: UsersPageProps) {
  const params = await searchParams;
  const range = params.range ?? '30d';
  const activeTab = params.tab ?? 'analytics';

  // Fetch data in parallel
  const [signupsResult, activationResult, pendingCountResult, deletionResult] = await Promise.allSettled([
    adminFetch<SignupsResponse>('/admin/analytics/users/signups', { range }),
    adminFetch<ActivationResponse>('/admin/analytics/users/activation', { range }),
    adminFetch<PendingCountResponse>('/admin/analytics/deletion-requests/pending-count'),
    activeTab === 'deletion-requests'
      ? adminFetch<DeletionRequestListResponse>('/admin/analytics/deletion-requests', {
          query: {
            page: parseInt(params.page ?? '1', 10) || 1,
            pageSize: parseInt(params.pageSize ?? '25', 10) || 25,
            search: params.search || undefined,
          },
        })
      : Promise.resolve(null),
  ]);

  const signupsData = signupsResult.status === 'fulfilled' ? signupsResult.value : null;
  const signupsError = signupsResult.status === 'rejected' ? getErrorMessage(signupsResult.reason) : null;

  const activationData = activationResult.status === 'fulfilled' ? activationResult.value : null;
  const activationError = activationResult.status === 'rejected' ? getErrorMessage(activationResult.reason) : null;

  const pendingDeletionCount = pendingCountResult.status === 'fulfilled' ? (pendingCountResult.value?.count ?? 0) : 0;

  const deletionData = deletionResult.status === 'fulfilled' ? deletionResult.value : null;
  const deletionError = deletionResult.status === 'rejected' ? getErrorMessage(deletionResult.reason) : null;

  const activationSeries =
    activationData?.series.map((p) => ({
      ...p,
      ratePct: Math.round(p.rate * 100),
    })) ?? [];

  const tabs = [
    { id: 'analytics', label: 'Analytics' },
    { id: 'user-list', label: 'User List' },
    {
      id: 'deletion-requests',
      label: 'Deletion Requests',
      badge: pendingDeletionCount > 0 ? pendingDeletionCount : undefined,
      badgeColor: 'amber' as const,
    },
  ];

  return (
    <div>
      {/* Page header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
        <h1 className="text-2xl font-bold text-white">Users</h1>
        <div className="flex flex-col sm:flex-row sm:items-center gap-4">
          {activeTab === 'analytics' && (
            <Suspense fallback={null}>
              <RangePicker />
            </Suspense>
          )}
          {activeTab === 'user-list' && (
            <CsvExportButton exportUrl="/api/admin/users/export" filename="users_export" />
          )}
        </div>
      </div>

      {/* Tab bar + content */}
      <ContentTabBar tabs={tabs} defaultTab={activeTab}>
        {(tab) => (
          <div className="mt-6">
            {tab === 'analytics' && (
              <div className="space-y-10">
                <section aria-labelledby="signups-heading">
                  <h2 id="signups-heading" className="text-lg font-semibold text-white mb-4">User Signups</h2>
                  {signupsError && <EmptyState variant="error" message={signupsError} />}
                  {signupsData && (
                    <>
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-6" role="region" aria-label="User signups metrics">
                        <StatCard title="Total Signups" value={signupsData.totals.total} />
                        <StatCard title="Daily Average" value={Math.round(signupsData.totals.avgPerDay)} />
                      </div>
                      <div className="rounded-xl bg-slate-800/50 border border-white/8 p-6">
                        <ChartErrorBoundary key={range}>
                          <TimeSeriesChart data={signupsData.series} xKey="date" yKey="value" />
                        </ChartErrorBoundary>
                      </div>
                      <div className="mt-4">
                        <DataTableToggle data={signupsData.series} columns={[{ key: 'date', label: 'Date' }, { key: 'value', label: 'Signups' }]} />
                      </div>
                    </>
                  )}
                </section>
                <section aria-labelledby="activation-heading">
                  <h2 id="activation-heading" className="text-lg font-semibold text-white mb-4">Activation Rate</h2>
                  {activationError && <EmptyState variant="error" message={activationError} />}
                  {activationData && (
                    <>
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-6" role="region" aria-label="Activation rate metrics">
                        <StatCard title="Activation Rate %" value={Math.round(activationData.totals.overallRate * 100)} />
                        <StatCard title="Total Activated" value={activationData.totals.totalActivated} />
                      </div>
                      <div className="rounded-xl bg-slate-800/50 border border-white/8 p-6">
                        <ChartErrorBoundary key={range}>
                          <TimeSeriesChart data={activationSeries} xKey="date" yKey="ratePct" color="#10b981" />
                        </ChartErrorBoundary>
                      </div>
                      <div className="mt-4">
                        <DataTableToggle data={activationSeries} columns={[{ key: 'date', label: 'Date' }, { key: 'ratePct', label: 'Activation Rate (%)' }, { key: 'value', label: 'Activated Count' }, { key: 'total', label: 'Total Signups' }]} />
                      </div>
                    </>
                  )}
                </section>
              </div>
            )}

            {tab === 'user-list' && (
              <UsersListSection
                role="user"
                heading="All Users"
                basePath="/admin/users"
                searchParams={{ search: params.search, page: params.page, pageSize: params.pageSize }}
              />
            )}

            {tab === 'deletion-requests' && (
              <div>
                {deletionError && <EmptyState variant="error" message={deletionError} />}
                {deletionData && (deletionData.data.length > 0 || params.search) ? (
                  <DeletionRequestsTable rows={deletionData.data} total={deletionData.total} page={deletionData.page} pageSize={deletionData.pageSize} search={params.search ?? ''} />
                ) : deletionData && deletionData.data.length === 0 && !params.search ? (
                  <EmptyState message="No deletion requests yet" />
                ) : null}
              </div>
            )}
          </div>
        )}
      </ContentTabBar>
    </div>
  );
}
