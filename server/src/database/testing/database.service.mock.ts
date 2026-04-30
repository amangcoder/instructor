/**
 * Centralized mock factory functions for database services.
 *
 * This module exports Jest mock factories for DatabaseService and all repository
 * classes. All test files import from this location instead of duplicating
 * createMockDatabaseService() and friends. This ensures:
 *
 * 1. DatabaseService interface changes automatically picked up by all specs
 * 2. ~300 lines of duplication eliminated
 * 3. Consistent mock behavior across the codebase
 *
 * Usage:
 * ```typescript
 * import { createMockDatabaseService, createMockAuthRepository } from '../database/testing';
 *
 * const dbService = createMockDatabaseService();
 * const authRepo = createMockAuthRepository();
 * ```
 */

import { DatabaseService } from '../database.service';
import { AuthRepository } from '../repositories/auth.repository';
import { PlanRepository } from '../repositories/plan.repository';
import { TtsRepository } from '../repositories/tts.repository';
import { UserRepository } from '../repositories/user.repository';
import { LibraryRepository } from '../repositories/library.repository';
import { SyncRepository } from '../repositories/sync.repository';
import { AdminRepository } from '../repositories/admin.repository';

/**
 * Create a fully-mocked DatabaseService with all methods returning sensible defaults.
 *
 * Every DatabaseService method is mocked to return a resolved Promise with a default value:
 *   - Methods returning void -> resolves to undefined
 *   - Methods returning a record -> resolves to null
 *   - Methods returning an array -> resolves to []
 *
 * The _mockDb property exposes the internal Drizzle mock for chaining assertions.
 *
 * Tests can override specific mocks:
 *   ```ts
 *   const mockDb = createMockDatabaseService();
 *   mockDb.getUserByEmail.mockResolvedValue(USER);
 *   ```
 */
export function createMockDatabaseService(): jest.Mocked<DatabaseService> {
  const mockDb = {
    select: jest.fn().mockReturnThis(),
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    groupBy: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    leftJoin: jest.fn().mockReturnThis(),
    innerJoin: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    offset: jest.fn().mockReturnThis(),
    update: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    returning: jest.fn().mockResolvedValue([]),
    execute: jest.fn(),
  };

  return {
    // Infrastructure
    getDb: jest.fn().mockReturnValue(mockDb),
    withRetry: jest.fn().mockImplementation(async (fn: () => Promise<any>) => fn()),
    noop: false,
    _mockDb: mockDb,

    // User operations
    getUserById: jest.fn().mockResolvedValue(null),
    getUserByEmail: jest.fn().mockResolvedValue(null),
    createUser: jest.fn().mockResolvedValue(undefined),
    updateUserProfile: jest.fn().mockResolvedValue(undefined),
    deleteUser: jest.fn().mockResolvedValue(undefined),

    // OTP operations
    createOtp: jest.fn().mockResolvedValue(undefined),
    getActiveOtps: jest.fn().mockResolvedValue([]),
    markOtpUsed: jest.fn().mockResolvedValue(undefined),
    incrementOtpAttempts: jest.fn().mockResolvedValue(undefined),
    invalidateOtpsForEmail: jest.fn().mockResolvedValue(undefined),

    // Refresh token operations
    createRefreshToken: jest.fn().mockResolvedValue(undefined),
    getRefreshToken: jest.fn().mockResolvedValue(null),
    revokeRefreshToken: jest.fn().mockResolvedValue(undefined),
    revokeAllRefreshTokens: jest.fn().mockResolvedValue(undefined),

    // Plan operations
    savePlan: jest.fn().mockResolvedValue({ planId: 'plan-1', updatedAt: new Date() }),
    getPlanById: jest.fn().mockResolvedValue(null),
    deletePlan: jest.fn().mockResolvedValue(undefined),
    activatePlan: jest.fn().mockResolvedValue(undefined),
    setTtsStatus: jest.fn().mockResolvedValue(undefined),
    incrementTtsCompleted: jest.fn().mockResolvedValue(undefined),
    listPlans: jest.fn().mockResolvedValue([]),
    copyLibraryPlanToUser: jest.fn().mockResolvedValue({ planId: 'plan-1' }),

    // Library plan operations
    listLibraryPlans: jest.fn().mockResolvedValue({ plans: [], total: 0 }),
    getLibraryPlanById: jest.fn().mockResolvedValue(null),
    createLibraryPlan: jest.fn().mockResolvedValue(undefined),
    listAllLibraryPlans: jest.fn().mockResolvedValue([]),
    updateLibraryPlan: jest.fn().mockResolvedValue(undefined),
    deleteLibraryPlan: jest.fn().mockResolvedValue(false),

    // TTS job operations
    createTtsJobs: jest.fn().mockResolvedValue([]),
    getTtsJobsByIds: jest.fn().mockResolvedValue([]),
    updateTtsJobStatus: jest.fn().mockResolvedValue(undefined),
    getPlanTtsStatus: jest.fn().mockResolvedValue({
      status: 'none',
      total: 0,
      completed: 0,
      failed: 0,
      ready: false,
      updatedAt: new Date(),
    }),
    getCompletedTtsJobs: jest.fn().mockResolvedValue([]),
    failStalePendingJobs: jest.fn().mockResolvedValue(undefined),
    finalizePlanTtsStatus: jest.fn().mockResolvedValue(undefined),

    // Sync metadata
    getSyncMetadata: jest.fn().mockResolvedValue(null),
    upsertSyncMetadata: jest.fn().mockResolvedValue(undefined),

    // Session completions
    upsertSessionCompletions: jest.fn().mockResolvedValue(0),
    getSessionCompletions: jest.fn().mockResolvedValue([]),

    // Plan triggers
    upsertPlanTriggers: jest.fn().mockResolvedValue([]),
    getPlanTriggers: jest.fn().mockResolvedValue([]),

    // Sharing
    updatePlanShareToken: jest.fn().mockResolvedValue(undefined),
    revokePlanShareToken: jest.fn().mockResolvedValue(true),
    getSharedPlan: jest.fn().mockResolvedValue(null),

    // Deletion requests
    insertDeletionRequest: jest.fn().mockResolvedValue(undefined),
  } as unknown as jest.Mocked<DatabaseService>;
}

/** Create a fully-mocked AuthRepository. */
export function createMockAuthRepository(): jest.Mocked<AuthRepository> {
  return {
    createOtp: jest.fn().mockResolvedValue(undefined),
    getActiveOtps: jest.fn().mockResolvedValue([]),
    markOtpUsed: jest.fn().mockResolvedValue(undefined),
    incrementOtpAttempts: jest.fn().mockResolvedValue(undefined),
    invalidateOtpsForEmail: jest.fn().mockResolvedValue(undefined),
    createRefreshToken: jest.fn().mockResolvedValue(undefined),
    getRefreshToken: jest.fn().mockResolvedValue(null),
    revokeRefreshToken: jest.fn().mockResolvedValue(undefined),
    revokeAllRefreshTokens: jest.fn().mockResolvedValue(undefined),
    cleanupExpiredOtps: jest.fn().mockResolvedValue(0),
  } as unknown as jest.Mocked<AuthRepository>;
}

/** Create a fully-mocked PlanRepository. */
export function createMockPlanRepository(): jest.Mocked<PlanRepository> {
  return {
    savePlan: jest.fn().mockResolvedValue({ planId: 'plan-1', updatedAt: new Date() }),
    getPlanById: jest.fn().mockResolvedValue(null),
    deletePlan: jest.fn().mockResolvedValue(undefined),
    activatePlan: jest.fn().mockResolvedValue(undefined),
    setTtsStatus: jest.fn().mockResolvedValue(undefined),
    incrementTtsCompleted: jest.fn().mockResolvedValue(undefined),
    listPlans: jest.fn().mockResolvedValue([]),
    copyLibraryPlanToUser: jest.fn().mockResolvedValue({ planId: 'plan-1' }),
    updatePlanShareToken: jest.fn().mockResolvedValue(undefined),
    revokePlanShareToken: jest.fn().mockResolvedValue(true),
    getSharedPlan: jest.fn().mockResolvedValue(null),
  } as unknown as jest.Mocked<PlanRepository>;
}

/** Create a fully-mocked TtsRepository. */
export function createMockTtsRepository(): jest.Mocked<TtsRepository> {
  return {
    createTtsJobs: jest.fn().mockResolvedValue([]),
    getTtsJobsByIds: jest.fn().mockResolvedValue([]),
    updateTtsJobStatus: jest.fn().mockResolvedValue(undefined),
    getPlanTtsStatus: jest.fn().mockResolvedValue({
      status: 'none',
      total: 0,
      completed: 0,
      failed: 0,
      ready: false,
      updatedAt: new Date(),
    }),
    getCompletedTtsJobs: jest.fn().mockResolvedValue([]),
    failStalePendingJobs: jest.fn().mockResolvedValue(undefined),
    finalizePlanTtsStatus: jest.fn().mockResolvedValue(undefined),
  } as unknown as jest.Mocked<TtsRepository>;
}

/** Create a fully-mocked UserRepository. */
export function createMockUserRepository(): jest.Mocked<UserRepository> {
  return {
    getUserById: jest.fn().mockResolvedValue(null),
    getUserByEmail: jest.fn().mockResolvedValue(null),
    createUser: jest.fn().mockResolvedValue(undefined),
    updateUserProfile: jest.fn().mockResolvedValue(undefined),
    deleteUser: jest.fn().mockResolvedValue(undefined),
  } as unknown as jest.Mocked<UserRepository>;
}

/** Create a fully-mocked LibraryRepository. */
export function createMockLibraryRepository(): jest.Mocked<LibraryRepository> {
  return {
    listAllLibraryPlans: jest.fn().mockResolvedValue([]),
    listLibraryPlans: jest.fn().mockResolvedValue({ plans: [], total: 0 }),
    getLibraryPlanById: jest.fn().mockResolvedValue(null),
    createLibraryPlan: jest.fn().mockResolvedValue(undefined),
    updateLibraryPlan: jest.fn().mockResolvedValue(undefined),
    deleteLibraryPlan: jest.fn().mockResolvedValue(false),
  } as unknown as jest.Mocked<LibraryRepository>;
}

/** Create a fully-mocked SyncRepository. */
export function createMockSyncRepository(): jest.Mocked<SyncRepository> {
  return {
    upsertSessionCompletions: jest.fn().mockResolvedValue(0),
    getSessionCompletions: jest.fn().mockResolvedValue([]),
    upsertPlanTriggers: jest.fn().mockResolvedValue([]),
    getPlanTriggers: jest.fn().mockResolvedValue([]),
  } as unknown as jest.Mocked<SyncRepository>;
}

/** Create a fully-mocked AdminRepository. */
export function createMockAdminRepository(): jest.Mocked<AdminRepository> {
  return {
    noop: false,
    insertDeletionRequest: jest.fn().mockResolvedValue(undefined),
  } as unknown as jest.Mocked<AdminRepository>;
}
