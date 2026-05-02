// ────────────────────────────────────────────────────────────────────────────
// Category types — shared between the categories page and CategoryManager
// ────────────────────────────────────────────────────────────────────────────

/**
 * A single category row as returned by GET /api/admin/categories.
 *
 * Fields mirror the NestJS response which serialises the `categories` Drizzle
 * schema in camelCase:
 *   id          — uuid primary key
 *   slug        — unique URL-safe identifier
 *   name        — display name
 *   icon        — optional emoji or icon identifier
 *   color       — optional hex colour string (e.g. "#6366f1")
 *   sortOrder   — ascending integer used for drag-drop ordering
 *   isPublished — controls user-visibility
 */
export type Category = {
  id: string;
  slug: string;
  name: string;
  icon: string | null;
  color: string | null;
  sortOrder: number;
  isPublished: boolean;
};

/**
 * Shape of the create/edit form state held in CategoryManager.
 * sortOrder is a string so it binds directly to a numeric <input>.
 */
export type CategoryFormData = {
  slug: string;
  name: string;
  icon: string;
  color: string;
  sortOrder: string;
  isPublished: boolean;
};

/**
 * Payload item sent to PATCH /api/admin/categories/reorder.
 * Each item carries its new sortOrder position.
 */
export type ReorderItem = {
  id: string;
  sortOrder: number;
};
