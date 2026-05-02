'use client';

import { useState, useCallback } from 'react';
import type { PlanVisibility } from '@/types/plan-detail';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface VisibilitySelectorProps {
  /** Plan UUID */
  planId: string;
  /** Current visibility value */
  initialValue: PlanVisibility;
  /** Callback after successful update — parent can refresh data */
  onChanged?: (newValue: PlanVisibility) => void;
}

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

const VISIBILITY_OPTIONS: { value: PlanVisibility; label: string }[] = [
  { value: 'private', label: 'Private' },
  { value: 'pending_review', label: 'Pending Review' },
  { value: 'public', label: 'Public' },
];

const SELECT_CLASS =
  'w-full rounded-lg border border-outline-variant bg-surface px-3 py-2 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent disabled:opacity-50 disabled:cursor-not-allowed';

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

function extractErrorMessage(data: unknown): string {
  if (typeof data === 'object' && data !== null && 'error' in data) {
    const msg = (data as Record<string, unknown>).error;
    if (typeof msg === 'string') return msg;
  }
  return 'Failed to update visibility.';
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * VisibilitySelector — client component
 *
 * A dropdown selector for the plan's `visibility` field.
 * Calls PATCH /api/admin/plans/:id { visibility } on change.
 *
 * Accessibility:
 *  - Uses native <select> for full keyboard + screen reader support
 *  - Includes a visible label
 *  - Error state shown via role="alert"
 */
export default function VisibilitySelector({
  planId,
  initialValue,
  onChanged,
}: VisibilitySelectorProps) {
  const [visibility, setVisibility] = useState<PlanVisibility>(initialValue);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleChange = useCallback(
    async (newValue: PlanVisibility) => {
      if (newValue === visibility) return;

      const previousValue = visibility;
      setVisibility(newValue); // optimistic
      setSaving(true);
      setError(null);

      try {
        const res = await fetch(`/api/admin/plans/${planId}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ visibility: newValue }),
        });

        if (!res.ok) {
          const body = await res.json().catch(() => ({}));
          setError(extractErrorMessage(body));
          setVisibility(previousValue); // revert
          return;
        }

        onChanged?.(newValue);
      } catch {
        setError('Network error. Please try again.');
        setVisibility(previousValue); // revert
      } finally {
        setSaving(false);
      }
    },
    [visibility, planId, onChanged],
  );

  return (
    <div className="flex flex-col gap-1">
      <label
        htmlFor="visibility-selector"
        className="block text-sm font-medium text-on-surface"
      >
        Visibility
      </label>
      <select
        id="visibility-selector"
        value={visibility}
        disabled={saving}
        onChange={(e) => {
          void handleChange(e.target.value as PlanVisibility);
        }}
        className={SELECT_CLASS}
        aria-describedby={error ? 'visibility-error' : undefined}
      >
        {VISIBILITY_OPTIONS.map((opt) => (
          <option key={opt.value} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>

      {saving && (
        <p className="text-xs text-on-surface-variant mt-1">Saving...</p>
      )}

      {error && (
        <p id="visibility-error" role="alert" className="text-xs text-error mt-1">
          {error}
        </p>
      )}
    </div>
  );
}
