'use client';

import { useState, useCallback, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import type { Voice } from '@/types/plan-detail';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface PlanDetailsEditorProps {
  planId: string;
  /**
   * Published voices used to populate the Default Voice dropdown.
   * When empty, the dropdown falls back to a freeform slug input so the page
   * remains usable if the voice list fetch failed.
   */
  voices: Voice[];
  initial: {
    name: string;
    description: string | null;
    category: string | null;
    tags: string[];
    defaultVoice: string | null;
  };
}

interface FormState {
  name: string;
  description: string;
  category: string;
  tagsRaw: string;
  defaultVoice: string;
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

function extractErrorMessage(data: unknown): string {
  if (typeof data === 'object' && data !== null && 'error' in data) {
    const msg = (data as Record<string, unknown>).error;
    if (typeof msg === 'string') return msg;
  }
  return 'Failed to save plan details.';
}

function diffPayload(initial: PlanDetailsEditorProps['initial'], form: FormState) {
  const tags = form.tagsRaw
    .split(',')
    .map((t) => t.trim())
    .filter((t) => t.length > 0);

  const payload: Record<string, unknown> = {};
  if (form.name !== initial.name) payload.name = form.name;
  if (form.description !== (initial.description ?? '')) {
    payload.description = form.description.length > 0 ? form.description : null;
  }
  if (form.category !== (initial.category ?? '')) payload.category = form.category;
  if (JSON.stringify(tags) !== JSON.stringify(initial.tags)) payload.tags = tags;
  if (form.defaultVoice !== (initial.defaultVoice ?? '')) payload.defaultVoice = form.defaultVoice;
  return payload;
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * PlanDetailsEditor — client component
 *
 * Edits the plan's name, description, category, tags (comma-separated), and
 * default voice. Submits via PATCH /api/admin/plans/:id with only the changed
 * fields, then triggers a router.refresh() so the page re-fetches the new
 * server-rendered state.
 */
export default function PlanDetailsEditor({ planId, voices, initial }: PlanDetailsEditorProps) {
  const router = useRouter();
  const [editing, setEditing] = useState(false);
  const [pasting, setPasting] = useState(false);
  const [pasteText, setPasteText] = useState('');
  const [pasteError, setPasteError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [savedAt, setSavedAt] = useState<number | null>(null);
  const [form, setForm] = useState<FormState>(() => ({
    name: initial.name,
    description: initial.description ?? '',
    category: initial.category ?? '',
    tagsRaw: initial.tags.join(', '),
    defaultVoice: initial.defaultVoice ?? '',
  }));

  const reset = useCallback(() => {
    setForm({
      name: initial.name,
      description: initial.description ?? '',
      category: initial.category ?? '',
      tagsRaw: initial.tags.join(', '),
      defaultVoice: initial.defaultVoice ?? '',
    });
    setError(null);
  }, [initial]);

  const handleSave = useCallback(async () => {
    setError(null);
    const payload = diffPayload(initial, form);
    if (Object.keys(payload).length === 0) {
      setEditing(false);
      return;
    }

    try {
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
      setSavedAt(Date.now());
      setEditing(false);
      startTransition(() => router.refresh());
    } catch {
      setError('Network error. Please try again.');
    }
  }, [form, initial, planId, router]);

  const cancel = useCallback(() => {
    reset();
    setEditing(false);
  }, [reset]);

  const handlePasteSave = useCallback(async () => {
    setPasteError(null);
    let parsed: unknown;
    try {
      parsed = JSON.parse(pasteText);
    } catch (e) {
      setPasteError(e instanceof Error ? e.message : 'Invalid JSON');
      return;
    }
    if (
      typeof parsed !== 'object' ||
      parsed === null ||
      Array.isArray(parsed) ||
      !Array.isArray((parsed as { steps?: unknown }).steps)
    ) {
      setPasteError('JSON must be an object with a `steps` array.');
      return;
    }

    const confirmed = window.confirm(
      'Replacing plan JSON will require regenerating TTS for changed steps. Continue?',
    );
    if (!confirmed) return;

    try {
      const res = await fetch(`/api/admin/plans/${planId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ planJson: JSON.stringify(parsed) }),
      });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        setPasteError(extractErrorMessage(body));
        return;
      }
      setSavedAt(Date.now());
      setPasting(false);
      setPasteText('');
      startTransition(() => router.refresh());
    } catch {
      setPasteError('Network error. Please try again.');
    }
  }, [pasteText, planId, router]);

  const cancelPaste = useCallback(() => {
    setPasting(false);
    setPasteText('');
    setPasteError(null);
  }, []);

  if (pasting) {
    return (
      <form
        onSubmit={(e) => {
          e.preventDefault();
          void handlePasteSave();
        }}
        className="space-y-3 rounded-lg border border-outline-variant/60 bg-surface-container-high p-4 sm:min-w-[480px]"
      >
        <label className="block text-sm">
          <span className="block text-xs font-medium text-on-surface-variant uppercase tracking-wider mb-1">
            Plan JSON (full replace)
          </span>
          <textarea
            rows={16}
            value={pasteText}
            onChange={(e) => setPasteText(e.target.value)}
            placeholder='{"name": "...", "steps": [ ... ]}'
            className="w-full rounded-lg bg-surface-container px-3 py-2 text-xs text-on-surface font-mono focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
            spellCheck={false}
            autoFocus
          />
        </label>
        {pasteError && (
          <p role="alert" className="text-xs text-error">
            {pasteError}
          </p>
        )}
        <div className="flex justify-end gap-2">
          <button
            type="button"
            onClick={cancelPaste}
            disabled={pending}
            className="rounded-lg px-3 py-1.5 text-xs font-semibold text-on-surface-variant hover:bg-surface-container-highest transition-colors disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={pending || pasteText.trim().length === 0}
            className="rounded-lg bg-primary px-3 py-1.5 text-xs font-semibold text-white hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
          >
            {pending ? 'Replacing...' : 'Replace plan'}
          </button>
        </div>
      </form>
    );
  }

  if (!editing) {
    return (
      <div className="flex flex-wrap items-center justify-end gap-3">
        {savedAt && (
          <span className="text-xs text-success" role="status">Saved</span>
        )}
        <button
          type="button"
          onClick={() => setPasting(true)}
          className="rounded-lg bg-surface-container-high px-3 py-1.5 text-xs font-semibold text-on-surface-variant hover:bg-surface-container-highest transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
        >
          Paste JSON
        </button>
        <button
          type="button"
          onClick={() => setEditing(true)}
          className="rounded-lg bg-primary/10 px-3 py-1.5 text-xs font-semibold text-primary hover:bg-primary/20 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
        >
          Edit details
        </button>
      </div>
    );
  }

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        void handleSave();
      }}
      className="space-y-4 rounded-lg border border-outline-variant/60 bg-surface-container-high p-4"
    >
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <label className="block text-sm sm:col-span-2">
          <span className="block text-xs font-medium text-on-surface-variant uppercase tracking-wider mb-1">
            Name
          </span>
          <input
            type="text"
            required
            value={form.name}
            onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
            className="w-full rounded-lg bg-surface-container px-3 py-2 text-sm text-on-surface focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
            maxLength={200}
          />
        </label>

        <label className="block text-sm sm:col-span-2">
          <span className="block text-xs font-medium text-on-surface-variant uppercase tracking-wider mb-1">
            Description
          </span>
          <textarea
            rows={3}
            value={form.description}
            onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
            className="w-full rounded-lg bg-surface-container px-3 py-2 text-sm text-on-surface focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
            maxLength={2000}
          />
        </label>

        <label className="block text-sm">
          <span className="block text-xs font-medium text-on-surface-variant uppercase tracking-wider mb-1">
            Category
          </span>
          <input
            type="text"
            value={form.category}
            onChange={(e) => setForm((f) => ({ ...f, category: e.target.value }))}
            className="w-full rounded-lg bg-surface-container px-3 py-2 text-sm text-on-surface focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
            maxLength={100}
          />
        </label>

        <label className="block text-sm">
          <span className="block text-xs font-medium text-on-surface-variant uppercase tracking-wider mb-1">
            Default Voice
          </span>
          {voices.length > 0 ? (
            <select
              value={form.defaultVoice}
              onChange={(e) => setForm((f) => ({ ...f, defaultVoice: e.target.value }))}
              className="w-full rounded-lg bg-surface-container px-3 py-2 text-sm text-on-surface focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
            >
              <option value="">— None —</option>
              {voices.map((v) => (
                <option key={v.id} value={v.slug}>
                  {v.displayName} ({v.locale}) · {v.slug}
                </option>
              ))}
            </select>
          ) : (
            <input
              type="text"
              value={form.defaultVoice}
              onChange={(e) => setForm((f) => ({ ...f, defaultVoice: e.target.value }))}
              placeholder="e.g. aoede"
              className="w-full rounded-lg bg-surface-container px-3 py-2 text-sm text-on-surface font-mono focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
              maxLength={100}
            />
          )}
        </label>

        <label className="block text-sm sm:col-span-2">
          <span className="block text-xs font-medium text-on-surface-variant uppercase tracking-wider mb-1">
            Tags (comma-separated)
          </span>
          <input
            type="text"
            value={form.tagsRaw}
            onChange={(e) => setForm((f) => ({ ...f, tagsRaw: e.target.value }))}
            placeholder="focus, deep-work, morning"
            className="w-full rounded-lg bg-surface-container px-3 py-2 text-sm text-on-surface focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
          />
        </label>
      </div>

      {error && (
        <p role="alert" className="text-xs text-error">
          {error}
        </p>
      )}

      <div className="flex justify-end gap-2">
        <button
          type="button"
          onClick={cancel}
          disabled={pending}
          className="rounded-lg px-3 py-1.5 text-xs font-semibold text-on-surface-variant hover:bg-surface-container-highest transition-colors disabled:opacity-50"
        >
          Cancel
        </button>
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-primary px-3 py-1.5 text-xs font-semibold text-white hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
        >
          {pending ? 'Saving...' : 'Save changes'}
        </button>
      </div>
    </form>
  );
}
