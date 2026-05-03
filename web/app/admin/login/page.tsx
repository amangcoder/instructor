'use client';

import { useState, useCallback, useEffect, useRef, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';

type Step = 'email' | 'otp';

/**
 * Admin Login Page — 'use client'
 *
 * Two-step OTP login form with dark card design:
 *   Step 1 (email): Enter email → POST /api/auth/session { action: 'login', email }
 *   Step 2 (otp):   Enter 6-digit code → POST /api/auth/session { action: 'verify', email, code }
 *
 * Design: centered dark card on bg-slate-950 background.
 * Accessibility: labeled inputs, aria-live error, spinner in loading state.
 */
export default function AdminLoginPage() {
  const router = useRouter();

  const [step, setStep] = useState<Step>('email');
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const otpInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (step === 'otp') {
      otpInputRef.current?.focus();
    }
  }, [step]);

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
            typeof data === 'object' && data !== null && 'message' in data &&
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

  const handleVerifyOtp = useCallback(
    async (e: FormEvent) => {
      e.preventDefault();
      setError('');
      setLoading(true);
      try {
        const res = await fetch('/api/auth/session', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'verify', email: email.trim(), code: code.trim() }),
        });
        const data: unknown = await res.json();
        if (!res.ok) {
          const msg =
            typeof data === 'object' && data !== null && 'message' in data &&
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

  const inputClass = [
    'w-full h-11 bg-slate-800 border border-white/10 rounded-xl px-4',
    'text-white placeholder-slate-500 text-sm',
    'focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500',
    'transition-colors disabled:opacity-50',
  ].join(' ');

  const Spinner = () => (
    <svg className="animate-spin w-5 h-5" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
    </svg>
  );

  return (
    <div className="flex-1 flex items-center justify-center p-4">
      <div className="w-full max-w-sm">
        <div className="bg-slate-900 border border-white/8 rounded-2xl p-8 shadow-2xl">
          {/* ── Header ───────────────────────────────────────────────────── */}
          <div className="text-center mb-8">
            <div
              className="inline-flex items-center justify-center w-12 h-12 rounded-xl bg-gradient-to-br from-indigo-500 to-violet-600 mb-4"
              aria-hidden="true"
            >
              <span className="text-white font-bold text-xl">I</span>
            </div>
            <h1 className="text-xl font-bold text-white">Admin Sign In</h1>
            <p className="text-sm text-slate-400 mt-2">
              {step === 'email'
                ? 'Enter your admin email to receive a one-time code.'
                : `We sent a code to ${email}`}
            </p>
          </div>

          {/* ── Error message ─────────────────────────────────────────────── */}
          <div
            role="alert"
            aria-live="assertive"
            aria-atomic="true"
            className={error
              ? 'mb-4 rounded-xl bg-red-950/80 border border-red-500/20 p-3 text-sm text-red-400'
              : 'sr-only'}
          >
            {error}
          </div>

          {/* ── Step 1: Email form ─────────────────────────────────────────── */}
          {step === 'email' && (
            <form onSubmit={handleSendOtp} noValidate>
              <div className="mb-4">
                <label htmlFor="admin-email" className="block text-sm font-medium text-slate-300 mb-1.5">
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
                  className={inputClass}
                />
              </div>
              <button
                type="submit"
                disabled={loading || !email.trim()}
                className="w-full h-11 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-sm transition-colors flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:outline-2 focus-visible:outline-indigo-400 focus-visible:outline-offset-2"
              >
                {loading ? <><Spinner />Sending…</> : 'Send OTP'}
              </button>
            </form>
          )}

          {/* ── Step 2: OTP form ───────────────────────────────────────────── */}
          {step === 'otp' && (
            <form onSubmit={handleVerifyOtp} noValidate>
              <div className="mb-4">
                <label htmlFor="admin-otp" className="block text-sm font-medium text-slate-300 mb-1.5">
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
                  className={`${inputClass} text-center tracking-[0.3em] font-mono placeholder:tracking-[0.3em]`}
                />
              </div>
              <button
                type="submit"
                disabled={loading || code.length !== 6}
                className="w-full h-11 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-sm transition-colors flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:outline-2 focus-visible:outline-indigo-400 focus-visible:outline-offset-2 mb-3"
              >
                {loading ? <><Spinner />Verifying…</> : 'Verify'}
              </button>
              <button
                type="button"
                disabled={loading}
                onClick={() => { setStep('email'); setCode(''); setError(''); }}
                className="w-full h-11 rounded-xl px-4 text-sm font-medium text-slate-400 hover:text-white transition-colors disabled:opacity-50 focus-visible:outline-none focus-visible:outline-2 focus-visible:outline-indigo-400 focus-visible:outline-offset-2"
              >
                <span aria-hidden="true">←</span>{' '}Back to email
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}
