import React from 'react';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface EmptyStateProps {
  /**
   * Visual variant.
   * 'default' — SVG illustration, heading, sub-text, optional CTA.
   * 'error'   — amber AlertTriangle icon, 'Failed to load data', Retry button.
   */
  variant?: 'default' | 'error';
  /** Short heading text */
  title?: string;
  /**
   * Descriptive message.
   * Kept for backward compatibility — maps to title if title is not set.
   */
  message?: string;
  /** Label for the optional CTA button */
  ctaLabel?: string;
  /** Callback for the CTA button */
  onCta?: () => void;
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * EmptyState — server/client component
 *
 * Two variants:
 *  - 'default' — empty box SVG illustration with heading, message, optional CTA
 *  - 'error'   — amber AlertTriangle icon with 'Failed to load data' and Retry
 *
 * Accessibility:
 *  - role="status" so screen readers can announce the state
 *  - Message text is always visible
 */
export default function EmptyState({
  variant = 'default',
  title,
  message,
  ctaLabel,
  onCta,
}: EmptyStateProps) {
  const isError = variant === 'error';
  const displayTitle = title ?? (isError ? 'Failed to load data' : 'No data available');

  return (
    <div
      className="flex min-h-[120px] flex-col items-center justify-center rounded-xl bg-slate-800/50 border border-white/8 p-8 text-center"
      role="status"
      aria-label={displayTitle}
    >
      {isError ? (
        /* ── Error variant: amber AlertTriangle ───────────────────────── */
        <>
          <div aria-hidden="true" className="mb-3">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              className="w-6 h-6 text-amber-400"
            >
              <path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3" />
              <path d="M12 9v4" />
              <path d="M12 17h.01" />
            </svg>
          </div>
          <p className="text-sm font-medium text-slate-300 mb-1">{displayTitle}</p>
          {message && <p className="text-xs text-slate-500 mt-1">{message}</p>}
          {onCta && (
            <button
              type="button"
              onClick={onCta}
              className="mt-4 border border-white/10 text-slate-400 hover:text-white hover:border-white/20 rounded-lg px-4 py-2 text-sm transition-colors focus-visible:outline-none focus-visible:outline-2 focus-visible:outline-indigo-400 focus-visible:outline-offset-2"
            >
              {ctaLabel ?? 'Retry'}
            </button>
          )}
        </>
      ) : (
        /* ── Default variant: empty box SVG ───────────────────────────── */
        <>
          <div aria-hidden="true" className="mb-3">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 64 64"
              fill="none"
              className="w-16 h-16 text-slate-600"
            >
              <rect x="8" y="16" width="48" height="36" rx="4" stroke="currentColor" strokeWidth="2" />
              <path d="M8 24h48" stroke="currentColor" strokeWidth="2" />
              <path d="M24 16V8M40 16V8" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
              <path d="M22 36h20M22 42h12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
            </svg>
          </div>
          <p className="text-sm font-medium text-slate-300 mb-1">{displayTitle}</p>
          {message && <p className="text-xs text-slate-500 mt-1">{message}</p>}
          {onCta && (
            <button
              type="button"
              onClick={onCta}
              className="mt-4 border border-white/10 text-slate-400 hover:text-white hover:border-white/20 rounded-lg px-4 py-2 text-sm transition-colors focus-visible:outline-none focus-visible:outline-2 focus-visible:outline-indigo-400 focus-visible:outline-offset-2"
            >
              {ctaLabel ?? 'Try again'}
            </button>
          )}
        </>
      )}
    </div>
  );
}
