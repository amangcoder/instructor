import Link from 'next/link';
import { notFound } from 'next/navigation';
import { adminFetch, AdminApiError } from '@/lib/admin-api';
import PlanJsonViewer from '@/components/admin/PlanJsonViewer';

interface PlanDetailResponse {
  id: string;
  userId: string;
  name: string;
  planJson: string;
  isActive: boolean;
  ttsStatus: string;
  ttsTotal: number;
  ttsCompleted: number;
  voiceQuality: string;
  shareToken: string | null;
  createdAt: string;
  updatedAt: string;
}

interface PageProps {
  params: Promise<{ id: string; planId: string }>;
}

function formatDate(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? '—' : d.toISOString().slice(0, 16).replace('T', ' ');
}

function Badge({ children, variant = 'default' }: { children: string; variant?: 'default' | 'success' | 'error' | 'warning' }) {
  const colors = {
    default: 'bg-surface-variant text-on-surface-variant',
    success: 'bg-primary/15 text-primary',
    error: 'bg-error-container text-on-error-container',
    warning: 'bg-tertiary/15 text-tertiary',
  };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${colors[variant]}`}>
      {children}
    </span>
  );
}

function ttsVariant(status: string): 'default' | 'success' | 'error' | 'warning' {
  if (status === 'completed') return 'success';
  if (status === 'failed') return 'error';
  if (status === 'processing' || status === 'pending') return 'warning';
  return 'default';
}

export default async function PlanDetailPage({ params }: PageProps) {
  const { id: userId, planId } = await params;

  let data: PlanDetailResponse | null = null;
  let error: string | null = null;

  try {
    data = await adminFetch<PlanDetailResponse>(
      `/admin/users/${userId}/plans/${planId}`,
    );
  } catch (err) {
    if (err instanceof AdminApiError && err.code === '404') notFound();
    error =
      err instanceof AdminApiError ? err.message
      : err instanceof Error ? err.message
      : 'Failed to load plan.';
  }

  return (
    <div>
      <div className="mb-4">
        <Link
          href={`/admin/users/${userId}`}
          className="text-sm text-primary hover:underline"
        >
          ← Back to user
        </Link>
      </div>

      {error && (
        <div className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-6" role="alert">
          <p className="font-medium">Failed to load plan</p>
          <p className="mt-1">{error}</p>
        </div>
      )}

      {data && (
        <>
          {/* ── Header ─────────────────────────────────────────────── */}
          <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4 mb-8">
            <div>
              <h1 className="text-2xl font-bold text-on-surface">{data.name}</h1>
              <p className="text-sm text-on-surface-variant mt-1">
                Created {formatDate(data.createdAt)} · Updated {formatDate(data.updatedAt)}
              </p>
              <div className="flex flex-wrap gap-2 mt-3">
                <Badge variant={data.isActive ? 'success' : 'default'}>
                  {data.isActive ? 'Active' : 'Inactive'}
                </Badge>
                <Badge variant={ttsVariant(data.ttsStatus)}>
                  TTS: {data.ttsStatus}
                </Badge>
                {data.ttsTotal > 0 && (
                  <Badge>
                    {data.ttsCompleted}/{data.ttsTotal} segments
                  </Badge>
                )}
                <Badge>{data.voiceQuality}</Badge>
                {data.shareToken && <Badge variant="success">Shared</Badge>}
              </div>
            </div>
          </div>

          {/* ── Viewer + download — client component ───────────────── */}
          <PlanJsonViewer
            planName={data.name}
            planJson={data.planJson}
          />
        </>
      )}
    </div>
  );
}
