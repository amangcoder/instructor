'use client';

import { useState, useCallback } from 'react';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface PublishToggleProps {
  /** Plan UUID */
  planId: string;
  /** Current publish state */
  initialValue: boolean;
  /** Callback after successful toggle — parent can refresh data */
  onToggled?: (newValue: boolean) => void;
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

function extractErrorMessage(data: unknown): string {
  if (typeof data === 'object' && data !== null && 'error' in data) {
    const msg = (data as Record<string, unknown>).error;
    if (typeof msg === 'string') return msg;
  }
  return 'Failed to update publish status.';
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * PublishToggle — client component
 *
 * A toggle switch for the plan's `is_published` field.
 * Calls PATCH /api/admin/plans/:id { isPublished } on change.
 *
 * Accessibility:
 *  - Uses a native checkbox styled as a toggle switch
 *  - Includes aria-checked and role="switch"
 *  - Keyboard navigable (Space to toggle)
 */
export default function PublishToggle({
  planId,
  initialValue,
  onToggled,
}: PublishToggleProps) {
  const [isPublished, setIsPublished] = useState(initialValue);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleToggle = useCallback(async () => {
    const newValue = !isPublished;
    setSaving(true);
    setError(null);

    try {
      const res = await fetch(`/api/admin/plans/${planId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isPublished: newValue }),
      });

      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        setError(extractErrorMessage(body));
        return;
      }

      setIsPublished(newValue);
      onToggled?.(newValue);
    } catch {
      setError('Network error. Please try again.');
    } finally {
      setSaving(false);
    }
  }, [isPublished, planId, onToggled]);

  return (
    <div className="flex flex-col gap-1">
      <div className="flex items-center gap-3">
        <button
          type="button"
          role="switch"
          aria-checked={isPublished}
          aria-label={isPublished ? 'Published — click to unpublish' : 'Unpublished — click to publish'}
          disabled={saving}
          onClick={() => { void handleToggle(); }}
          className={`relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed ${
            isPublished ? 'bg-primary' : 'bg-outline-variant'
          }`}
        >
          <span
            aria-hidden="true"
            className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow-sm ring-0 transition duration-200 ease-in-out ${
              isPublished ? 'translate-x-5' : 'translate-x-0'
            }`}
          />
        </button>
        <span className="text-sm font-medium text-on-surface">
          {saving ? 'Saving...' : isPublished ? 'Published' : 'Draft'}
        </span>
      </div>

      {error && (
        <p role="alert" className="text-xs text-error mt-1">
          {error}
        </p>
      )}
    </div>
  );
}
