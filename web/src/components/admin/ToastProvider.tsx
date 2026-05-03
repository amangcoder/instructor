'use client';

import React, { createContext, useContext, useState, useCallback, useEffect, useRef } from 'react';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export type ToastVariant = 'success' | 'error' | 'warning';

export interface ToastMessage {
  id: string;
  variant: ToastVariant;
  message: string;
}

interface ToastContextValue {
  toast: (msg: Omit<ToastMessage, 'id'>) => void;
  removeToast: (id: string) => void;
}

// ────────────────────────────────────────────────────────────────────────────
// Context
// ────────────────────────────────────────────────────────────────────────────

const ToastContext = createContext<ToastContextValue | null>(null);

// ────────────────────────────────────────────────────────────────────────────
// Toast Component
// ────────────────────────────────────────────────────────────────────────────

const VARIANT_STYLES: Record<ToastVariant, string> = {
  success: 'border-emerald-500/30 text-emerald-400',
  error: 'border-red-500/30 text-red-400',
  warning: 'border-amber-500/30 text-amber-400',
};

function Toast({
  toast: t,
  onDismiss,
}: {
  toast: ToastMessage;
  onDismiss: (id: string) => void;
}) {
  useEffect(() => {
    const timer = setTimeout(() => onDismiss(t.id), 5000);
    return () => clearTimeout(timer);
  }, [t.id, onDismiss]);

  return (
    <div
      className={`bg-slate-800 border ${VARIANT_STYLES[t.variant]} rounded-xl px-4 py-3 flex items-center gap-3 min-w-[280px] max-w-sm shadow-xl`}
      role="status"
      aria-live="polite"
    >
      <span className="flex-1 text-sm">{t.message}</span>
      <button
        type="button"
        onClick={() => onDismiss(t.id)}
        className="text-slate-400 hover:text-white transition-colors flex-shrink-0 focus-visible:outline-none focus-visible:outline-2 focus-visible:outline-indigo-400 focus-visible:outline-offset-2"
        aria-label="Dismiss notification"
      >
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-4 h-4" aria-hidden="true">
          <line x1="18" y1="6" x2="6" y2="18" />
          <line x1="6" y1="6" x2="18" y2="18" />
        </svg>
      </button>
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Provider
// ────────────────────────────────────────────────────────────────────────────

export default function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<ToastMessage[]>([]);
  const idCounter = useRef(0);

  const addToast = useCallback((msg: Omit<ToastMessage, 'id'>) => {
    const id = `toast-${++idCounter.current}-${Date.now()}`;
    setToasts((prev) => [...prev, { ...msg, id }]);
  }, []);

  const removeToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  return (
    <ToastContext.Provider value={{ toast: addToast, removeToast }}>
      {children}
      {/* Toast container */}
      <div className="fixed bottom-6 right-6 z-50 flex flex-col gap-2" aria-label="Notifications">
        {toasts.map((t) => (
          <Toast key={t.id} toast={t} onDismiss={removeToast} />
        ))}
      </div>
    </ToastContext.Provider>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Hook — exported from this file for convenience
// ────────────────────────────────────────────────────────────────────────────

export function useToast(): ToastContextValue {
  const ctx = useContext(ToastContext);
  if (!ctx) {
    throw new Error('useToast must be used within a ToastProvider');
  }
  return ctx;
}
