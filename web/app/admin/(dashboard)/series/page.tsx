'use client';

/**
 * Admin Series Page — client component (REQ-015)
 *
 * Lists all series (including drafts) grouped by category and provides
 * full CRUD: create, update, delete, publish toggle, and per-series plan
 * reorder via dedicated proxy routes.
 *
 * Route: /admin/series
 * Layout: AdminDashboardLayout (auth-gated, sidebar)
 */

import { useState, useEffect, useCallback, type FormEvent, type MouseEvent } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import type { AdminSeriesRecord } from '@/types/series';
import type { Category } from '@/types/categories';
import type { Voice } from '@/types/plan-detail';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

interface SeriesByCategory {
  [category: string]: AdminSeriesRecord[];
}

interface SeriesFormData {
  name: string;
  description: string;
  category: string;
  defaultVoice: string;
  locale: string;
  tags: string;
  sortOrder: string;
  isPublished: boolean;
}

const EMPTY_FORM: SeriesFormData = {
  name: '',
  description: '',
  category: '',
  defaultVoice: '',
  locale: 'en-US',
  tags: '',
  sortOrder: '0',
  isPublished: false,
};

const INPUT_CLASS =
  'w-full rounded-lg border border-outline-variant bg-surface px-3 py-2 text-sm text-on-surface placeholder:text-outline focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent disabled:opacity-50';

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

function groupByCategory(series: AdminSeriesRecord[]): SeriesByCategory {
  return series.reduce<SeriesByCategory>((acc, s) => {
    const key = s.category || 'Uncategorised';
    if (!acc[key]) acc[key] = [];
    acc[key].push(s);
    return acc;
  }, {});
}

function seriesToForm(s: AdminSeriesRecord): SeriesFormData {
  return {
    name: s.name,
    description: s.description ?? '',
    category: s.category,
    defaultVoice: s.defaultVoice,
    locale: s.locale,
    tags: s.tags ?? '',
    sortOrder: String(s.sortOrder),
    isPublished: s.isPublished,
  };
}

function extractMessage(data: unknown): string {
  if (typeof data === 'object' && data !== null) {
    const obj = data as Record<string, unknown>;
    const msg = obj.message ?? obj.error;
    if (Array.isArray(msg)) return msg.join(', ');
    if (typeof msg === 'string') return msg;
  }
  return 'Request failed.';
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

export default function AdminSeriesPage() {
  const router = useRouter();
  const [series, setSeries] = useState<AdminSeriesRecord[]>([]);
  const [voices, setVoices] = useState<Voice[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [togglingId, setTogglingId] = useState<string | null>(null);

  const handleRowClick = (e: MouseEvent<HTMLTableRowElement>, seriesId: string) => {
    // Ignore clicks that originated from interactive children (buttons, links).
    if ((e.target as HTMLElement).closest('button, a')) return;
    router.push(`/admin/series/${seriesId}`);
  };

  // ── Modal state ──────────────────────────────────────────────────────────
  const [modalMode, setModalMode] = useState<'create' | 'edit' | null>(null);
  const [editTarget, setEditTarget] = useState<AdminSeriesRecord | null>(null);
  const [form, setForm] = useState<SeriesFormData>(EMPTY_FORM);
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  // ── Delete state ─────────────────────────────────────────────────────────
  const [deleteTarget, setDeleteTarget] = useState<AdminSeriesRecord | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  // ── Fetch series ─────────────────────────────────────────────────────────

  const fetchSeries = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/admin/series');
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error(extractMessage(body) || `HTTP ${res.status}`);
      }
      const data = (await res.json()) as AdminSeriesRecord[];
      setSeries(Array.isArray(data) ? data : []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load series.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void fetchSeries();
  }, [fetchSeries]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch('/api/admin/voices');
        if (!res.ok) return;
        const data = (await res.json()) as Voice[];
        if (!cancelled && Array.isArray(data)) setVoices(data);
      } catch {
        // Leave voices empty — the form falls back to a freeform input.
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch('/api/admin/categories');
        if (!res.ok) return;
        const data = (await res.json()) as unknown;
        if (cancelled) return;
        // The admin endpoint returns { categories, total, page, pageSize }.
        // Accept a bare array too in case the proxy is bypassed.
        const list: unknown = Array.isArray(data)
          ? data
          : typeof data === 'object' && data !== null &&
              Array.isArray((data as { categories?: unknown }).categories)
            ? (data as { categories: unknown[] }).categories
            : [];
        if (!Array.isArray(list)) return;
        // Defensive filter — keeps the dropdown clean if upstream shape drifts.
        const valid = list.filter(
          (c): c is Category =>
            typeof c === 'object' &&
            c !== null &&
            typeof (c as Category).id === 'string' &&
            typeof (c as Category).slug === 'string' &&
            typeof (c as Category).name === 'string',
        );
        setCategories(valid);
      } catch {
        // Leave categories empty — the form falls back to a freeform input.
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  // ── Publish toggle ───────────────────────────────────────────────────────

  const handlePublishToggle = async (s: AdminSeriesRecord) => {
    setTogglingId(s.id);
    try {
      const res = await fetch(`/api/admin/series/${s.id}/publish`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ is_published: !s.isPublished }),
      });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error(extractMessage(body) || `HTTP ${res.status}`);
      }
      setSeries((prev) =>
        prev.map((item) =>
          item.id === s.id ? { ...item, isPublished: !s.isPublished } : item,
        ),
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update publish state.');
    } finally {
      setTogglingId(null);
    }
  };

  // ── Modal helpers ────────────────────────────────────────────────────────

  const openCreate = () => {
    setForm(EMPTY_FORM);
    setFormError(null);
    setEditTarget(null);
    setModalMode('create');
  };

  const openEdit = (s: AdminSeriesRecord) => {
    setForm(seriesToForm(s));
    setFormError(null);
    setEditTarget(s);
    setModalMode('edit');
  };

  const closeModal = () => {
    setModalMode(null);
    setEditTarget(null);
    setFormError(null);
  };

  // ── Create / Edit submit ─────────────────────────────────────────────────

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setFormError(null);
    setSubmitting(true);

    const categorySlug = form.category.trim();
    const matchedCategory = categories.find((c) => c.slug === categorySlug);
    const payload = {
      name: form.name.trim(),
      description: form.description.trim() || undefined,
      category: categorySlug,
      // Resolving categoryId here is what makes the series visible in the
      // app's category-scoped views (GET /api/series?categorySlug=…), which
      // INNER JOIN on series.categoryId.
      ...(matchedCategory ? { categoryId: matchedCategory.id } : {}),
      defaultVoice: form.defaultVoice.trim(),
      locale: form.locale.trim() || undefined,
      tags: form.tags.trim() || undefined,
      sortOrder: parseInt(form.sortOrder, 10) || 0,
      isPublished: form.isPublished,
    };

    try {
      const url =
        modalMode === 'create'
          ? '/api/admin/series'
          : `/api/admin/series/${editTarget!.id}`;

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
      await fetchSeries();
    } catch {
      setFormError('Network error. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  // ── Delete ───────────────────────────────────────────────────────────────

  const openDeleteConfirm = (s: AdminSeriesRecord) => {
    setDeleteTarget(s);
    setDeleteError(null);
  };

  const handleDelete = async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    setDeleteError(null);

    try {
      const res = await fetch(`/api/admin/series/${deleteTarget.id}`, {
        method: 'DELETE',
      });

      if (!res.ok && res.status !== 204) {
        setDeleteError(extractMessage(await res.json().catch(() => ({}))));
        return;
      }

      setDeleteTarget(null);
      await fetchSeries();
    } catch {
      setDeleteError('Network error. Please try again.');
    } finally {
      setDeleting(false);
    }
  };

  // ── Grouped data ─────────────────────────────────────────────────────────

  const grouped = groupByCategory(series);
  const groupedKeys = Object.keys(grouped).sort();

  // ── Render ───────────────────────────────────────────────────────────────

  return (
    <div>
      {/* ── Page header ──────────────────────────────────────────────────── */}
      <div className="mb-8 flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-on-surface">Series</h1>
          <p className="mt-1 text-sm text-on-surface-variant">
            Manage multi-session programs. Create, edit, delete, toggle publish state,
            or reorder plans within each series.
          </p>
        </div>
        <button
          type="button"
          onClick={openCreate}
          className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white hover:bg-primary/90 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 flex-shrink-0"
        >
          + New Series
        </button>
      </div>

      {/* ── Error banner ──────────────────────────────────────────────────── */}
      {error && (
        <div
          className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-6"
          role="alert"
        >
          <p className="font-medium">Error</p>
          <p className="mt-1">{error}</p>
        </div>
      )}

      {/* ── Loading ───────────────────────────────────────────────────────── */}
      {loading && (
        <div
          className="flex items-center justify-center py-20 text-on-surface-variant text-sm"
          role="status"
          aria-label="Loading series"
        >
          Loading series…
        </div>
      )}

      {/* ── Empty state ───────────────────────────────────────────────────── */}
      {!loading && !error && series.length === 0 && (
        <div className="rounded-xl bg-surface-container p-10 text-center">
          <p className="text-on-surface-variant text-sm">
            No series yet. Click <strong>+ New Series</strong> to create one.
          </p>
        </div>
      )}

      {/* ── Series grouped by category ────────────────────────────────────── */}
      {!loading && groupedKeys.map((category) => (
        <section key={category} className="mb-10">
          <h2 className="text-lg font-semibold text-on-surface mb-3 capitalize">
            {category}
          </h2>

          <div className="overflow-x-auto rounded-lg border border-outline-variant">
            <table className="min-w-full divide-y divide-outline-variant text-sm" aria-label={`Series in ${category}`}>
              <thead className="bg-surface-container">
                <tr>
                  <th className="px-4 py-3 text-left font-semibold text-on-surface-variant">
                    Name
                  </th>
                  <th className="px-4 py-3 text-left font-semibold text-on-surface-variant">
                    Sessions
                  </th>
                  <th className="px-4 py-3 text-left font-semibold text-on-surface-variant">
                    Locale
                  </th>
                  <th className="px-4 py-3 text-left font-semibold text-on-surface-variant">
                    Status
                  </th>
                  <th className="px-4 py-3 text-left font-semibold text-on-surface-variant">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-outline-variant bg-surface">
                {grouped[category].map((s) => (
                  <tr
                    key={s.id}
                    onClick={(e) => handleRowClick(e, s.id)}
                    className="cursor-pointer hover:bg-surface-container-low transition-colors"
                  >
                    <td className="px-4 py-3 font-medium text-on-surface">
                      <Link
                        href={`/admin/series/${s.id}`}
                        className="text-primary hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary rounded"
                      >
                        {s.name}
                      </Link>
                      {s.description && (
                        <p className="text-xs text-on-surface-variant font-normal mt-0.5 line-clamp-1">
                          {s.description}
                        </p>
                      )}
                    </td>
                    <td className="px-4 py-3 text-on-surface-variant">
                      {s.totalSessions}
                    </td>
                    <td className="px-4 py-3 text-on-surface-variant">{s.locale}</td>
                    <td className="px-4 py-3">
                      <span
                        className={[
                          'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold',
                          s.isPublished
                            ? 'bg-green-100 text-green-800'
                            : 'bg-outline-variant/40 text-on-surface-variant',
                        ].join(' ')}
                      >
                        {s.isPublished ? 'Published' : 'Draft'}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex flex-wrap items-center gap-1">
                        <button
                          type="button"
                          onClick={() => handlePublishToggle(s)}
                          disabled={togglingId === s.id}
                          aria-label={s.isPublished ? `Unpublish ${s.name}` : `Publish ${s.name}`}
                          className={[
                            'rounded px-3 py-1.5 text-xs font-medium transition-colors',
                            'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary',
                            'disabled:opacity-50 disabled:cursor-not-allowed',
                            s.isPublished
                              ? 'bg-outline-variant/30 text-on-surface hover:bg-outline-variant/50'
                              : 'bg-primary/10 text-primary hover:bg-primary/20',
                          ].join(' ')}
                        >
                          {togglingId === s.id
                            ? 'Saving…'
                            : s.isPublished
                            ? 'Unpublish'
                            : 'Publish'}
                        </button>
                        <button
                          type="button"
                          onClick={() => openEdit(s)}
                          className="rounded px-3 py-1.5 text-xs font-medium text-primary hover:bg-primary/10 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
                        >
                          Edit
                        </button>
                        <button
                          type="button"
                          onClick={() => openDeleteConfirm(s)}
                          className="rounded px-3 py-1.5 text-xs font-medium text-error hover:bg-error/10 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error"
                        >
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      ))}

      {/* ── Create / Edit modal ───────────────────────────────────────────── */}
      {modalMode !== null && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50"
          role="dialog"
          aria-modal="true"
          aria-labelledby="series-modal-title"
        >
          <div className="w-full max-w-lg max-h-[90vh] overflow-y-auto rounded-2xl bg-surface p-6 shadow-xl">
            <div className="flex items-center justify-between mb-5">
              <h3
                id="series-modal-title"
                className="text-lg font-semibold text-on-surface"
              >
                {modalMode === 'create' ? 'New Series' : 'Edit Series'}
              </h3>
              <button
                type="button"
                onClick={closeModal}
                aria-label="Close modal"
                className="rounded-lg p-1 text-on-surface-variant hover:bg-surface-container transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
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

            <form
              onSubmit={(e) => {
                void handleSubmit(e);
              }}
              className="space-y-4"
              noValidate
            >
              {/* Name */}
              <div>
                <label
                  htmlFor="series-name"
                  className="block text-sm font-medium text-on-surface mb-1"
                >
                  Name *
                </label>
                <input
                  id="series-name"
                  type="text"
                  required
                  maxLength={200}
                  disabled={submitting}
                  value={form.name}
                  onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                  className={INPUT_CLASS}
                  placeholder="e.g. Morning Mobility"
                />
              </div>

              {/* Description */}
              <div>
                <label
                  htmlFor="series-description"
                  className="block text-sm font-medium text-on-surface mb-1"
                >
                  Description
                </label>
                <textarea
                  id="series-description"
                  rows={3}
                  maxLength={1000}
                  disabled={submitting}
                  value={form.description}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, description: e.target.value }))
                  }
                  className={INPUT_CLASS}
                  placeholder="Short summary shown in the catalogue."
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {/* Category */}
                <div>
                  <label
                    htmlFor="series-category"
                    className="block text-sm font-medium text-on-surface mb-1"
                  >
                    Category *
                  </label>
                  {categories.length > 0 ? (
                    <select
                      id="series-category"
                      required
                      disabled={submitting}
                      value={form.category}
                      onChange={(e) =>
                        setForm((f) => ({ ...f, category: e.target.value }))
                      }
                      className={INPUT_CLASS}
                    >
                      <option value="" disabled>
                        Select a category…
                      </option>
                      {categories.map((c) => (
                        <option key={c.id} value={c.slug}>
                          {c.name}
                          {c.isPublished ? '' : ' (unpublished)'}
                        </option>
                      ))}
                      {form.category &&
                        !categories.some((c) => c.slug === form.category) && (
                          <option value={form.category}>
                            {form.category} (legacy)
                          </option>
                        )}
                    </select>
                  ) : (
                    <input
                      id="series-category"
                      type="text"
                      required
                      maxLength={100}
                      disabled={submitting}
                      value={form.category}
                      onChange={(e) =>
                        setForm((f) => ({ ...f, category: e.target.value }))
                      }
                      className={INPUT_CLASS}
                      placeholder="e.g. movement"
                    />
                  )}
                </div>

                {/* Default voice */}
                <div>
                  <label
                    htmlFor="series-voice"
                    className="block text-sm font-medium text-on-surface mb-1"
                  >
                    Default Voice *
                  </label>
                  {voices.length > 0 ? (
                    <select
                      id="series-voice"
                      required
                      disabled={submitting}
                      value={form.defaultVoice}
                      onChange={(e) =>
                        setForm((f) => ({ ...f, defaultVoice: e.target.value }))
                      }
                      className={INPUT_CLASS}
                    >
                      <option value="" disabled>
                        Select a voice…
                      </option>
                      {voices.map((v) => (
                        <option key={v.id} value={v.slug}>
                          {v.displayName} ({v.locale}) · {v.slug}
                        </option>
                      ))}
                      {form.defaultVoice &&
                        !voices.some((v) => v.slug === form.defaultVoice) && (
                          <option value={form.defaultVoice}>
                            {form.defaultVoice} (unpublished)
                          </option>
                        )}
                    </select>
                  ) : (
                    <input
                      id="series-voice"
                      type="text"
                      required
                      maxLength={100}
                      disabled={submitting}
                      value={form.defaultVoice}
                      onChange={(e) =>
                        setForm((f) => ({ ...f, defaultVoice: e.target.value }))
                      }
                      className={INPUT_CLASS}
                      placeholder="e.g. am_michael"
                    />
                  )}
                </div>

                {/* Locale */}
                <div>
                  <label
                    htmlFor="series-locale"
                    className="block text-sm font-medium text-on-surface mb-1"
                  >
                    Locale
                  </label>
                  <input
                    id="series-locale"
                    type="text"
                    maxLength={20}
                    disabled={submitting}
                    value={form.locale}
                    onChange={(e) =>
                      setForm((f) => ({ ...f, locale: e.target.value }))
                    }
                    className={INPUT_CLASS}
                    placeholder="e.g. en-US"
                  />
                </div>

                {/* Sort order */}
                <div>
                  <label
                    htmlFor="series-sort"
                    className="block text-sm font-medium text-on-surface mb-1"
                  >
                    Sort Order
                  </label>
                  <input
                    id="series-sort"
                    type="number"
                    min={0}
                    disabled={submitting}
                    value={form.sortOrder}
                    onChange={(e) =>
                      setForm((f) => ({ ...f, sortOrder: e.target.value }))
                    }
                    className={INPUT_CLASS}
                  />
                </div>
              </div>

              {/* Tags */}
              <div>
                <label
                  htmlFor="series-tags"
                  className="block text-sm font-medium text-on-surface mb-1"
                >
                  Tags
                </label>
                <input
                  id="series-tags"
                  type="text"
                  maxLength={500}
                  disabled={submitting}
                  value={form.tags}
                  onChange={(e) => setForm((f) => ({ ...f, tags: e.target.value }))}
                  className={INPUT_CLASS}
                  placeholder="comma,separated,tags"
                />
              </div>

              {/* Published */}
              <div className="flex items-center gap-2">
                <input
                  id="series-published"
                  type="checkbox"
                  disabled={submitting}
                  checked={form.isPublished}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, isPublished: e.target.checked }))
                  }
                  className="h-4 w-4 rounded border-outline-variant text-primary focus:ring-primary"
                />
                <label
                  htmlFor="series-published"
                  className="text-sm font-medium text-on-surface"
                >
                  Published
                </label>
              </div>

              {/* Actions */}
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

      {/* ── Delete confirmation modal ─────────────────────────────────────── */}
      {deleteTarget && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50"
          role="dialog"
          aria-modal="true"
          aria-labelledby="delete-series-modal-title"
          aria-label="Delete Series"
        >
          <div className="w-full max-w-sm rounded-2xl bg-surface p-6 shadow-xl">
            <h3
              id="delete-series-modal-title"
              className="text-base font-semibold text-on-surface mb-2"
            >
              Delete Series
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
                onClick={() => {
                  void handleDelete();
                }}
                disabled={deleting}
                className="rounded-lg bg-error px-4 py-2 text-sm font-semibold text-white hover:bg-error/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error focus-visible:ring-offset-2"
              >
                {deleting ? 'Deleting…' : 'Delete'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
