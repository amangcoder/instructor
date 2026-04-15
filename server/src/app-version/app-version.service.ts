import { Injectable, Logger } from '@nestjs/common';

export type AppPlatform = 'ios' | 'android';

export interface AppVersionCheckResult {
  /** True when the force-update policy is active for this platform. */
  forceUpdate: boolean;
  /** True when the version gate is enabled server-side at all. */
  enabled: boolean;
  /** Minimum supported version for the platform (semver-style "x.y.z"). */
  minVersion: string | null;
  /** Latest known store version (informational). */
  latestVersion: string | null;
  /** Platform-specific store URL the app should open to update. */
  storeUrl: string | null;
  /** Message to show on the force-update screen. */
  message: string;
}

/**
 * Reads the minimum-required app version config from environment variables:
 *
 *   APP_VERSION_FORCE_UPDATE_ENABLED  — "true" to enable the gate
 *   APP_VERSION_MIN_IOS               — e.g. "1.0.5"
 *   APP_VERSION_MIN_ANDROID           — e.g. "1.0.5"
 *   APP_VERSION_LATEST_IOS            — optional, informational
 *   APP_VERSION_LATEST_ANDROID        — optional, informational
 *   APP_VERSION_STORE_URL_IOS         — App Store URL
 *   APP_VERSION_STORE_URL_ANDROID     — Play Store URL
 *   APP_VERSION_UPDATE_MESSAGE        — optional custom message
 */
@Injectable()
export class AppVersionService {
  private readonly logger = new Logger(AppVersionService.name);

  check(platform: AppPlatform, currentVersion: string): AppVersionCheckResult {
    const enabled =
      (process.env.APP_VERSION_FORCE_UPDATE_ENABLED ?? '').toLowerCase() === 'true';

    const minVersion =
      platform === 'ios'
        ? (process.env.APP_VERSION_MIN_IOS ?? '').trim() || null
        : (process.env.APP_VERSION_MIN_ANDROID ?? '').trim() || null;

    const latestVersion =
      platform === 'ios'
        ? (process.env.APP_VERSION_LATEST_IOS ?? '').trim() || null
        : (process.env.APP_VERSION_LATEST_ANDROID ?? '').trim() || null;

    const storeUrl =
      platform === 'ios'
        ? (process.env.APP_VERSION_STORE_URL_IOS ?? '').trim() || null
        : (process.env.APP_VERSION_STORE_URL_ANDROID ?? '').trim() || null;

    const message =
      (process.env.APP_VERSION_UPDATE_MESSAGE ?? '').trim() ||
      'A new version is required to keep using the app. Please update to continue.';

    const forceUpdate =
      enabled &&
      minVersion !== null &&
      compareVersions(currentVersion, minVersion) < 0;

    return { forceUpdate, enabled, minVersion, latestVersion, storeUrl, message };
  }
}

/**
 * Compare two dot-separated version strings numerically.
 * Returns negative if a < b, 0 if equal, positive if a > b.
 * Non-numeric or missing segments are treated as 0.
 */
export function compareVersions(a: string, b: string): number {
  const pa = normalize(a);
  const pb = normalize(b);
  const len = Math.max(pa.length, pb.length);
  for (let i = 0; i < len; i++) {
    const da = pa[i] ?? 0;
    const db = pb[i] ?? 0;
    if (da !== db) return da - db;
  }
  return 0;
}

function normalize(v: string): number[] {
  return (v || '')
    .split('+')[0]
    .split('-')[0]
    .split('.')
    .map((s) => {
      const n = parseInt(s, 10);
      return Number.isFinite(n) ? n : 0;
    });
}
