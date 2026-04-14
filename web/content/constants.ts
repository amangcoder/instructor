/**
 * Static constants for the Instructor marketing website.
 */

/**
 * App Store download link
 * TODO: Replace with actual App Store URL once app is published
 */
export const APP_STORE_URL = '#TODO-app-store';

/**
 * Google Play Store download link
 * TODO: Replace with actual Play Store URL once app is published
 */
export const PLAY_STORE_URL = '#TODO-play-store';

/**
 * Support email address for user inquiries
 */
export const SUPPORT_EMAIL = 'admin@layersiq.com';

/**
 * Data deletion processing timeline in days (GDPR Article 17 requirement)
 * Users will be notified that deletion requests are processed within this timeline
 */
export const PROCESSING_TIMELINE_DAYS = 30;

/**
 * Marketing tracking (optional, disabled by default)
 * Set to true to enable basic analytics; ensure compliance with privacy policy
 */
export const ENABLE_ANALYTICS = false;

/**
 * Backend API endpoint for deletion requests
 * Points to the NestJS server admin endpoint
 */
export const DELETION_API_ENDPOINT = process.env.NEXT_PUBLIC_API_URL
  ? `${process.env.NEXT_PUBLIC_API_URL}/api/admin/deletion-requests`
  : 'http://localhost:3071/api/admin/deletion-requests';

/**
 * Fallback email for deletion requests if API is unavailable
 * Uses mailto: link if the API endpoint fails
 */
export const DELETION_FALLBACK_EMAIL = SUPPORT_EMAIL;

/**
 * Client-side cooldown timer for form resubmission (seconds)
 */
export const DELETION_FORM_COOLDOWN_SECONDS = 60;

/**
 * OTP expiration time (minutes)
 * Matches backend implementation
 */
export const OTP_EXPIRATION_MINUTES = 10;

/**
 * Refresh token expiration (days)
 * Matches backend implementation
 */
export const REFRESH_TOKEN_EXPIRATION_DAYS = 30;

/**
 * TTS audio cache retention period (days)
 * Older cached audio files are automatically purged
 */
export const TTS_CACHE_RETENTION_DAYS = 90;

/**
 * Execution history retention period (days)
 * Session history older than this is automatically deleted
 */
export const EXECUTION_HISTORY_RETENTION_DAYS = 365;
