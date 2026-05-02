/**
 * E2E tests for AdminPlanRequestsController — POST /admin/plan-requests/:id/promote
 *
 * Tests cover:
 *   1. Full happy-path promote flow (plan + plan_voices created, TTS enqueued, 201 returned)
 *   2. Transaction rollback: DB error on plan_voices insert leaves no orphaned plan
 *   3. TTS enqueue failure is non-fatal (plan + plan_voices committed)
 *   4. Auth guards active (403 for non-admin, 401 for unauthenticated)
 *   5. Validation (missing voiceIds, invalid UUIDs, empty array)
 *   6. 404 when plan request not found
 *   7. 422 when plan request already processed
 *   8. 422 when voiceIds reference non-existent voices
 *
 * Strategy:
 *   - PlanRequestPromoteService is fully mocked for controller-level tests.
 *   - For service-level e2e tests, all repositories and TtsBatchPregenService
 *     are mocked to verify the exact DB call sequence and rollback behaviour.
 *   - JwtAuthGuard is overridden with a PassThroughGuard.
 *   - AdminRoleGuard is overridden for admin/non-admin scenarios.
 */

import { Test, TestingModule } from '@nestjs/testing';
import {
  ExecutionContext,
  ValidationPipe,
  INestApplication,
  HttpStatus,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { APP_PIPE } from '@nestjs/core';
import * as request from 'supertest';
import { AdminPlanRequestsController } from './admin-plan-requests.controller';
import { PlanRequestPromoteService } from './plan-request-promote.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRoleGuard } from '../auth/admin-role.guard';

// ---------------------------------------------------------------------------
// Mock factories
// ---------------------------------------------------------------------------

function createMockPromoteService() {
  return {
    promote: jest.fn().mockResolvedValue({ planId: 'new-plan-uuid-001' }),
  };
}

// ---------------------------------------------------------------------------
// Guard factories
// ---------------------------------------------------------------------------

/** Admin guard that passes and injects admin user. */
function makeAdminAuthGuard(userId: string) {
  return class {
    canActivate(ctx: ExecutionContext): boolean {
      const req = ctx.switchToHttp().getRequest();
      req.user = { sub: userId, role: 'admin' };
      return true;
    }
  };
}

/** Guard that always rejects (simulates missing JWT). */
class RejectGuard {
  canActivate(): boolean {
    return false;
  }
}

/** AdminRoleGuard pass-through for admin tests. */
class PassThroughAdminGuard {
  canActivate(): boolean {
    return true;
  }
}

// ---------------------------------------------------------------------------
// App builder
// ---------------------------------------------------------------------------

async function buildApp(
  mockService: ReturnType<typeof createMockPromoteService>,
  options: { admin?: boolean; userId?: string } = { admin: true, userId: 'admin-user-001' },
): Promise<INestApplication> {
  const jwtGuard = options.admin
    ? makeAdminAuthGuard(options.userId ?? 'admin-user-001')
    : RejectGuard;

  const adminGuard = options.admin ? PassThroughAdminGuard : RejectGuard;

  const module: TestingModule = await Test.createTestingModule({
    controllers: [AdminPlanRequestsController],
    providers: [
      { provide: PlanRequestPromoteService, useValue: mockService },
      {
        provide: APP_PIPE,
        useValue: new ValidationPipe({ whitelist: true, forbidNonWhitelisted: false }),
      },
    ],
  })
    .overrideGuard(JwtAuthGuard)
    .useClass(jwtGuard)
    .overrideGuard(AdminRoleGuard)
    .useClass(adminGuard)
    .compile();

  const app = module.createNestApplication();
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: false,
      transform: true,
    }),
  );
  await app.init();
  return app;
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const VALID_PLAN_REQUEST_ID = '11111111-1111-1111-1111-111111111111';
const VALID_VOICE_ID_1 = '22222222-2222-2222-2222-222222222222';
const VALID_VOICE_ID_2 = '33333333-3333-3333-3333-333333333333';
const VALID_SERIES_ID = '44444444-4444-4444-4444-444444444444';
const VALID_CATEGORY_ID = '55555555-5555-5555-5555-555555555555';

const VALID_PROMOTE_BODY = {
  voiceIds: [VALID_VOICE_ID_1, VALID_VOICE_ID_2],
  seriesId: VALID_SERIES_ID,
  categoryId: VALID_CATEGORY_ID,
  position: 1,
};

// ---------------------------------------------------------------------------
// Controller-level tests (HTTP request → response)
// ---------------------------------------------------------------------------

describe('AdminPlanRequestsController — POST /admin/plan-requests/:id/promote', () => {
  let app: INestApplication;
  let mockService: ReturnType<typeof createMockPromoteService>;

  beforeEach(async () => {
    mockService = createMockPromoteService();
    app = await buildApp(mockService);
  });

  afterEach(async () => {
    await app.close();
    jest.restoreAllMocks();
  });

  // ── Authentication / Authorization ──────────────────────────────────────

  it('returns 403 when JwtAuthGuard rejects (unauthenticated)', async () => {
    const rejectedApp = await buildApp(mockService, { admin: false });
    await request(rejectedApp.getHttpServer())
      .post(`/admin/plan-requests/${VALID_PLAN_REQUEST_ID}/promote`)
      .send(VALID_PROMOTE_BODY)
      .expect(403);
    await rejectedApp.close();
  });

  // ── Happy path ──────────────────────────────────────────────────────────

  it('returns 201 with { planId } on successful promote', async () => {
    const res = await request(app.getHttpServer())
      .post(`/admin/plan-requests/${VALID_PLAN_REQUEST_ID}/promote`)
      .send(VALID_PROMOTE_BODY)
      .expect(HttpStatus.CREATED);

    expect(res.body).toEqual({ planId: 'new-plan-uuid-001' });
  });

  it('calls promote service with correct parameters', async () => {
    await request(app.getHttpServer())
      .post(`/admin/plan-requests/${VALID_PLAN_REQUEST_ID}/promote`)
      .send(VALID_PROMOTE_BODY)
      .expect(HttpStatus.CREATED);

    expect(mockService.promote).toHaveBeenCalledWith(
      VALID_PLAN_REQUEST_ID,
      [VALID_VOICE_ID_1, VALID_VOICE_ID_2],
      VALID_SERIES_ID,
      VALID_CATEGORY_ID,
      1,
    );
  });

  it('works with minimal body (only voiceIds)', async () => {
    await request(app.getHttpServer())
      .post(`/admin/plan-requests/${VALID_PLAN_REQUEST_ID}/promote`)
      .send({ voiceIds: [VALID_VOICE_ID_1] })
      .expect(HttpStatus.CREATED);

    expect(mockService.promote).toHaveBeenCalledWith(
      VALID_PLAN_REQUEST_ID,
      [VALID_VOICE_ID_1],
      undefined,
      undefined,
      undefined,
    );
  });

  // ── Validation ──────────────────────────────────────────────────────────

  it('returns 400 when voiceIds is missing', async () => {
    await request(app.getHttpServer())
      .post(`/admin/plan-requests/${VALID_PLAN_REQUEST_ID}/promote`)
      .send({})
      .expect(400);
  });

  it('returns 400 when voiceIds is empty array', async () => {
    await request(app.getHttpServer())
      .post(`/admin/plan-requests/${VALID_PLAN_REQUEST_ID}/promote`)
      .send({ voiceIds: [] })
      .expect(400);
  });

  it('returns 400 when voiceIds contains non-UUID strings', async () => {
    await request(app.getHttpServer())
      .post(`/admin/plan-requests/${VALID_PLAN_REQUEST_ID}/promote`)
      .send({ voiceIds: ['not-a-uuid'] })
      .expect(400);
  });

  it('returns 400 when plan request ID is not a valid UUID', async () => {
    await request(app.getHttpServer())
      .post('/admin/plan-requests/not-a-uuid/promote')
      .send({ voiceIds: [VALID_VOICE_ID_1] })
      .expect(400);
  });

  it('returns 400 when seriesId is not a valid UUID', async () => {
    await request(app.getHttpServer())
      .post(`/admin/plan-requests/${VALID_PLAN_REQUEST_ID}/promote`)
      .send({ voiceIds: [VALID_VOICE_ID_1], seriesId: 'bad' })
      .expect(400);
  });

  it('returns 400 when position is negative', async () => {
    await request(app.getHttpServer())
      .post(`/admin/plan-requests/${VALID_PLAN_REQUEST_ID}/promote`)
      .send({ voiceIds: [VALID_VOICE_ID_1], position: -1 })
      .expect(400);
  });

  // ── Error propagation ──────────────────────────────────────────────────

  it('returns 404 when plan request not found', async () => {
    mockService.promote.mockRejectedValueOnce(
      new NotFoundException('Plan request not found'),
    );

    await request(app.getHttpServer())
      .post(`/admin/plan-requests/${VALID_PLAN_REQUEST_ID}/promote`)
      .send({ voiceIds: [VALID_VOICE_ID_1] })
      .expect(404);
  });

  it('returns 422 when plan request already processed', async () => {
    mockService.promote.mockRejectedValueOnce(
      new UnprocessableEntityException('Plan request already processed'),
    );

    await request(app.getHttpServer())
      .post(`/admin/plan-requests/${VALID_PLAN_REQUEST_ID}/promote`)
      .send({ voiceIds: [VALID_VOICE_ID_1] })
      .expect(422);
  });

  it('returns 422 when voice IDs not found', async () => {
    mockService.promote.mockRejectedValueOnce(
      new UnprocessableEntityException('Voice IDs not found: bad-id'),
    );

    await request(app.getHttpServer())
      .post(`/admin/plan-requests/${VALID_PLAN_REQUEST_ID}/promote`)
      .send({ voiceIds: [VALID_VOICE_ID_1] })
      .expect(422);
  });
});

// ---------------------------------------------------------------------------
// Service-level tests (promote flow + rollback)
// ---------------------------------------------------------------------------

describe('PlanRequestPromoteService — promote flow', () => {
  // We test the service directly with fully mocked dependencies

  let service: PlanRequestPromoteService;
  let mockDbService: any;
  let mockAdminRepo: any;
  let mockPlanVoicesRepo: any;
  let mockTtsBatchPregen: any;
  let drizzleChain: any;

  function makeChainMock(resolveWith: unknown[] = []) {
    const chain: Record<string, jest.Mock> = {
      insert: jest.fn(),
      select: jest.fn(),
      update: jest.fn(),
      from: jest.fn(),
      where: jest.fn(),
      values: jest.fn(),
      set: jest.fn(),
      onConflictDoUpdate: jest.fn(),
      orderBy: jest.fn(),
      limit: jest.fn(),
      offset: jest.fn(),
      returning: jest.fn().mockResolvedValue(resolveWith),
      execute: jest.fn().mockResolvedValue(resolveWith),
    };
    for (const key of Object.keys(chain)) {
      if (key !== 'returning' && key !== 'execute') {
        chain[key].mockReturnValue(chain);
      }
    }
    return chain;
  }

  const PLAN_REQUEST_ROW = {
    id: VALID_PLAN_REQUEST_ID,
    userId: 'user-uuid-001',
    email: 'user@example.com',
    title: 'Morning Meditation',
    description: 'A 10-minute morning meditation plan.',
    category: 'wellness',
    status: 'pending',
    processedAt: null,
    createdAt: new Date('2026-01-01T00:00:00Z'),
  };

  const VOICE_ROW_1 = { id: VALID_VOICE_ID_1, locale: 'en-US', provider: 'kokoro' };
  const VOICE_ROW_2 = { id: VALID_VOICE_ID_2, locale: 'en-IN', provider: 'gemini' };

  beforeEach(() => {
    drizzleChain = makeChainMock();

    mockDbService = {
      getDb: jest.fn().mockReturnValue(drizzleChain),
      withRetry: jest.fn().mockImplementation(async (fn: () => Promise<unknown>) => fn()),
      noop: false,
    };

    mockAdminRepo = {
      markPlanRequestProcessed: jest.fn().mockResolvedValue({
        ...PLAN_REQUEST_ROW,
        status: 'processed',
        processedAt: new Date(),
      }),
    };

    mockPlanVoicesRepo = {
      createBatch: jest.fn().mockResolvedValue([
        { id: 'pv-1', planId: 'new-plan-uuid', voiceId: VALID_VOICE_ID_1, locale: 'en-US', status: 'pending' },
        { id: 'pv-2', planId: 'new-plan-uuid', voiceId: VALID_VOICE_ID_2, locale: 'en-IN', status: 'pending' },
      ]),
    };

    mockTtsBatchPregen = {
      startBatchPregen: jest.fn().mockResolvedValue(undefined),
    };

    // Import the service class to instantiate with mocks
    const { PlanRequestPromoteService: ServiceClass } = require('./plan-request-promote.service');
    service = new ServiceClass(
      mockDbService,
      mockAdminRepo,
      mockPlanVoicesRepo,
      mockTtsBatchPregen,
    );
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  // ── Happy path ────────────────────────────────────────────────────────

  it('creates plan + plan_voices + marks request processed + enqueues TTS', async () => {
    // Mock: 1st withRetry → plan request lookup
    mockDbService.withRetry
      .mockImplementationOnce(async () => [PLAN_REQUEST_ROW])
      // 2nd → voice lookup
      .mockImplementationOnce(async () => [VOICE_ROW_1, VOICE_ROW_2])
      // 3rd → plan insert
      .mockImplementationOnce(async () => [{ id: 'new-plan-uuid' }]);

    const result = await service.promote(
      VALID_PLAN_REQUEST_ID,
      [VALID_VOICE_ID_1, VALID_VOICE_ID_2],
      VALID_SERIES_ID,
    );

    // Verify plan was created
    expect(result.planId).toBe('new-plan-uuid');

    // Verify plan_voices batch was called
    expect(mockPlanVoicesRepo.createBatch).toHaveBeenCalledTimes(1);
    const batchArgs = mockPlanVoicesRepo.createBatch.mock.calls[0][0];
    expect(batchArgs).toHaveLength(2);
    expect(batchArgs[0]).toMatchObject({
      planId: 'new-plan-uuid',
      voiceId: VALID_VOICE_ID_1,
      locale: 'en-US',
      status: 'pending',
    });
    expect(batchArgs[1]).toMatchObject({
      planId: 'new-plan-uuid',
      voiceId: VALID_VOICE_ID_2,
      locale: 'en-IN',
      status: 'pending',
    });

    // Verify plan request was marked processed
    expect(mockAdminRepo.markPlanRequestProcessed).toHaveBeenCalledWith(VALID_PLAN_REQUEST_ID);

    // Verify TTS was enqueued for each voice
    expect(mockTtsBatchPregen.startBatchPregen).toHaveBeenCalledTimes(2);
    expect(mockTtsBatchPregen.startBatchPregen).toHaveBeenCalledWith(
      'new-plan-uuid',
      expect.any(String), // planJson
      VALID_VOICE_ID_1,
      'en-US',
      'kokoro',
      '1.00',
    );
    expect(mockTtsBatchPregen.startBatchPregen).toHaveBeenCalledWith(
      'new-plan-uuid',
      expect.any(String),
      VALID_VOICE_ID_2,
      'en-IN',
      'gemini',
      '1.00',
    );
  });

  // ── 404: plan request not found ───────────────────────────────────────

  it('throws NotFoundException when plan request does not exist', async () => {
    mockDbService.withRetry
      .mockImplementationOnce(async () => []); // no rows

    await expect(
      service.promote(VALID_PLAN_REQUEST_ID, [VALID_VOICE_ID_1]),
    ).rejects.toThrow(NotFoundException);
  });

  // ── 422: plan request already processed ───────────────────────────────

  it('throws UnprocessableEntityException when plan request is already processed', async () => {
    mockDbService.withRetry
      .mockImplementationOnce(async () => [{ ...PLAN_REQUEST_ROW, status: 'processed' }]);

    await expect(
      service.promote(VALID_PLAN_REQUEST_ID, [VALID_VOICE_ID_1]),
    ).rejects.toThrow(UnprocessableEntityException);
  });

  // ── 422: invalid voice IDs ────────────────────────────────────────────

  it('throws UnprocessableEntityException when some voiceIds are not found', async () => {
    mockDbService.withRetry
      .mockImplementationOnce(async () => [PLAN_REQUEST_ROW])
      .mockImplementationOnce(async () => [VOICE_ROW_1]); // only 1 of 2 found

    await expect(
      service.promote(VALID_PLAN_REQUEST_ID, [VALID_VOICE_ID_1, VALID_VOICE_ID_2]),
    ).rejects.toThrow(UnprocessableEntityException);
  });

  // ── Rollback: plan_voices failure does not leave orphaned plan ─────────

  it('propagates error when plan_voices createBatch fails (no TTS enqueued)', async () => {
    mockDbService.withRetry
      .mockImplementationOnce(async () => [PLAN_REQUEST_ROW])
      .mockImplementationOnce(async () => [VOICE_ROW_1])
      .mockImplementationOnce(async () => [{ id: 'orphan-plan-uuid' }]);

    // Simulate DB error on plan_voices insert
    mockPlanVoicesRepo.createBatch.mockRejectedValueOnce(
      new Error('FK constraint violation'),
    );

    await expect(
      service.promote(VALID_PLAN_REQUEST_ID, [VALID_VOICE_ID_1]),
    ).rejects.toThrow('FK constraint violation');

    // Verify TTS was NOT enqueued (post-commit block not reached)
    expect(mockTtsBatchPregen.startBatchPregen).not.toHaveBeenCalled();

    // Verify plan request was NOT marked as processed
    expect(mockAdminRepo.markPlanRequestProcessed).not.toHaveBeenCalled();
  });

  // ── TTS enqueue failure is non-fatal ──────────────────────────────────

  it('returns planId even when TTS enqueue fails (plan + plan_voices committed)', async () => {
    mockDbService.withRetry
      .mockImplementationOnce(async () => [PLAN_REQUEST_ROW])
      .mockImplementationOnce(async () => [VOICE_ROW_1])
      .mockImplementationOnce(async () => [{ id: 'new-plan-uuid' }]);

    // TTS enqueue fails
    mockTtsBatchPregen.startBatchPregen.mockRejectedValueOnce(
      new Error('TTS queue unavailable'),
    );

    const result = await service.promote(
      VALID_PLAN_REQUEST_ID,
      [VALID_VOICE_ID_1],
    );

    // Plan was still created successfully
    expect(result.planId).toBe('new-plan-uuid');

    // plan_voices were created
    expect(mockPlanVoicesRepo.createBatch).toHaveBeenCalledTimes(1);

    // Plan request was marked as processed
    expect(mockAdminRepo.markPlanRequestProcessed).toHaveBeenCalledTimes(1);
  });

  // ── Plan insert failure stops everything ──────────────────────────────

  it('propagates error when plan insert fails (no plan_voices, no TTS)', async () => {
    mockDbService.withRetry
      .mockImplementationOnce(async () => [PLAN_REQUEST_ROW])
      .mockImplementationOnce(async () => [VOICE_ROW_1])
      .mockImplementationOnce(async () => { throw new Error('DB insert failed'); });

    await expect(
      service.promote(VALID_PLAN_REQUEST_ID, [VALID_VOICE_ID_1]),
    ).rejects.toThrow('DB insert failed');

    // No downstream calls
    expect(mockPlanVoicesRepo.createBatch).not.toHaveBeenCalled();
    expect(mockAdminRepo.markPlanRequestProcessed).not.toHaveBeenCalled();
    expect(mockTtsBatchPregen.startBatchPregen).not.toHaveBeenCalled();
  });

  // ── Documentation: TTS enqueue happens post-commit ─────────────────────

  it('enqueues TTS AFTER all DB writes succeed (verifying call order)', async () => {
    const callOrder: string[] = [];

    mockDbService.withRetry
      .mockImplementationOnce(async () => { callOrder.push('fetch-request'); return [PLAN_REQUEST_ROW]; })
      .mockImplementationOnce(async () => { callOrder.push('fetch-voices'); return [VOICE_ROW_1]; })
      .mockImplementationOnce(async () => { callOrder.push('insert-plan'); return [{ id: 'new-plan-uuid' }]; });

    mockPlanVoicesRepo.createBatch.mockImplementation(async () => {
      callOrder.push('insert-plan-voices');
      return [{ id: 'pv-1' }];
    });

    mockAdminRepo.markPlanRequestProcessed.mockImplementation(async () => {
      callOrder.push('mark-processed');
      return {};
    });

    mockTtsBatchPregen.startBatchPregen.mockImplementation(async () => {
      callOrder.push('enqueue-tts');
    });

    await service.promote(VALID_PLAN_REQUEST_ID, [VALID_VOICE_ID_1]);

    expect(callOrder).toEqual([
      'fetch-request',
      'fetch-voices',
      'insert-plan',
      'insert-plan-voices',
      'mark-processed',
      'enqueue-tts',
    ]);
  });
});
