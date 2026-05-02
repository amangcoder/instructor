import { adminFetch } from '@/lib/admin-api';
import type { PlanDetail, PlanTreeNode, PlanVoice, ParsedPlanJson, Voice } from '@/types/plan-detail';
import SubPlanTree from '@/components/admin/SubPlanTree';
import VoiceGrid from '@/components/admin/VoiceGrid';
import PublishToggle from '@/components/admin/PublishToggle';
import VisibilitySelector from '@/components/admin/VisibilitySelector';
import PlanStepList from '@/components/admin/PlanStepList';
import PlanDetailsEditor from '@/components/admin/PlanDetailsEditor';
import RegenerateMissingButton from '@/components/admin/RegenerateMissingButton';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

interface PlanDetailPageProps {
  params: Promise<{ id: string }>;
  searchParams?: Promise<{
    from?: string | string[];
    seriesId?: string | string[];
  }>;
}

function firstParam(value: string | string[] | undefined): string | undefined {
  if (Array.isArray(value)) return value[0];
  return value;
}

function resolveBackLink(
  searchParams: { from?: string | string[]; seriesId?: string | string[] } | undefined,
): { href: string; label: string } {
  const from = firstParam(searchParams?.from);
  const seriesId = firstParam(searchParams?.seriesId);
  if (from === 'series' && seriesId && /^[a-zA-Z0-9_-]+$/.test(seriesId)) {
    return { href: `/admin/series/${seriesId}`, label: 'Back to Series' };
  }
  return { href: '/admin/plans', label: 'Back to Plans' };
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

function getErrorMessage(reason: unknown): string {
  if (reason instanceof Error) return reason.message;
  if (typeof reason === 'string') return reason;
  return 'An unknown error occurred.';
}

// ────────────────────────────────────────────────────────────────────────────
// Page
// ────────────────────────────────────────────────────────────────────────────

/**
 * Admin Plan Detail Page — server component
 *
 * Renders the admin plan detail view with four interactive sections:
 *
 *   1. SubPlanTree      — Recursive sub-plan hierarchy with drag-drop reorder
 *   2. VoiceGrid        — Per-voice TTS status pills with Regenerate buttons
 *   3. PublishToggle    — Toggle for is_published field
 *   4. VisibilitySelector — Dropdown for visibility enum
 *
 * All sections are fetched in parallel via Promise.allSettled so that a
 * failure in one section never crashes the others.
 *
 * Matches patterns from AdminPlansPage (server component with parallel fetch
 * and per-section error isolation).
 */
export default async function AdminPlanDetailPage({
  params,
  searchParams,
}: PlanDetailPageProps) {
  const { id: planId } = await params;
  const resolvedSearchParams = searchParams ? await searchParams : undefined;
  const backLink = resolveBackLink(resolvedSearchParams);

  // ── Parallel fetch with per-section error isolation ──────────────────
  const [planResult, treeResult, voicesResult, allVoicesResult] = await Promise.allSettled([
    adminFetch<PlanDetail>(`/admin/plans/${planId}`),
    adminFetch<PlanTreeNode>(`/plans/${planId}/tree`),
    adminFetch<PlanVoice[]>(`/admin/plans/${planId}/voices`),
    adminFetch<Voice[]>('/admin/voices'),
  ]);

  const plan =
    planResult.status === 'fulfilled' ? planResult.value : null;
  const planError =
    planResult.status === 'rejected'
      ? getErrorMessage(planResult.reason)
      : null;

  const tree =
    treeResult.status === 'fulfilled' ? treeResult.value : null;
  const treeError =
    treeResult.status === 'rejected'
      ? getErrorMessage(treeResult.reason)
      : null;

  const voices =
    voicesResult.status === 'fulfilled' ? voicesResult.value : null;
  const voicesError =
    voicesResult.status === 'rejected'
      ? getErrorMessage(voicesResult.reason)
      : null;

  const allVoices =
    allVoicesResult.status === 'fulfilled' ? allVoicesResult.value : [];

  // ── Parse planJson safely ───────────────────────────────────────────
  let parsedPlan: ParsedPlanJson | null = null;
  if (plan?.planJson) {
    try {
      parsedPlan = JSON.parse(plan.planJson) as ParsedPlanJson;
    } catch {
      // malformed JSON — steps section will show an error
    }
  }

  // ── If plan itself failed, show top-level error ─────────────────────
  if (!plan) {
    return (
      <div className="space-y-4">
        <div className="flex items-center gap-3">
          <a
            href={backLink.href}
            className="rounded-lg px-3 py-1.5 text-sm font-medium text-primary hover:bg-primary/10 transition-colors"
          >
            &larr; {backLink.label}
          </a>
        </div>
        <div
          role="alert"
          className="rounded-lg bg-error-container p-4 text-sm text-on-error-container"
        >
          {planError ?? 'Plan not found.'}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* ── Page header ────────────────────────────────────────────────────── */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-3">
          <a
            href={backLink.href}
            className="rounded-lg px-3 py-1.5 text-sm font-medium text-primary hover:bg-primary/10 transition-colors"
          >
            &larr; {backLink.label}
          </a>
          <h1 className="text-xl font-semibold text-on-surface">
            {plan.name}
          </h1>
        </div>
        <p className="text-xs text-on-surface-variant tabular-nums">
          ID: {plan.id}
        </p>
      </div>

      {/* ── Plan details card ──────────────────────────────────────────────── */}
      <section
        aria-labelledby="plan-details-heading"
        className="rounded-xl bg-surface-container p-6 shadow-sm space-y-4"
      >
        <div className="flex items-start justify-between gap-3">
          <h2
            id="plan-details-heading"
            className="text-base font-semibold text-on-surface"
          >
            Plan Details
          </h2>
          <PlanDetailsEditor
            planId={planId}
            voices={allVoices}
            initial={{
              name: plan.name,
              description: plan.description ?? parsedPlan?.description ?? null,
              category: parsedPlan?.category ?? null,
              tags: parsedPlan?.tags ?? [],
              defaultVoice: parsedPlan?.defaultVoice ?? null,
            }}
          />
        </div>
        <dl className="grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-4">
          {(plan.description || parsedPlan?.description) && (
            <div className="sm:col-span-2">
              <dt className="text-xs font-medium text-on-surface-variant uppercase tracking-wider mb-1">
                Description
              </dt>
              <dd className="text-sm text-on-surface">
                {plan.description ?? parsedPlan?.description}
              </dd>
            </div>
          )}
          {parsedPlan?.category && (
            <div>
              <dt className="text-xs font-medium text-on-surface-variant uppercase tracking-wider mb-1">
                Category
              </dt>
              <dd className="text-sm text-on-surface">{parsedPlan.category}</dd>
            </div>
          )}
          {parsedPlan?.defaultVoice && (
            <div>
              <dt className="text-xs font-medium text-on-surface-variant uppercase tracking-wider mb-1">
                Default Voice
              </dt>
              <dd className="text-sm text-on-surface font-mono">
                {parsedPlan.defaultVoice}
              </dd>
            </div>
          )}
          {parsedPlan?.tags && parsedPlan.tags.length > 0 && (
            <div className="sm:col-span-2">
              <dt className="text-xs font-medium text-on-surface-variant uppercase tracking-wider mb-1">
                Tags
              </dt>
              <dd className="flex flex-wrap gap-1.5">
                {parsedPlan.tags.map((tag) => (
                  <span
                    key={tag}
                    className="inline-flex items-center rounded-full bg-surface-container-high px-2 py-0.5 text-xs text-on-surface-variant"
                  >
                    {tag}
                  </span>
                ))}
              </dd>
            </div>
          )}
          <div>
            <dt className="text-xs font-medium text-on-surface-variant uppercase tracking-wider mb-1">
              Owner
            </dt>
            <dd className="text-sm text-on-surface">
              {plan.ownerUserId ? (
                <a
                  href={`/admin/users/${plan.ownerUserId}`}
                  className="font-mono text-primary hover:underline"
                >
                  {plan.ownerUserId}
                </a>
              ) : (
                <span className="text-on-surface-variant">—</span>
              )}
            </dd>
          </div>
          {plan.parentPlanId && (
            <div>
              <dt className="text-xs font-medium text-on-surface-variant uppercase tracking-wider mb-1">
                Parent Plan
              </dt>
              <dd className="text-sm">
                <a
                  href={`/admin/plans/${plan.parentPlanId}`}
                  className="font-mono text-primary hover:underline"
                >
                  {plan.parentPlanId}
                </a>
              </dd>
            </div>
          )}
          <div>
            <dt className="text-xs font-medium text-on-surface-variant uppercase tracking-wider mb-1">
              Position
            </dt>
            <dd className="text-sm text-on-surface tabular-nums">
              {plan.position}
            </dd>
          </div>
          <div>
            <dt className="text-xs font-medium text-on-surface-variant uppercase tracking-wider mb-1">
              Created
            </dt>
            <dd className="text-sm text-on-surface-variant tabular-nums">
              {new Date(plan.createdAt).toLocaleString()}
            </dd>
          </div>
          <div>
            <dt className="text-xs font-medium text-on-surface-variant uppercase tracking-wider mb-1">
              Updated
            </dt>
            <dd className="text-sm text-on-surface-variant tabular-nums">
              {new Date(plan.updatedAt).toLocaleString()}
            </dd>
          </div>
        </dl>
      </section>

      {/* ── Controls row: Publish toggle + Visibility selector ────────────── */}
      <section
        aria-labelledby="plan-controls-heading"
        className="rounded-xl bg-surface-container p-6 shadow-sm"
      >
        <h2
          id="plan-controls-heading"
          className="text-base font-semibold text-on-surface mb-4"
        >
          Plan Settings
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
          <div>
            <span className="block text-sm font-medium text-on-surface mb-2">
              Publish Status
            </span>
            <PublishToggle
              planId={planId}
              initialValue={plan.isPublished}
            />
          </div>
          <VisibilitySelector
            planId={planId}
            initialValue={plan.visibility}
          />
        </div>
      </section>

      {/* ── Sub-plan hierarchy ─────────────────────────────────────────────── */}
      <section aria-labelledby="sub-plan-heading">
        <h2
          id="sub-plan-heading"
          className="text-base font-semibold text-on-surface mb-3"
        >
          Sub-Plan Hierarchy
        </h2>

        {treeError && (
          <div
            role="alert"
            className="rounded-lg bg-error-container p-3 text-sm text-on-error-container mb-3"
          >
            {treeError}
          </div>
        )}

        {tree ? (
          <SubPlanTree planId={planId} tree={tree} />
        ) : (
          !treeError && (
            <div
              className="flex min-h-[80px] items-center justify-center rounded-xl bg-surface-container p-6 text-center"
              role="status"
            >
              <p className="text-sm text-on-surface-variant">
                No sub-plan data available.
              </p>
            </div>
          )
        )}
      </section>

      {/* ── TTS pre-generation progress ────────────────────────────────────── */}
      <section aria-labelledby="tts-progress-heading">
        <h2
          id="tts-progress-heading"
          className="text-base font-semibold text-on-surface mb-3"
        >
          TTS Pre-generation
        </h2>
        <div className="rounded-xl bg-surface-container p-5 shadow-sm space-y-3">
          <div className="flex items-center gap-3 flex-wrap">
            <span
              className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold ${
                plan.ttsStatus === 'completed'
                  ? 'bg-success-container text-success'
                  : plan.ttsStatus === 'processing'
                    ? 'bg-primary/10 text-primary'
                    : plan.ttsStatus === 'failed'
                      ? 'bg-error-container text-error'
                      : plan.ttsStatus === 'partial'
                        ? 'bg-warning-container text-warning'
                        : 'bg-surface-container-high text-on-surface-variant'
              }`}
            >
              {plan.ttsStatus ?? 'none'}
            </span>
            <span className="text-sm text-on-surface-variant tabular-nums">
              {plan.ttsCompleted} / {plan.ttsTotal} steps
            </span>
          </div>
          {plan.ttsTotal > 0 && (
            <div
              role="progressbar"
              aria-valuenow={plan.ttsCompleted}
              aria-valuemin={0}
              aria-valuemax={plan.ttsTotal}
              aria-label="TTS pre-generation progress"
              className="h-2 w-full overflow-hidden rounded-full bg-surface-container-high"
            >
              <div
                className={`h-full rounded-full transition-all ${
                  plan.ttsStatus === 'completed' && plan.ttsCompleted >= plan.ttsTotal
                    ? 'bg-success'
                    : plan.ttsStatus === 'failed'
                      ? 'bg-error'
                      : 'bg-primary'
                }`}
                style={{
                  width: `${Math.round((plan.ttsCompleted / plan.ttsTotal) * 100)}%`,
                }}
              />
            </div>
          )}
          <RegenerateMissingButton planId={planId} voices={voices} />
        </div>
      </section>

      {/* ── Steps ──────────────────────────────────────────────────────────── */}
      <section aria-labelledby="steps-heading">
        <h2
          id="steps-heading"
          className="text-base font-semibold text-on-surface mb-3"
        >
          Steps
          {parsedPlan && (
            <span className="ml-2 text-sm font-normal text-on-surface-variant">
              ({parsedPlan.steps.length})
            </span>
          )}
        </h2>
        {parsedPlan ? (
          <PlanStepList
            steps={parsedPlan.steps}
            planId={planId}
            defaultVoiceSlug={parsedPlan.defaultVoice ?? null}
          />
        ) : (
          <div
            role="alert"
            className="rounded-lg bg-error-container p-3 text-sm text-on-error-container"
          >
            Could not parse plan JSON.
          </div>
        )}
      </section>

      {/* ── Voice grid ─────────────────────────────────────────────────────── */}
      <section aria-labelledby="voice-grid-heading">
        <h2
          id="voice-grid-heading"
          className="text-base font-semibold text-on-surface mb-3"
        >
          Voice Renditions
        </h2>

        {voicesError && (
          <div
            role="alert"
            className="rounded-lg bg-error-container p-3 text-sm text-on-error-container mb-3"
          >
            {voicesError}
          </div>
        )}

        {voices ? (
          <VoiceGrid
            planId={planId}
            voices={voices}
            defaultVoiceSlug={parsedPlan?.defaultVoice ?? null}
          />
        ) : (
          !voicesError && (
            <div
              className="flex min-h-[80px] items-center justify-center rounded-xl bg-surface-container p-6 text-center"
              role="status"
            >
              <p className="text-sm text-on-surface-variant">
                No voice data available.
              </p>
            </div>
          )
        )}
      </section>
    </div>
  );
}
