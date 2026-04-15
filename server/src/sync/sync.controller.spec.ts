/**
 * Integration tests for SyncController — session completion sync endpoints.
 *
 * Tests:
 *   - POST /sync/completions — upload completions, auth guard, idempotency
 *   - GET /sync/completions — download completions, since parameter, auth guard
 *   - JWT-guarded (both endpoints require authentication)
 *   - Request/response DTO validation
 *   - Idempotent uploads (duplicate client_id doesn't create duplicates)
 *
 * Strategy:
 *   - SyncService is fully mocked so tests are isolated to controller logic.
 *   - JwtAuthGuard is overridden with a PassThroughGuard for auth scenarios.
 *   - Uses supertest for HTTP-level testing through the full NestJS pipeline.
 */

import { Test, TestingModule } from '@nestjs/testing';
import {
  ExecutionContext,
  ValidationPipe,
  INestApplication,
} from '@nestjs/common';
import { APP_PIPE } from '@nestjs/core';
import * as request from 'supertest';
import { SyncController } from './sync.controller';
import { SyncService } from './sync.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

// ---------------------------------------------------------------------------
// Mock factories
// ---------------------------------------------------------------------------

function createMockSyncService() {
  return {
    uploadCompletions: jest.fn().mockResolvedValue({ syncedCount: 3 }),
    getCompletions: jest.fn().mockResolvedValue({
      completions: [
        {
          id: 'completion-uuid-1',
          planId: 'plan-uuid-001',
          completedAt: '2026-04-14T12:00:00.000Z',
          durationMs: 600000,
        },
        {
          id: 'completion-uuid-2',
          planId: 'plan-uuid-001',
          completedAt: '2026-04-15T12:00:00.000Z',
          durationMs: 900000,
        },
      ],
    }),
  };
}

// ---------------------------------------------------------------------------
// Guard factories
// ---------------------------------------------------------------------------

function makeAuthGuard(userId: string) {
  return class {
    canActivate(ctx: ExecutionContext): boolean {
      const req = ctx.switchToHttp().getRequest();
      req.user = { sub: userId };
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
  mockService: ReturnType<typeof createMockSyncService>,
  guardUserId?: string,
): Promise<INestApplication> {
  const guard = guardUserId ? makeAuthGuard(guardUserId) : RejectGuard;

  const module: TestingModule = await Test.createTestingModule({
    controllers: [SyncController],
    providers: [
      { provide: SyncService, useValue: mockService },
      {
        provide: APP_PIPE,
        useValue: new ValidationPipe({
          whitelist: true,
          forbidNonWhitelisted: false,
        }),
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
// Tests — POST /sync/completions
// ---------------------------------------------------------------------------

describe('SyncController — POST /sync/completions', () => {
  let app: INestApplication;
  let mockService: ReturnType<typeof createMockSyncService>;
  const USER_ID = 'jwt-user-abc';

  beforeEach(async () => {
    mockService = createMockSyncService();
    app = await buildApp(mockService, USER_ID);
  });

  afterEach(async () => {
    await app.close();
    jest.restoreAllMocks();
  });

  // ── Authentication ─────────────────────────────────────────────────────

  it('returns 403 when JwtAuthGuard rejects the request', async () => {
    const rejectedApp = await buildApp(mockService, undefined);
    await request(rejectedApp.getHttpServer())
      .post('/sync/completions')
      .send({ completions: [] })
      .expect(403);
    await rejectedApp.close();
  });

  // ── Happy path ─────────────────────────────────────────────────────────

  it('returns 200 with syncedCount on success', async () => {
    const res = await request(app.getHttpServer())
      .post('/sync/completions')
      .send({
        completions: [
          {
            planId: '00000000-0000-0000-0000-000000000001',
            completedAt: '2026-04-15T12:00:00.000Z',
            durationMs: 600000,
          },
          {
            planId: '00000000-0000-0000-0000-000000000001',
            completedAt: '2026-04-14T12:00:00.000Z',
            durationMs: 900000,
          },
          {
            planId: '00000000-0000-0000-0000-000000000002',
            completedAt: '2026-04-13T12:00:00.000Z',
            durationMs: 300000,
          },
        ],
      })
      .expect(200);

    expect(res.body).toMatchObject({ syncedCount: 3 });
  });

  it('passes JWT userId and completions array to service', async () => {
    const completions = [
      {
        planId: '00000000-0000-0000-0000-000000000001',
        completedAt: '2026-04-15T12:00:00.000Z',
        durationMs: 600000,
      },
    ];

    await request(app.getHttpServer())
      .post('/sync/completions')
      .send({ completions })
      .expect(200);

    expect(mockService.uploadCompletions).toHaveBeenCalledWith(
      USER_ID,
      expect.arrayContaining([
        expect.objectContaining({ planId: '00000000-0000-0000-0000-000000000001' }),
      ]),
    );
  });

  // ── IDOR prevention ────────────────────────────────────────────────────

  it('uses JWT userId, ignores any userId in request body', async () => {
    await request(app.getHttpServer())
      .post('/sync/completions')
      .send({
        userId: 'attacker-id',
        completions: [
          {
            planId: '00000000-0000-0000-0000-000000000001',
            completedAt: '2026-04-15T12:00:00.000Z',
            durationMs: 600000,
          },
        ],
      })
      .expect(200);

    const callArgs = mockService.uploadCompletions.mock.calls[0];
    expect(callArgs[0]).toBe(USER_ID);
    expect(callArgs[0]).not.toBe('attacker-id');
  });

  // ── Idempotency ────────────────────────────────────────────────────────

  it('accepts duplicate completions (idempotent via client_id)', async () => {
    const completions = [
      {
        planId: '00000000-0000-0000-0000-000000000001',
        completedAt: '2026-04-15T12:00:00.000Z',
        durationMs: 600000,
        clientId: '00000000-0000-0000-0000-000000000099',
      },
    ];

    // First upload
    mockService.uploadCompletions.mockResolvedValueOnce({ syncedCount: 1 });
    const res1 = await request(app.getHttpServer())
      .post('/sync/completions')
      .send({ completions })
      .expect(200);

    expect(res1.body.syncedCount).toBe(1);

    // Second upload of same data — should succeed (idempotent)
    mockService.uploadCompletions.mockResolvedValueOnce({ syncedCount: 0 });
    const res2 = await request(app.getHttpServer())
      .post('/sync/completions')
      .send({ completions })
      .expect(200);

    // syncedCount may be 0 since duplicates are ignored
    expect(res2.body.syncedCount).toBe(0);
  });

  // ── Validation ─────────────────────────────────────────────────────────

  it('returns 400 when completions array is missing', async () => {
    await request(app.getHttpServer())
      .post('/sync/completions')
      .send({})
      .expect(400);
  });

  it('returns 400 when completions contain entries with invalid planId format', async () => {
    await request(app.getHttpServer())
      .post('/sync/completions')
      .send({
        completions: [{ planId: 'not-a-uuid', completedAt: '2026-04-15T12:00:00.000Z', durationMs: 600000 }],
      })
      .expect(400);
  });

  // ── Empty batch ────────────────────────────────────────────────────────

  it('handles empty completions array gracefully', async () => {
    const res = await request(app.getHttpServer())
      .post('/sync/completions')
      .send({ completions: [] })
      .expect(200);

    expect(res.body.syncedCount).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// Tests — GET /sync/completions
// ---------------------------------------------------------------------------

describe('SyncController — GET /sync/completions', () => {
  let app: INestApplication;
  let mockService: ReturnType<typeof createMockSyncService>;
  const USER_ID = 'jwt-user-abc';

  beforeEach(async () => {
    mockService = createMockSyncService();
    app = await buildApp(mockService, USER_ID);
  });

  afterEach(async () => {
    await app.close();
    jest.restoreAllMocks();
  });

  // ── Authentication ─────────────────────────────────────────────────────

  it('returns 403 when JwtAuthGuard rejects the request', async () => {
    const rejectedApp = await buildApp(mockService, undefined);
    await request(rejectedApp.getHttpServer())
      .get('/sync/completions')
      .expect(403);
    await rejectedApp.close();
  });

  // ── Happy path ─────────────────────────────────────────────────────────

  it('returns 200 with completions array', async () => {
    const res = await request(app.getHttpServer())
      .get('/sync/completions')
      .expect(200);

    expect(res.body).toHaveProperty('completions');
    expect(res.body.completions).toBeInstanceOf(Array);
    expect(res.body.completions.length).toBe(2);
  });

  it('each completion has id, planId, completedAt, durationMs', async () => {
    const res = await request(app.getHttpServer())
      .get('/sync/completions')
      .expect(200);

    const completion = res.body.completions[0];
    expect(completion).toHaveProperty('id');
    expect(completion).toHaveProperty('planId');
    expect(completion).toHaveProperty('completedAt');
    expect(completion).toHaveProperty('durationMs');
  });

  // ── Since parameter ────────────────────────────────────────────────────

  it('passes since parameter to service as options object with Date', async () => {
    const since = '2026-04-14T00:00:00.000Z';

    await request(app.getHttpServer())
      .get(`/sync/completions?since=${since}`)
      .expect(200);

    expect(mockService.getCompletions).toHaveBeenCalledWith(
      USER_ID,
      expect.objectContaining({
        since: expect.any(Date),
      }),
    );
  });

  it('returns all completions when since is not provided', async () => {
    await request(app.getHttpServer())
      .get('/sync/completions')
      .expect(200);

    expect(mockService.getCompletions).toHaveBeenCalledWith(
      USER_ID,
      expect.objectContaining({ since: undefined }),
    );
  });

  it('returns empty array when no completions exist after since', async () => {
    mockService.getCompletions.mockResolvedValueOnce({ completions: [] });

    const res = await request(app.getHttpServer())
      .get('/sync/completions?since=2027-01-01T00:00:00.000Z')
      .expect(200);

    expect(res.body.completions).toEqual([]);
  });

  it('returns 400 for invalid since timestamp', async () => {
    await request(app.getHttpServer())
      .get('/sync/completions?since=not-a-date')
      .expect(400);
  });

  // ── userId isolation ────────────────────────────────────────────────────

  it('calls getCompletions with JWT userId only', async () => {
    await request(app.getHttpServer())
      .get('/sync/completions?userId=attacker-id')
      .expect(200);

    const callArgs = mockService.getCompletions.mock.calls[0];
    expect(callArgs[0]).toBe(USER_ID);
    expect(callArgs[0]).not.toBe('attacker-id');
  });
});
