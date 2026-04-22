import React from 'react';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface EmptyStateProps {
  /**
   * Message to display inside the empty-state panel.
   * Should be a short, human-readable description of why no data is available
   * (e.g. 'No data for the selected period', 'No deletion requests pending').
   */
  message: string;
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * EmptyState — server component
 *
 * Renders a centred grey panel with a descriptive message.
 * Use this to replace blank panels or zero-value charts that would otherwise
 * show an empty or misleading graphic with no context for the admin.
 *
 * Follows REQ-018: empty / zero-data panels must provide a human-readable
 * explanation rather than showing a blank area or zero-value chart.
 *
 * Features:
 *  - Full-width, minimum-height container matching surrounding card styles
 *  - Centred text with a soft icon to soften the empty feeling
 *  - Theme-aware colours (surface-container / on-surface-variant)
 *
 * Accessibility:
 *  - role="status" so screen readers can announce the empty state
 *  - Message text is always visible — not hidden behind icons
 */
export default function EmptyState({ message }: EmptyStateProps) {
  return (
    <div
      className="flex min-h-[120px] flex-col items-center justify-center rounded-xl bg-surface-container p-8 text-center"
      role="status"
      aria-label={message}
    >
      {/* Decorative empty-box icon */}
      <span
        aria-hidden="true"
        className="mb-3 text-2xl text-on-surface-variant/40"
      >
        ◫
      </span>

      {/* Message text */}
      <p className="text-sm text-on-surface-variant">{message}</p>
    </div>
  );
}
