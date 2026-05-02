/**
 * Extended unit tests for PlansService — sub-plan tree, user plan creation,
 * request-publish, admin update, IDOR checks, and depth validation.
 *
 * These tests cover the new methods added in TASK-013.
 */

import { Test, TestingModule } from '@nestjs/testing';
import {
  ForbiddenException,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { PlansService } from './plans.service';
import { DatabaseService } from '../database/database.service';
import { TtsBatchPregenService } from '../tts/tts-batch-pregen.service';
import { createMockDatabaseService } from '../database/testing';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createMockDbWithExecute() {
  const mockDatabaseService = createMockDatabaseService();

  // Default mocks for plan operations
  (mockDatabaseService.savePlan as jest.Mock).mockResolvedValue({ planId: 'test-plan-id', updatedAt: new Date() });
  (mockDatabaseService.listPlans as jest.Mock).mockResolvedValue([]);

  // Mock getDb to return an object with insert/select/update/execute
  const mockInternalDb = {
    select: jest.fn().mockReturnThis(),
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    limit: jest.fn().mockResolvedValue([]),
    insert: jest.fn().mockReturnThis(),
    values: jest.fn().mockReturnThis(),
    returning: jest.fn().mockResolvedValue([]),
    update: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    execute: jest.fn().mockResolvedValue({ rows: [] }),
  };

  (mockDatabaseService.getDb as jest.Mock).mockReturnValue(mockInternalDb);
  (mockDatabaseService.withRetry as jest.Mock).mockImplementation(async (fn: () => Promise<any>) => fn());

  return { mockDatabaseService, mockInternalDb };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('PlansService — Extended (TASK-013)', () => {
  let service: PlansService;
  let mockDatabaseService: jest.Mocked<DatabaseService>;
  let mockInternalDb: any;
  let mockTtsBatchPregen: { startBatchPregen: jest.Mock };

  beforeEach(async () => {
    delete process.env.GEMINI_API_KEY;
    delete process.env.LLM_PROVIDER;

    const result = createMockDbWithExecute();
    mockDatabaseService = result.mockDatabaseService;
    mockInternalDb = result.mockInternalDb;

    mockTtsBatchPregen = { startBatchPregen: jest.fn().mockResolvedValue(undefined) };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PlansService,
        { provide: DatabaseService, useValue: mockDatabaseService },
        { provide: TtsBatchPregenService, useValue: mockTtsBatchPregen },
      ],
    }).compile();

    service = module.get<PlansService>(PlansService);
  });

  afterEach(() => {
    jest.restoreAllMocks();
    delete process.env.GEMINI_API_KEY;
    delete process.env.LLM_PROVIDER;
  });

  // ── GET /plans/:id/tree — Sub-plan tree retrieval ──────────────────────────

  describe('getPlanTree', () => {
    it('returns a nested tree structure for a root plan with children', async () => {
      // First call: root plan lookup (select().from().where().limit())
      const rootPlan = {
        id: 'root-id',
        name: 'Root Plan',
        visibility: 'public',
        ownerUserId: 'user-1',
        parentPlanId: null,
        position: 0,
        isPublished: true,
      };

      // Mock the chain: select().from(plans).where().limit() for root check
      const limitMock = jest.fn().mockResolvedValueOnce([rootPlan]);
      const whereMock = jest.fn().mockReturnValue({ limit: limitMock });
      const fromMock = jest.fn().mockReturnValue({ where: whereMock });
      const selectMock = jest.fn().mockReturnValue({ from: fromMock });
      mockInternalDb.select = selectMock;

      // Mock the execute for recursive CTE
      mockInternalDb.execute = jest.fn().mockResolvedValue({
        rows: [
          { id: 'root-id', name: 'Root Plan', parent_plan_id: null, position: 0, visibility: 'public', is_published: true, owner_user_id: 'user-1', depth: 1 },
          { id: 'child-1', name: 'Child 1', parent_plan_id: 'root-id', position: 0, visibility: 'public', is_published: true, owner_user_id: null, depth: 2 },
          { id: 'child-2', name: 'Child 2', parent_plan_id: 'root-id', position: 1, visibility: 'public', is_published: true, owner_user_id: null, depth: 2 },
          { id: 'grandchild-1', name: 'Grandchild 1', parent_plan_id: 'child-1', position: 0, visibility: 'public', is_published: true, owner_user_id: null, depth: 3 },
        ],
      });

      const tree = await service.getPlanTree('user-1', 'root-id');

      expect(tree.id).toBe('root-id');
      expect(tree.children).toHaveLength(2);
      expect(tree.children[0].id).toBe('child-1');
      expect(tree.children[0].children).toHaveLength(1);
      expect(tree.children[0].children[0].id).toBe('grandchild-1');
      expect(tree.children[1].id).toBe('child-2');
      expect(tree.children[1].children).toHaveLength(0);
    });

    it('throws NotFoundException when plan does not exist', async () => {
      const limitMock = jest.fn().mockResolvedValueOnce([]);
      const whereMock = jest.fn().mockReturnValue({ limit: limitMock });
      const fromMock = jest.fn().mockReturnValue({ where: whereMock });
      const selectMock = jest.fn().mockReturnValue({ from: fromMock });
      mockInternalDb.select = selectMock;

      await expect(service.getPlanTree('user-1', 'nonexistent')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('throws ForbiddenException for private plan accessed by non-owner (IDOR)', async () => {
      const privatePlan = {
        id: 'private-id',
        name: 'Private Plan',
        visibility: 'private',
        ownerUserId: 'owner-user',
        parentPlanId: null,
        position: 0,
        isPublished: false,
      };

      const limitMock = jest.fn().mockResolvedValueOnce([privatePlan]);
      const whereMock = jest.fn().mockReturnValue({ limit: limitMock });
      const fromMock = jest.fn().mockReturnValue({ where: whereMock });
      const selectMock = jest.fn().mockReturnValue({ from: fromMock });
      mockInternalDb.select = selectMock;

      await expect(service.getPlanTree('attacker-user', 'private-id')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('allows private plan access by the owner', async () => {
      const privatePlan = {
        id: 'private-id',
        name: 'My Private Plan',
        visibility: 'private',
        ownerUserId: 'owner-user',
        parentPlanId: null,
        position: 0,
        isPublished: false,
      };

      const limitMock = jest.fn().mockResolvedValueOnce([privatePlan]);
      const whereMock = jest.fn().mockReturnValue({ limit: limitMock });
      const fromMock = jest.fn().mockReturnValue({ where: whereMock });
      const selectMock = jest.fn().mockReturnValue({ from: fromMock });
      mockInternalDb.select = selectMock;

      mockInternalDb.execute = jest.fn().mockResolvedValue({
        rows: [
          { id: 'private-id', name: 'My Private Plan', parent_plan_id: null, position: 0, visibility: 'private', is_published: false, owner_user_id: 'owner-user', depth: 1 },
        ],
      });

      const tree = await service.getPlanTree('owner-user', 'private-id');
      expect(tree.id).toBe('private-id');
      expect(tree.children).toHaveLength(0);
    });

    it('allows public plan access by any user', async () => {
      const publicPlan = {
        id: 'public-id',
        name: 'Public Plan',
        visibility: 'public',
        ownerUserId: 'someone-else',
        parentPlanId: null,
        position: 0,
        isPublished: true,
      };

      const limitMock = jest.fn().mockResolvedValueOnce([publicPlan]);
      const whereMock = jest.fn().mockReturnValue({ limit: limitMock });
      const fromMock = jest.fn().mockReturnValue({ where: whereMock });
      const selectMock = jest.fn().mockReturnValue({ from: fromMock });
      mockInternalDb.select = selectMock;

      mockInternalDb.execute = jest.fn().mockResolvedValue({
        rows: [
          { id: 'public-id', name: 'Public Plan', parent_plan_id: null, position: 0, visibility: 'public', is_published: true, owner_user_id: 'someone-else', depth: 1 },
        ],
      });

      const tree = await service.getPlanTree('random-user', 'public-id');
      expect(tree.id).toBe('public-id');
    });
  });

  // ── POST /plans — User plan creation ──────────────────────────────────────

  describe('createUserPlan', () => {
    it('creates a plan with visibility=private and owner_user_id from auth', async () => {
      const returningMock = jest.fn().mockResolvedValue([{ id: 'new-plan-id' }]);
      const valuesMock = jest.fn().mockReturnValue({ returning: returningMock });
      const insertMock = jest.fn().mockReturnValue({ values: valuesMock });
      mockInternalDb.insert = insertMock;

      const result = await service.createUserPlan('user-1', 'My Plan', '{"steps":[]}', 'A description');

      expect(result.planId).toBe('new-plan-id');
      // Verify the values passed to insert
      const insertedValues = valuesMock.mock.calls[0][0];
      expect(insertedValues.userId).toBe('user-1');
      expect(insertedValues.name).toBe('My Plan');
      expect(insertedValues.planJson).toBe('{"steps":[]}');
      expect(insertedValues.visibility).toBe('private');
      expect(insertedValues.ownerUserId).toBe('user-1');
    });

    it('sets seriesId when provided', async () => {
      const returningMock = jest.fn().mockResolvedValue([{ id: 'new-plan-id' }]);
      const valuesMock = jest.fn().mockReturnValue({ returning: returningMock });
      const insertMock = jest.fn().mockReturnValue({ values: valuesMock });
      mockInternalDb.insert = insertMock;

      await service.createUserPlan('user-1', 'Series Plan', '{}', undefined, 'series-123');

      const insertedValues = valuesMock.mock.calls[0][0];
      expect(insertedValues.seriesId).toBe('series-123');
    });

    it('sets seriesId to null when not provided', async () => {
      const returningMock = jest.fn().mockResolvedValue([{ id: 'new-plan-id' }]);
      const valuesMock = jest.fn().mockReturnValue({ returning: returningMock });
      const insertMock = jest.fn().mockReturnValue({ values: valuesMock });
      mockInternalDb.insert = insertMock;

      await service.createUserPlan('user-1', 'Standalone Plan', '{}');

      const insertedValues = valuesMock.mock.calls[0][0];
      expect(insertedValues.seriesId).toBeNull();
    });
  });

  // ── POST /plans/:id/request-publish — Publish request ─────────────────────

  describe('requestPublish', () => {
    it('transitions private → pending_review for owner', async () => {
      // select().from().where().limit() for plan lookup
      const limitMock = jest.fn().mockResolvedValue([{
        id: 'plan-1',
        visibility: 'private',
        ownerUserId: 'user-1',
      }]);
      const whereMock = jest.fn().mockReturnValue({ limit: limitMock });
      const fromMock = jest.fn().mockReturnValue({ where: whereMock });
      const selectMock = jest.fn().mockReturnValue({ from: fromMock });
      mockInternalDb.select = selectMock;

      // update().set().where() for status update
      const updateWhereMock = jest.fn().mockResolvedValue(undefined);
      const setMock = jest.fn().mockReturnValue({ where: updateWhereMock });
      const updateMock = jest.fn().mockReturnValue({ set: setMock });
      mockInternalDb.update = updateMock;

      const result = await service.requestPublish('user-1', 'plan-1');

      expect(result.visibility).toBe('pending_review');
    });

    it('throws NotFoundException when plan does not exist', async () => {
      const limitMock = jest.fn().mockResolvedValue([]);
      const whereMock = jest.fn().mockReturnValue({ limit: limitMock });
      const fromMock = jest.fn().mockReturnValue({ where: whereMock });
      const selectMock = jest.fn().mockReturnValue({ from: fromMock });
      mockInternalDb.select = selectMock;

      await expect(service.requestPublish('user-1', 'nonexistent')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('throws ForbiddenException when requester is not the owner', async () => {
      const limitMock = jest.fn().mockResolvedValue([{
        id: 'plan-1',
        visibility: 'private',
        ownerUserId: 'real-owner',
      }]);
      const whereMock = jest.fn().mockReturnValue({ limit: limitMock });
      const fromMock = jest.fn().mockReturnValue({ where: whereMock });
      const selectMock = jest.fn().mockReturnValue({ from: fromMock });
      mockInternalDb.select = selectMock;

      await expect(service.requestPublish('attacker', 'plan-1')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('throws UnprocessableEntityException when plan is not private', async () => {
      const limitMock = jest.fn().mockResolvedValue([{
        id: 'plan-1',
        visibility: 'pending_review',
        ownerUserId: 'user-1',
      }]);
      const whereMock = jest.fn().mockReturnValue({ limit: limitMock });
      const fromMock = jest.fn().mockReturnValue({ where: whereMock });
      const selectMock = jest.fn().mockReturnValue({ from: fromMock });
      mockInternalDb.select = selectMock;

      await expect(service.requestPublish('user-1', 'plan-1')).rejects.toThrow(
        UnprocessableEntityException,
      );
    });

    it('throws UnprocessableEntityException for already public plan', async () => {
      const limitMock = jest.fn().mockResolvedValue([{
        id: 'plan-1',
        visibility: 'public',
        ownerUserId: 'user-1',
      }]);
      const whereMock = jest.fn().mockReturnValue({ limit: limitMock });
      const fromMock = jest.fn().mockReturnValue({ where: whereMock });
      const selectMock = jest.fn().mockReturnValue({ from: fromMock });
      mockInternalDb.select = selectMock;

      await expect(service.requestPublish('user-1', 'plan-1')).rejects.toThrow(
        UnprocessableEntityException,
      );
    });
  });

  // ── PATCH /admin/plans/:id — Admin update ─────────────────────────────────

  describe('adminUpdatePlan', () => {
    it('updates plan fields successfully', async () => {
      // select for existence check
      const limitMock = jest.fn().mockResolvedValue([{ id: 'plan-1' }]);
      const whereMock = jest.fn().mockReturnValue({ limit: limitMock });
      const fromMock = jest.fn().mockReturnValue({ where: whereMock });
      const selectMock = jest.fn().mockReturnValue({ from: fromMock });
      mockInternalDb.select = selectMock;

      // update chain
      const updateWhereMock = jest.fn().mockResolvedValue(undefined);
      const setMock = jest.fn().mockReturnValue({ where: updateWhereMock });
      const updateMock = jest.fn().mockReturnValue({ set: setMock });
      mockInternalDb.update = updateMock;

      await service.adminUpdatePlan('plan-1', {
        position: 2,
        visibility: 'public',
        isPublished: true,
      });

      // Verify update was called with the right fields
      const setArg = setMock.mock.calls[0][0];
      expect(setArg.position).toBe(2);
      expect(setArg.visibility).toBe('public');
      expect(setArg.isPublished).toBe(true);
      expect(setArg.updatedAt).toBeInstanceOf(Date);
    });

    it('throws NotFoundException when plan does not exist', async () => {
      const limitMock = jest.fn().mockResolvedValue([]);
      const whereMock = jest.fn().mockReturnValue({ limit: limitMock });
      const fromMock = jest.fn().mockReturnValue({ where: whereMock });
      const selectMock = jest.fn().mockReturnValue({ from: fromMock });
      mockInternalDb.select = selectMock;

      await expect(
        service.adminUpdatePlan('nonexistent', { position: 0 }),
      ).rejects.toThrow(NotFoundException);
    });

    it('rejects with 422 if depth exceeds 3 when setting parent_plan_id', async () => {
      // select for existence check
      const limitMock = jest.fn().mockResolvedValue([{ id: 'plan-deep' }]);
      const whereMock = jest.fn().mockReturnValue({ limit: limitMock });
      const fromMock = jest.fn().mockReturnValue({ where: whereMock });
      const selectMock = jest.fn().mockReturnValue({ from: fromMock });
      mockInternalDb.select = selectMock;

      // Mock execute for validateDepth:
      // ancestor CTE (parent is already at depth 3)
      mockInternalDb.execute = jest.fn()
        .mockResolvedValueOnce({ rows: [{ max_depth: 3 }] })   // ancestors: parent is at depth 3
        .mockResolvedValueOnce({ rows: [{ max_depth: 1 }] });  // descendants: plan has 1 level of children

      await expect(
        service.adminUpdatePlan('plan-deep', { parentPlanId: 'deep-parent' }),
      ).rejects.toThrow(UnprocessableEntityException);
    });

    it('allows setting parent_plan_id when depth is within limit', async () => {
      // select for existence check
      const limitMock = jest.fn().mockResolvedValue([{ id: 'plan-ok' }]);
      const whereMock = jest.fn().mockReturnValue({ limit: limitMock });
      const fromMock = jest.fn().mockReturnValue({ where: whereMock });
      const selectMock = jest.fn().mockReturnValue({ from: fromMock });
      mockInternalDb.select = selectMock;

      // Mock execute for validateDepth:
      // ancestor CTE (parent is at depth 1 = root level)
      mockInternalDb.execute = jest.fn()
        .mockResolvedValueOnce({ rows: [{ max_depth: 1 }] })   // ancestors: parent is root
        .mockResolvedValueOnce({ rows: [{ max_depth: 0 }] });  // descendants: plan has no children

      // update chain
      const updateWhereMock = jest.fn().mockResolvedValue(undefined);
      const setMock = jest.fn().mockReturnValue({ where: updateWhereMock });
      const updateMock = jest.fn().mockReturnValue({ set: setMock });
      mockInternalDb.update = updateMock;

      // Total depth = 1 (ancestor) + 1 (plan) + 0 (descendants) = 2 ≤ 3
      await expect(
        service.adminUpdatePlan('plan-ok', { parentPlanId: 'root-parent' }),
      ).resolves.not.toThrow();
    });

    it('allows setting parent_plan_id to null (move to top level)', async () => {
      // select for existence check
      const limitMock = jest.fn().mockResolvedValue([{ id: 'plan-move' }]);
      const whereMock = jest.fn().mockReturnValue({ limit: limitMock });
      const fromMock = jest.fn().mockReturnValue({ where: whereMock });
      const selectMock = jest.fn().mockReturnValue({ from: fromMock });
      mockInternalDb.select = selectMock;

      // update chain
      const updateWhereMock = jest.fn().mockResolvedValue(undefined);
      const setMock = jest.fn().mockReturnValue({ where: updateWhereMock });
      const updateMock = jest.fn().mockReturnValue({ set: setMock });
      mockInternalDb.update = updateMock;

      // null parent — should NOT trigger validateDepth
      await service.adminUpdatePlan('plan-move', { parentPlanId: null });

      const setArg = setMock.mock.calls[0][0];
      expect(setArg.parentPlanId).toBeNull();
    });
  });

  // ── Depth validation ──────────────────────────────────────────────────────

  describe('validateDepth', () => {
    it('throws when total depth would be exactly 4 (exceeds 3)', async () => {
      // Parent at depth 2, plan has 1 level of children
      // Total = 2 + 1 + 1 = 4 > 3
      mockInternalDb.execute = jest.fn()
        .mockResolvedValueOnce({ rows: [{ max_depth: 2 }] })
        .mockResolvedValueOnce({ rows: [{ max_depth: 1 }] });

      await expect(
        service.validateDepth('plan-1', 'parent-1'),
      ).rejects.toThrow(UnprocessableEntityException);
    });

    it('passes when total depth is exactly 3', async () => {
      // Parent at depth 1, plan has 1 level of children
      // Total = 1 + 1 + 1 = 3 ≤ 3
      mockInternalDb.execute = jest.fn()
        .mockResolvedValueOnce({ rows: [{ max_depth: 1 }] })
        .mockResolvedValueOnce({ rows: [{ max_depth: 1 }] });

      await expect(
        service.validateDepth('plan-1', 'parent-1'),
      ).resolves.not.toThrow();
    });

    it('passes for a leaf plan under a root parent', async () => {
      // Parent at depth 1 (root), plan has no children
      // Total = 1 + 1 + 0 = 2 ≤ 3
      mockInternalDb.execute = jest.fn()
        .mockResolvedValueOnce({ rows: [{ max_depth: 1 }] })
        .mockResolvedValueOnce({ rows: [{ max_depth: 0 }] });

      await expect(
        service.validateDepth('leaf-plan', 'root-parent'),
      ).resolves.not.toThrow();
    });

    it('throws NotFoundException when parent plan does not exist', async () => {
      // ancestorDepth = 0 means parent not found
      mockInternalDb.execute = jest.fn()
        .mockResolvedValueOnce({ rows: [{ max_depth: 0 }] });

      await expect(
        service.validateDepth('plan-1', 'nonexistent-parent'),
      ).rejects.toThrow(NotFoundException);
    });
  });
});
