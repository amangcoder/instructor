/**
 * Unit tests for SharingService — plan sharing business logic.
 *
 * Tests:
 *   - generateShareToken: nanoid(12) format, stored on plans table, idempotent
 *   - revokeShareToken: clears token, NotFoundException for missing plan
 *   - getSharedPlan: returns plan data for valid token, null for invalid
 *   - Ownership validation: only plan owner can share/revoke (NotFoundException for non-owner)
 *   - Security: token format validation (12 chars, URL-safe alphabet)
 *
 * Strategy:
 *   - DatabaseService is fully mocked — no real DB connection needed.
 *   - Tests exercise service methods in isolation.
 *   - getPlanById mock returns null for wrong userId (matches real DB behavior).
 */

import { Test, TestingModule } from '@nestjs/testing';
import {
  NotFoundException,
} from '@nestjs/common';
import { SharingService } from './sharing.service';
import { DatabaseService } from '../database/database.service';

// ---------------------------------------------------------------------------
// Mock factories
// ---------------------------------------------------------------------------

function createMockDatabaseService() {
  return {
    // Plan queries — returns a plan owned by 'owner-user-id'
    getPlanById: jest.fn().mockResolvedValue({
      planId: 'plan-uuid-001',
      userId: 'owner-user-id',
      name: 'Morning Yoga',
      planJson: JSON.stringify({
        name: 'Morning Yoga',
        description: 'A relaxing morning routine.',
        steps: [
          { type: 'say', text: 'Welcome.' },
          { type: 'wait', duration: 300 },
        ],
      }),
      shareToken: null,
      shareTokenCreatedAt: null,
      isActive: false,
      ttsStatus: 'none',
      ttsTotal: 0,
      ttsCompleted: 0,
      voiceQuality: 'standard',
      sourceLibraryPlanId: null,
      createdAt: new Date('2026-01-01T00:00:00Z'),
      updatedAt: new Date('2026-01-15T00:00:00Z'),
    }),

    // Share token operations (match actual DatabaseService method names)
    updatePlanShareToken: jest.fn().mockResolvedValue(undefined),
    revokePlanShareToken: jest.fn().mockResolvedValue(true),
    getSharedPlan: jest.fn().mockResolvedValue(null),

    // Generic withRetry wrapper (passthrough)
    withRetry: jest.fn().mockImplementation((fn: () => Promise<unknown>) => fn()),
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('SharingService', () => {
  let service: SharingService;
  let dbService: ReturnType<typeof createMockDatabaseService>;

  beforeEach(async () => {
    dbService = createMockDatabaseService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SharingService,
        { provide: DatabaseService, useValue: dbService },
      ],
    }).compile();

    service = module.get<SharingService>(SharingService);
  });

  // ─── generateShareToken ────────────────────────────────────────────────

  describe('generateShareToken', () => {
    it('generates a share token and URL for a valid plan', async () => {
      const result = await service.generateShareToken(
        'owner-user-id',
        'plan-uuid-001',
      );

      expect(result).toHaveProperty('shareToken');
      expect(result).toHaveProperty('shareUrl');
      expect(result.shareToken).toBeTruthy();
      expect(result.shareUrl).toContain(result.shareToken);
    });

    it('generates a token of 12 characters (nanoid default)', async () => {
      const result = await service.generateShareToken(
        'owner-user-id',
        'plan-uuid-001',
      );

      expect(result.shareToken.length).toBe(12);
    });

    it('generates URL-safe tokens (alphanumeric + _ + -)', async () => {
      const result = await service.generateShareToken(
        'owner-user-id',
        'plan-uuid-001',
      );

      expect(result.shareToken).toMatch(/^[A-Za-z0-9_-]{12}$/);
    });

    it('calls DatabaseService.updatePlanShareToken with correct args', async () => {
      const result = await service.generateShareToken(
        'owner-user-id',
        'plan-uuid-001',
      );

      expect(dbService.updatePlanShareToken).toHaveBeenCalledWith(
        'plan-uuid-001',
        result.shareToken,
      );
    });

    it('throws NotFoundException when plan does not exist (or user does not own it)', async () => {
      // Real DB returns null when planId+userId combo does not match
      dbService.getPlanById.mockResolvedValueOnce(null);

      await expect(
        service.generateShareToken('owner-user-id', 'nonexistent-plan'),
      ).rejects.toThrow(NotFoundException);
    });

    it('throws NotFoundException when userId does not own the plan', async () => {
      // Real DB returns null for cross-user access — same as not found (IDOR prevention)
      dbService.getPlanById.mockResolvedValueOnce(null);

      await expect(
        service.generateShareToken('attacker-user-id', 'plan-uuid-001'),
      ).rejects.toThrow(NotFoundException);
    });

    it('returns existing token if plan is already shared (idempotent)', async () => {
      dbService.getPlanById.mockResolvedValueOnce({
        planId: 'plan-uuid-001',
        userId: 'owner-user-id',
        name: 'Morning Yoga',
        planJson: '{}',
        shareToken: 'existingToken1',  // 12 chars, valid format
        shareTokenCreatedAt: new Date(),
        isActive: false,
        ttsStatus: 'none',
        ttsTotal: 0,
        ttsCompleted: 0,
        voiceQuality: 'standard',
        sourceLibraryPlanId: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      const result = await service.generateShareToken(
        'owner-user-id',
        'plan-uuid-001',
      );

      expect(result.shareToken).toBe('existingToken1');
      // Should NOT call updatePlanShareToken since token already exists
      expect(dbService.updatePlanShareToken).not.toHaveBeenCalled();
    });

    it('generates URL under 60 characters (AC-007)', async () => {
      const result = await service.generateShareToken(
        'owner-user-id',
        'plan-uuid-001',
      );

      // https://instructor.app/s/XXXXXXXXXXXX = 36 + 12 = 48 chars
      expect(result.shareUrl.length).toBeLessThanOrEqual(60);
    });
  });

  // ─── revokeShareToken ──────────────────────────────────────────────────

  describe('revokeShareToken', () => {
    it('returns true after successfully revoking share token', async () => {
      dbService.getPlanById.mockResolvedValueOnce({
        planId: 'plan-uuid-001',
        userId: 'owner-user-id',
        name: 'Morning Yoga',
        planJson: '{}',
        shareToken: 'activeToken12',
        shareTokenCreatedAt: new Date(),
        isActive: false,
        ttsStatus: 'none',
        ttsTotal: 0,
        ttsCompleted: 0,
        voiceQuality: 'standard',
        sourceLibraryPlanId: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      const result = await service.revokeShareToken(
        'owner-user-id',
        'plan-uuid-001',
      );

      expect(result).toBe(true);
      expect(dbService.revokePlanShareToken).toHaveBeenCalledWith(
        'owner-user-id',
        'plan-uuid-001',
      );
    });

    it('throws NotFoundException when userId does not own the plan', async () => {
      // Real DB returns null for cross-user access (IDOR prevention)
      dbService.getPlanById.mockResolvedValueOnce(null);

      await expect(
        service.revokeShareToken('attacker-user-id', 'plan-uuid-001'),
      ).rejects.toThrow(NotFoundException);
    });

    it('throws NotFoundException when plan does not exist', async () => {
      dbService.getPlanById.mockResolvedValueOnce(null);

      await expect(
        service.revokeShareToken('owner-user-id', 'nonexistent-plan'),
      ).rejects.toThrow(NotFoundException);
    });

    it('does not call revokePlanShareToken when plan is not found', async () => {
      dbService.getPlanById.mockResolvedValueOnce(null);

      try {
        await service.revokeShareToken('owner-user-id', 'nonexistent');
      } catch {
        // Expected to throw
      }

      expect(dbService.revokePlanShareToken).not.toHaveBeenCalled();
    });
  });

  // ─── getSharedPlan ─────────────────────────────────────────────────────

  describe('getSharedPlan', () => {
    it('returns null for tokens with invalid format (not 12 chars)', async () => {
      const result = await service.getSharedPlan('short');
      expect(result).toBeNull();
      // Should not call DB for invalid token format
      expect(dbService.getSharedPlan).not.toHaveBeenCalled();
    });

    it('returns null for tokens with invalid characters', async () => {
      const result = await service.getSharedPlan('invalid!token');
      expect(result).toBeNull();
    });

    it('returns null when token is not found in DB (revoked or never existed)', async () => {
      // Token has valid format (12 URL-safe chars) but no matching plan
      dbService.getSharedPlan.mockResolvedValueOnce(null);

      const result = await service.getSharedPlan('validToken12');
      expect(result).toBeNull();
    });

    it('returns plan data for a valid share token', async () => {
      dbService.getSharedPlan.mockResolvedValueOnce({
        name: 'Morning Yoga',
        description: 'A relaxing morning routine.',
        steps: [
          { type: 'say', text: 'Welcome.' },
          { type: 'wait', duration: 300 },
        ],
        stepCount: 2,
        estimatedDurationMs: 900000,
      });

      const result = await service.getSharedPlan('validToken12');

      expect(result).toMatchObject({
        name: 'Morning Yoga',
        description: expect.any(String),
        steps: expect.any(Array),
        stepCount: 2,
        estimatedDurationMs: expect.any(Number),
      });
    });

    it('response excludes userId and internal database IDs', async () => {
      dbService.getSharedPlan.mockResolvedValueOnce({
        name: 'Morning Yoga',
        description: 'Description.',
        steps: [],
        stepCount: 0,
        estimatedDurationMs: 0,
      });

      const result = await service.getSharedPlan('validToken12');

      expect(result).not.toHaveProperty('userId');
      expect(result).not.toHaveProperty('id');
      expect(result).not.toHaveProperty('shareToken');
      expect(result).not.toHaveProperty('createdAt');
      expect(result).not.toHaveProperty('updatedAt');
    });

    it('returns correct stepCount matching steps array length', async () => {
      const steps = [
        { type: 'say', text: 'A' },
        { type: 'wait', duration: 10 },
        { type: 'say', text: 'B' },
        { type: 'say', text: 'C' },
      ];

      dbService.getSharedPlan.mockResolvedValueOnce({
        name: 'Test Plan',
        description: 'Test.',
        steps,
        stepCount: 4,
        estimatedDurationMs: 120000,
      });

      const result = await service.getSharedPlan('validToken12');

      expect(result!.stepCount).toBe(4);
      expect(result!.steps.length).toBe(4);
    });

    it('returns null on database errors (no throw to caller)', async () => {
      dbService.getSharedPlan.mockRejectedValueOnce(new Error('DB timeout'));

      const result = await service.getSharedPlan('validToken12');
      expect(result).toBeNull();
    });
  });

  // ─── Token format ──────────────────────────────────────────────────────

  describe('token format validation', () => {
    it('accepts exactly 12-char URL-safe tokens and queries DB', async () => {
      dbService.getSharedPlan.mockResolvedValueOnce({
        name: 'Test',
        description: undefined,
        steps: [],
        stepCount: 0,
        estimatedDurationMs: 0,
      });

      await service.getSharedPlan('abc123XYZ_-0');
      expect(dbService.getSharedPlan).toHaveBeenCalledWith('abc123XYZ_-0');
    });

    it('rejects 11-char tokens without querying DB', async () => {
      const result = await service.getSharedPlan('abc123XYZ_-');  // 11 chars
      expect(result).toBeNull();
      expect(dbService.getSharedPlan).not.toHaveBeenCalled();
    });

    it('rejects 13-char tokens without querying DB', async () => {
      const result = await service.getSharedPlan('abc123XYZ_-01');  // 13 chars
      expect(result).toBeNull();
      expect(dbService.getSharedPlan).not.toHaveBeenCalled();
    });
  });
});
