'use client';

import { useEffect, useState, useCallback } from 'react';
import type {
  TtsHealthResponse,
  TtsProviderHealth,
  TtsHealthStatus,
} from '@/types/tts-health';

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

/** Polling interval in milliseconds — 60 seconds */
const POLL_INTERVAL_MS = 60_000;

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/** Aggregate status: worst status among all providers */
type AggregateStatus = 'healthy' | 'degraded' | 'offline';

function getAggregateStatus(providers: TtsProviderHealth[]): AggregateStatus {
  if (providers.length === 0) return 'offline';
  const hasOffline = providers.some((p) => p.status === 'unknown');
  const hasDegraded = providers.some((p) => p.status === 'degraded');
  if (hasOffline) return 'offline';
  if (hasDegraded) return 'degraded';
  return 'healthy';
}

function statusDotClass(status: TtsHealthStatus): string {
  switch (status) {
    case 'healthy': return 'bg-emerald-500';
    case 'degraded': return 'bg-amber-400';
    case 'unknown': return 'bg-red-500';
    default: return 'bg-slate-500';
  }
}

function statusLabel(status: TtsHealthStatus): string {
  switch (status) {
    case 'healthy': return 'Healthy';
    case 'degraded': return 'Degraded';
    case 'unknown': return 'Offline';
    default: return 'Unknown';
  }
}

function formatErrorRate(rate: number): string {
  return `${(rate * 100).toFixed(1)}%`;
}

function formatLastSuccess(iso: string | null): string {
  if (!iso) return 'No success in last 60 min';
  const date = new Date(iso);
  return date.toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

// ────────────────────────────────────────────────────────────────────────────
// Sub-component: ProviderRow
// ────────────────────────────────────────────────────────────────────────────

function ProviderRow({ provider }: { provider: TtsProviderHealth }) {
  const dotClass = statusDotClass(provider.status);
  const label = statusLabel(provider.status);

  const errorRateClass =
    provider.errorRateLast60m > 0.2
      ? 'font-semibold text-red-400'
      : provider.errorRateLast60m >= 0.05
        ? 'font-semibold text-amber-400'
        : 'font-medium text-slate-300';

  return (
    <li className="flex flex-wrap items-center gap-x-6 gap-y-1.5 px-6 py-3.5 border-b border-white/5 last:border-b-0">
      {/* Status dot */}
      <span
        aria-hidden="true"
        className={`inline-block h-2.5 w-2.5 flex-shrink-0 rounded-full ${dotClass}`}
      />

      {/* Provider name */}
      <span className="w-28 text-sm font-semibold capitalize text-white">
        {provider.provider}
      </span>

      {/* Status label */}
      <span className="w-20 text-sm text-slate-400">{label}</span>

      {/* Error rate */}
      <span className="flex items-center gap-1 text-sm text-slate-400">
        <span className="text-xs uppercase tracking-wide">Errors (60m):</span>
        <span className={errorRateClass}>
          {formatErrorRate(provider.errorRateLast60m)}
        </span>
      </span>

      {/* Last success */}
      <span className="ml-auto text-sm text-slate-500">
        <span className="text-xs uppercase tracking-wide">Last ok: </span>
        {formatLastSuccess(provider.lastSuccessAt)}
      </span>
    </li>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Main component: TtsHealthBanner
// ────────────────────────────────────────────────────────────────────────────

/**
 * TtsHealthBanner — 'use client' component
 *
 * Three visual states based on aggregate provider status:
 *   1. Healthy   — emerald bg/border, pulsing green dot
 *   2. Degraded  — amber bg/border, amber dot, Refresh button
 *   3. Offline   — red bg/border, red dot, Refresh button
 *
 * Polls /api/admin/tts-health-proxy every 60 seconds.
 *
 * Accessibility (WCAG 2.1 AA):
 *   - Section labelled via aria-label
 *   - Status dot is aria-hidden; status communicated via text label
 *   - Providers rendered as a <ul> list for screen-reader enumeration
 *   - Loading state announced via aria-busy on the section
 */
export default function TtsHealthBanner() {
  const [data, setData] = useState<TtsHealthResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [fetchError, setFetchError] = useState<string | null>(null);

  const fetchHealth = useCallback(async () => {
    try {
      const res = await fetch('/api/admin/tts-health-proxy', { cache: 'no-store' });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json: TtsHealthResponse = await res.json();
      setData(json);
      setFetchError(null);
    } catch (err) {
      setFetchError(err instanceof Error ? err.message : 'Failed to fetch TTS health');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void fetchHealth();
    const timer = setInterval(() => { void fetchHealth(); }, POLL_INTERVAL_MS);
    return () => clearInterval(timer);
  }, [fetchHealth]);

  const providers = data?.providers ?? [];
  const aggregateStatus = getAggregateStatus(providers);

  // Banner colour config per aggregate status
  const bannerConfig =
    aggregateStatus === 'healthy'
      ? {
          container: 'bg-emerald-950/80 border-emerald-500/20',
          dot: 'bg-emerald-500 animate-pulse',
          heading: 'text-emerald-300',
          headingText: 'All TTS providers healthy',
          sub: 'text-emerald-400/70',
        }
      : aggregateStatus === 'degraded'
        ? {
            container: 'bg-amber-950/80 border-amber-500/20',
            dot: 'bg-amber-400 animate-pulse',
            heading: 'text-amber-300',
            headingText: 'One or more providers degraded',
            sub: 'text-amber-400/70',
          }
        : {
            container: 'bg-red-950/80 border-red-500/20',
            dot: 'bg-red-500 animate-pulse',
            heading: 'text-red-300',
            headingText: 'One or more TTS providers are offline',
            sub: 'text-red-400/70',
          };

  const showRefresh = (aggregateStatus !== 'healthy' || !!fetchError) && !loading;

  return (
    <section
      aria-label="TTS Provider Health Status"
      aria-busy={loading}
      className={`mb-8 overflow-hidden rounded-xl border ${bannerConfig.container}`}
    >
      {/* ── Banner header ─────────────────────────────────────────────────── */}
      <div className="flex items-center justify-between px-6 py-4">
        <div className="flex items-center gap-3">
          <span
            aria-hidden="true"
            className={`inline-block h-2.5 w-2.5 flex-shrink-0 rounded-full ${loading ? 'bg-slate-500 animate-pulse' : bannerConfig.dot}`}
          />
          <div>
            <p className={`text-sm font-semibold ${bannerConfig.heading}`}>
              {loading
                ? 'Checking TTS provider health…'
                : fetchError
                  ? 'Failed to load health data'
                  : bannerConfig.headingText}
            </p>
            <p className={`mt-0.5 text-xs ${bannerConfig.sub}`}>
              Last 60 minutes · auto-refreshes every 60s
            </p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          {loading && (
            <span aria-live="polite" className={`text-xs ${bannerConfig.sub}`}>
              Loading…
            </span>
          )}
          {showRefresh && (
            <button
              type="button"
              onClick={() => { void fetchHealth(); }}
              className={[
                'border rounded-lg px-3 py-1.5 text-xs font-medium transition-colors',
                'focus-visible:outline-none focus-visible:outline-2 focus-visible:outline-indigo-400 focus-visible:outline-offset-2',
                aggregateStatus === 'degraded'
                  ? 'border-amber-500/30 text-amber-400 hover:bg-amber-500/10'
                  : 'border-red-500/30 text-red-400 hover:bg-red-500/10',
              ].join(' ')}
            >
              Refresh
            </button>
          )}
        </div>
      </div>

      {/* ── API error state ─────────────────────────────────────────────── */}
      {fetchError && !loading && (
        <div
          role="alert"
          className="bg-red-950/60 px-6 py-3 text-sm text-red-400 border-t border-red-500/20"
        >
          Failed to load provider health: {fetchError}
        </div>
      )}

      {/* ── No-data state ────────────────────────────────────────────────── */}
      {!loading && !fetchError && providers.length === 0 && (
        <div className="flex items-center gap-3 px-6 py-3 border-t border-white/8">
          <span
            aria-hidden="true"
            className="inline-block h-2.5 w-2.5 flex-shrink-0 rounded-full bg-slate-500"
          />
          <span className="text-sm text-slate-400">Unknown — no provider data available</span>
        </div>
      )}

      {/* ── Provider rows ─────────────────────────────────────────────────── */}
      {providers.length > 0 && (
        <ul role="list" aria-label="TTS providers" className="border-t border-white/8">
          {providers.map((p) => (
            <ProviderRow key={p.provider} provider={p} />
          ))}
        </ul>
      )}
    </section>
  );
}
