'use client';

import { useState } from 'react';

// ────────────────────────────────────────────────────────────────────────────
// Step types (matches runtimeType values in plan_json)
// ────────────────────────────────────────────────────────────────────────────

interface SayStep       { runtimeType: 'say';       id: string; text: string; }
interface WaitStep      { runtimeType: 'wait';      id: string; duration: number; } // microseconds
interface PlayStep      { runtimeType: 'play';      id: string; audioAssetKey: string; loop: boolean; volume: number; fadeInMs?: number | null; fadeOutMs?: number | null; }
interface StopAudioStep { runtimeType: 'stopAudio'; id: string; }
interface NotifyStep    { runtimeType: 'notify';    id: string; title: string; body: string; }
interface CountStep     { runtimeType: 'count';     id: string; from: number; to: number; intervalSeconds: number; }
interface RepeatStep    { runtimeType: 'repeat';    id: string; count: number; children: Step[]; }

type Step = SayStep | WaitStep | PlayStep | StopAudioStep | NotifyStep | CountStep | RepeatStep;

interface PlanData {
  name?: string;
  description?: string;
  category?: string;
  tags?: string[];
  defaultVoice?: string;
  steps?: Step[];
  [key: string]: unknown;
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

function fmtDuration(us: number): string {
  const sec = Math.round(us / 1_000_000);
  if (sec < 60) return `${sec}s`;
  const min = Math.floor(sec / 60);
  const rem = sec % 60;
  return rem ? `${min}m ${rem}s` : `${min}m`;
}

function chip(label: string) {
  return (
    <span className="rounded-full bg-surface-variant px-2 py-0.5 text-xs text-on-surface-variant">
      {label}
    </span>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Per-type renderers
// ────────────────────────────────────────────────────────────────────────────

function StepBody({ step, depth = 0 }: { step: Step; depth?: number }) {
  switch (step.runtimeType) {
    case 'say':
      return <p className="text-sm text-on-surface mt-0.5 break-words">{step.text}</p>;

    case 'wait':
      return (
        <div className="flex items-center gap-2 mt-0.5">
          {chip('wait')}
          <span className="text-sm text-on-surface-variant tabular-nums">{fmtDuration(step.duration)}</span>
        </div>
      );

    case 'play':
      return (
        <div className="flex flex-wrap items-center gap-2 mt-0.5">
          {chip('play')}
          <span className="text-sm text-on-surface font-medium">{step.audioAssetKey}</span>
          {step.loop && chip('loop')}
          <span className="text-xs text-on-surface-variant">vol {step.volume}</span>
          {step.fadeInMs != null  && <span className="text-xs text-on-surface-variant">fade-in {step.fadeInMs}ms</span>}
          {step.fadeOutMs != null && <span className="text-xs text-on-surface-variant">fade-out {step.fadeOutMs}ms</span>}
        </div>
      );

    case 'stopAudio':
      return <div className="flex items-center gap-2 mt-0.5">{chip('stop audio')}</div>;

    case 'notify':
      return (
        <div className="mt-0.5">
          <div className="flex items-center gap-2">{chip('notify')}<span className="text-sm font-medium text-on-surface">{step.title}</span></div>
          {step.body && step.body !== step.title && (
            <p className="text-xs text-on-surface-variant mt-0.5">{step.body}</p>
          )}
        </div>
      );

    case 'count':
      return (
        <div className="flex flex-wrap items-center gap-2 mt-0.5">
          {chip('count')}
          <span className="text-sm text-on-surface">{step.from} → {step.to}</span>
          <span className="text-xs text-on-surface-variant">every {step.intervalSeconds}s</span>
        </div>
      );

    case 'repeat':
      return (
        <div className="mt-0.5">
          <div className="flex items-center gap-2 mb-2">
            {chip('repeat')}
            <span className="text-sm text-on-surface">× {step.count}</span>
          </div>
          {depth < 3 && step.children?.length > 0 && (
            <ol className={`space-y-1.5 pl-4 border-l-2 border-outline-variant`}>
              {step.children.map((child, i) => (
                <li key={child.id ?? i} className="rounded-lg bg-surface-container-highest/40 px-3 py-2">
                  <StepBody step={child} depth={depth + 1} />
                </li>
              ))}
            </ol>
          )}
        </div>
      );

    default:
      return <p className="text-xs text-on-surface-variant mt-0.5 break-all">{JSON.stringify(step)}</p>;
  }
}

const TYPE_LABELS: Record<string, string> = {
  say: 'Say',
  wait: 'Wait',
  play: 'Play',
  stopAudio: 'Stop',
  notify: 'Notify',
  count: 'Count',
  repeat: 'Repeat',
};

const TYPE_COLORS: Record<string, string> = {
  say:       'bg-primary/10 text-primary',
  wait:      'bg-surface-variant text-on-surface-variant',
  play:      'bg-tertiary/10 text-tertiary',
  stopAudio: 'bg-error/10 text-error',
  notify:    'bg-secondary/10 text-secondary',
  count:     'bg-tertiary/10 text-tertiary',
  repeat:    'bg-primary/5 text-primary',
};

function StepRow({ step, index }: { step: Step; index: number }) {
  const colorCls = TYPE_COLORS[step.runtimeType] ?? 'bg-surface-variant text-on-surface-variant';
  const label = TYPE_LABELS[step.runtimeType] ?? step.runtimeType;

  return (
    <li className="rounded-xl bg-surface-container shadow-sm p-4">
      <div className="flex items-start gap-3">
        <span className="flex-shrink-0 w-7 h-7 rounded-full bg-surface-variant/60 text-on-surface-variant text-xs font-semibold flex items-center justify-center mt-0.5">
          {index + 1}
        </span>
        <div className="flex-1 min-w-0">
          <span className={`inline-block rounded-full px-2 py-0.5 text-xs font-medium mb-1 ${colorCls}`}>
            {label}
          </span>
          <StepBody step={step} />
        </div>
      </div>
    </li>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Main component
// ────────────────────────────────────────────────────────────────────────────

export default function PlanJsonViewer({
  planName,
  planJson,
}: {
  planName: string;
  planJson: string;
}) {
  const [tab, setTab] = useState<'structured' | 'raw'>('structured');

  const parsed: PlanData | null = (() => {
    try { return JSON.parse(planJson) as PlanData; } catch { return null; }
  })();

  function download() {
    const blob = new Blob([planJson], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${planName.replace(/[^a-z0-9_-]/gi, '_')}.json`;
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <div>
      {/* ── Toolbar ──────────────────────────────────────────────────── */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex rounded-lg border border-outline-variant overflow-hidden text-sm">
          {(['structured', 'raw'] as const).map((t) => (
            <button
              key={t}
              type="button"
              onClick={() => setTab(t)}
              className={[
                'px-4 py-1.5 font-medium capitalize transition-colors',
                tab === t
                  ? 'bg-primary text-white'
                  : 'text-on-surface-variant hover:bg-surface-variant/40',
              ].join(' ')}
            >
              {t}
            </button>
          ))}
        </div>
        <button
          type="button"
          onClick={download}
          className="rounded-lg bg-primary/10 px-4 py-1.5 text-sm font-medium text-primary hover:bg-primary/20 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
        >
          ↓ Download JSON
        </button>
      </div>

      {/* ── Structured ───────────────────────────────────────────────── */}
      {tab === 'structured' && parsed && (
        <div className="space-y-6">
          {/* Metadata */}
          <div className="rounded-xl bg-surface-container shadow-sm p-5 space-y-2">
            {parsed.description && (
              <p className="text-sm text-on-surface-variant">{parsed.description}</p>
            )}
            <div className="flex flex-wrap gap-2 text-xs">
              {parsed.category && chip(parsed.category)}
              {parsed.defaultVoice && chip(`voice: ${parsed.defaultVoice}`)}
              {(parsed.tags ?? []).map((tag, i) => (
                <span key={i} className="rounded-full bg-surface-variant px-2.5 py-0.5 text-xs text-on-surface-variant">
                  #{tag}
                </span>
              ))}
            </div>
          </div>

          {/* Steps */}
          {Array.isArray(parsed.steps) && (
            <>
              <h2 className="text-base font-semibold text-on-surface">
                Steps ({parsed.steps.length})
              </h2>
              {parsed.steps.length === 0
                ? <p className="text-sm text-on-surface-variant">No steps.</p>
                : (
                  <ol className="space-y-2">
                    {parsed.steps.map((step, i) => (
                      <StepRow key={step.id ?? i} step={step} index={i} />
                    ))}
                  </ol>
                )
              }
            </>
          )}
        </div>
      )}

      {tab === 'structured' && !parsed && (
        <p className="text-sm text-error">Could not parse plan JSON.</p>
      )}

      {/* ── Raw ──────────────────────────────────────────────────────── */}
      {tab === 'raw' && (
        <div className="rounded-xl bg-surface-container shadow-sm overflow-hidden">
          <pre className="p-5 text-xs text-on-surface-variant overflow-x-auto leading-relaxed whitespace-pre-wrap break-words">
            {parsed ? JSON.stringify(parsed, null, 2) : planJson}
          </pre>
        </div>
      )}
    </div>
  );
}
