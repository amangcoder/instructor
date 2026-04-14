'use client';

import { useState, useEffect, useRef } from 'react';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

type ScopeType = 'full' | 'selective' | '';

interface SelectiveItems {
  plans: boolean;
  ttsCache: boolean;
  profile: boolean;
}

type FormStatus = 'idle' | 'submitting' | 'success' | 'error';

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

/** RFC 5322-inspired email regex for client-side validation */
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** Seconds the submit button stays disabled after a successful submission */
const COOLDOWN_SECONDS = 60;

const INITIAL_SELECTIVE_ITEMS: SelectiveItems = {
  plans: false,
  ttsCache: false,
  profile: false,
};

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * DeletionForm
 *
 * Client-side form that collects the user's email address, deletion scope,
 * and an optional reason before POSTing to /api/deletion-request.
 *
 * Accessibility:
 *  - All interactive elements have explicit <label> elements
 *  - ARIA live regions announce success/error states
 *  - Touch targets are >= 44 × 44 px
 *  - Keyboard-navigable (Tab order follows DOM order)
 *
 * Dark mode:
 *  - Uses surface-container instead of bg-white for inputs
 *  - Borders use outline-variant instead of gray-200/300
 *  - Success/error banners use theme-aware semantic colors
 */
export default function DeletionForm() {
  // Form field state
  const [email, setEmail] = useState('');
  const [emailError, setEmailError] = useState('');
  const [scope, setScope] = useState<ScopeType>('');
  const [selectiveItems, setSelectiveItems] = useState<SelectiveItems>(
    INITIAL_SELECTIVE_ITEMS,
  );
  const [reason, setReason] = useState('');

  // Submission lifecycle
  const [status, setStatus] = useState<FormStatus>('idle');
  const [errorMessage, setErrorMessage] = useState('');

  // 60-second cooldown after success
  const [cooldown, setCooldown] = useState(0);
  const cooldownTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Cleanup timer on unmount
  useEffect(() => {
    return () => {
      if (cooldownTimerRef.current) {
        clearInterval(cooldownTimerRef.current);
      }
    };
  }, []);

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────

  const startCooldown = () => {
    setCooldown(COOLDOWN_SECONDS);
    cooldownTimerRef.current = setInterval(() => {
      setCooldown((prev) => {
        if (prev <= 1) {
          if (cooldownTimerRef.current) {
            clearInterval(cooldownTimerRef.current);
            cooldownTimerRef.current = null;
          }
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
  };

  const validateEmail = (value: string): boolean => {
    if (!EMAIL_REGEX.test(value)) {
      setEmailError('Please enter a valid email address');
      return false;
    }
    setEmailError('');
    return true;
  };

  const hasValidScope = (): boolean => {
    if (scope === 'full') return true;
    if (scope === 'selective') {
      return Object.values(selectiveItems).some(Boolean);
    }
    return false;
  };

  const clearForm = () => {
    setEmail('');
    setEmailError('');
    setScope('');
    setSelectiveItems(INITIAL_SELECTIVE_ITEMS);
    setReason('');
  };

  // ──────────────────────────────────────────────────────────────────────────
  // Event handlers
  // ──────────────────────────────────────────────────────────────────────────

  const handleEmailBlur = () => {
    if (email) validateEmail(email);
  };

  const handleScopeChange = (value: ScopeType) => {
    setScope(value);
    if (value === 'full') {
      setSelectiveItems(INITIAL_SELECTIVE_ITEMS);
    }
  };

  const handleSelectiveItemChange = (key: keyof SelectiveItems) => {
    setSelectiveItems((prev) => ({ ...prev, [key]: !prev[key] }));
  };

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();

    const isEmailValid = validateEmail(email);
    if (!isEmailValid || !hasValidScope()) return;

    setStatus('submitting');
    setErrorMessage('');

    // Map internal scope state to DTO-compatible string[] values
    const scopePayload: string[] =
      scope === 'full'
        ? ['full_account']
        : [
            ...(selectiveItems.plans ? ['plans'] : []),
            ...(selectiveItems.ttsCache ? ['audio_cache'] : []),
            // profile data is stored at the account level; map to full_account scope
            ...(selectiveItems.profile ? ['full_account'] : []),
          ].filter((v, i, a) => a.indexOf(v) === i); // deduplicate

    const payload = {
      email,
      scope: scopePayload,
      ...(reason.trim() && { reason: reason.trim() }),
    };

    try {
      const response = await fetch('/api/deletion-request', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        let serverMessage = 'Request failed. Please try again.';
        try {
          const data = (await response.json()) as { message?: string };
          if (data.message) serverMessage = data.message;
        } catch {
          // JSON parse failed — use default message
        }
        throw new Error(serverMessage);
      }

      clearForm();
      setStatus('success');
      startCooldown();
    } catch (err) {
      setStatus('error');
      setErrorMessage(
        err instanceof Error
          ? err.message
          : 'An unexpected error occurred. Please try again.',
      );
    }
  };

  const handleRetry = () => {
    setStatus('idle');
    setErrorMessage('');
  };

  // ──────────────────────────────────────────────────────────────────────────
  // Derived state
  // ──────────────────────────────────────────────────────────────────────────

  const isButtonDisabled = status === 'submitting' || cooldown > 0;

  const submitLabel =
    status === 'submitting'
      ? 'Submitting…'
      : cooldown > 0
        ? `Request sent — retry in ${cooldown}s`
        : 'Submit Deletion Request';

  // ──────────────────────────────────────────────────────────────────────────
  // Render
  // ──────────────────────────────────────────────────────────────────────────

  return (
    <div className="w-full max-w-xl">
      {/* ── Success banner ─────────────────────────────────────────────────── */}
      {status === 'success' && (
        <div
          role="alert"
          aria-live="polite"
          className="mb-6 rounded-lg border border-success bg-success-container/20 p-4 text-on-surface"
        >
          <p className="font-semibold">Request submitted successfully</p>
          <p className="mt-1 text-sm text-on-surface-variant">
            We have received your deletion request and will process it within 30
            days in accordance with GDPR Article 17. You will receive a
            confirmation email at the address you provided.
          </p>
        </div>
      )}

      {/* ── Error banner ───────────────────────────────────────────────────── */}
      {status === 'error' && (
        <div
          role="alert"
          aria-live="assertive"
          className="mb-6 rounded-lg border border-error bg-error-container/20 p-4 text-on-surface"
        >
          <p className="font-semibold">Something went wrong</p>
          <p className="mt-1 text-sm text-on-surface-variant">{errorMessage}</p>
          <button
            type="button"
            onClick={handleRetry}
            className="mt-3 rounded-md bg-error px-4 py-2 text-sm font-medium text-on-error transition hover:opacity-90 focus:outline-none focus-visible:ring-2 focus-visible:ring-error min-h-[44px]"
          >
            Try again
          </button>
        </div>
      )}

      {/* ── Form (always rendered; cleared on success) ─────────────────────── */}
      {status !== 'error' && (
        <form
          onSubmit={handleSubmit}
          noValidate
          aria-label="Data deletion request form"
          className="space-y-6"
        >
          {/* Email */}
          <div>
            <label
              htmlFor="deletion-email"
              className="block text-sm font-semibold text-on-surface mb-1"
            >
              Email address <span aria-hidden="true" className="text-error">*</span>
            </label>
            <input
              id="deletion-email"
              type="email"
              autoComplete="email"
              required
              value={email}
              onChange={(e) => {
                setEmail(e.target.value);
                if (emailError) validateEmail(e.target.value);
              }}
              onBlur={handleEmailBlur}
              aria-required="true"
              aria-invalid={!!emailError}
              aria-describedby={emailError ? 'email-error' : undefined}
              placeholder="you@example.com"
              className={`w-full rounded-lg border px-4 py-3 text-sm text-on-surface bg-surface-container transition focus:outline-none focus-visible:ring-2 focus-visible:ring-primary min-h-[44px] ${
                emailError
                  ? 'border-error focus-visible:ring-error'
                  : 'border-outline-variant focus-visible:ring-primary'
              }`}
            />
            {emailError && (
              <p
                id="email-error"
                role="alert"
                className="mt-1 text-sm text-error"
              >
                {emailError}
              </p>
            )}
          </div>

          {/* Deletion scope */}
          <fieldset>
            <legend className="block text-sm font-semibold text-on-surface mb-3">
              Deletion scope <span aria-hidden="true" className="text-error">*</span>
            </legend>

            {/* Full account */}
            <label
              className={`flex items-start gap-3 rounded-lg border p-4 cursor-pointer transition min-h-[44px] mb-3 ${
                scope === 'full'
                  ? 'border-primary bg-primary/5'
                  : 'border-outline-variant hover:border-primary/40'
              }`}
            >
              <input
                type="radio"
                name="deletion-scope"
                value="full"
                checked={scope === 'full'}
                onChange={() => handleScopeChange('full')}
                className="mt-0.5 h-4 w-4 accent-primary"
                aria-label="Full account deletion"
              />
              <span>
                <span className="block text-sm font-medium text-on-surface">
                  Full account deletion
                </span>
                <span className="block text-xs text-on-surface-variant mt-0.5">
                  Permanently removes your account, all plans, TTS cache, tokens, and OTPs
                </span>
              </span>
            </label>

            {/* Selective */}
            <label
              className={`flex items-start gap-3 rounded-lg border p-4 cursor-pointer transition min-h-[44px] ${
                scope === 'selective'
                  ? 'border-primary bg-primary/5'
                  : 'border-outline-variant hover:border-primary/40'
              }`}
            >
              <input
                type="radio"
                name="deletion-scope"
                value="selective"
                checked={scope === 'selective'}
                onChange={() => handleScopeChange('selective')}
                className="mt-0.5 h-4 w-4 accent-primary"
                aria-label="Selective data deletion"
              />
              <span>
                <span className="block text-sm font-medium text-on-surface">
                  Selective deletion
                </span>
                <span className="block text-xs text-on-surface-variant mt-0.5">
                  Choose which data categories to delete
                </span>
              </span>
            </label>

            {/* Selective checkboxes — only shown when selective is chosen */}
            {scope === 'selective' && (
              <div
                className="mt-3 ml-6 space-y-2"
                role="group"
                aria-label="Select data categories to delete"
              >
                {(
                  [
                    { key: 'plans' as const, label: 'Plans', description: 'All workout, meditation, study, and cooking plans' },
                    { key: 'ttsCache' as const, label: 'TTS cache', description: 'Cached audio generated by the Kokoro TTS engine' },
                    { key: 'profile' as const, label: 'Profile data', description: 'Display name, preferences, and account settings' },
                  ] as const
                ).map(({ key, label, description }) => (
                  <label
                    key={key}
                    className="flex items-start gap-3 rounded-lg border border-outline-variant p-3 cursor-pointer hover:border-primary/40 transition min-h-[44px]"
                  >
                    <input
                      type="checkbox"
                      checked={selectiveItems[key]}
                      onChange={() => handleSelectiveItemChange(key)}
                      className="mt-0.5 h-4 w-4 accent-primary"
                    />
                    <span>
                      <span className="block text-sm font-medium text-on-surface">{label}</span>
                      <span className="block text-xs text-on-surface-variant">{description}</span>
                    </span>
                  </label>
                ))}
              </div>
            )}
          </fieldset>

          {/* Reason (optional) */}
          <div>
            <label
              htmlFor="deletion-reason"
              className="block text-sm font-semibold text-on-surface mb-1"
            >
              Reason{' '}
              <span className="font-normal text-on-surface-variant">(optional)</span>
            </label>
            <textarea
              id="deletion-reason"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              rows={4}
              placeholder="Tell us why you'd like to delete your data (optional)"
              className="w-full rounded-lg border border-outline-variant px-4 py-3 text-sm text-on-surface bg-surface-container transition focus:outline-none focus-visible:ring-2 focus-visible:ring-primary resize-y min-h-[44px]"
            />
          </div>

          {/* Submit */}
          <button
            type="submit"
            disabled={isButtonDisabled}
            aria-disabled={isButtonDisabled}
            aria-busy={status === 'submitting'}
            className={`w-full rounded-lg px-6 py-3 text-sm font-semibold text-white transition min-h-[44px] focus:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 ${
              isButtonDisabled
                ? 'bg-primary/40 cursor-not-allowed'
                : 'bg-primary hover:bg-primary/90 active:scale-[0.98]'
            }`}
          >
            {submitLabel}
          </button>

          <p className="text-xs text-on-surface-variant text-center">
            Fields marked <span aria-hidden="true" className="text-error">*</span> are required.
          </p>
        </form>
      )}
    </div>
  );
}
