'use client';

import { useState, useEffect, useCallback, type FormEvent } from 'react';
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
} from '@dnd-kit/core';
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  rectSortingStrategy,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import type { Category, CategoryFormData } from '@/types/categories';

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

const EMPTY_FORM: CategoryFormData = {
  slug: '',
  name: '',
  icon: '',
  color: '',
  sortOrder: '0',
  isPublished: false,
};

const INPUT_CLASS =
  'w-full rounded-lg border border-outline-variant bg-surface px-3 py-2 text-sm text-on-surface placeholder:text-outline focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent disabled:opacity-50';

const HEX_RE = /^#([0-9a-f]{6})$/i;
const MATERIAL_SYMBOL_RE = /^[a-z][a-z0-9_]*$/;

/**
 * Material Symbols icon names available in the catalogue.
 *
 * Names that match Flutter's Icons.* identifiers (used by `_resolveIcon` in
 * discover_screen.dart) render identically in the mobile app. Names not in
 * Flutter's switch fall back to Icons.category_outlined on the device.
 */
const ICON_CATALOGUE: readonly string[] = [
  // Mind / wellness
  'self_improvement', 'spa', 'psychology', 'mindfulness',
  'bedtime', 'nightlight', 'sentiment_satisfied', 'air',
  // Activity / fitness
  'fitness_center', 'sports_gymnastics', 'sports_martial_arts', 'sports_basketball',
  'sports_soccer', 'sports_tennis', 'sports_volleyball', 'sports_handball',
  'directions_run', 'run_circle', 'directions_bike', 'directions_walk',
  'hiking', 'pool', 'surfing', 'downhill_skiing',
  // Health
  'favorite', 'monitor_heart', 'ecg_heart', 'health_and_safety',
  // Nutrition
  'restaurant', 'local_dining', 'ramen_dining', 'breakfast_dining',
  'water_drop', 'local_drink', 'local_cafe', 'eco',
  // Learning / creative
  'school', 'menu_book', 'edit_note', 'draw',
  'palette', 'lightbulb', 'auto_stories', 'translate',
  // Music
  'music_note', 'headphones', 'library_music', 'mic',
  // Focus / productivity
  'center_focus_strong', 'checklist', 'task_alt', 'alarm',
  // Time / nature
  'wb_sunny', 'dark_mode', 'park', 'local_florist',
  // Generic
  'category', 'label', 'star', 'emoji_events',
];

function normaliseHex(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) return '';
  const withHash = trimmed.startsWith('#') ? trimmed : `#${trimmed}`;
  return HEX_RE.test(withHash) ? withHash.toLowerCase() : '';
}

/**
 * Render a category icon. If the value looks like a Material Symbol name
 * (snake_case alphanumeric) it renders the icon glyph; otherwise it falls
 * back to the raw string — preserves backwards-compat with categories whose
 * icon was set as an emoji before the picker was switched to icon names.
 */
function CategoryIcon({
  value,
  className = '',
}: {
  value: string;
  className?: string;
}) {
  if (MATERIAL_SYMBOL_RE.test(value)) {
    return (
      <span
        aria-hidden="true"
        className={`material-symbols-outlined leading-none ${className}`}
      >
        {value}
      </span>
    );
  }
  return <span className={className}>{value}</span>;
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

function categoryToForm(cat: Category): CategoryFormData {
  return {
    slug: cat.slug,
    name: cat.name,
    icon: cat.icon ?? '',
    color: cat.color ?? '',
    sortOrder: String(cat.sortOrder),
    isPublished: cat.isPublished,
  };
}

function extractMessage(data: unknown): string {
  if (typeof data === 'object' && data !== null && 'message' in data) {
    const msg = (data as Record<string, unknown>).message;
    if (Array.isArray(msg)) return msg.join(', ');
    if (typeof msg === 'string') return msg;
  }
  return 'Request failed.';
}

/**
 * Normalise the categories API response — the NestJS endpoint returns a
 * paginated envelope { categories: Category[], total: number }, but accept
 * a flat array or { items: Category[] } shape as well for forward-compat.
 */
function parseCategories(raw: unknown): Category[] {
  if (Array.isArray(raw)) return raw as Category[];
  if (typeof raw === 'object' && raw !== null) {
    const obj = raw as Record<string, unknown>;
    if (Array.isArray(obj.categories)) return obj.categories as Category[];
    if (Array.isArray(obj.items)) return obj.items as Category[];
  }
  return [];
}

// ────────────────────────────────────────────────────────────────────────────
// SortableCategoryCard
// ────────────────────────────────────────────────────────────────────────────

interface SortableCategoryCardProps {
  category: Category;
  onEdit: (category: Category) => void;
  onDelete: (category: Category) => void;
}

/**
 * Individual draggable category card rendered inside the DnD grid.
 * The drag handle is the grip button in the top-right corner so that
 * clicks on Edit / Delete buttons are not swallowed by the drag sensor.
 */
function SortableCategoryCard({
  category,
  onEdit,
  onDelete,
}: SortableCategoryCardProps) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: category.id });

  const style: React.CSSProperties = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
    zIndex: isDragging ? 10 : undefined,
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={`relative rounded-xl bg-surface-container border border-outline-variant/50 shadow-sm transition-shadow hover:shadow-md ${
        isDragging ? 'shadow-lg ring-2 ring-primary/30' : ''
      }`}
      aria-label={`Category: ${category.name}`}
    >
      {/* Drag handle — top-right corner */}
      <button
        type="button"
        {...attributes}
        {...listeners}
        className="absolute top-3 right-3 p-1.5 rounded text-on-surface-variant hover:text-on-surface hover:bg-surface-container-high cursor-grab active:cursor-grabbing transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
        aria-label={`Drag to reorder ${category.name}`}
      >
        {/* Hamburger / grip icon */}
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="currentColor"
          aria-hidden="true"
        >
          <path d="M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z" />
        </svg>
      </button>

      <div className="p-4">
        {/* Icon + colour swatch + name */}
        <div className="flex items-start gap-2.5 mb-3 pr-9">
          {category.icon && (
            <span
              className="flex-shrink-0"
              role="img"
              aria-label={`${category.name} icon`}
            >
              <CategoryIcon
                value={category.icon}
                className="text-xl leading-tight"
              />
            </span>
          )}
          {category.color && (
            <span
              className="mt-0.5 w-3.5 h-3.5 rounded-full flex-shrink-0 border border-outline-variant/50"
              style={{ backgroundColor: category.color }}
              aria-label={`Color: ${category.color}`}
            />
          )}
          <h3 className="font-semibold text-on-surface text-sm leading-snug">
            {category.name}
          </h3>
        </div>

        {/* Slug */}
        <p className="text-xs text-on-surface-variant font-mono mb-3 truncate">
          /{category.slug}
        </p>

        {/* Status badge + sort order + action buttons */}
        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-2 min-w-0">
            <span
              className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium flex-shrink-0 ${
                category.isPublished
                  ? 'bg-primary/10 text-primary'
                  : 'bg-surface-container-high text-on-surface-variant'
              }`}
            >
              {category.isPublished ? 'Published' : 'Draft'}
            </span>
            <span className="text-xs text-on-surface-variant tabular-nums flex-shrink-0">
              #{category.sortOrder}
            </span>
          </div>

          <div className="flex gap-1 flex-shrink-0">
            <button
              type="button"
              onClick={() => onEdit(category)}
              className="rounded px-2 py-1 text-xs font-medium text-primary hover:bg-primary/10 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
            >
              Edit
            </button>
            <button
              type="button"
              onClick={() => onDelete(category)}
              className="rounded px-2 py-1 text-xs font-medium text-error hover:bg-error/10 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error"
            >
              Delete
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// CategoryManager — main component
// ────────────────────────────────────────────────────────────────────────────

export interface CategoryManagerProps {
  /** Pre-fetched categories from the server component — avoids initial client fetch. */
  initialCategories?: Category[];
}

/**
 * CategoryManager — client component
 *
 * Full CRUD interface for the categories content taxonomy. Embedded in the
 * admin /admin/categories page.
 *
 * Features:
 *   - Grid of draggable category cards (dnd-kit/sortable)
 *   - Create modal: slug, name, icon, color, sort_order, is_published (REQ-014)
 *   - Edit modal: pre-fills all fields from the selected category
 *   - Delete confirmation modal
 *   - Drag-drop reorder → PATCH /api/admin/categories/reorder (AC-023)
 *
 * Data flow:
 *   1. Initial render uses `initialCategories` prop (server-prefetched)
 *   2. After any mutation the client re-fetches from GET /api/admin/categories
 *      so the grid is always consistent with the backend
 */
export default function CategoryManager({
  initialCategories = [],
}: CategoryManagerProps) {
  const [categories, setCategories] = useState<Category[]>(initialCategories);
  const [loading, setLoading] = useState(initialCategories.length === 0);
  const [fetchError, setFetchError] = useState<string | null>(null);

  // ── Modal state ───────────────────────────────────────────────────────────
  const [modalMode, setModalMode] = useState<'create' | 'edit' | null>(null);
  const [editTarget, setEditTarget] = useState<Category | null>(null);
  const [form, setForm] = useState<CategoryFormData>(EMPTY_FORM);
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [iconPickerOpen, setIconPickerOpen] = useState(false);

  // ── Delete state ──────────────────────────────────────────────────────────
  const [deleteTarget, setDeleteTarget] = useState<Category | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  // ── Reorder error ─────────────────────────────────────────────────────────
  const [reorderError, setReorderError] = useState<string | null>(null);

  // ── DnD sensors ───────────────────────────────────────────────────────────
  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    }),
  );

  // ── Data fetching ─────────────────────────────────────────────────────────

  const fetchCategories = useCallback(async () => {
    setLoading(true);
    setFetchError(null);
    try {
      const res = await fetch('/api/admin/categories');
      if (!res.ok) {
        setFetchError('Failed to load categories.');
        return;
      }
      setCategories(parseCategories(await res.json()));
    } catch {
      setFetchError('Network error loading categories.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (initialCategories.length === 0) {
      void fetchCategories();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fetchCategories]);

  // ── Modal helpers ─────────────────────────────────────────────────────────

  const openCreate = () => {
    setForm(EMPTY_FORM);
    setFormError(null);
    setEditTarget(null);
    setIconPickerOpen(false);
    setModalMode('create');
  };

  const openEdit = (cat: Category) => {
    setForm(categoryToForm(cat));
    setFormError(null);
    setEditTarget(cat);
    setIconPickerOpen(false);
    setModalMode('edit');
  };

  const closeModal = () => {
    setModalMode(null);
    setEditTarget(null);
    setFormError(null);
    setIconPickerOpen(false);
  };

  // ── Create / Edit submit ──────────────────────────────────────────────────

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setFormError(null);
    setSubmitting(true);

    const payload = {
      slug: form.slug.trim(),
      name: form.name.trim(),
      icon: form.icon.trim() || undefined,
      color: form.color.trim() || undefined,
      sortOrder: parseInt(form.sortOrder, 10) || 0,
      isPublished: form.isPublished,
    };

    try {
      const url =
        modalMode === 'create'
          ? '/api/admin/categories'
          : `/api/admin/categories/${editTarget!.id}`;

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
      await fetchCategories();
    } catch {
      setFormError('Network error. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  // ── Delete ────────────────────────────────────────────────────────────────

  const openDeleteConfirm = (cat: Category) => {
    setDeleteTarget(cat);
    setDeleteError(null);
  };

  const handleDelete = async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    setDeleteError(null);

    try {
      const res = await fetch(`/api/admin/categories/${deleteTarget.id}`, {
        method: 'DELETE',
      });

      if (!res.ok && res.status !== 204) {
        setDeleteError('Failed to delete category. Please try again.');
        return;
      }

      setDeleteTarget(null);
      await fetchCategories();
    } catch {
      setDeleteError('Network error. Please try again.');
    } finally {
      setDeleting(false);
    }
  };

  // ── Drag-and-drop reorder ─────────────────────────────────────────────────

  const handleDragEnd = async (event: DragEndEvent) => {
    const { active, over } = event;
    if (!over || active.id === over.id) return;

    const oldIndex = categories.findIndex((c) => c.id === active.id);
    const newIndex = categories.findIndex((c) => c.id === over.id);
    if (oldIndex === -1 || newIndex === -1) return;

    // Optimistically update the UI then persist
    const reordered = arrayMove(categories, oldIndex, newIndex).map(
      (cat, idx) => ({ ...cat, sortOrder: idx }),
    );
    setCategories(reordered);
    setReorderError(null);

    try {
      // The NestJS DTO is { items: ReorderItemDto[] } with camelCase fields —
      // sending a bare array or snake_case keys gets stripped by the global
      // ValidationPipe (whitelist:true) and the reorder silently no-ops.
      const res = await fetch('/api/admin/categories/reorder', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          items: reordered.map((c) => ({ id: c.id, sortOrder: c.sortOrder })),
        }),
      });

      if (!res.ok) {
        setReorderError('Failed to save new order. Please refresh the page.');
      }
    } catch {
      setReorderError('Network error saving order. Please refresh the page.');
    }
  };

  // ── Render ────────────────────────────────────────────────────────────────

  return (
    <section aria-labelledby="categories-crud-heading">
      {/* ── Section header ───────────────────────────────────────────────── */}
      <div className="flex items-center justify-between mb-6">
        <h2
          id="categories-crud-heading"
          className="text-lg font-semibold text-on-surface"
        >
          Manage Categories
        </h2>
        <button
          type="button"
          onClick={openCreate}
          className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white hover:bg-primary/90 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
        >
          + New Category
        </button>
      </div>

      {/* ── Fetch error ──────────────────────────────────────────────────── */}
      {fetchError && (
        <div
          role="alert"
          className="rounded-lg bg-error-container p-3 text-sm text-on-error-container mb-4"
        >
          {fetchError}
        </div>
      )}

      {/* ── Reorder error ────────────────────────────────────────────────── */}
      {reorderError && (
        <div
          role="alert"
          className="rounded-lg bg-error-container p-3 text-sm text-on-error-container mb-4"
        >
          {reorderError}
        </div>
      )}

      {/* ── Loading ──────────────────────────────────────────────────────── */}
      {loading && (
        <p
          role="status"
          aria-label="Loading categories"
          className="text-sm text-on-surface-variant py-12 text-center"
        >
          Loading categories…
        </p>
      )}

      {/* ── Empty state ──────────────────────────────────────────────────── */}
      {!loading && categories.length === 0 && !fetchError && (
        <div className="rounded-xl bg-surface-container p-10 text-center">
          <p className="text-on-surface-variant text-sm">
            No categories yet. Create one to get started.
          </p>
        </div>
      )}

      {/* ── DnD grid ─────────────────────────────────────────────────────── */}
      {!loading && categories.length > 0 && (
        <DndContext
          sensors={sensors}
          collisionDetection={closestCenter}
          onDragEnd={(e) => {
            void handleDragEnd(e);
          }}
        >
          <SortableContext
            items={categories.map((c) => c.id)}
            strategy={rectSortingStrategy}
          >
            <div
              className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4"
              aria-label="Categories grid"
            >
              {categories.map((category) => (
                <SortableCategoryCard
                  key={category.id}
                  category={category}
                  onEdit={openEdit}
                  onDelete={openDeleteConfirm}
                />
              ))}
            </div>
          </SortableContext>
        </DndContext>
      )}

      {/* ── Create / Edit modal ──────────────────────────────────────────── */}
      {modalMode !== null && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50"
          role="dialog"
          aria-modal="true"
          aria-labelledby="category-modal-title"
        >
          <div className="w-full max-w-lg max-h-[90vh] overflow-y-auto rounded-2xl bg-surface p-6 shadow-xl">
            <div className="flex items-center justify-between mb-5">
              <h3
                id="category-modal-title"
                className="text-lg font-semibold text-on-surface"
              >
                {modalMode === 'create' ? 'New Category' : 'Edit Category'}
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
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">

                {/* Slug */}
                <div>
                  <label
                    htmlFor="cat-slug"
                    className="block text-sm font-medium text-on-surface mb-1"
                  >
                    Slug *
                  </label>
                  <input
                    id="cat-slug"
                    type="text"
                    required
                    maxLength={100}
                    disabled={submitting}
                    value={form.slug}
                    onChange={(e) =>
                      setForm((f) => ({ ...f, slug: e.target.value }))
                    }
                    className={INPUT_CLASS}
                    placeholder="e.g. morning-mindfulness"
                  />
                </div>

                {/* Name */}
                <div>
                  <label
                    htmlFor="cat-name"
                    className="block text-sm font-medium text-on-surface mb-1"
                  >
                    Name *
                  </label>
                  <input
                    id="cat-name"
                    type="text"
                    required
                    maxLength={200}
                    disabled={submitting}
                    value={form.name}
                    onChange={(e) =>
                      setForm((f) => ({ ...f, name: e.target.value }))
                    }
                    className={INPUT_CLASS}
                    placeholder="e.g. Morning Mindfulness"
                  />
                </div>

                {/* Icon */}
                <div>
                  <label
                    htmlFor="cat-icon"
                    className="block text-sm font-medium text-on-surface mb-1"
                  >
                    Icon (emoji)
                  </label>
                  <div className="flex gap-2">
                    <input
                      id="cat-icon"
                      type="text"
                      maxLength={50}
                      disabled={submitting}
                      value={form.icon}
                      onChange={(e) =>
                        setForm((f) => ({ ...f, icon: e.target.value }))
                      }
                      className={INPUT_CLASS}
                      placeholder="e.g. self_improvement"
                    />
                    <button
                      type="button"
                      onClick={() => setIconPickerOpen((v) => !v)}
                      disabled={submitting}
                      aria-expanded={iconPickerOpen}
                      aria-controls="cat-icon-catalogue"
                      className="flex-shrink-0 rounded-lg border border-outline-variant px-3 py-2 text-sm text-on-surface-variant hover:bg-surface-container transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary disabled:opacity-50"
                    >
                      {iconPickerOpen ? 'Close' : 'Browse'}
                    </button>
                  </div>
                  {iconPickerOpen && (
                    <div
                      id="cat-icon-catalogue"
                      role="listbox"
                      aria-label="Symbol catalogue"
                      className="mt-2 max-h-56 overflow-y-auto rounded-lg border border-outline-variant bg-surface-container p-2 grid grid-cols-8 gap-1"
                    >
                      {ICON_CATALOGUE.map((name) => {
                        const selected = form.icon === name;
                        return (
                          <button
                            key={name}
                            type="button"
                            role="option"
                            aria-selected={selected}
                            title={name}
                            onClick={() =>
                              setForm((f) => ({ ...f, icon: name }))
                            }
                            disabled={submitting}
                            className={`flex items-center justify-center h-9 w-9 rounded transition-colors text-on-surface hover:bg-surface-container-high focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary ${
                              selected ? 'bg-primary/15 ring-2 ring-primary' : ''
                            }`}
                          >
                            <CategoryIcon value={name} className="text-xl" />
                            <span className="sr-only">{name}</span>
                          </button>
                        );
                      })}
                    </div>
                  )}
                </div>

                {/* Color */}
                <div>
                  <label
                    htmlFor="cat-color"
                    className="block text-sm font-medium text-on-surface mb-1"
                  >
                    Color (hex)
                  </label>
                  <div className="flex gap-2">
                    <input
                      id="cat-color"
                      type="text"
                      maxLength={20}
                      disabled={submitting}
                      value={form.color}
                      onChange={(e) =>
                        setForm((f) => ({ ...f, color: e.target.value }))
                      }
                      className={INPUT_CLASS}
                      placeholder="e.g. #6366f1"
                    />
                    <input
                      type="color"
                      aria-label="Pick color"
                      disabled={submitting}
                      value={normaliseHex(form.color) || '#000000'}
                      onChange={(e) =>
                        setForm((f) => ({ ...f, color: e.target.value }))
                      }
                      className="flex-shrink-0 h-10 w-12 rounded-lg border border-outline-variant bg-surface cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                    />
                  </div>
                </div>

                {/* Sort Order */}
                <div>
                  <label
                    htmlFor="cat-sort-order"
                    className="block text-sm font-medium text-on-surface mb-1"
                  >
                    Sort Order
                  </label>
                  <input
                    id="cat-sort-order"
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

                {/* Published */}
                <div className="flex items-center gap-2 sm:pt-5">
                  <input
                    id="cat-published"
                    type="checkbox"
                    disabled={submitting}
                    checked={form.isPublished}
                    onChange={(e) =>
                      setForm((f) => ({
                        ...f,
                        isPublished: e.target.checked,
                      }))
                    }
                    className="h-4 w-4 rounded border-outline-variant text-primary focus:ring-primary"
                  />
                  <label
                    htmlFor="cat-published"
                    className="text-sm font-medium text-on-surface"
                  >
                    Published
                  </label>
                </div>

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
          aria-labelledby="delete-category-modal-title"
          aria-label="Delete Category"
        >
          <div className="w-full max-w-sm rounded-2xl bg-surface p-6 shadow-xl">
            <h3
              id="delete-category-modal-title"
              className="text-base font-semibold text-on-surface mb-2"
            >
              Delete Category
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
    </section>
  );
}
