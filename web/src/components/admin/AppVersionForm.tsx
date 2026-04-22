'use client';

import { useState, type FormEvent } from 'react';
import type { AppVersionConfigResponse, PlatformVersionConfig } from '@/types/app-version';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

interface FormState {
  ios: {
    minVersion: string;
    forceUpdateVersion: string;
  };
  android: {
    minVersion: string;
    forceUpdateVersion: string;
  };
  enabled: boolean;
}

interface FormErrors {
  ios?: string;
  android?: string;
  general?: string;
}

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

const INPUT_CLASS =
  'w-full rounded-lg border border-outline-variant bg-surface px-3 py-2 text-sm text-on-surface placeholder:text-outline focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent disabled:opacity-50';

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/** Human-readable display labels for each platform. */
const PLATFORM_LABEL: Record<'ios' | 'android', string> = {
  ios: 'iOS',
  android: 'Android',
};

/**
 * Compare two semver-style version strings (e.g. "1.2.3").
 * Returns negative if a < b, 0 if equal, positive if a > b.
 */
function compareVersions(a: string, b: string): number {
  const partsA = a.split('.').map(Number);
  const partsB = b.split('.').map(Number);
  const len = Math.max(partsA.length, partsB.length);
  for (let i = 0; i < len; i++) {
    const numA = partsA[i] ?? 0;
    const numB = partsB[i] ?? 0;
    if (numA !== numB) return numA - numB;
  }
  return 0;
}

/**
 * Validate a single platform's version configuration.
 * Returns an error message if validation fails, undefined otherwise.
 */
function validatePlatform(
  platform: 'ios' | 'android',
  config: { minVersion: string; forceUpdateVersion: string },
): string | undefined {
  const { minVersion, forceUpdateVersion } = config;
  const label = PLATFORM_LABEL[platform];

  if (!minVersion.trim()) {
    return `${label}: Minimum version is required`;
  }

  if (!forceUpdateVersion.trim()) {
    return `${label}: Force update version is required`;
  }

  if (compareVersions(forceUpdateVersion.trim(), minVersion.trim()) < 0) {
    return `${label}: Force update version must be >= minimum version`;
  }

  return undefined;
}

/**
 * Show a simple toast notification (visual feedback for success).
 * Uses a temporarily visible div that disappears after 3 seconds.
 */
function showSuccessToast(message: string) {
  // Create a toast element
  const toast = document.createElement('div');
  toast.className =
    'fixed bottom-4 right-4 px-4 py-3 rounded-lg bg-success text-on-success text-sm font-medium shadow-lg z-50 animate-fade-in';
  toast.setAttribute('role', 'status');
  toast.setAttribute('aria-live', 'polite');
  toast.textContent = message;

  document.body.appendChild(toast);

  // Add fade-in animation inline
  const style = document.createElement('style');
  if (!document.querySelector('style[data-toast-animation]')) {
    style.setAttribute('data-toast-animation', 'true');
    style.textContent = `
      @keyframes fadeIn {
        from { opacity: 0; transform: translateY(10px); }
        to { opacity: 1; transform: translateY(0); }
      }
      .animate-fade-in {
        animation: fadeIn 0.3s ease-out;
      }
    `;
    document.head.appendChild(style);
  }

  // Auto-remove after 3 seconds
  setTimeout(() => {
    toast.style.animation = 'fadeIn 0.3s ease-out reverse';
    setTimeout(() => toast.remove(), 300);
  }, 3000);
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

interface AppVersionFormProps {
  initialConfig: AppVersionConfigResponse;
}

/**
 * AppVersionForm — client component for editing app version configuration
 *
 * Features:
 *  - Two sections for iOS and Android
 *  - Each section has inputs for minimum version and force-update version
 *  - Global enabled toggle
 *  - Client-side validation (force >= min for each platform)
 *  - Server-side validation via PATCH endpoint (uses AppVersionService.compareVersions)
 *  - Success toast notification after save
 *  - Error handling and display
 */
export default function AppVersionForm({ initialConfig }: AppVersionFormProps) {
  const [formState, setFormState] = useState<FormState>({
    ios: {
      minVersion: initialConfig.ios.minVersion,
      forceUpdateVersion: initialConfig.ios.forceUpdateVersion,
    },
    android: {
      minVersion: initialConfig.android.minVersion,
      forceUpdateVersion: initialConfig.android.forceUpdateVersion,
    },
    enabled: initialConfig.enabled,
  });

  const [errors, setErrors] = useState<FormErrors>({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleInputChange = (
    platform: 'ios' | 'android',
    field: 'minVersion' | 'forceUpdateVersion',
    value: string,
  ) => {
    setFormState((prev) => ({
      ...prev,
      [platform]: {
        ...prev[platform],
        [field]: value,
      },
    }));
    // Clear error for this platform when user modifies it
    if (errors[platform]) {
      setErrors((prev) => ({
        ...prev,
        [platform]: undefined,
      }));
    }
  };

  const handleEnabledToggle = () => {
    setFormState((prev) => ({
      ...prev,
      enabled: !prev.enabled,
    }));
  };

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();

    // Client-side validation
    const iosError = validatePlatform('ios', formState.ios);
    const androidError = validatePlatform('android', formState.android);

    if (iosError || androidError) {
      setErrors({
        ios: iosError,
        android: androidError,
      });
      return;
    }

    setIsSubmitting(true);
    setErrors({});

    try {
      const response = await fetch('/api/admin/app-version', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          ios: formState.ios,
          android: formState.android,
          enabled: formState.enabled,
        }),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        const errorMessage =
          typeof errorData === 'object' &&
          errorData !== null &&
          'message' in errorData
            ? (errorData as Record<string, unknown>).message
            : 'Failed to save app version configuration';

        setErrors({
          general:
            typeof errorMessage === 'string'
              ? errorMessage
              : 'Failed to save app version configuration',
        });
        return;
      }

      const updatedConfig = (await response.json()) as AppVersionConfigResponse;

      // Update form state with server response
      setFormState({
        ios: {
          minVersion: updatedConfig.ios.minVersion,
          forceUpdateVersion: updatedConfig.ios.forceUpdateVersion,
        },
        android: {
          minVersion: updatedConfig.android.minVersion,
          forceUpdateVersion: updatedConfig.android.forceUpdateVersion,
        },
        enabled: updatedConfig.enabled,
      });

      showSuccessToast('App version configuration saved successfully');
    } catch (err) {
      setErrors({
        general:
          err instanceof Error ? err.message : 'An unexpected error occurred',
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {/* ── General error ────────────────────────────────────────────────── */}
      {errors.general && (
        <div
          className="rounded-lg bg-error-container p-4 text-sm text-on-error-container"
          role="alert"
        >
          <p className="font-medium">Error saving configuration</p>
          <p className="mt-1">{errors.general}</p>
        </div>
      )}

      {/* ── Enabled toggle ───────────────────────────────────────────────── */}
      <div className="rounded-lg bg-surface-container p-6">
        <label className="flex items-center gap-3 cursor-pointer">
          <input
            type="checkbox"
            checked={formState.enabled}
            onChange={handleEnabledToggle}
            className="w-5 h-5 rounded border-outline-variant cursor-pointer accent-primary"
            aria-label="Enable app version enforcement"
          />
          <span className="text-sm font-medium text-on-surface">
            Enable version enforcement
          </span>
        </label>
        <p className="text-xs text-on-surface-variant mt-2 ml-8">
          When enabled, app clients will enforce minimum and forced-update versions
        </p>
      </div>

      {/* ── iOS Section ──────────────────────────────────────────────────── */}
      <fieldset className="rounded-lg bg-surface-container p-6">
        <legend className="text-lg font-semibold text-on-surface mb-6">
          iOS Configuration
        </legend>

        {errors.ios && (
          <div role="alert" className="rounded-lg bg-error-container p-3 mb-4 text-sm text-on-error-container">
            {errors.ios}
          </div>
        )}

        <div className="space-y-4">
          <div>
            <label htmlFor="ios-min-version" className="block text-sm font-medium text-on-surface mb-2">
              Minimum Version
            </label>
            <input
              id="ios-min-version"
              type="text"
              value={formState.ios.minVersion}
              onChange={(e) =>
                handleInputChange('ios', 'minVersion', e.target.value)
              }
              placeholder="e.g., 1.0.0"
              className={INPUT_CLASS}
              disabled={isSubmitting}
              aria-label="iOS minimum version"
            />
            <p className="text-xs text-on-surface-variant mt-1">
              Users with versions below this will be blocked from using the app
            </p>
          </div>

          <div>
            <label htmlFor="ios-force-update" className="block text-sm font-medium text-on-surface mb-2">
              Force Update Version
            </label>
            <input
              id="ios-force-update"
              type="text"
              value={formState.ios.forceUpdateVersion}
              onChange={(e) =>
                handleInputChange('ios', 'forceUpdateVersion', e.target.value)
              }
              placeholder="e.g., 1.0.0"
              className={INPUT_CLASS}
              disabled={isSubmitting}
              aria-label="iOS force update version"
            />
            <p className="text-xs text-on-surface-variant mt-1">
              Users with versions below this will see a strong nudge to update
            </p>
          </div>
        </div>
      </fieldset>

      {/* ── Android Section ──────────────────────────────────────────────── */}
      <fieldset className="rounded-lg bg-surface-container p-6">
        <legend className="text-lg font-semibold text-on-surface mb-6">
          Android Configuration
        </legend>

        {errors.android && (
          <div role="alert" className="rounded-lg bg-error-container p-3 mb-4 text-sm text-on-error-container">
            {errors.android}
          </div>
        )}

        <div className="space-y-4">
          <div>
            <label htmlFor="android-min-version" className="block text-sm font-medium text-on-surface mb-2">
              Minimum Version
            </label>
            <input
              id="android-min-version"
              type="text"
              value={formState.android.minVersion}
              onChange={(e) =>
                handleInputChange('android', 'minVersion', e.target.value)
              }
              placeholder="e.g., 1.0.0"
              className={INPUT_CLASS}
              disabled={isSubmitting}
              aria-label="Android minimum version"
            />
            <p className="text-xs text-on-surface-variant mt-1">
              Users with versions below this will be blocked from using the app
            </p>
          </div>

          <div>
            <label htmlFor="android-force-update" className="block text-sm font-medium text-on-surface mb-2">
              Force Update Version
            </label>
            <input
              id="android-force-update"
              type="text"
              value={formState.android.forceUpdateVersion}
              onChange={(e) =>
                handleInputChange('android', 'forceUpdateVersion', e.target.value)
              }
              placeholder="e.g., 1.0.0"
              className={INPUT_CLASS}
              disabled={isSubmitting}
              aria-label="Android force update version"
            />
            <p className="text-xs text-on-surface-variant mt-1">
              Users with versions below this will see a strong nudge to update
            </p>
          </div>
        </div>
      </fieldset>

      {/* ── Submit button ────────────────────────────────────────────────── */}
      <div className="flex gap-3 justify-end pt-4">
        <button
          type="submit"
          disabled={isSubmitting}
          className={[
            'px-6 py-2.5 rounded-lg font-medium text-sm',
            'transition-colors min-h-[44px] min-w-[120px]',
            'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-1',
            isSubmitting
              ? 'bg-primary/50 text-on-primary cursor-not-allowed opacity-50'
              : 'bg-primary text-on-primary hover:bg-primary/90 active:bg-primary/80',
          ]
            .filter(Boolean)
            .join(' ')}
          aria-label={isSubmitting ? 'Saving...' : 'Save Configuration'}
        >
          {isSubmitting ? 'Saving...' : 'Save Configuration'}
        </button>
      </div>
    </form>
  );
}
