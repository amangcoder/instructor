import Link from 'next/link';
import { notFound } from 'next/navigation';
import { adminFetch, AdminApiError } from '@/lib/admin-api';
import StatCard from '@/components/admin/StatCard';
import EmptyState from '@/components/admin/EmptyState';
import type { UserSessionsResponse, UserPlanSummary, TtsStatus } from '@/types/users';

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

interface UserDetailResponse {
  user: {
    id: string;
    email: string;
    name: string | null;
    username: string | null;
    role: 'user' | 'admin';
    photoUrl: string | null;
    createdAt: string;
  };
  stats: {
    totalPlans: number;
    activePlans: number;
    totalSessions: number;
    avgSessionDurationMs: number;
    totalSessionDurationMs: number;
    lastActivityAt: string | null;
    ttsJobsTotal: number;
    ttsJobsCompleted: number;
    ttsJobsFailed: number;
  };
  /** Enriched per-plan summary list (replaces legacy recentPlans) */
  plansWithSummary: UserPlanSummary[];
}

interface PageProps {
  params: Promise<{ id: string }>;
}

// ─────────────────────────────────────────────────────────────────────────────
// Formatting helpers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Format an ISO timestamp as "Apr 21, 2026" (date only, for created/last-run dates).
 */
function formatDate(iso: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toISOString().slice(0, 10);
}

/**
 * Format an ISO timestamp as "Apr 21, 2026 14:32" (session completed-at format).
 * Matches AC-008: "Apr 21, 2026 14:32"
 */
function formatCompletedAt(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  // Build "Apr 21, 2026 14:32" using Intl for locale-safe month abbreviation
  const month = d.toLocaleString('en-US', { month: 'short', timeZone: 'UTC' });
  const day = d.getUTCDate();
  const year = d.getUTCFullYear();
  const hh = String(d.getUTCHours()).padStart(2, '0');
  const mm = String(d.getUTCMinutes()).padStart(2, '0');
  return `${month} ${day}, ${year} ${hh}:${mm}`;
}

/**
 * Format session duration as "12.3 min" (AC-008).
 */
function formatSessionDuration(ms: number): string {
  if (!ms || ms <= 0) return '0.0 min';
  const minutes = ms / 60_000;
  return `${minutes.toFixed(1)} min`;
}

/**
 * Format the total session duration for the footer line.
 */
function formatDuration(ms: number): string {
  if (!ms || ms <= 0) return '0s';
  const totalSec = Math.round(ms / 1000);
  if (totalSec < 60) return `${totalSec}s`;
  const min = Math.floor(totalSec / 60);
  const sec = totalSec % 60;
  if (min < 60) return sec ? `${min}m ${sec}s` : `${min}m`;
  const hr = Math.floor(min / 60);
  const remMin = min % 60;
  return remMin ? `${hr}h ${remMin}m` : `${hr}h`;
}

// ─────────────────────────────────────────────────────────────────────────────
// TTS Status badge
// ─────────────────────────────────────────────────────────────────────────────

const TTS_STATUS_STYLES: Record<TtsStatus | string, string> = {
  pending: 'bg-surface-variant text-on-surface-variant',
  in_progress: 'bg-primary/15 text-primary',
  completed: 'bg-[#166534]/15 text-[#166534] dark:bg-[#bbf7d0]/20 dark:text-[#4ade80]',
  failed: 'bg-error-container text-on-error-container',
};

function TtsStatusBadge({ status }: { status: string }) {
  const cls = TTS_STATUS_STYLES[status] ?? 'bg-surface-variant text-on-surface-variant';
  return (
    <span
      className={[
        'inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium',
        cls,
      ].join(' ')}
    >
      {status}
    </span>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared table-header class
// ─────────────────────────────────────────────────────────────────────────────

const TH = 'px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-on-surface-variant';

// ─────────────────────────────────────────────────────────────────────────────
// Avatar
// ─────────────────────────────────────────────────────────────────────────────

function initialsFor(name: string | null, email: string): string {
  const source = (name ?? email).trim();
  if (!source) return '?';
  const parts = source.split(/\s+/).filter(Boolean);
  if (parts.length === 0) return source[0]!.toUpperCase();
  if (parts.length === 1) return parts[0]!.slice(0, 2).toUpperCase();
  return (parts[0]![0]! + parts[parts.length - 1]![0]!).toUpperCase();
}

function UserAvatar({
  photoUrl,
  name,
  email,
}: {
  photoUrl: string | null;
  name: string | null;
  email: string;
}) {
  const label = name ?? email;
  const baseCls =
    'h-16 w-16 shrink-0 rounded-full overflow-hidden bg-surface-variant flex items-center justify-center text-on-surface-variant text-lg font-semibold';
  if (photoUrl) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={photoUrl}
        alt={`${label}'s profile photo`}
        className={baseCls + ' object-cover'}
        referrerPolicy="no-referrer"
      />
    );
  }
  return (
    <div className={baseCls} aria-label={`${label}'s profile photo placeholder`}>
      {initialsFor(name, email)}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Page component
// ─────────────────────────────────────────────────────────────────────────────

export default async function UserDetailPage({ params }: PageProps) {
  const { id } = await params;

  let data: UserDetailResponse | null = null;
  let sessions: UserSessionsResponse | null = null;
  let error: string | null = null;

  try {
    // Fetch user detail and session history in parallel (AC requirement)
    [data, sessions] = await Promise.all([
      adminFetch<UserDetailResponse>(`/admin/users/${id}`),
      adminFetch<UserSessionsResponse>(`/admin/users/${id}/sessions`),
    ]);
  } catch (err) {
    if (err instanceof AdminApiError && err.code === '404') {
      notFound();
    }
    error =
      err instanceof AdminApiError
        ? err.message
        : err instanceof Error
          ? err.message
          : 'Failed to load user.';
  }

  return (
    <div>
      <div className="mb-4">
        <Link
          href="/admin/users-list"
          className="text-sm text-primary hover:underline"
        >
          ← Back to users
        </Link>
      </div>

      {error && (
        <div
          className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-6"
          role="alert"
        >
          <p className="font-medium">Failed to load user</p>
          <p className="mt-1">{error}</p>
        </div>
      )}

      {data && (
        <>
          {/* ── Header ─────────────────────────────────────────────────── */}
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
            <div className="flex items-center gap-4">
              <UserAvatar
                photoUrl={data.user.photoUrl}
                name={data.user.name}
                email={data.user.email}
              />
              <div>
                <h1 className="text-2xl font-bold text-on-surface">
                  {data.user.name ?? data.user.email}
                </h1>
                <p className="text-sm text-on-surface-variant mt-1">
                  {data.user.email}
                  {data.user.username ? ` • @${data.user.username}` : ''} •
                  joined {formatDate(data.user.createdAt)}
                </p>
              </div>
            </div>
            <span
              className={[
                'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium self-start sm:self-auto',
                data.user.role === 'admin'
                  ? 'bg-primary/15 text-primary'
                  : 'bg-surface-variant text-on-surface-variant',
              ].join(' ')}
            >
              {data.user.role}
            </span>
          </div>

          {/* ── Stat cards ──────────────────────────────────────────────── */}
          <div className="space-y-4 mb-8" aria-label="User metrics">
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <StatCard title="Total Plans" value={data.stats.totalPlans} />
              <StatCard title="Active Plans" value={data.stats.activePlans} />
              <StatCard
                title="Sessions Completed"
                value={data.stats.totalSessions}
              />
              <StatCard
                title="Total Time (min)"
                value={Math.round(data.stats.totalSessionDurationMs / 60000)}
              />
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <StatCard
                title="Avg Session (sec)"
                value={Math.round(data.stats.avgSessionDurationMs / 1000)}
              />
              <StatCard title="TTS Jobs" value={data.stats.ttsJobsTotal} />
              <StatCard
                title="TTS Completed"
                value={data.stats.ttsJobsCompleted}
              />
              <StatCard title="TTS Failed" value={data.stats.ttsJobsFailed} />
            </div>
          </div>

          {/* ── Plans summary table ─────────────────────────────────────── */}
          <section aria-labelledby="plans-summary-heading" className="mb-8">
            <h2
              id="plans-summary-heading"
              className="text-lg font-semibold text-on-surface mb-3"
            >
              Plans
            </h2>
            <div className="rounded-xl bg-surface-container shadow-sm overflow-hidden">
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-outline-variant">
                  <thead className="bg-surface-variant/30">
                    <tr>
                      <th scope="col" className={TH}>Name</th>
                      <th scope="col" className={TH}>Created</th>
                      <th scope="col" className={TH}>TTS Status</th>
                      <th scope="col" className={TH}>Times Run</th>
                      <th scope="col" className={TH}>Last Run</th>
                      <th scope="col" className={TH}>Active</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-outline-variant">
                    {data.plansWithSummary.length === 0 ? (
                      <tr>
                        <td
                          colSpan={6}
                          className="px-4 py-10 text-center text-sm text-on-surface-variant"
                        >
                          No plans yet.
                        </td>
                      </tr>
                    ) : (
                      data.plansWithSummary.map((p) => (
                        <tr
                          key={p.planId}
                          className="hover:bg-surface-variant/20"
                        >
                          <td className="px-4 py-3 text-sm font-medium text-on-surface">
                            <Link
                              href={`/admin/users/${data.user.id}/plans/${p.planId}`}
                              className="text-primary hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary rounded-sm"
                            >
                              {p.name}
                            </Link>
                          </td>
                          <td className="px-4 py-3 text-sm text-on-surface-variant tabular-nums">
                            {formatDate(p.createdAt)}
                          </td>
                          <td className="px-4 py-3 text-sm">
                            <TtsStatusBadge status={p.ttsStatus} />
                          </td>
                          <td className="px-4 py-3 text-sm text-on-surface-variant tabular-nums">
                            {p.runCount}
                          </td>
                          <td className="px-4 py-3 text-sm text-on-surface-variant tabular-nums">
                            {p.lastRunAt ? formatDate(p.lastRunAt) : '—'}
                          </td>
                          <td className="px-4 py-3 text-sm text-on-surface-variant">
                            {p.isActive ? 'Yes' : 'No'}
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </section>

          {/* ── Session History table ───────────────────────────────────── */}
          <section aria-labelledby="session-history-heading" className="mb-6">
            <h2
              id="session-history-heading"
              className="text-lg font-semibold text-on-surface mb-3"
            >
              Session History
            </h2>

            {sessions && sessions.sessions.length === 0 ? (
              <EmptyState message="No sessions recorded yet." />
            ) : (
              <div className="rounded-xl bg-surface-container shadow-sm overflow-hidden">
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-outline-variant">
                    <thead className="bg-surface-variant/30">
                      <tr>
                        <th scope="col" className={TH}>Plan Name</th>
                        <th scope="col" className={TH}>Completed At</th>
                        <th scope="col" className={TH}>Duration</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-outline-variant">
                      {sessions?.sessions.map((s, i) => (
                        <tr
                          // completedAt + planName as composite key; fallback to index
                          key={`${s.completedAt}-${s.planName}-${i}`}
                          className="hover:bg-surface-variant/20"
                        >
                          <td className="px-4 py-3 text-sm font-medium text-on-surface">
                            {s.planName}
                          </td>
                          <td className="px-4 py-3 text-sm text-on-surface-variant tabular-nums">
                            {formatCompletedAt(s.completedAt)}
                          </td>
                          <td className="px-4 py-3 text-sm text-on-surface-variant tabular-nums">
                            {formatSessionDuration(s.durationMs)}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}
          </section>

          <p className="mt-2 text-xs text-on-surface-variant">
            Last session:{' '}
            <span className="tabular-nums">
              {formatDate(data.stats.lastActivityAt)}
            </span>{' '}
            • Total session time:{' '}
            {formatDuration(data.stats.totalSessionDurationMs)}
          </p>
        </>
      )}
    </div>
  );
}
