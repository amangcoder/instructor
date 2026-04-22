/**
 * App Version Configuration API — Response types for app version management.
 *
 * These mirror the server-side DTOs in server/src/admin/app-version.service.ts.
 * They are duplicated here so the Next.js web app does not depend on the
 * NestJS server package at build time.
 */

// ---------------------------------------------------------------------------
// Platform Version Configuration  — GET /api/admin/app-version
// ---------------------------------------------------------------------------

/** Version configuration for a specific platform */
export interface PlatformVersionConfig {
  /** Minimum supported version (users below this are blocked) */
  minVersion: string;
  /** Force-update version (strong nudge to update, but not blocking) */
  forceUpdateVersion: string;
}

/** Application version configuration for iOS and Android platforms */
export interface AppVersionConfigResponse {
  /** iOS version constraints */
  ios: PlatformVersionConfig;
  /** Android version constraints */
  android: PlatformVersionConfig;
  /** Whether version enforcement is enabled globally */
  enabled: boolean;
}
