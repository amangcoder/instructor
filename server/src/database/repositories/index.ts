/**
 * Barrel export for all domain repositories.
 *
 * Import from this file rather than individual repository files
 * to keep import paths stable during the migration.
 */

export { AuthRepository } from './auth.repository';
export { UserRepository } from './user.repository';
export { PlanRepository } from './plan.repository';
export { TtsRepository } from './tts.repository';
export { AdminAnalyticsRepository } from './analytics.repository';
export { LibraryRepository } from './library.repository';
export { SyncRepository } from './sync.repository';
export { AdminRepository } from './admin.repository';
