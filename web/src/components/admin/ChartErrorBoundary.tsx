'use client';

import React from 'react';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

interface Props {
  /** Chart component to render; caught on error */
  children: React.ReactNode;
  /** Optional fallback override (defaults to red-tinted error card) */
  fallback?: React.ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

// ────────────────────────────────────────────────────────────────────────────
// ChartErrorBoundary
// ────────────────────────────────────────────────────────────────────────────

/**
 * ChartErrorBoundary — class component error boundary
 *
 * Wraps chart components to catch render-time errors and display a
 * red-tinted fallback card instead of crashing the whole page.
 *
 * Usage:
 *   <ChartErrorBoundary>
 *     <TimeSeriesChart data={...} />
 *   </ChartErrorBoundary>
 *
 * Accessibility:
 *  - Error card uses role="alert" so screen readers announce the failure
 *  - Error message text is visible and readable (not just an icon)
 *
 * REQ-019: API errors surface as visible error states via ChartErrorBoundary
 */
export default class ChartErrorBoundary extends React.Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo): void {
    // Log to console so developers can diagnose issues
    console.error('[ChartErrorBoundary] Chart render error:', error, info);
  }

  render(): React.ReactNode {
    if (this.state.hasError) {
      // Allow callers to supply a custom fallback
      if (this.props.fallback) {
        return this.props.fallback;
      }

      return (
        <div
          role="alert"
          className="rounded-xl border border-error/30 bg-error-container/20 p-4"
        >
          <p className="text-sm font-semibold text-error">Chart failed to load</p>
          {this.state.error && (
            <p className="mt-1 text-xs text-on-surface-variant">
              {this.state.error.message}
            </p>
          )}
        </div>
      );
    }

    return this.props.children;
  }
}
