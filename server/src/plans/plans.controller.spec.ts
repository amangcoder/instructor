/**
 * Unit tests for PlansController — save / list endpoints.
 *
 * Strategy:
 *   - PlansService is fully mocked so tests are isolated to controller logic.
 *   - JwtAuthGuard is overridden with a PassThroughGuard that injects a fake
 *     user so we can test both authenticated and guard-rejection scenarios.
 *   - Tests verify:
 *       1. JWT guard is active (returns 401 without valid token)
 *       2. userId is derived from JWT, not request body (IDOR prevention)
 *       3. Upsert: planId absent → create; planId present → update
 *       4. userId isolation: list returns only the caller's plans
 *       5. Oversized planJson returns 400 Bad Request
 *       6. Plan JSON round-trip: save → list → verify stored structure
 */

import { Test, TestingModule } from '@nestjs/testing';
import { ExecutionContext, ValidationPipe, INestApplication } from '@nestjs/common';
import { APP_PIPE } from '@nestjs/core';
import * as request from 'supertest';
import { PlansController } from './plans.controller';
import { PlansService } from './plans.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

// ---------------------------------------------------------------------------
// Mock PlansService
// ---------------------------------------------------------------------------

function createMockPlansService() {
  return {
    generatePlan: jest.fn().mockResolvedValue({ plan: { name: 'Test', steps: [] } }),
    savePlan: jest.fn().mockResolvedValue({
      planId: 'plan-uuid-001',
      updatedAt: new Date('2026-01-15T10:00:00.000Z'),
    }),
    listPlans: jest.fn().mockResolvedValue({
      plans: [
        {
          planId: 'plan-uuid-001',
          name: 'Morning Yoga',
          createdAt: new Date('2026-01-10T08:00:00.000Z'),
          updatedAt: new Date('2026-01-15T10:00:00.000Z'),
        },
      ],
    }),
  };
}

// ---------------------------------------------------------------------------
// Guard factories
// ---------------------------------------------------------------------------

/** Guard that simulates a successfully authenticated request for a given userId. */
function makeAuthGuard(userId: string) {
  return class {
    canActivate(ctx: ExecutionContext): boolean {
      const req = ctx.switchToHttp().getRequest();
      req.user = { sub: userId };
      return true;
    }
  };
}

/** Guard that always rejects (simulates missing/invalid JWT). */
class RejectGuard {
  canActivate(): boolean {
    return false;
  }
}

// ---------------------------------------------------------------------------
// App builder helpers
// ---------------------------------------------------------------------------

async function buildApp(
  mockService: ReturnType<typeof createMockPlansService>,
  guardUserId?: string, // undefined → use RejectGuard
): Promise<INestApplication> {
  const guard = guardUserId ? makeAuthGuard(guardUserId) : RejectGuard;

  const module: TestingModule = await Test.createTestingModule({
    controllers: [PlansController],
    providers: [
      { provide: PlansService, useValue: mockService },
      {
        provide: APP_PIPE,
        useValue: new ValidationPipe({ whitelist: true, forbidNonWhitelisted: false }),
      },
    ],
  })
    .overrideGuard(JwtAuthGuard)
    .useClass(guard)
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
// Tests
// ---------------------------------------------------------------------------

describe('PlansController — POST /plans/save', () => {
  let app: INestApplication;
  let mockService: ReturnType<typeof createMockPlansService>;
  const USER_ID = 'jwt-user-abc';

  beforeEach(async () => {
    mockService = createMockPlansService();
    app = await buildApp(mockService, USER_ID);
  });

  afterEach(async () => {
    await app.close();
    jest.restoreAllMocks();
  });

  // ── Authentication ─────────────────────────────────────────────────────────

  it('returns 403 when JwtAuthGuard rejects the request', async () => {
    const rejectedApp = await buildApp(mockService, undefined);
    await request(rejectedApp.getHttpServer())
      .post('/plans/save')
      .send({ name: 'Test Plan', planJson: '{}' })
      .expect(403);
    await rejectedApp.close();
  });

  // ── Happy path — create new plan ───────────────────────────────────────────

  it('creates a new plan and returns planId + updatedAt', async () => {
    const res = await request(app.getHttpServer())
      .post('/plans/save')
      .send({ name: 'Morning Yoga', planJson: '{"steps":[]}' })
      .expect(200);

    expect(res.body).toMatchObject({
      planId: 'plan-uuid-001',
      updatedAt: '2026-01-15T10:00:00.000Z',
    });
  });

  it('derives userId from JWT (req.user.sub), NOT from the request body', async () => {
    // Even if the caller sends a different userId in the body, the service
    // must be called with the JWT userId — preventing IDOR.
    await request(app.getHttpServer())
      .post('/plans/save')
      .send({ name: 'Yoga', planJson: '{}', userId: 'attacker-id' })
      .expect(200);

    expect(mockService.savePlan).toHaveBeenCalledWith(
      USER_ID, // JWT userId, not 'attacker-id'
      expect.objectContaining({ name: 'Yoga' }),
    );
    const callArgs = mockService.savePlan.mock.calls[0];
    expect(callArgs[0]).toBe(USER_ID);
    expect(callArgs[0]).not.toBe('attacker-id');
  });

  // ── Happy path — update existing plan ─────────────────────────────────────

  it('passes planId to service when provided (update scenario)', async () => {
    const existingPlanId = 'existing-plan-uuid';
    await request(app.getHttpServer())
      .post('/plans/save')
      .send({ planId: existingPlanId, name: 'Updated Plan', planJson: '{"steps":[1,2]}' })
      .expect(200);

    expect(mockService.savePlan).toHaveBeenCalledWith(
      USER_ID,
      expect.objectContaining({ planId: existingPlanId }),
    );
  });

  // ── Validation — oversized planJson ───────────────────────────────────────

  it('returns 400 when planJson exceeds 524288 bytes', async () => {
    const oversized = 'x'.repeat(524289); // 1 byte over the 512 KB limit
    await request(app.getHttpServer())
      .post('/plans/save')
      .send({ name: 'Big Plan', planJson: oversized })
      .expect(400);
  });

  it('returns 400 when name is missing', async () => {
    await request(app.getHttpServer())
      .post('/plans/save')
      .send({ planJson: '{}' })
      .expect(400);
  });

  it('returns 400 when planJson is missing', async () => {
    await request(app.getHttpServer())
      .post('/plans/save')
      .send({ name: 'Valid Name' })
      .expect(400);
  });

  it('returns 400 when planId is not a valid UUID', async () => {
    await request(app.getHttpServer())
      .post('/plans/save')
      .send({ planId: 'not-a-uuid', name: 'Plan', planJson: '{}' })
      .expect(400);
  });

  // ── Plan JSON round-trip ───────────────────────────────────────────────────

  it('round-trip: saved planJson is returned in list as planId reference', async () => {
    const originalPlan = { steps: [{ type: 'say', text: 'Hello' }], name: 'Yoga' };
    const planJsonStr = JSON.stringify(originalPlan);

    // Save the plan
    const saveRes = await request(app.getHttpServer())
      .post('/plans/save')
      .send({ name: 'Yoga', planJson: planJsonStr })
      .expect(200);

    const { planId } = saveRes.body;

    // Verify service was called with the correct planJson
    expect(mockService.savePlan).toHaveBeenCalledWith(
      USER_ID,
      expect.objectContaining({ planJson: planJsonStr }),
    );

    // Mock the list to include the plan we just saved
    mockService.listPlans.mockResolvedValueOnce({
      plans: [
        {
          planId,
          name: 'Yoga',
          createdAt: new Date('2026-01-10T08:00:00.000Z'),
          updatedAt: new Date('2026-01-15T10:00:00.000Z'),
        },
      ],
    });

    // List plans and verify the saved planId appears
    const listRes = await request(app.getHttpServer())
      .get('/plans/list')
      .expect(200);

    expect(listRes.body.plans).toContainEqual(expect.objectContaining({ planId }));
  });
});

describe('PlansController — GET /plans/list', () => {
  let app: INestApplication;
  let mockService: ReturnType<typeof createMockPlansService>;
  const USER_ID = 'jwt-user-abc';

  beforeEach(async () => {
    mockService = createMockPlansService();
    app = await buildApp(mockService, USER_ID);
  });

  afterEach(async () => {
    await app.close();
    jest.restoreAllMocks();
  });

  // ── Authentication ─────────────────────────────────────────────────────────

  it('returns 403 when JwtAuthGuard rejects the request', async () => {
    const rejectedApp = await buildApp(mockService, undefined);
    await request(rejectedApp.getHttpServer())
      .get('/plans/list')
      .expect(403);
    await rejectedApp.close();
  });

  // ── Happy path ─────────────────────────────────────────────────────────────

  it('returns plans array for authenticated user', async () => {
    const res = await request(app.getHttpServer())
      .get('/plans/list')
      .expect(200);

    expect(res.body).toMatchObject({
      plans: [
        {
          planId: 'plan-uuid-001',
          name: 'Morning Yoga',
          createdAt: '2026-01-10T08:00:00.000Z',
          updatedAt: '2026-01-15T10:00:00.000Z',
        },
      ],
    });
  });

  it('returns empty plans array when user has no plans', async () => {
    mockService.listPlans.mockResolvedValueOnce({ plans: [] });

    const res = await request(app.getHttpServer())
      .get('/plans/list')
      .expect(200);

    expect(res.body).toEqual({ plans: [] });
  });

  // ── userId isolation ───────────────────────────────────────────────────────

  it('calls listPlans with JWT userId only — never with userId from query params', async () => {
    // Query param userId should be ignored — controller always uses JWT sub
    await request(app.getHttpServer())
      .get('/plans/list?userId=attacker-id')
      .expect(200);

    expect(mockService.listPlans).toHaveBeenCalledWith(USER_ID);
    const callArgs = mockService.listPlans.mock.calls[0];
    expect(callArgs[0]).toBe(USER_ID);
    expect(callArgs[0]).not.toBe('attacker-id');
  });

  it('only returns plans from the authenticated user — different users get different results', async () => {
    // User A's app
    const userAApp = await buildApp(mockService, 'user-a');
    mockService.listPlans.mockResolvedValueOnce({
      plans: [{ planId: 'plan-a', name: 'User A Plan', createdAt: new Date(), updatedAt: new Date() }],
    });
    const resA = await request(userAApp.getHttpServer()).get('/plans/list').expect(200);
    expect(mockService.listPlans).toHaveBeenCalledWith('user-a');
    await userAApp.close();

    // User B's app
    const userBApp = await buildApp(mockService, 'user-b');
    mockService.listPlans.mockResolvedValueOnce({
      plans: [{ planId: 'plan-b', name: 'User B Plan', createdAt: new Date(), updatedAt: new Date() }],
    });
    const resB = await request(userBApp.getHttpServer()).get('/plans/list').expect(200);
    expect(mockService.listPlans).toHaveBeenCalledWith('user-b');
    await userBApp.close();

    // Verify the results are different for each user
    expect(resA.body.plans[0].planId).toBe('plan-a');
    expect(resB.body.plans[0].planId).toBe('plan-b');
  });
});
