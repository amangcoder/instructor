/**
 * Unit tests for PlanVoicesController.
 *
 * Tests the HTTP layer for plan-voices admin endpoints including:
 *   POST /api/admin/plans/:id/voices/:voiceId/regenerate
 *   GET /api/admin/plan-voices?status=failed
 *
 * Strategy:
 *   - PlanVoicesService is fully mocked (unit boundary at controller layer).
 *   - JwtAuthGuard and AdminRoleGuard are overridden to isolate endpoint logic.
 *   - Tests verify endpoint routing, parameter binding, and response shape.
 */

import { Test, TestingModule } from '@nestjs/testing';
import { ExecutionContext, INestApplication, ValidationPipe } from '@nestjs/common';
import { APP_PIPE } from '@nestjs/core';
import * as request from 'supertest';
import { PlanVoicesController } from './plan-voices.controller';
import { PlanVoicesService } from './plan-voices.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRoleGuard } from '../auth/admin-role.guard';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const ADMIN_USER = {
  id: 'user-uuid-admin',
  email: 'admin@example.com',
  role: 'admin',
};

const PLAN_VOICE_ITEM_FIXTURE = {
  id: 'pv-uuid-001',
  planId: 'plan-uuid-001',
  voiceId: 'voice-uuid-001',
  locale: 'en-US',
  status: 'failed' as const,
  audioUrl: null,
  durationMs: null,
  errorMsg: 'Synthesis timeout',
  generatedAt: null,
  createdAt: new Date('2026-01-01T00:00:00.000Z'),
  updatedAt: new Date('2026-01-02T00:00:00.000Z'),
};

// ---------------------------------------------------------------------------
// Mock service factory
// ---------------------------------------------------------------------------

function createMockPlanVoicesService() {
  return {
    regenerateVoice: jest.fn().mockResolvedValue({
      jobId: 'job-uuid-001',
      planId: 'plan-uuid-001',
      voiceId: 'voice-uuid-001',
      status: 'pending',
    }),
    listFailed: jest.fn().mockResolvedValue({
      items: [PLAN_VOICE_ITEM_FIXTURE],
      total: 1,
      page: 1,
      pageSize: 20,
    }),
    listByPlan: jest.fn().mockResolvedValue([PLAN_VOICE_ITEM_FIXTURE]),
  };
}

// ---------------------------------------------------------------------------
// Guard factories
// ---------------------------------------------------------------------------

function makePassThroughGuard(user: Record<string, unknown>) {
  return class {
    canActivate(ctx: ExecutionContext): boolean {
      ctx.switchToHttp().getRequest().user = user;
      return true;
    }
  };
}

class RejectGuard {
  canActivate(): boolean {
    return false;
  }
}

// ---------------------------------------------------------------------------
// App builder
// ---------------------------------------------------------------------------

async function buildApp(
  mockService: ReturnType<typeof createMockPlanVoicesService>,
  authGuardClass: any = makePassThroughGuard(ADMIN_USER),
  adminGuardClass: any = makePassThroughGuard(ADMIN_USER),
) {
  const moduleFixture: TestingModule = await Test.createTestingModule({
    controllers: [PlanVoicesController],
    providers: [
      {
        provide: PlanVoicesService,
        useValue: mockService,
      },
      {
        provide: APP_PIPE,
        useValue: new ValidationPipe({ whitelist: true, transform: true }),
      },
    ],
  })
    .overrideGuard(JwtAuthGuard)
    .useClass(authGuardClass)
    .overrideGuard(AdminRoleGuard)
    .useClass(adminGuardClass)
    .compile();

  const app = moduleFixture.createNestApplication();
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.setGlobalPrefix('api');
  await app.init();
  return { app, mockService };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('PlanVoicesController', () => {
  describe('POST /admin/plans/:id/voices/:voiceId/regenerate', () => {
    it('returns 202 Accepted with regeneration response', async () => {
      const mockService = createMockPlanVoicesService();
      const { app } = await buildApp(mockService);

      const res = await request(app.getHttpServer())
        .post('/api/admin/plans/plan-uuid-001/voices/voice-uuid-001/regenerate')
        .expect(202);

      expect(res.body).toMatchObject({
        jobId: expect.any(String),
        planId: 'plan-uuid-001',
        voiceId: 'voice-uuid-001',
        status: 'pending',
      });

      expect(mockService.regenerateVoice).toHaveBeenCalledWith(
        'plan-uuid-001',
        'voice-uuid-001',
      );
    });

    it('rejects request without authentication', async () => {
      const mockService = createMockPlanVoicesService();
      const { app } = await buildApp(
        mockService,
        RejectGuard,
        makePassThroughGuard(ADMIN_USER),
      );

      await request(app.getHttpServer())
        .post('/api/admin/plans/plan-uuid-001/voices/voice-uuid-001/regenerate')
        .expect(403);
    });

    it('rejects request without admin role', async () => {
      const mockService = createMockPlanVoicesService();
      const { app } = await buildApp(
        mockService,
        makePassThroughGuard(ADMIN_USER),
        RejectGuard,
      );

      await request(app.getHttpServer())
        .post('/api/admin/plans/plan-uuid-001/voices/voice-uuid-001/regenerate')
        .expect(403);
    });
  });

  describe('GET /admin/plans/:id/voices', () => {
    it('returns plan-voice array for the given plan', async () => {
      const mockService = createMockPlanVoicesService();
      const { app } = await buildApp(mockService);

      const res = await request(app.getHttpServer())
        .get('/api/admin/plans/plan-uuid-001/voices')
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body[0]).toMatchObject({
        id: PLAN_VOICE_ITEM_FIXTURE.id,
        planId: PLAN_VOICE_ITEM_FIXTURE.planId,
      });
      expect(mockService.listByPlan).toHaveBeenCalledWith('plan-uuid-001');
    });

    it('rejects request without authentication', async () => {
      const mockService = createMockPlanVoicesService();
      const { app } = await buildApp(
        mockService,
        RejectGuard,
        makePassThroughGuard(ADMIN_USER),
      );

      await request(app.getHttpServer())
        .get('/api/admin/plans/plan-uuid-001/voices')
        .expect(403);
    });

    it('rejects request without admin role', async () => {
      const mockService = createMockPlanVoicesService();
      const { app } = await buildApp(
        mockService,
        makePassThroughGuard(ADMIN_USER),
        RejectGuard,
      );

      await request(app.getHttpServer())
        .get('/api/admin/plans/plan-uuid-001/voices')
        .expect(403);
    });
  });

  describe('GET /admin/plan-voices', () => {
    it('returns paginated list of failed plan-voices', async () => {
      const mockService = createMockPlanVoicesService();
      const { app } = await buildApp(mockService);

      const res = await request(app.getHttpServer())
        .get('/api/admin/plan-voices?status=failed&page=1&pageSize=20')
        .expect(200);

      expect(res.body).toMatchObject({
        items: expect.arrayContaining([
          expect.objectContaining({
            id: PLAN_VOICE_ITEM_FIXTURE.id,
            status: 'failed',
          }),
        ]),
        total: 1,
        page: 1,
        pageSize: 20,
      });

      expect(mockService.listFailed).toHaveBeenCalledWith(1, 20);
    });

    it('defaults to page=1 and pageSize=20', async () => {
      const mockService = createMockPlanVoicesService();
      const { app } = await buildApp(mockService);

      await request(app.getHttpServer())
        .get('/api/admin/plan-voices')
        .expect(200);

      expect(mockService.listFailed).toHaveBeenCalledWith(1, 20);
    });

    it('rejects request without authentication', async () => {
      const mockService = createMockPlanVoicesService();
      const { app } = await buildApp(
        mockService,
        RejectGuard,
        makePassThroughGuard(ADMIN_USER),
      );

      await request(app.getHttpServer())
        .get('/api/admin/plan-voices?status=failed')
        .expect(403);
    });

    it('rejects request without admin role', async () => {
      const mockService = createMockPlanVoicesService();
      const { app } = await buildApp(
        mockService,
        makePassThroughGuard(ADMIN_USER),
        RejectGuard,
      );

      await request(app.getHttpServer())
        .get('/api/admin/plan-voices?status=failed')
        .expect(403);
    });
  });

  describe('endpoint discoverable via module registration', () => {
    it('both endpoints are registered in the application', async () => {
      const mockService = createMockPlanVoicesService();
      const { app } = await buildApp(mockService);

      // Verify POST endpoint exists and is functional
      const postRes = await request(app.getHttpServer())
        .post('/api/admin/plans/test-plan/voices/test-voice/regenerate')
        .expect(202);

      expect(postRes.body).toHaveProperty('jobId');

      // Verify GET endpoint exists and is functional
      const getRes = await request(app.getHttpServer())
        .get('/api/admin/plan-voices?status=failed')
        .expect(200);

      expect(getRes.body).toHaveProperty('items');
      expect(Array.isArray(getRes.body.items)).toBe(true);
    });
  });
});
