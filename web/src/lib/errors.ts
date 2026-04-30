import { AdminApiError } from './admin-api';

// ────────────────────────────────────────────────────────────────────────────
// Shared error utilities for admin dashboard pages
// ────────────────────────────────────────────────────────────────────────────

/**
 * Extract a user-readable error message from an unknown thrown value.
 *
 * Handles:
 *   - AdminApiError: returns the structured error message from the API
 *   - Error: returns the standard message property
 *   - anything else: returns the provided fallback string
 *
 * @param err      The caught error value (unknown type from catch blocks)
 * @param fallback Custom fallback string shown for non-Error throws
 * @returns        A human-readable error string safe to display in the UI
 */
export function getPageErrorMessage(
  err: unknown,
  fallback = 'An unexpected error occurred.',
): string {
  if (err instanceof AdminApiError) return err.message;
  if (err instanceof Error) return err.message;
  return fallback;
}
