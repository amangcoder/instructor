/**
 * Shared test utilities and mock factories for DatabaseService and repositories.
 *
 * Centralizes all mock definitions to eliminate duplication across test files.
 * Any change to DatabaseService or repository interfaces will automatically be
 * reflected in all test files that use these factories.
 */

export {
  createMockDatabaseService,
  createMockAuthRepository,
  createMockPlanRepository,
  createMockTtsRepository,
  createMockUserRepository,
  createMockLibraryRepository,
  createMockSyncRepository,
  createMockAdminRepository,
} from './database.service.mock';
