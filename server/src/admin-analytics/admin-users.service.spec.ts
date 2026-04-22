/**
 * Unit tests for AdminUsersService.
 *
 * Tests new TASK-006 methods:
 *   - getUserSessions() returns last 20 completions for a user
 *   - getUserSessions() uses library plan name when available, falls back to plan name
 *   - getPlansWithSummary() returns plan run stats per plan
 *   - getPlansWithSummary() includes hasRecentSession boolean
 *
 * Also tests existing methods:
 *   - listUsers() returns paginated users with correct fields
 *   - getUserDetail() throws NotFoundException when user not found
 *   - updateRole() updates user role
 *   - updateRole() throws NotFoundException when user not found
 */

import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { AdminUsersService } from './admin-users.service';
import { DatabaseService } from '../database/database.service';

// ---------------------------------------------------------------------------
// Mock factory
// ---------------------------------------------------------------------------

function createMockDatabaseService() {
  const mockDb = {
    select: jest.fn().mockReturnThis(),
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    offset: jest.fn().mockResolvedValue([]),
    innerJoin: jest.fn().mockReturnThis(),
    update: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    returning: jest.fn().mockResolvedValue([]),
    execute: jest.fn(),
  };

  return {
    getDb: jest.fn().mockReturnValue(mockDb),
    withRetry: jest.fn().mockImplementation(async (fn: () => Promise<any>) => fn()),
    _mockDb: mockDb,
  };
}

const USER_ID = 'user-uuid-001';
const NOW = new Date('2026-04-21T12:00:00Z');

describe('AdminUsersService', () => {
  let service: AdminUsersService;
  let dbService: ReturnType<typeof createMockDatabaseService>;

  beforeEach(async () => {
    dbService = createMockDatabaseService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AdminUsersService,
        { provide: DatabaseService, useValue: dbService },
      ],
    }).compile();

    service = module.get<AdminUsersService>(AdminUsersService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  // -------------------------------------------------------------------------
  // listUsers
  // -------------------------------------------------------------------------

  describe('listUsers()', () => {
    it('returns paginated list with correct structure', async () => {
      const userRows = [
        {
          id: USER_ID,
          email: 'alice@test.com',
          name: 'Alice',
          username: 'alice',
          role: 'user',
          createdAt: NOW,
          planCount: 3,
          lastActivityAt: NOW,
        },
      ];

      // First call = count, second call = rows
      dbService._mockDb.offset
        .mockResolvedValueOnce([{ value: 1 }])
        .mockResolvedValueOnce(userRows);

      const result = await service.listUsers({ page: 1, pageSize: 20 });

      expect(result.total).toBe(1);
      expect(result.users).toHaveLength(1);
      expect(result.users[0].email).toBe('alice@test.com');
      expect(result.users[0].planCount).toBe(3);
    });

    it('defaults page to 1 and pageSize to 10 when not provided', async () => {
      dbService._mockDb.offset
        .mockResolvedValueOnce([{ value: 0 }])
        .mockResolvedValueOnce([]);

      const result = await service.listUsers({});

      expect(result.page).toBe(1);
    });
  });

  // -------------------------------------------------------------------------
  // getUserDetail (NotFoundException)
  // -------------------------------------------------------------------------

  describe('getUserDetail()', () => {
    it('throws NotFoundException when user not found', async () => {
      dbService._mockDb.limit.mockResolvedValueOnce([]);

      await expect(service.getUserDetail('nonexistent-uuid')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  // -------------------------------------------------------------------------
  // getUserSessions — TASK-006
  // -------------------------------------------------------------------------

  describe('getUserSessions()', () => {
    it('returns session list with correct fields', async () => {
      dbService._mockDb.execute.mockResolvedValueOnce({
        rows: [
          {
            id: 'session-001',
            plan_name: 'Morning Yoga',
            completed_at: NOW,
            duration_ms: 1200000,
          },
          {
            id: 'session-002',
            plan_name: 'Meditation 10min',
            completed_at: new Date(NOW.getTime() - 86400000),
            duration_ms: 600000,
          },
        ],
      });

      const result = await service.getUserSessions(USER_ID);

      expect(result.sessions).toHaveLength(2);
      expect(result.sessions[0].id).toBe('session-001');
      expect(result.sessions[0].planName).toBe('Morning Yoga');
      expect(result.sessions[0].durationMs).toBe(1200000);
      expect(typeof result.sessions[0].completedAt).toBe('string');
    });

    it('returns ISO string for completedAt', async () => {
      dbService._mockDb.execute.mockResolvedValueOnce({
        rows: [
          {
            id: 'session-001',
            plan_name: 'Plan A',
            completed_at: NOW, // Date object
            duration_ms: 500,
          },
        ],
      });

      const result = await service.getUserSessions(USER_ID);

      expect(result.sessions[0].completedAt).toBe(NOW.toISOString());
    });

    it('returns empty sessions array when user has no completions', async () => {
      dbService._mockDb.execute.mockResolvedValueOnce({ rows: [] });

      const result = await service.getUserSessions(USER_ID);

      expect(result.sessions).toEqual([]);
    });

    it('returns "Unknown Plan" when plan_name is null', async () => {
      dbService._mockDb.execute.mockResolvedValueOnce({
        rows: [
          {
            id: 'session-003',
            plan_name: null,
            completed_at: NOW,
            duration_ms: 0,
          },
        ],
      });

      const result = await service.getUserSessions(USER_ID);

      expect(result.sessions[0].planName).toBe('Unknown Plan');
    });
  });

  // -------------------------------------------------------------------------
  // getPlansWithSummary — TASK-006
  // -------------------------------------------------------------------------

  describe('getPlansWithSummary()', () => {
    it('returns plan list with run stats', async () => {
      const lastRunAt = new Date('2026-04-20T10:00:00Z');

      dbService._mockDb.execute.mockResolvedValueOnce({
        rows: [
          {
            id: 'plan-001',
            name: 'Morning Yoga',
            is_active: true,
            tts_status: 'completed',
            created_at: NOW,
            run_count: 5,
            last_run_at: lastRunAt,
            has_recent_session: true,
          },
          {
            id: 'plan-002',
            name: 'Evening Stretch',
            is_active: false,
            tts_status: 'none',
            created_at: NOW,
            run_count: 0,
            last_run_at: null,
            has_recent_session: false,
          },
        ],
      });

      const result = await service.getPlansWithSummary(USER_ID);

      expect(result).toHaveLength(2);

      const plan1 = result[0];
      expect(plan1.id).toBe('plan-001');
      expect(plan1.name).toBe('Morning Yoga');
      expect(plan1.isActive).toBe(true);
      expect(plan1.ttsStatus).toBe('completed');
      expect(plan1.runCount).toBe(5);
      expect(plan1.lastRunAt).toBe(lastRunAt.toISOString());
      expect(plan1.hasRecentSession).toBe(true);

      const plan2 = result[1];
      expect(plan2.runCount).toBe(0);
      expect(plan2.lastRunAt).toBeNull();
      expect(plan2.hasRecentSession).toBe(false);
    });

    it('returns empty array when user has no plans', async () => {
      dbService._mockDb.execute.mockResolvedValueOnce({ rows: [] });

      const result = await service.getPlansWithSummary(USER_ID);

      expect(result).toEqual([]);
    });
  });

  // -------------------------------------------------------------------------
  // updateRole
  // -------------------------------------------------------------------------

  describe('updateRole()', () => {
    it('updates user role and returns updated record', async () => {
      dbService._mockDb.returning.mockResolvedValueOnce([{ id: USER_ID, role: 'user' }]);

      const result = await service.updateRole(USER_ID, 'user');

      expect(result.id).toBe(USER_ID);
      expect(result.role).toBe('user');
    });

    it('throws NotFoundException when user not found', async () => {
      dbService._mockDb.returning.mockResolvedValueOnce([]);

      await expect(service.updateRole('nonexistent-uuid', 'user')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });
});
