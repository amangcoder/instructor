'use client';

import { useState } from 'react';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface CsvExportButtonProps {
  /**
   * URL that the browser will navigate to in order to trigger the CSV
   * download (e.g. '/api/admin/analytics/users/export').
   */
  exportUrl: string;
  /**
   * Suggested filename for the downloaded file (e.g. 'users-export.csv').
   * Passed as the `download` attribute on the anchor element.
   */
  filename: string;
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * CsvExportButton — client component
 *
 * Renders a button that triggers a CSV file download when clicked.
 * The button transitions into a disabled "Downloading…" state while the
 * browser is fetching the file, preventing double-clicks.
 *
 * Download strategy:
 *  - Creates a temporary <a download> element pointing at `exportUrl`
 *  - Programmatically clicks it so the browser handles the file download
 *    (respects Content-Disposition: attachment headers from the server)
 *  - Falls back to window.location.href if anchor creation fails
 *
 * Features:
 *  - Loading / disabled state during download to prevent duplicate requests
 *  - Matches the project's button styling conventions
 *
 * Accessibility (WCAG 2.1 AA):
 *  - aria-label changes dynamically to reflect current action
 *  - disabled attribute + aria-disabled both set during loading
 *  - Minimum 44px tap target
 *  - Focus-visible ring for keyboard users
 */
export default function CsvExportButton({ exportUrl, filename }: CsvExportButtonProps) {
  const [isDownloading, setIsDownloading] = useState(false);

  const handleDownload = () => {
    if (isDownloading) return;

    setIsDownloading(true);

    try {
      // Preferred approach: anchor with `download` attribute so the browser
      // saves the file with the suggested filename
      const anchor = document.createElement('a');
      anchor.href = exportUrl;
      anchor.download = filename;
      anchor.style.display = 'none';
      document.body.appendChild(anchor);
      anchor.click();
      document.body.removeChild(anchor);
    } catch {
      // Fallback: set location directly (no filename suggestion)
      window.location.href = exportUrl;
    }

    // Reset after a brief delay — the browser handles the actual download
    // asynchronously so we can't know the exact completion time
    setTimeout(() => {
      setIsDownloading(false);
    }, 1500);
  };

  return (
    <button
      type="button"
      onClick={handleDownload}
      disabled={isDownloading}
      aria-disabled={isDownloading}
      aria-label={
        isDownloading
          ? `Downloading ${filename}…`
          : `Export ${filename} as CSV`
      }
      className={[
        'inline-flex items-center gap-2',
        'text-sm font-medium',
        'rounded-lg px-4 py-2',
        'border border-outline-variant',
        'transition-colors',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-1',
        'min-h-[44px]',
        isDownloading
          ? 'bg-surface-container text-on-surface-variant cursor-not-allowed opacity-60'
          : 'bg-surface-container text-on-surface hover:bg-surface-container-high',
      ].join(' ')}
    >
      {/* Download icon */}
      {isDownloading ? (
        <>
          {/* Spinner via CSS animation */}
          <span
            aria-hidden="true"
            className="inline-block h-3.5 w-3.5 animate-spin rounded-full border-2 border-on-surface-variant border-t-transparent"
          />
          <span>Downloading…</span>
        </>
      ) : (
        <>
          <span aria-hidden="true">↓</span>
          <span>Export CSV</span>
        </>
      )}
    </button>
  );
}
