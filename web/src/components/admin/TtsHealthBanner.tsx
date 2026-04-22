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

/**
 * Map TTS health status to a Tailwind background-colour class for the dot.
 *
 * Colour rules (AC-007):
 *   green  — healthy   (error rate < 5%)
 *   amber  — degraded  (error rate 5–20%)
 *   red    — unknown   (error rate > 20% or no success in last 60m)
 *   grey   — (fallback) no data / fully unknown
 */
function statusDotClass(status: TtsHealthStatus): string {
  switch (status) {
    case 'healthy':
      return 'bg-green-500';
    case 'degraded':
      return 'bg-amber-400';
    case 'unknown':
      return 'bg-red-500';
    default:
      return 'bg-gray-400';
  }
}

function statusLabel(status: TtsHealthStatus): string {
  switch (status) {
    case 'healthy':
      return 'Healthy';
    case 'degraded':
      return 'Degraded';
    case 'unknown':
      return 'Unknown';
    default:
      return 'Unknown';
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
      ? 'font-semibold text-error'
      : provider.errorRateLast60m >= 0.05
        ? 'font-semibold text-amber-600'
        : 'font-medium text-on-surface';

  return (
    <li className="flex flex-wrap items-center gap-x-6 gap-y-1.5 px-6 py-4">
      {/* Status dot */}
      <span
        aria-hidden="true"
        className={`inline-block h-3 w-3 flex-shrink-0 rounded-full ${dotClass}`}
      />

      {/* Provider name */}
      <span className="w-28 text-sm font-semibold capitalize text-on-surface">
        {provider.provider}
      </span>

      {/* Status label */}
      <span className="w-20 text-sm text-on-surface-variant">{label}</span>

      {/* Error rate */}
      <span className="flex items-center gap-1 text-sm text-on-surface-variant">
        <span className="text-xs uppercase tracking-wide">Error rate (60m):</span>
        <span className={errorRateClass}>
          {formatErrorRate(provider.errorRateLast60m)}
        </span>
      </span>

      {/* Last success */}
      <span className="ml-auto text-sm text-on-surface-variant">
        <span className="text-xs uppercase tracking-wide">Last success: </span>
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
 * Polls /api/admin/tts-health-proxy every 60 seconds and renders a status
 * banner showing one row per TTS provider (Kokoro + ElevenLabs) with:
 *   - Provider name
 *   - Colour-coded status dot (green / amber / red / grey)
 *   - Error rate percentage for the last 60 minutes
 *   - Last successful job timestamp
 *
 * The proxy route reads the httpOnly access_token cookie server-side so
 * the admin JWT is never exposed to the browser.
 *
 * Accessibility (WCAG 2.1 AA):
 *   - Section labelled via aria-label
 *   - Status dot is aria-hidden; status is communicated via text label
 *   - Providers rendered as a <ul> list for screen-reader enumeration
 *   - Loading state announced via aria-busy on the section
 */
export default function TtsHealthBanner() {
  const [data, setData] = useState<TtsHealthResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [fetchError, setFetchError] = useState<string | null>(null);

  const fetchHealth = useCallback(async () => {
    try {
      const res = await fetch('/api/admin/tts-health-proxy', {
        cache: 'no-store',
      });
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }
      const json: TtsHealthResponse = await res.json();
      setData(json);
      setFetchError(null);
    } catch (err) {
      setFetchError(
        err instanceof Error ? err.message : 'Failed to fetch TTS health',
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchHealth();
    const timer = setInterval(fetchHealth, POLL_INTERVAL_MS);
    return () => clearInterval(timer);
  }, [fetchHealth]);

  const hasProviders = data && data.providers.length > 0;

  return (
    <section
      aria-label="TTS Provider Health Status"
      aria-busy={loading}
      className="mb-8 overflow-hidden rounded-xl bg-surface-container shadow-sm"
    >
      {/* ── Header ──────────────────────────────────────────────────────────── */}
      <div className="flex items-center justify-between border-b border-outline-variant px-6 py-4">
        <div>
          <p className="text-sm font-semibold text-on-surface">
            Provider Health
          </p>
          <p className="mt-0.5 text-xs text-on-surface-variant">
            Last 60 minutes · auto-refreshes every 60s
          </p>
        </div>
        <span
          aria-live="polite"
          className="animate-pulse text-xs text-on-surface-variant"
        >
          {loading ? 'Loading…' : ''}
        </span>
      </div>

      {/* ── API error state ─────────────────────────────────────────────────── */}
      {fetchError && !loading && (
        <div
          role="alert"
          className="bg-error-container px-6 py-4 text-sm text-on-error-container"
        >
          Failed to load provider health: {fetchError}
        </div>
      )}

      {/* ── No-data / unknown state ─────────────────────────────────────────── */}
      {!loading && !fetchError && !hasProviders && (
        <div className="flex items-center gap-3 px-6 py-4">
          <span
            aria-hidden="true"
            className="inline-block h-3 w-3 flex-shrink-0 rounded-full bg-gray-400"
          />
          <span className="text-sm text-on-surface-variant">
            Unknown — no provider data available
          </span>
        </div>
      )}

      {/* ── Provider rows ───────────────────────────────────────────────────── */}
      {hasProviders && (
        <ul
          role="list"
          className="divide-y divide-outline-variant"
          aria-label="TTS providers"
        >
          {data.providers.map((p) => (
            <ProviderRow key={p.provider} provider={p} />
          ))}
        </ul>
      )}
    </section>
  );
}
