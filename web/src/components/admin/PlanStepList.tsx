'use client';

import { useState, useCallback, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import type { PlanStep, PlanStepSay } from '@/types/plan-detail';

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

function microsToSeconds(micros: number): number {
  return Math.round(micros / 1_000_000);
}

function formatDuration(seconds: number): string {
  if (seconds <= 0) return '0s';
  if (seconds < 60) return `${seconds}s`;
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return s > 0 ? `${m}m ${s}s` : `${m}m`;
}

function extractErrorMessage(data: unknown): string {
  if (typeof data === 'object' && data !== null && 'error' in data) {
    const msg = (data as Record<string, unknown>).error;
    if (typeof msg === 'string') return msg;
  }
  return 'Request failed.';
}

// ────────────────────────────────────────────────────────────────────────────
// Step badge
// ────────────────────────────────────────────────────────────────────────────

const TYPE_STYLES: Record<string, string> = {
  say: 'bg-primary/10 text-primary',
  wait: 'bg-surface-container-high text-on-surface-variant',
  notify: 'bg-warning-container text-warning',
  play: 'bg-success-container text-success',
  stopAudio: 'bg-error-container text-error',
  repeat: 'bg-secondary/10 text-secondary',
  count: 'bg-surface-container-high text-on-surface-variant',
};

function Badge({ label, type }: { label: string; type: string }) {
  return (
    <span
      className={`inline-flex shrink-0 items-center rounded-full px-2 py-0.5 text-xs font-semibold ${
        TYPE_STYLES[type] ?? 'bg-surface-container-high text-on-surface-variant'
      }`}
    >
      {label}
    </span>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// SayStepRow — editable + synth button
// ────────────────────────────────────────────────────────────────────────────

interface SayStepRowProps {
  step: PlanStepSay;
  index: number;
  depth: number;
  planId: string;
  defaultVoiceSlug: string | null;
  onSaved: () => void;
}

function SayStepRow({ step, index, depth, planId, defaultVoiceSlug, onSaved }: SayStepRowProps) {
  const indent = depth > 0 ? { paddingLeft: `${16 + depth * 24}px` } : undefined;

  const [editing, setEditing] = useState(false);
  const [text, setText] = useState(step.text);
  const [voiceId, setVoiceId] = useState(step.voiceId ?? '');
  const [savePending, setSavePending] = useState(false);
  const [synthPending, setSynthPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [synthInfo, setSynthInfo] = useState<string | null>(null);

  const handleSave = useCallback(async () => {
    setSavePending(true);
    setError(null);
    try {
      const payload: Record<string, unknown> = { stepEdits: [{ id: step.id, text, voiceId: voiceId || null }] };
      const res = await fetch(`/api/admin/plans/${planId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        setError(extractErrorMessage(body));
        return;
      }
      setEditing(false);
      onSaved();
    } catch {
      setError('Network error.');
    } finally {
      setSavePending(false);
    }
  }, [step.id, text, voiceId, planId, onSaved]);

  const handleSynth = useCallback(async () => {
    setSynthPending(true);
    setError(null);
    setSynthInfo(null);
    try {
      const body: Record<string, unknown> = { stepId: step.id };
      const slug = voiceId || step.voiceId || defaultVoiceSlug;
      if (slug) body.voiceSlug = slug;

      const res = await fetch(`/api/admin/plans/${planId}/synth-step`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      if (!res.ok) {
        const errBody = await res.json().catch(() => ({}));
        setError(extractErrorMessage(errBody));
        return;
      }
      const data = (await res.json().catch(() => ({}))) as {
        voiceSlug?: string;
        locale?: string;
        textLength?: number;
      };
      setSynthInfo(
        `Synthesized · ${data.voiceSlug ?? '?'} · ${data.locale ?? '?'} · ${data.textLength ?? '?'} chars`,
      );
    } catch {
      setError('Network error.');
    } finally {
      setSynthPending(false);
    }
  }, [step.id, step.voiceId, voiceId, defaultVoiceSlug, planId]);

  return (
    <div
      style={indent}
      className="flex items-start gap-3 border-b border-outline-variant/40 px-4 py-2.5 last:border-b-0 hover:bg-primary/5 transition-colors"
    >
      <span className="w-6 shrink-0 pt-0.5 text-right text-xs tabular-nums text-on-surface-variant/60">
        {index + 1}
      </span>
      <div className="pt-0.5">
        <Badge label="say" type="say" />
      </div>
      <div className="min-w-0 flex-1 space-y-1">
        {editing ? (
          <div className="space-y-2">
            <textarea
              rows={2}
              value={text}
              onChange={(e) => setText(e.target.value)}
              className="w-full rounded-lg bg-surface-container-high px-3 py-2 text-sm text-on-surface focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
              maxLength={5000}
              aria-label="Step text"
            />
            <div className="flex flex-wrap items-center gap-2">
              <input
                type="text"
                value={voiceId}
                onChange={(e) => setVoiceId(e.target.value)}
                placeholder={defaultVoiceSlug ?? 'voice slug'}
                className="rounded-lg bg-surface-container-high px-2 py-1 text-xs text-on-surface font-mono focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
                aria-label="Voice slug for this step"
                maxLength={100}
              />
              <button
                type="button"
                onClick={() => { void handleSave(); }}
                disabled={savePending}
                className="rounded-lg bg-primary px-3 py-1 text-xs font-semibold text-white hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {savePending ? 'Saving…' : 'Save'}
              </button>
              <button
                type="button"
                onClick={() => {
                  setText(step.text);
                  setVoiceId(step.voiceId ?? '');
                  setEditing(false);
                  setError(null);
                }}
                disabled={savePending}
                className="rounded-lg px-3 py-1 text-xs font-semibold text-on-surface-variant hover:bg-surface-container-highest transition-colors disabled:opacity-50"
              >
                Cancel
              </button>
            </div>
          </div>
        ) : (
          <>
            <div className="break-words">
              <span className="text-sm text-on-surface">{step.text}</span>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              {(step.voiceId || step.estimatedDuration) && (
                <span className="text-xs text-on-surface-variant">
                  {[
                    step.voiceId,
                    step.estimatedDuration && step.estimatedDuration > 0
                      ? `~${formatDuration(microsToSeconds(step.estimatedDuration))}`
                      : null,
                  ]
                    .filter(Boolean)
                    .join(' · ')}
                </span>
              )}
              <button
                type="button"
                onClick={() => setEditing(true)}
                className="rounded px-2 py-0.5 text-xs font-semibold text-primary hover:bg-primary/10 transition-colors"
              >
                Edit
              </button>
              <button
                type="button"
                onClick={() => { void handleSynth(); }}
                disabled={synthPending}
                className="rounded px-2 py-0.5 text-xs font-semibold text-success hover:bg-success-container transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                title={`Synth this step using ${voiceId || step.voiceId || defaultVoiceSlug || 'default voice'}`}
              >
                {synthPending ? 'Synth…' : 'Synth'}
              </button>
            </div>
          </>
        )}
        {error && (
          <p role="alert" className="text-xs text-error">{error}</p>
        )}
        {synthInfo && !error && (
          <p className="text-xs text-success">{synthInfo}</p>
        )}
      </div>
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Read-only rows for non-say step types
// ────────────────────────────────────────────────────────────────────────────

function ReadOnlyRow({
  step,
  index,
  depth,
}: {
  step: Exclude<PlanStep, PlanStepSay>;
  index: number;
  depth: number;
}) {
  const indent = depth > 0 ? { paddingLeft: `${16 + depth * 24}px` } : undefined;
  let typeBadge: React.ReactNode;
  let primary: React.ReactNode = null;
  let secondary: React.ReactNode = null;

  switch (step.runtimeType) {
    case 'wait':
      typeBadge = <Badge label="wait" type="wait" />;
      primary = (
        <span className="text-sm text-on-surface tabular-nums">
          {formatDuration(microsToSeconds(step.duration))}
        </span>
      );
      break;
    case 'notify':
      typeBadge = <Badge label="notify" type="notify" />;
      primary = <span className="text-sm text-on-surface">{step.title}</span>;
      if (step.body) {
        secondary = <span className="text-xs text-on-surface-variant">{step.body}</span>;
      }
      break;
    case 'play': {
      typeBadge = <Badge label="play" type="play" />;
      primary = <span className="text-sm text-on-surface">{step.audioAssetKey}</span>;
      const meta: string[] = [];
      if (step.loop !== undefined) meta.push(step.loop ? 'loop' : 'one-shot');
      if (step.volume !== undefined && step.volume !== 1) meta.push(`vol ${step.volume}`);
      if (step.fadeInMs) meta.push(`fade-in ${step.fadeInMs}ms`);
      if (step.fadeOutMs) meta.push(`fade-out ${step.fadeOutMs}ms`);
      if (meta.length > 0) {
        secondary = <span className="text-xs text-on-surface-variant">{meta.join(' · ')}</span>;
      }
      break;
    }
    case 'stopAudio':
      typeBadge = <Badge label="stopAudio" type="stopAudio" />;
      primary = <span className="text-xs text-on-surface-variant">Stops ambient audio</span>;
      break;
    case 'repeat':
      typeBadge = <Badge label="repeat" type="repeat" />;
      primary = (
        <span className="text-sm text-on-surface">
          ×{step.count}
          <span className="ml-2 text-xs text-on-surface-variant">
            {step.children.length} inner step{step.children.length !== 1 ? 's' : ''}
          </span>
        </span>
      );
      break;
    case 'count':
      typeBadge = <Badge label="count" type="count" />;
      primary = (
        <span className="text-sm text-on-surface tabular-nums">
          {step.from} → {step.to}
        </span>
      );
      secondary = (
        <span className="text-xs text-on-surface-variant">
          every {formatDuration(step.intervalSeconds)}
        </span>
      );
      break;
    default: {
      const unknown = step as { runtimeType?: string };
      typeBadge = <Badge label={unknown.runtimeType ?? 'unknown'} type="unknown" />;
      primary = (
        <span className="text-xs text-on-surface-variant italic">Unknown step type</span>
      );
    }
  }

  return (
    <div
      style={indent}
      className="flex items-start gap-3 border-b border-outline-variant/40 px-4 py-2.5 last:border-b-0 hover:bg-primary/5 transition-colors"
    >
      <span className="w-6 shrink-0 pt-0.5 text-right text-xs tabular-nums text-on-surface-variant/60">
        {index + 1}
      </span>
      <div className="pt-0.5">{typeBadge}</div>
      <div className="min-w-0 flex-1 space-y-0.5">
        <div className="break-words">{primary}</div>
        {secondary && <div>{secondary}</div>}
      </div>
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Recursive renderer
// ────────────────────────────────────────────────────────────────────────────

function StepRow(props: {
  step: PlanStep;
  index: number;
  depth: number;
  planId: string;
  defaultVoiceSlug: string | null;
  onSaved: () => void;
}) {
  const { step, index, depth, planId, defaultVoiceSlug, onSaved } = props;

  if (step.runtimeType === 'say') {
    return (
      <SayStepRow
        step={step}
        index={index}
        depth={depth}
        planId={planId}
        defaultVoiceSlug={defaultVoiceSlug}
        onSaved={onSaved}
      />
    );
  }

  return (
    <>
      <ReadOnlyRow step={step} index={index} depth={depth} />
      {step.runtimeType === 'repeat' &&
        step.children.map((inner, i) => (
          <StepRow
            key={inner.id ?? i}
            step={inner}
            index={i}
            depth={depth + 1}
            planId={planId}
            defaultVoiceSlug={defaultVoiceSlug}
            onSaved={onSaved}
          />
        ))}
    </>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Public component
// ────────────────────────────────────────────────────────────────────────────

export interface PlanStepListProps {
  steps: PlanStep[];
  planId: string;
  /** Used as the synth fallback when a step has no voiceId of its own. */
  defaultVoiceSlug: string | null;
}

export default function PlanStepList({ steps, planId, defaultVoiceSlug }: PlanStepListProps) {
  const router = useRouter();
  const [, startTransition] = useTransition();

  const handleSaved = useCallback(() => {
    startTransition(() => router.refresh());
  }, [router]);

  if (!steps || steps.length === 0) {
    return (
      <div
        className="flex min-h-[80px] items-center justify-center rounded-xl bg-surface-container p-6 text-center"
        role="status"
      >
        <p className="text-sm text-on-surface-variant">No steps in this plan.</p>
      </div>
    );
  }

  return (
    <div className="rounded-xl bg-surface-container shadow-sm overflow-hidden">
      {steps.map((step, i) => (
        <StepRow
          key={step.id ?? i}
          step={step}
          index={i}
          depth={0}
          planId={planId}
          defaultVoiceSlug={defaultVoiceSlug}
          onSaved={handleSaved}
        />
      ))}
    </div>
  );
}
