import Link from 'next/link';
import { adminFetch } from '@/lib/admin-api';
import type { AdminSeriesDetail, AdminSeriesPlanRecord } from '@/types/series';
import AddSessionButton from './AddSessionButton';
import SessionsTable from './SessionsTable';

interface SeriesDetailPageProps {
  params: Promise<{ id: string }>;
}

function getErrorMessage(reason: unknown): string {
  if (reason instanceof Error) return reason.message;
  if (typeof reason === 'string') return reason;
  return 'An unknown error occurred.';
}

export default async function AdminSeriesDetailPage({
  params,
}: SeriesDetailPageProps) {
  const { id } = await params;

  let series: AdminSeriesDetail | null = null;
  let error: string | null = null;
  try {
    series = await adminFetch<AdminSeriesDetail>(`/series/${id}`);
  } catch (err) {
    error = getErrorMessage(err);
  }

  if (!series) {
    return (
      <div className="space-y-4">
        <div className="flex items-center gap-3">
          <Link
            href="/admin/series"
            className="rounded-lg px-3 py-1.5 text-sm font-medium text-primary hover:bg-primary/10 transition-colors"
          >
            &larr; Back to Series
          </Link>
        </div>
        <div
          role="alert"
          className="rounded-lg bg-error-container p-4 text-sm text-on-error-container"
        >
          {error ?? 'Series not found.'}
        </div>
      </div>
    );
  }

  const sessions: AdminSeriesPlanRecord[] = series.sessions ?? [];

  return (
    <div className="space-y-8">
      {/* ── Header ────────────────────────────────────────────────────────── */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex items-start gap-3">
          <Link
            href="/admin/series"
            className="rounded-lg px-3 py-1.5 text-sm font-medium text-primary hover:bg-primary/10 transition-colors"
          >
            &larr; Back to Series
          </Link>
          <div>
            <h1 className="text-2xl font-bold text-on-surface">{series.name}</h1>
            {series.description && (
              <p className="mt-1 text-sm text-on-surface-variant max-w-2xl">
                {series.description}
              </p>
            )}
          </div>
        </div>
        <span
          className={[
            'inline-flex items-center self-start rounded-full px-2.5 py-0.5 text-xs font-semibold',
            series.isPublished
              ? 'bg-green-100 text-green-800'
              : 'bg-outline-variant/40 text-on-surface-variant',
          ].join(' ')}
        >
          {series.isPublished ? 'Published' : 'Draft'}
        </span>
      </div>

      {/* ── Meta grid ─────────────────────────────────────────────────────── */}
      <section
        aria-labelledby="series-meta-heading"
        className="rounded-xl bg-surface-container p-6 shadow-sm"
      >
        <h2
          id="series-meta-heading"
          className="text-base font-semibold text-on-surface mb-4"
        >
          Series Info
        </h2>
        <dl className="grid grid-cols-2 sm:grid-cols-4 gap-4 text-sm">
          <div>
            <dt className="text-on-surface-variant">Category</dt>
            <dd className="mt-0.5 font-medium text-on-surface capitalize">
              {series.category || '—'}
            </dd>
          </div>
          <div>
            <dt className="text-on-surface-variant">Locale</dt>
            <dd className="mt-0.5 font-medium text-on-surface">{series.locale}</dd>
          </div>
          <div>
            <dt className="text-on-surface-variant">Default voice</dt>
            <dd className="mt-0.5 font-medium text-on-surface">
              {series.defaultVoice}
            </dd>
          </div>
          <div>
            <dt className="text-on-surface-variant">Sessions</dt>
            <dd className="mt-0.5 font-medium text-on-surface tabular-nums">
              {sessions.length}
            </dd>
          </div>
        </dl>
      </section>

      {/* ── Sessions / plans ──────────────────────────────────────────────── */}
      <section aria-labelledby="sessions-heading">
        <div className="flex items-center justify-between gap-3 mb-3">
          <div className="flex items-baseline gap-3">
            <h2
              id="sessions-heading"
              className="text-base font-semibold text-on-surface"
            >
              Sessions
            </h2>
            {sessions.length > 1 && (
              <p className="text-xs text-on-surface-variant">
                Drag rows to reorder.
              </p>
            )}
          </div>
          <AddSessionButton seriesId={series.id} />
        </div>

        <SessionsTable
          seriesId={series.id}
          seriesName={series.name}
          initialSessions={sessions}
        />
      </section>
    </div>
  );
}
