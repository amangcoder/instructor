/**
 * Tests for AdminPlansController — PATCH /admin/plans/:id
 *
 * Covers:
 *   1. 200 success on valid update
 *   2. 422 when PlansService.adminUpdatePlan throws UnprocessableEntityException
 *      (depth > 3 hierarchy rule violation)
 *   3. 401 / 403 when no valid JWT (JwtAuthGuard rejects)
 *   4. 403 when JWT present but role is not 'admin' (AdminRoleGuard rejects)
 *   5. 400 when :id is not a valid UUID (ParseUUIDPipe rejects)
 *
 * Strategy:
 *   - PlansService is fully mocked for controller-level tests.
 *   - JwtAuthGuard and AdminRoleGuard are overridden per scenario.
 */

import { Test, TestingModule } from '@nestjs/testing';
import {
  ExecutionContext,
  ValidationPipe,
  INestApplication,
  HttpStatus,
  UnprocessableEntityException,
} from '@nestjs/common';
import { APP_PIPE } from '@nestjs/core';
import * as request from 'supertest';
import { AdminPlansController } from './admin-plans.controller';
import { PlansService } from './plans.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRoleGuard } from '../auth/admin-role.guard';

// ---------------------------------------------------------------------------
// Mock factories
// ---------------------------------------------------------------------------

function createMockPlansService() {
  return {
    adminUpdatePlan: jest.fn().mockResolvedValue(undefined),
  };
}

// ---------------------------------------------------------------------------
// Guard factories (mirrors admin-plan-requests.controller.spec.ts pattern)
// ---------------------------------------------------------------------------

/** Admin JWT guard that passes and injects an admin user into req.user. */
function makeAdminAuthGuard(userId: string) {
  return class {
    canActivate(ctx: ExecutionContext): boolean {
      const req = ctx.switchToHttp().getRequest();
      req.user = { sub: userId, role: 'admin' };
      return true;
    }
  };
}

/** Non-admin JWT guard that passes but injects a regular user role. */
function makeUserAuthGuard(userId: string) {
  return class {
    canActivate(ctx: ExecutionContext): boolean {
      const req = ctx.switchToHttp().getRequest();
      req.user = { sub: userId, role: 'user' };
      return true;
    }
  };
}

/** Guard that always rejects — simulates missing / invalid JWT. */
class RejectGuard {
  canActivate(): boolean {
    return false;
  }
}

/** AdminRoleGuard pass-through — used when the JWT guard already set role='admin'. */
class PassThroughAdminGuard {
  canActivate(): boolean {
    return true;
  }
}

/** AdminRoleGuard that rejects — simulates a non-admin user hitting an admin endpoint. */
class RejectAdminGuard {
  canActivate(): boolean {
    return false;
  }
}

// ---------------------------------------------------------------------------
// App builder
// ---------------------------------------------------------------------------

type BuildOptions = {
  jwtGuard?: 'admin' | 'user' | 'reject';
  userId?: string;
};

async function buildApp(
  mockService: ReturnType<typeof createMockPlansService>,
  options: BuildOptions = { jwtGuard: 'admin', userId: 'admin-user-001' },
): Promise<INestApplication> {
  const userId = options.userId ?? 'admin-user-001';

  let jwtGuardClass: new (...args: any[]) => any;
  let adminGuardClass: new (...args: any[]) => any;

  switch (options.jwtGuard) {
    case 'admin':
      jwtGuardClass = makeAdminAuthGuard(userId);
      adminGuardClass = PassThroughAdminGuard;
      break;
    case 'user':
      jwtGuardClass = makeUserAuthGuard(userId);
      adminGuardClass = RejectAdminGuard;
      break;
    case 'reject':
    default:
      jwtGuardClass = RejectGuard;
      adminGuardClass = RejectGuard;
      break;
  }

  const module: TestingModule = await Test.createTestingModule({
    controllers: [AdminPlansController],
    providers: [
      { provide: PlansService, useValue: mockService },
      {
        provide: APP_PIPE,
        useValue: new ValidationPipe({ whitelist: true, forbidNonWhitelisted: false }),
      },
    ],
  })
    .overrideGuard(JwtAuthGuard)
    .useClass(jwtGuardClass)
    .overrideGuard(AdminRoleGuard)
    .useClass(adminGuardClass)
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

const VALID_PLAN_ID = 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa';
const VALID_PARENT_PLAN_ID = 'bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb';

const VALID_UPDATE_BODY = {
  parentPlanId: VALID_PARENT_PLAN_ID,
  position: 2,
  visibility: 'public',
  isPublished: true,
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('AdminPlansController — PATCH /admin/plans/:id', () => {
  let app: INestApplication;
  let mockService: ReturnType<typeof createMockPlansService>;

  beforeEach(async () => {
    mockService = createMockPlansService();
    app = await buildApp(mockService);
  });

  afterEach(async () => {
    await app.close();
    jest.restoreAllMocks();
  });

  // ── Happy path ──────────────────────────────────────────────────────────

  it('returns 200 { success: true } on valid update', async () => {
    const res = await request(app.getHttpServer())
      .patch(`/admin/plans/${VALID_PLAN_ID}`)
      .send(VALID_UPDATE_BODY)
      .expect(HttpStatus.OK);

    expect(res.body).toEqual({ success: true });
    expect(mockService.adminUpdatePlan).toHaveBeenCalledWith(VALID_PLAN_ID, {
      parentPlanId: VALID_PARENT_PLAN_ID,
      position: 2,
      visibility: 'public',
      isPublished: true,
    });
  });

  it('returns 200 with partial body (only isPublished)', async () => {
    await request(app.getHttpServer())
      .patch(`/admin/plans/${VALID_PLAN_ID}`)
      .send({ isPublished: true })
      .expect(HttpStatus.OK);

    expect(mockService.adminUpdatePlan).toHaveBeenCalledWith(VALID_PLAN_ID, {
      parentPlanId: undefined,
      position: undefined,
      visibility: undefined,
      isPublished: true,
    });
  });

  // ── Depth hierarchy rule (AC-009 / architecture spec) ──────────────────

  it('returns 422 when adminUpdatePlan throws UnprocessableEntityException (depth > 3)', async () => {
    mockService.adminUpdatePlan.mockRejectedValueOnce(
      new UnprocessableEntityException(
        'Setting parentPlanId would exceed the maximum allowed plan depth of 3',
      ),
    );

    await request(app.getHttpServer())
      .patch(`/admin/plans/${VALID_PLAN_ID}`)
      .send({ parentPlanId: VALID_PARENT_PLAN_ID })
      .expect(HttpStatus.UNPROCESSABLE_ENTITY);
  });

  // ── Authentication / Authorization ──────────────────────────────────────

  it('returns 403 when JwtAuthGuard rejects (unauthenticated / missing JWT)', async () => {
    const rejectedApp = await buildApp(mockService, { jwtGuard: 'reject' });
    await request(rejectedApp.getHttpServer())
      .patch(`/admin/plans/${VALID_PLAN_ID}`)
      .send(VALID_UPDATE_BODY)
      .expect(HttpStatus.FORBIDDEN);
    await rejectedApp.close();
  });

  it('returns 403 when user is authenticated but does not have admin role', async () => {
    const userApp = await buildApp(mockService, { jwtGuard: 'user', userId: 'regular-user-001' });
    await request(userApp.getHttpServer())
      .patch(`/admin/plans/${VALID_PLAN_ID}`)
      .send(VALID_UPDATE_BODY)
      .expect(HttpStatus.FORBIDDEN);
    await userApp.close();
  });

  // ── Input validation ────────────────────────────────────────────────────

  it('returns 400 when :id is not a valid UUID', async () => {
    await request(app.getHttpServer())
      .patch('/admin/plans/not-a-uuid')
      .send(VALID_UPDATE_BODY)
      .expect(HttpStatus.BAD_REQUEST);
  });
});
