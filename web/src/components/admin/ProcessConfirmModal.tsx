'use client';

import { useCallback, useEffect, useRef, useState } from 'react';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface ProcessConfirmModalProps {
  /** Whether the modal is open */
  open: boolean;
  /** Masked email of the request being processed */
  email: string;
  /** Called when the admin confirms the action. May throw on failure. */
  onConfirm: () => Promise<void>;
  /** Called to close the modal (cancel or after success) */
  onClose: () => void;
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * ProcessConfirmModal — client component
 *
 * Confirmation dialog shown before marking a deletion request as processed.
 * Uses a native <dialog> element for correct modal semantics.
 *
 * Features:
 *  - Traps focus inside the dialog while open
 *  - Closes on Escape key
 *  - Shows loading state during API call
 *  - Displays error message on failure
 *
 * Accessibility:
 *  - <dialog> with aria-labelledby + aria-describedby
 *  - Focus auto-trapped by <dialog> element
 *  - Cancel + Confirm buttons with clear labels
 *  - aria-live error region for screen readers
 */
export default function ProcessConfirmModal({
  open,
  email,
  onConfirm,
  onClose,
}: ProcessConfirmModalProps) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const cancelRef = useRef<HTMLButtonElement>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // ── Open/close the native <dialog> ────────────────────────────────────
  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;

    if (open && !dialog.open) {
      dialog.showModal();
      // Focus the cancel button by default (safer action)
      cancelRef.current?.focus();
    } else if (!open && dialog.open) {
      dialog.close();
    }
  }, [open]);

  // ── Reset state when modal opens ──────────────────────────────────────
  useEffect(() => {
    if (open) {
      setIsLoading(false);
      setError(null);
    }
  }, [open]);

  // ── Handle confirm ────────────────────────────────────────────────────
  const handleConfirm = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      await onConfirm();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An unexpected error occurred');
    } finally {
      setIsLoading(false);
    }
  }, [onConfirm, onClose]);

  // ── Handle native dialog close (Escape key) ──────────────────────────
  const handleDialogClose = useCallback(() => {
    if (!isLoading) {
      onClose();
    }
  }, [isLoading, onClose]);

  // ── Handle backdrop click ─────────────────────────────────────────────
  const handleBackdropClick = useCallback(
    (e: React.MouseEvent<HTMLDialogElement>) => {
      // Only close if clicking the backdrop (dialog element itself), not content
      if (e.target === dialogRef.current && !isLoading) {
        onClose();
      }
    },
    [isLoading, onClose],
  );

  return (
    <dialog
      ref={dialogRef}
      onClose={handleDialogClose}
      onClick={handleBackdropClick}
      aria-labelledby="process-confirm-title"
      aria-describedby="process-confirm-description"
      className="backdrop:bg-black/50 rounded-xl bg-surface p-0 shadow-xl max-w-md w-full"
    >
      <div className="p-6">
        {/* ── Title ──────────────────────────────────────────────────── */}
        <h2
          id="process-confirm-title"
          className="text-lg font-semibold text-on-surface mb-2"
        >
          Confirm Processing
        </h2>

        {/* ── Description ───────────────────────────────────────────── */}
        <p
          id="process-confirm-description"
          className="text-sm text-on-surface-variant mb-6"
        >
          Are you sure you want to mark the deletion request from{' '}
          <strong className="text-on-surface">{email}</strong> as processed?
          This action cannot be undone.
        </p>

        {/* ── Error message ─────────────────────────────────────────── */}
        {error && (
          <div
            className="rounded-lg bg-error-container p-3 text-sm text-on-error-container mb-4"
            role="alert"
          >
            {error}
          </div>
        )}

        {/* ── Actions ───────────────────────────────────────────────── */}
        <div className="flex items-center justify-end gap-3">
          <button
            ref={cancelRef}
            type="button"
            onClick={onClose}
            disabled={isLoading}
            className="rounded-lg border border-outline-variant px-4 py-2 text-sm font-medium text-on-surface hover:bg-surface-variant/30 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary disabled:opacity-50 disabled:cursor-not-allowed min-h-[44px] transition-colors"
            aria-label="Cancel processing"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={handleConfirm}
            disabled={isLoading}
            className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-1 disabled:opacity-50 disabled:cursor-not-allowed min-h-[44px] transition-colors"
            aria-label={isLoading ? 'Processing deletion request' : 'Confirm mark as processed'}
          >
            {isLoading ? 'Processing…' : 'Mark as Processed'}
          </button>
        </div>
      </div>
    </dialog>
  );
}
