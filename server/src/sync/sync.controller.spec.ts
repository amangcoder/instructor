/**
 * Integration tests for SyncController — session completion, plan-trigger, and
 * content-cache sync endpoints.
 *
 * Tests:
 *   - POST /sync/completions   — upload completions, auth guard, idempotency
 *   - GET  /sync/completions   — download completions, since parameter, auth guard
 *   - GET  /sync/categories    — published categories, since parameter, auth guard
 *   - GET  /sync/voices        — published voices, since parameter, auth guard
 *   - GET  /sync/plan-voices   — ready plan-voice renditions, since parameter, auth guard
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
    // Content-cache sync methods (TASK-018)
    getCategories: jest.fn().mockResolvedValue({
      categories: [
        {
          id: 'cat-uuid-1',
          slug: 'wellness',
          name: 'Wellness',
          icon: null,
          color: '#4CAF50',
          sortOrder: 1,
          isPublished: true,
          createdAt: '2026-01-01T00:00:00.000Z',
          updatedAt: '2026-04-01T00:00:00.000Z',
        },
        {
          id: 'cat-uuid-2',
          slug: 'fitness',
          name: 'Fitness',
          icon: 'dumbbell',
          color: '#F44336',
          sortOrder: 2,
          isPublished: true,
          createdAt: '2026-01-01T00:00:00.000Z',
          updatedAt: '2026-04-02T00:00:00.000Z',
        },
      ],
      deletedIds: [],
    }),
    getVoices: jest.fn().mockResolvedValue({
      voices: [
        {
          id: 'voice-uuid-1',
          slug: 'google-en-us-wavenet-a',
          displayName: 'Google US English (WaveNet A)',
          locale: 'en-US',
          provider: 'google',
          sampleUrl: 'https://cdn.example.com/samples/google-en-us-wavenet-a.mp3',
          isPublished: true,
          createdAt: '2026-01-01T00:00:00.000Z',
          updatedAt: '2026-04-01T00:00:00.000Z',
        },
      ],
      deletedIds: [],
    }),
    getPlanVoices: jest.fn().mockResolvedValue({
      planVoices: [
        {
          id: 'pv-uuid-1',
          planId: 'plan-uuid-001',
          voiceId: 'voice-uuid-1',
          locale: 'en-US',
          status: 'ready',
          audioUrl: 'https://cdn.example.com/audio/plan-001-en-us.mp3',
          durationMs: 3600000,
          generatedAt: '2026-04-01T10:00:00.000Z',
          createdAt: '2026-01-01T00:00:00.000Z',
          updatedAt: '2026-04-01T10:00:00.000Z',
        },
      ],
      deletedIds: [],
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

// ---------------------------------------------------------------------------
// Tests — GET /sync/categories (TASK-018, REQ-023, AC-021)
// ---------------------------------------------------------------------------

describe('SyncController — GET /sync/categories', () => {
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
      .get('/sync/categories')
      .expect(403);
    await rejectedApp.close();
  });

  // ── Happy path ─────────────────────────────────────────────────────────

  it('returns 200 with categories array and deletedIds', async () => {
    const res = await request(app.getHttpServer())
      .get('/sync/categories')
      .expect(200);

    expect(res.body).toHaveProperty('categories');
    expect(res.body).toHaveProperty('deletedIds');
    expect(Array.isArray(res.body.categories)).toBe(true);
    expect(Array.isArray(res.body.deletedIds)).toBe(true);
  });

  it('each category has required fields (id, slug, name, sortOrder, isPublished, createdAt, updatedAt)', async () => {
    const res = await request(app.getHttpServer())
      .get('/sync/categories')
      .expect(200);

    const cat = res.body.categories[0];
    expect(cat).toHaveProperty('id');
    expect(cat).toHaveProperty('slug');
    expect(cat).toHaveProperty('name');
    expect(cat).toHaveProperty('sortOrder');
    expect(cat).toHaveProperty('isPublished');
    expect(cat).toHaveProperty('createdAt');
    expect(cat).toHaveProperty('updatedAt');
  });

  it('returns multiple categories with correct field values', async () => {
    const res = await request(app.getHttpServer())
      .get('/sync/categories')
      .expect(200);

    expect(res.body.categories).toHaveLength(2);
    expect(res.body.categories[0].slug).toBe('wellness');
    expect(res.body.categories[1].slug).toBe('fitness');
  });

  it('returns empty deletedIds when no categories were unpublished', async () => {
    const res = await request(app.getHttpServer())
      .get('/sync/categories')
      .expect(200);

    expect(res.body.deletedIds).toEqual([]);
  });

  // ── Since parameter ────────────────────────────────────────────────────

  it('passes undefined sinceDate to service when since is absent (full sync)', async () => {
    await request(app.getHttpServer())
      .get('/sync/categories')
      .expect(200);

    expect(mockService.getCategories).toHaveBeenCalledWith(undefined);
  });

  it('passes a Date to service when valid ISO 8601 since is provided (delta sync)', async () => {
    const since = '2026-04-01T00:00:00.000Z';

    await request(app.getHttpServer())
      .get(`/sync/categories?since=${since}`)
      .expect(200);

    expect(mockService.getCategories).toHaveBeenCalledWith(
      expect.any(Date),
    );
    // The Date value should correspond to the since parameter
    const passedDate: Date = mockService.getCategories.mock.calls[0][0];
    expect(passedDate.toISOString()).toBe(since);
  });

  it('returns 400 for an invalid since timestamp', async () => {
    await request(app.getHttpServer())
      .get('/sync/categories?since=not-a-date')
      .expect(400);
  });

  it('returns 400 for a malformed since timestamp', async () => {
    await request(app.getHttpServer())
      .get('/sync/categories?since=2026-99-99')
      .expect(400);
  });

  it('does NOT call service for invalid since (fails fast)', async () => {
    await request(app.getHttpServer())
      .get('/sync/categories?since=bad-timestamp')
      .expect(400);

    expect(mockService.getCategories).not.toHaveBeenCalled();
  });

  // ── Delta sync — deletedIds ────────────────────────────────────────────

  it('forwards deletedIds from service to the response body', async () => {
    mockService.getCategories.mockResolvedValueOnce({
      categories: [],
      deletedIds: ['cat-old-1', 'cat-old-2'],
    });

    const res = await request(app.getHttpServer())
      .get('/sync/categories?since=2026-04-01T00:00:00.000Z')
      .expect(200);

    expect(res.body.deletedIds).toEqual(['cat-old-1', 'cat-old-2']);
  });

  it('can return both categories and deletedIds simultaneously', async () => {
    mockService.getCategories.mockResolvedValueOnce({
      categories: [
        {
          id: 'cat-new',
          slug: 'mindfulness',
          name: 'Mindfulness',
          icon: null,
          color: null,
          sortOrder: 3,
          isPublished: true,
          createdAt: '2026-04-01T00:00:00.000Z',
          updatedAt: '2026-04-02T00:00:00.000Z',
        },
      ],
      deletedIds: ['cat-evicted'],
    });

    const res = await request(app.getHttpServer())
      .get('/sync/categories?since=2026-03-01T00:00:00.000Z')
      .expect(200);

    expect(res.body.categories).toHaveLength(1);
    expect(res.body.deletedIds).toEqual(['cat-evicted']);
  });

  // ── Empty response ─────────────────────────────────────────────────────

  it('returns empty categories array and empty deletedIds on full sync with no data', async () => {
    mockService.getCategories.mockResolvedValueOnce({ categories: [], deletedIds: [] });

    const res = await request(app.getHttpServer())
      .get('/sync/categories')
      .expect(200);

    expect(res.body.categories).toEqual([]);
    expect(res.body.deletedIds).toEqual([]);
  });

  // ── Error handling ─────────────────────────────────────────────────────

  it('returns 500 when service throws an unexpected error', async () => {
    mockService.getCategories.mockRejectedValueOnce(new Error('DB connection lost'));

    await request(app.getHttpServer())
      .get('/sync/categories')
      .expect(500);
  });
});

// ---------------------------------------------------------------------------
// Tests — GET /sync/voices (TASK-018, REQ-023, AC-021)
// ---------------------------------------------------------------------------

describe('SyncController — GET /sync/voices', () => {
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
      .get('/sync/voices')
      .expect(403);
    await rejectedApp.close();
  });

  // ── Happy path ─────────────────────────────────────────────────────────

  it('returns 200 with voices array and deletedIds', async () => {
    const res = await request(app.getHttpServer())
      .get('/sync/voices')
      .expect(200);

    expect(res.body).toHaveProperty('voices');
    expect(res.body).toHaveProperty('deletedIds');
    expect(Array.isArray(res.body.voices)).toBe(true);
    expect(Array.isArray(res.body.deletedIds)).toBe(true);
  });

  it('each voice has required fields (id, slug, displayName, locale, provider, isPublished, createdAt, updatedAt)', async () => {
    const res = await request(app.getHttpServer())
      .get('/sync/voices')
      .expect(200);

    const voice = res.body.voices[0];
    expect(voice).toHaveProperty('id');
    expect(voice).toHaveProperty('slug');
    expect(voice).toHaveProperty('displayName');
    expect(voice).toHaveProperty('locale');
    expect(voice).toHaveProperty('provider');
    expect(voice).toHaveProperty('isPublished');
    expect(voice).toHaveProperty('createdAt');
    expect(voice).toHaveProperty('updatedAt');
  });

  it('returns correct voice field values', async () => {
    const res = await request(app.getHttpServer())
      .get('/sync/voices')
      .expect(200);

    const voice = res.body.voices[0];
    expect(voice.slug).toBe('google-en-us-wavenet-a');
    expect(voice.locale).toBe('en-US');
    expect(voice.provider).toBe('google');
  });

  it('returns empty deletedIds on full sync when no voices were unpublished', async () => {
    const res = await request(app.getHttpServer())
      .get('/sync/voices')
      .expect(200);

    expect(res.body.deletedIds).toEqual([]);
  });

  // ── Since parameter ────────────────────────────────────────────────────

  it('passes undefined sinceDate to service when since is absent (full sync)', async () => {
    await request(app.getHttpServer())
      .get('/sync/voices')
      .expect(200);

    expect(mockService.getVoices).toHaveBeenCalledWith(undefined);
  });

  it('passes a Date to service when valid ISO 8601 since is provided (delta sync)', async () => {
    const since = '2026-04-01T00:00:00.000Z';

    await request(app.getHttpServer())
      .get(`/sync/voices?since=${since}`)
      .expect(200);

    expect(mockService.getVoices).toHaveBeenCalledWith(expect.any(Date));
    const passedDate: Date = mockService.getVoices.mock.calls[0][0];
    expect(passedDate.toISOString()).toBe(since);
  });

  it('returns 400 for an invalid since timestamp', async () => {
    await request(app.getHttpServer())
      .get('/sync/voices?since=not-a-date')
      .expect(400);
  });

  it('does NOT call service for invalid since (fails fast)', async () => {
    await request(app.getHttpServer())
      .get('/sync/voices?since=bad-timestamp')
      .expect(400);

    expect(mockService.getVoices).not.toHaveBeenCalled();
  });

  // ── Delta sync — deletedIds ────────────────────────────────────────────

  it('forwards deletedIds from service to the response body', async () => {
    mockService.getVoices.mockResolvedValueOnce({
      voices: [],
      deletedIds: ['voice-deprecated-1'],
    });

    const res = await request(app.getHttpServer())
      .get('/sync/voices?since=2026-04-01T00:00:00.000Z')
      .expect(200);

    expect(res.body.deletedIds).toEqual(['voice-deprecated-1']);
  });

  it('can return both voices and deletedIds simultaneously', async () => {
    mockService.getVoices.mockResolvedValueOnce({
      voices: [
        {
          id: 'voice-new',
          slug: 'elevenlabs-en-gb',
          displayName: 'ElevenLabs GB English',
          locale: 'en-GB',
          provider: 'elevenlabs',
          sampleUrl: null,
          isPublished: true,
          createdAt: '2026-04-01T00:00:00.000Z',
          updatedAt: '2026-04-02T00:00:00.000Z',
        },
      ],
      deletedIds: ['voice-retired'],
    });

    const res = await request(app.getHttpServer())
      .get('/sync/voices?since=2026-03-01T00:00:00.000Z')
      .expect(200);

    expect(res.body.voices).toHaveLength(1);
    expect(res.body.deletedIds).toEqual(['voice-retired']);
  });

  // ── Empty response ─────────────────────────────────────────────────────

  it('returns empty voices array and empty deletedIds on full sync with no data', async () => {
    mockService.getVoices.mockResolvedValueOnce({ voices: [], deletedIds: [] });

    const res = await request(app.getHttpServer())
      .get('/sync/voices')
      .expect(200);

    expect(res.body.voices).toEqual([]);
    expect(res.body.deletedIds).toEqual([]);
  });

  // ── Error handling ─────────────────────────────────────────────────────

  it('returns 500 when service throws an unexpected error', async () => {
    mockService.getVoices.mockRejectedValueOnce(new Error('DB connection lost'));

    await request(app.getHttpServer())
      .get('/sync/voices')
      .expect(500);
  });
});

// ---------------------------------------------------------------------------
// Tests — GET /sync/plan-voices (TASK-018, REQ-023, AC-021)
// ---------------------------------------------------------------------------

describe('SyncController — GET /sync/plan-voices', () => {
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
      .get('/sync/plan-voices')
      .expect(403);
    await rejectedApp.close();
  });

  // ── Happy path ─────────────────────────────────────────────────────────

  it('returns 200 with planVoices array and deletedIds', async () => {
    const res = await request(app.getHttpServer())
      .get('/sync/plan-voices')
      .expect(200);

    expect(res.body).toHaveProperty('planVoices');
    expect(res.body).toHaveProperty('deletedIds');
    expect(Array.isArray(res.body.planVoices)).toBe(true);
    expect(Array.isArray(res.body.deletedIds)).toBe(true);
  });

  it('each planVoice has required fields (id, planId, voiceId, locale, status, createdAt, updatedAt)', async () => {
    const res = await request(app.getHttpServer())
      .get('/sync/plan-voices')
      .expect(200);

    const pv = res.body.planVoices[0];
    expect(pv).toHaveProperty('id');
    expect(pv).toHaveProperty('planId');
    expect(pv).toHaveProperty('voiceId');
    expect(pv).toHaveProperty('locale');
    expect(pv).toHaveProperty('status');
    expect(pv).toHaveProperty('createdAt');
    expect(pv).toHaveProperty('updatedAt');
  });

  it('all returned planVoices have status=ready (visibility gate)', async () => {
    const res = await request(app.getHttpServer())
      .get('/sync/plan-voices')
      .expect(200);

    for (const pv of res.body.planVoices) {
      expect(pv.status).toBe('ready');
    }
  });

  it('returned planVoice has audioUrl and durationMs fields', async () => {
    const res = await request(app.getHttpServer())
      .get('/sync/plan-voices')
      .expect(200);

    const pv = res.body.planVoices[0];
    expect(pv).toHaveProperty('audioUrl');
    expect(pv).toHaveProperty('durationMs');
    // Ready rows should have audio metadata populated
    expect(pv.audioUrl).not.toBeNull();
    expect(pv.durationMs).toBeGreaterThan(0);
  });

  it('returns empty deletedIds on full sync when no plan-voices were evicted', async () => {
    const res = await request(app.getHttpServer())
      .get('/sync/plan-voices')
      .expect(200);

    expect(res.body.deletedIds).toEqual([]);
  });

  // ── Since parameter ────────────────────────────────────────────────────

  it('passes undefined sinceDate to service when since is absent (full sync)', async () => {
    await request(app.getHttpServer())
      .get('/sync/plan-voices')
      .expect(200);

    expect(mockService.getPlanVoices).toHaveBeenCalledWith(undefined);
  });

  it('passes a Date to service when valid ISO 8601 since is provided (delta sync)', async () => {
    const since = '2026-04-01T00:00:00.000Z';

    await request(app.getHttpServer())
      .get(`/sync/plan-voices?since=${since}`)
      .expect(200);

    expect(mockService.getPlanVoices).toHaveBeenCalledWith(expect.any(Date));
    const passedDate: Date = mockService.getPlanVoices.mock.calls[0][0];
    expect(passedDate.toISOString()).toBe(since);
  });

  it('returns 400 for an invalid since timestamp', async () => {
    await request(app.getHttpServer())
      .get('/sync/plan-voices?since=not-a-date')
      .expect(400);
  });

  it('does NOT call service for invalid since (fails fast)', async () => {
    await request(app.getHttpServer())
      .get('/sync/plan-voices?since=bad-timestamp')
      .expect(400);

    expect(mockService.getPlanVoices).not.toHaveBeenCalled();
  });

  // ── Delta sync — deletedIds ────────────────────────────────────────────

  it('forwards deletedIds from service to the response body', async () => {
    mockService.getPlanVoices.mockResolvedValueOnce({
      planVoices: [],
      deletedIds: ['pv-evicted-1', 'pv-evicted-2'],
    });

    const res = await request(app.getHttpServer())
      .get('/sync/plan-voices?since=2026-04-01T00:00:00.000Z')
      .expect(200);

    expect(res.body.deletedIds).toEqual(['pv-evicted-1', 'pv-evicted-2']);
  });

  it('can return both planVoices and deletedIds simultaneously', async () => {
    mockService.getPlanVoices.mockResolvedValueOnce({
      planVoices: [
        {
          id: 'pv-new',
          planId: 'plan-uuid-002',
          voiceId: 'voice-uuid-1',
          locale: 'en-IN',
          status: 'ready',
          audioUrl: 'https://cdn.example.com/audio/plan-002-en-in.mp3',
          durationMs: 1800000,
          generatedAt: '2026-04-02T10:00:00.000Z',
          createdAt: '2026-04-01T00:00:00.000Z',
          updatedAt: '2026-04-02T10:00:00.000Z',
        },
      ],
      deletedIds: ['pv-status-failed', 'pv-plan-unpublished'],
    });

    const res = await request(app.getHttpServer())
      .get('/sync/plan-voices?since=2026-03-01T00:00:00.000Z')
      .expect(200);

    expect(res.body.planVoices).toHaveLength(1);
    expect(res.body.planVoices[0].status).toBe('ready');
    expect(res.body.deletedIds).toEqual(['pv-status-failed', 'pv-plan-unpublished']);
  });

  it('deletedIds represent plan-voices that are no longer ready or whose plan was unpublished', async () => {
    mockService.getPlanVoices.mockResolvedValueOnce({
      planVoices: [],
      // One row failed synthesis, one row's parent plan was unpublished
      deletedIds: ['pv-failed-synthesis', 'pv-plan-unpublished'],
    });

    const res = await request(app.getHttpServer())
      .get('/sync/plan-voices?since=2026-04-01T00:00:00.000Z')
      .expect(200);

    expect(res.body.deletedIds).toHaveLength(2);
    expect(res.body.deletedIds).toContain('pv-failed-synthesis');
    expect(res.body.deletedIds).toContain('pv-plan-unpublished');
  });

  // ── Empty response ─────────────────────────────────────────────────────

  it('returns empty planVoices array and empty deletedIds on full sync with no data', async () => {
    mockService.getPlanVoices.mockResolvedValueOnce({ planVoices: [], deletedIds: [] });

    const res = await request(app.getHttpServer())
      .get('/sync/plan-voices')
      .expect(200);

    expect(res.body.planVoices).toEqual([]);
    expect(res.body.deletedIds).toEqual([]);
  });

  // ── Error handling ─────────────────────────────────────────────────────

  it('returns 500 when service throws an unexpected error', async () => {
    mockService.getPlanVoices.mockRejectedValueOnce(new Error('DB connection lost'));

    await request(app.getHttpServer())
      .get('/sync/plan-voices')
      .expect(500);
  });
});
