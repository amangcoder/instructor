'use client';

import { useEffect } from 'react';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export type ToastVariant = 'success' | 'error' | 'warning';

export interface ToastMessage {
  id: string;
  variant: ToastVariant;
  message: string;
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

interface ToastProps {
  toast: ToastMessage;
  onDismiss: (id: string) => void;
}

/**
 * Toast — individual notification component
 *
 * Auto-dismisses after 5000ms. Has an X close button.
 *
 * Variants:
 *  - success: emerald-500/30 border, text-emerald-400
 *  - error: red-500/30 border, text-red-400
 *  - warning: amber-500/30 border, text-amber-400
 *
 * Accessibility:
 *  - role="alert" for screen reader announcement
 *  - X button has aria-label="Dismiss notification"
 */
export default function Toast({ toast, onDismiss }: ToastProps) {
  // Auto-dismiss after 5s
  useEffect(() => {
    const timer = setTimeout(() => onDismiss(toast.id), 5000);
    return () => clearTimeout(timer);
  }, [toast.id, onDismiss]);

  const variantClasses = {
    success: 'border-emerald-500/30 text-emerald-400',
    error: 'border-red-500/30 text-red-400',
    warning: 'border-amber-500/30 text-amber-400',
  }[toast.variant];

  const iconMap = {
    success: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-4 h-4 flex-shrink-0" aria-hidden="true">
        <polyline points="20 6 9 17 4 12" />
      </svg>
    ),
    error: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-4 h-4 flex-shrink-0" aria-hidden="true">
        <circle cx="12" cy="12" r="10" />
        <line x1="15" y1="9" x2="9" y2="15" />
        <line x1="9" y1="9" x2="15" y2="15" />
      </svg>
    ),
    warning: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-4 h-4 flex-shrink-0" aria-hidden="true">
        <path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3" />
        <path d="M12 9v4" />
        <path d="M12 17h.01" />
      </svg>
    ),
  }[toast.variant];

  return (
    <div
      role="alert"
      className={[
        'bg-slate-800 border rounded-xl px-4 py-3',
        'flex items-center gap-3 min-w-[280px] max-w-sm shadow-xl',
        variantClasses,
      ].join(' ')}
    >
      {iconMap}
      <p className="flex-1 text-sm font-medium">{toast.message}</p>
      <button
        type="button"
        onClick={() => onDismiss(toast.id)}
        aria-label="Dismiss notification"
        className={[
          'flex-shrink-0 rounded-lg p-1 transition-colors opacity-70 hover:opacity-100',
          'focus-visible:outline-none focus-visible:outline-2 focus-visible:outline-indigo-400',
        ].join(' ')}
      >
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-3.5 h-3.5" aria-hidden="true">
          <line x1="18" y1="6" x2="6" y2="18" />
          <line x1="6" y1="6" x2="18" y2="18" />
        </svg>
      </button>
    </div>
  );
}
