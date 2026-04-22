'use client';

import { useState, useEffect, useCallback, type FormEvent } from 'react';
import type { AdminLibraryPlanRecord } from '@/types/analytics';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

type FormData = {
  name: string;
  description: string;
  category: string;
  tags: string;
  defaultVoice: string;
  planJson: string;
  locale: string;
  isPublished: boolean;
  sortOrder: string;
};

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

const EMPTY_FORM: FormData = {
  name: '',
  description: '',
  category: '',
  tags: '',
  defaultVoice: '',
  planJson: '',
  locale: 'enUS',
  isPublished: false,
  sortOrder: '0',
};

const INPUT_CLASS =
  'w-full rounded-lg border border-outline-variant bg-surface px-3 py-2 text-sm text-on-surface placeholder:text-outline focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent disabled:opacity-50';

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

function planToForm(plan: AdminLibraryPlanRecord): FormData {
  return {
    name: plan.name,
    description: plan.description ?? '',
    category: plan.category,
    tags: plan.tags,
    defaultVoice: plan.defaultVoice,
    planJson: plan.planJson,
    locale: plan.locale,
    isPublished: plan.isPublished,
    sortOrder: String(plan.sortOrder),
  };
}

function extractMessage(data: unknown): string {
  if (
    typeof data === 'object' &&
    data !== null &&
    'message' in data
  ) {
    const msg = (data as Record<string, unknown>).message;
    if (Array.isArray(msg)) return msg.join(', ');
    if (typeof msg === 'string') return msg;
  }
  return 'Request failed.';
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * LibraryPlanManager — client component
 *
 * Full CRUD interface for the global library plan catalogue, embedded in the
 * admin library page below the analytics section.
 *
 * Fetches all plans (including unpublished) via the Next.js proxy route
 * GET /api/library/plans, which forwards with the server-side API key.
 */
export default function LibraryPlanManager() {
  const [plans, setPlans] = useState<AdminLibraryPlanRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [fetchError, setFetchError] = useState<string | null>(null);

  // Modal state
  const [modalMode, setModalMode] = useState<'create' | 'edit' | null>(null);
  const [editTarget, setEditTarget] = useState<AdminLibraryPlanRecord | null>(null);
  const [form, setForm] = useState<FormData>(EMPTY_FORM);
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  // Delete state
  const [deleteTarget, setDeleteTarget] = useState<AdminLibraryPlanRecord | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  // ── Data fetching ─────────────────────────────────────────────────────────

  const fetchPlans = useCallback(async () => {
    setLoading(true);
    setFetchError(null);
    try {
      const res = await fetch('/api/library/plans');
      if (!res.ok) {
        setFetchError('Failed to load library plans.');
        return;
      }
      setPlans(await res.json() as AdminLibraryPlanRecord[]);
    } catch {
      setFetchError('Network error loading library plans.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void fetchPlans(); }, [fetchPlans]);

  // ── Modal helpers ─────────────────────────────────────────────────────────

  const openCreate = () => {
    setForm(EMPTY_FORM);
    setFormError(null);
    setEditTarget(null);
    setModalMode('create');
  };

  const openEdit = (plan: AdminLibraryPlanRecord) => {
    setForm(planToForm(plan));
    setFormError(null);
    setEditTarget(plan);
    setModalMode('edit');
  };

  const closeModal = () => {
    setModalMode(null);
    setEditTarget(null);
    setFormError(null);
  };

  // ── Form submit ───────────────────────────────────────────────────────────

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setFormError(null);
    setSubmitting(true);

    const payload = {
      name: form.name.trim(),
      description: form.description.trim() || undefined,
      category: form.category.trim(),
      tags: form.tags.trim() || undefined,
      defaultVoice: form.defaultVoice.trim(),
      planJson: form.planJson.trim(),
      locale: form.locale.trim() || 'enUS',
      isPublished: form.isPublished,
      sortOrder: parseInt(form.sortOrder, 10) || 0,
    };

    try {
      const url = modalMode === 'create'
        ? '/api/library/plans'
        : `/api/library/plans/${editTarget!.id}`;

      const res = await fetch(url, {
        method: modalMode === 'create' ? 'POST' : 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      if (!res.ok) {
        setFormError(extractMessage(await res.json().catch(() => ({}))));
        return;
      }

      closeModal();
      await fetchPlans();
    } catch {
      setFormError('Network error. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  // ── Delete ────────────────────────────────────────────────────────────────

  const handleDelete = async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    setDeleteError(null);

    try {
      const res = await fetch(`/api/library/plans/${deleteTarget.id}`, { method: 'DELETE' });

      if (!res.ok && res.status !== 204) {
        setDeleteError('Failed to delete plan. Please try again.');
        return;
      }

      setDeleteTarget(null);
      await fetchPlans();
    } catch {
      setDeleteError('Network error. Please try again.');
    } finally {
      setDeleting(false);
    }
  };

  // ── Render ────────────────────────────────────────────────────────────────

  return (
    <section aria-labelledby="library-crud-heading" className="mt-10">
      {/* ── Section header ─────────────────────────────────────────────────── */}
      <div className="flex items-center justify-between mb-4">
        <h2
          id="library-crud-heading"
          className="text-lg font-semibold text-on-surface"
        >
          Manage Plans
        </h2>
        <button
          type="button"
          onClick={openCreate}
          className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white hover:bg-primary/90 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
        >
          + New Plan
        </button>
      </div>

      {fetchError && (
        <div
          role="alert"
          className="rounded-lg bg-error-container p-3 text-sm text-on-error-container mb-4"
        >
          {fetchError}
        </div>
      )}

      {/* ── Plans table ────────────────────────────────────────────────────── */}
      <div className="rounded-xl bg-surface-container shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table
            className="w-full text-sm"
            aria-label="Library plans management table"
          >
            <thead>
              <tr className="border-b border-outline-variant bg-surface-container-high">
                {['Name', 'Category', 'Status', 'Sort', 'Actions'].map((h, i) => (
                  <th
                    key={h}
                    scope="col"
                    className={`px-4 py-3 text-xs font-semibold text-on-surface-variant uppercase tracking-wider ${i >= 3 ? 'text-right' : 'text-left'}`}
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {loading && (
                <tr>
                  <td
                    colSpan={5}
                    className="px-4 py-8 text-center text-on-surface-variant"
                  >
                    Loading…
                  </td>
                </tr>
              )}
              {!loading && plans.length === 0 && !fetchError && (
                <tr>
                  <td
                    colSpan={5}
                    className="px-4 py-8 text-center text-on-surface-variant"
                  >
                    No plans yet. Create one above.
                  </td>
                </tr>
              )}
              {plans.map((plan) => (
                <tr
                  key={plan.id}
                  className="border-b border-outline-variant/50 hover:bg-primary/5 transition-colors last:border-b-0"
                >
                  <td className="px-4 py-3 font-medium text-on-surface">
                    {plan.name}
                  </td>
                  <td className="px-4 py-3 text-on-surface-variant capitalize">
                    {plan.category}
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${
                        plan.isPublished
                          ? 'bg-primary/10 text-primary'
                          : 'bg-surface-container-high text-on-surface-variant'
                      }`}
                    >
                      {plan.isPublished ? 'Published' : 'Draft'}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-right tabular-nums text-on-surface-variant">
                    {plan.sortOrder}
                  </td>
                  <td className="px-4 py-3 text-right space-x-2 whitespace-nowrap">
                    <button
                      type="button"
                      onClick={() => openEdit(plan)}
                      className="rounded px-2 py-1 text-xs font-medium text-primary hover:bg-primary/10 transition-colors"
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      onClick={() => { setDeleteTarget(plan); setDeleteError(null); }}
                      className="rounded px-2 py-1 text-xs font-medium text-error hover:bg-error/10 transition-colors"
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── Create / Edit modal ─────────────────────────────────────────────── */}
      {modalMode !== null && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50"
          role="dialog"
          aria-modal="true"
          aria-labelledby="plan-modal-title"
        >
          <div className="w-full max-w-2xl max-h-[90vh] overflow-y-auto rounded-2xl bg-surface p-6 shadow-xl">
            <div className="flex items-center justify-between mb-5">
              <h3
                id="plan-modal-title"
                className="text-lg font-semibold text-on-surface"
              >
                {modalMode === 'create' ? 'New Library Plan' : 'Edit Library Plan'}
              </h3>
              <button
                type="button"
                onClick={closeModal}
                aria-label="Close"
                className="rounded-lg p-1 text-on-surface-variant hover:bg-surface-container transition-colors"
              >
                ✕
              </button>
            </div>

            {formError && (
              <div
                role="alert"
                className="mb-4 rounded-lg bg-error-container p-3 text-sm text-on-error-container"
              >
                {formError}
              </div>
            )}

            <form onSubmit={(e) => { void handleSubmit(e); }} className="space-y-4" noValidate>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">

                <div className="sm:col-span-2">
                  <label htmlFor="plan-name" className="block text-sm font-medium text-on-surface mb-1">
                    Name *
                  </label>
                  <input
                    id="plan-name"
                    type="text"
                    required
                    maxLength={200}
                    disabled={submitting}
                    value={form.name}
                    onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                    className={INPUT_CLASS}
                    placeholder="e.g. Morning Mindfulness"
                  />
                </div>

                <div className="sm:col-span-2">
                  <label htmlFor="plan-description" className="block text-sm font-medium text-on-surface mb-1">
                    Description
                  </label>
                  <textarea
                    id="plan-description"
                    rows={2}
                    maxLength={1000}
                    disabled={submitting}
                    value={form.description}
                    onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
                    className={INPUT_CLASS}
                    placeholder="Short description…"
                  />
                </div>

                <div>
                  <label htmlFor="plan-category" className="block text-sm font-medium text-on-surface mb-1">
                    Category *
                  </label>
                  <input
                    id="plan-category"
                    type="text"
                    required
                    maxLength={100}
                    disabled={submitting}
                    value={form.category}
                    onChange={(e) => setForm((f) => ({ ...f, category: e.target.value }))}
                    className={INPUT_CLASS}
                    placeholder="e.g. meditation"
                  />
                </div>

                <div>
                  <label htmlFor="plan-voice" className="block text-sm font-medium text-on-surface mb-1">
                    Default Voice *
                  </label>
                  <input
                    id="plan-voice"
                    type="text"
                    required
                    maxLength={100}
                    disabled={submitting}
                    value={form.defaultVoice}
                    onChange={(e) => setForm((f) => ({ ...f, defaultVoice: e.target.value }))}
                    className={INPUT_CLASS}
                    placeholder="e.g. en-US-Neural2-F"
                  />
                </div>

                <div>
                  <label htmlFor="plan-tags" className="block text-sm font-medium text-on-surface mb-1">
                    Tags
                  </label>
                  <input
                    id="plan-tags"
                    type="text"
                    maxLength={500}
                    disabled={submitting}
                    value={form.tags}
                    onChange={(e) => setForm((f) => ({ ...f, tags: e.target.value }))}
                    className={INPUT_CLASS}
                    placeholder="comma,separated,tags"
                  />
                </div>

                <div>
                  <label htmlFor="plan-locale" className="block text-sm font-medium text-on-surface mb-1">
                    Locale
                  </label>
                  <input
                    id="plan-locale"
                    type="text"
                    maxLength={20}
                    disabled={submitting}
                    value={form.locale}
                    onChange={(e) => setForm((f) => ({ ...f, locale: e.target.value }))}
                    className={INPUT_CLASS}
                    placeholder="enUS"
                  />
                </div>

                <div>
                  <label htmlFor="plan-sort" className="block text-sm font-medium text-on-surface mb-1">
                    Sort Order
                  </label>
                  <input
                    id="plan-sort"
                    type="number"
                    min={0}
                    disabled={submitting}
                    value={form.sortOrder}
                    onChange={(e) => setForm((f) => ({ ...f, sortOrder: e.target.value }))}
                    className={INPUT_CLASS}
                  />
                </div>

                <div className="flex items-center gap-2 sm:pt-5">
                  <input
                    id="plan-published"
                    type="checkbox"
                    disabled={submitting}
                    checked={form.isPublished}
                    onChange={(e) => setForm((f) => ({ ...f, isPublished: e.target.checked }))}
                    className="h-4 w-4 rounded border-outline-variant text-primary focus:ring-primary"
                  />
                  <label
                    htmlFor="plan-published"
                    className="text-sm font-medium text-on-surface"
                  >
                    Published
                  </label>
                </div>

                <div className="sm:col-span-2">
                  <label htmlFor="plan-json" className="block text-sm font-medium text-on-surface mb-1">
                    Plan JSON *
                  </label>
                  <textarea
                    id="plan-json"
                    required
                    rows={8}
                    disabled={submitting}
                    value={form.planJson}
                    onChange={(e) => setForm((f) => ({ ...f, planJson: e.target.value }))}
                    className={`${INPUT_CLASS} font-mono text-xs`}
                    placeholder='{"phases": [...]}'
                  />
                </div>
              </div>

              <div className="flex justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={closeModal}
                  disabled={submitting}
                  className="rounded-lg px-4 py-2 text-sm font-medium text-on-surface-variant hover:text-on-surface hover:bg-surface-container transition-colors disabled:opacity-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
                >
                  {submitting
                    ? 'Saving…'
                    : modalMode === 'create'
                    ? 'Create'
                    : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── Delete confirmation modal ────────────────────────────────────────── */}
      {deleteTarget && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50"
          role="dialog"
          aria-modal="true"
          aria-labelledby="delete-modal-title"
        >
          <div className="w-full max-w-sm rounded-2xl bg-surface p-6 shadow-xl">
            <h3
              id="delete-modal-title"
              className="text-base font-semibold text-on-surface mb-2"
            >
              Delete Plan
            </h3>
            <p className="text-sm text-on-surface-variant mb-1">
              Are you sure you want to delete{' '}
              <strong className="text-on-surface">{deleteTarget.name}</strong>?
            </p>
            <p className="text-xs text-on-surface-variant mb-4">
              This action cannot be undone.
            </p>

            {deleteError && (
              <div
                role="alert"
                className="mb-4 rounded-lg bg-error-container p-3 text-sm text-on-error-container"
              >
                {deleteError}
              </div>
            )}

            <div className="flex justify-end gap-3">
              <button
                type="button"
                onClick={() => setDeleteTarget(null)}
                disabled={deleting}
                className="rounded-lg px-4 py-2 text-sm font-medium text-on-surface-variant hover:text-on-surface hover:bg-surface-container transition-colors disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={() => { void handleDelete(); }}
                disabled={deleting}
                className="rounded-lg bg-error px-4 py-2 text-sm font-semibold text-white hover:bg-error/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error focus-visible:ring-offset-2"
              >
                {deleting ? 'Deleting…' : 'Delete'}
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}
