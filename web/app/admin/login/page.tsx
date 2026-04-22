'use client';

import { useState, useCallback, useEffect, useRef, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

type Step = 'email' | 'otp';

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * Admin Login Page — 'use client'
 *
 * Two-step OTP login form:
 *   Step 1 (email): Enter email → POST /api/auth/session { action: 'login', email }
 *   Step 2 (otp):   Enter 6-digit code → POST /api/auth/session { action: 'verify', email, code }
 *
 * On successful verification, redirects to /admin/overview.
 *
 * This page renders WITHOUT the AdminSidebar since the user is
 * unauthenticated. The admin root layout provides the full-screen
 * fixed container that hides the marketing Header/Footer.
 *
 * Accessibility:
 *  - Labels associated with inputs via htmlFor
 *  - Error messages announced via aria-live="polite"
 *  - Loading state disables form controls and shows spinner
 *  - Focus management on step transitions
 */
export default function AdminLoginPage() {
  const router = useRouter();

  const [step, setStep] = useState<Step>('email');
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const otpInputRef = useRef<HTMLInputElement>(null);

  // Move focus to the OTP input when the step transitions to 'otp'
  useEffect(() => {
    if (step === 'otp') {
      otpInputRef.current?.focus();
    }
  }, [step]);

  // ── Step 1: Request OTP ─────────────────────────────────────────────────
  const handleSendOtp = useCallback(
    async (e: FormEvent) => {
      e.preventDefault();
      setError('');
      setLoading(true);

      try {
        const res = await fetch('/api/auth/session', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'login', email: email.trim() }),
        });

        const data: unknown = await res.json();

        if (!res.ok) {
          const msg =
            typeof data === 'object' &&
            data !== null &&
            'message' in data &&
            typeof (data as Record<string, unknown>).message === 'string'
              ? (data as Record<string, string>).message
              : 'Failed to send OTP. Please try again.';
          setError(msg);
          return;
        }

        setStep('otp');
      } catch {
        setError('Network error. Please try again.');
      } finally {
        setLoading(false);
      }
    },
    [email],
  );

  // ── Step 2: Verify OTP ──────────────────────────────────────────────────
  const handleVerifyOtp = useCallback(
    async (e: FormEvent) => {
      e.preventDefault();
      setError('');
      setLoading(true);

      try {
        const res = await fetch('/api/auth/session', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            action: 'verify',
            email: email.trim(),
            code: code.trim(),
          }),
        });

        const data: unknown = await res.json();

        if (!res.ok) {
          const msg =
            typeof data === 'object' &&
            data !== null &&
            'message' in data &&
            typeof (data as Record<string, unknown>).message === 'string'
              ? (data as Record<string, string>).message
              : 'Verification failed. Please try again.';
          setError(msg);
          return;
        }

        router.push('/admin/overview');
      } catch {
        setError('Network error. Please try again.');
      } finally {
        setLoading(false);
      }
    },
    [email, code, router],
  );

  return (
    <div className="flex-1 flex items-center justify-center p-4">
      <div className="w-full max-w-sm">
        {/* ── Header ──────────────────────────────────────────────────────── */}
        <div className="text-center mb-8">
          <h1 className="text-2xl font-bold text-on-surface">Admin Login</h1>
          <p className="text-sm text-on-surface-variant mt-2">
            {step === 'email'
              ? 'Enter your admin email to receive a one-time code.'
              : `We sent a code to ${email}`}
          </p>
        </div>

        {/* ── Error message ───────────────────────────────────────────────── */}
        {/* Always in DOM so VoiceOver/Safari announces dynamic updates */}
        <div
          role="alert"
          aria-live="assertive"
          aria-atomic="true"
          className={error ? 'mb-4 rounded-lg bg-error-container p-3 text-sm text-on-error-container' : 'sr-only'}
        >
          {error}
        </div>

        {/* ── Step 1: Email form ──────────────────────────────────────────── */}
        {step === 'email' && (
          <form onSubmit={handleSendOtp} noValidate>
            <div className="mb-4">
              <label
                htmlFor="admin-email"
                className="block text-sm font-medium text-on-surface mb-1.5"
              >
                Email address
              </label>
              <input
                id="admin-email"
                type="email"
                autoComplete="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                disabled={loading}
                placeholder="admin@example.com"
                className="w-full rounded-lg border border-outline-variant bg-surface px-3 py-2.5 text-sm text-on-surface placeholder:text-outline focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent disabled:opacity-50"
              />
            </div>

            <button
              type="submit"
              disabled={loading || !email.trim()}
              className="w-full rounded-lg bg-primary px-4 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-primary/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed min-h-[44px]"
            >
              {loading ? 'Sending…' : 'Send OTP'}
            </button>
          </form>
        )}

        {/* ── Step 2: OTP form ────────────────────────────────────────────── */}
        {step === 'otp' && (
          <form onSubmit={handleVerifyOtp} noValidate>
            <div className="mb-4">
              <label
                htmlFor="admin-otp"
                className="block text-sm font-medium text-on-surface mb-1.5"
              >
                Verification code
              </label>
              <input
                ref={otpInputRef}
                id="admin-otp"
                type="text"
                inputMode="numeric"
                pattern="[0-9]{6}"
                autoComplete="one-time-code"
                required
                maxLength={6}
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
                disabled={loading}
                placeholder="123456"
                className="w-full rounded-lg border border-outline-variant bg-surface px-3 py-2.5 text-sm text-on-surface text-center tracking-[0.3em] font-mono placeholder:text-outline placeholder:tracking-[0.3em] focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent disabled:opacity-50"
              />
            </div>

            <button
              type="submit"
              disabled={loading || code.length !== 6}
              className="w-full rounded-lg bg-primary px-4 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-primary/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed min-h-[44px]"
            >
              {loading ? 'Verifying…' : 'Verify'}
            </button>

            <button
              type="button"
              onClick={() => {
                setStep('email');
                setCode('');
                setError('');
              }}
              className="w-full mt-3 rounded-lg px-4 py-2 text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors min-h-[44px]"
            >
              <span aria-hidden="true">←</span>{' '}Back to email
            </button>
          </form>
        )}
      </div>
    </div>
  );
}
