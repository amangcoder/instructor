'use server';

import { adminFetch, AdminApiError } from '@/lib/admin-api';
import AppVersionForm from '@/components/admin/AppVersionForm';
import type { AppVersionConfigResponse } from '@/types/app-version';

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * Admin App Version Page — server component
 *
 * Displays and allows editing of minimum supported and forced-update app
 * versions for iOS and Android platforms.
 *
 * Data is fetched server-side via adminFetch('/admin/app-version').
 * Errors are caught and displayed inline — never crash the page.
 *
 * The AppVersionForm is a client component that handles form state,
 * validation, and API calls.
 */
export default async function AppVersionPage() {
  let config: AppVersionConfigResponse | null = null;
  let errorMessage: string | null = null;

  try {
    config = await adminFetch<AppVersionConfigResponse>('/admin/app-version');
  } catch (err) {
    if (err instanceof AdminApiError) {
      errorMessage = err.message;
    } else {
      errorMessage = 'An unexpected error occurred while loading app version configuration.';
    }
  }

  return (
    <div>
      {/* ── Page header ──────────────────────────────────────────────────── */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-on-surface">App Version Management</h1>
        <p className="text-sm text-on-surface-variant mt-1">
          Configure minimum supported and forced-update versions for iOS and Android
        </p>
      </div>

      {/* ── Error state ──────────────────────────────────────────────────── */}
      {errorMessage && (
        <div
          className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-6"
          role="alert"
        >
          <p className="font-medium">Failed to load app version configuration</p>
          <p className="mt-1">{errorMessage}</p>
        </div>
      )}

      {/* ── Form ─────────────────────────────────────────────────────────── */}
      {config && <AppVersionForm initialConfig={config} />}

      {/* ── Loading state ────────────────────────────────────────────────── */}
      {!config && !errorMessage && (
        <div
          className="rounded-lg bg-surface-container p-8 text-center"
          role="status"
          aria-live="polite"
        >
          <p className="text-on-surface-variant">Loading configuration...</p>
        </div>
      )}
    </div>
  );
}
