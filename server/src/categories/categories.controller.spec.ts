/**
 * Integration tests for CategoriesController and AdminCategoriesController.
 *
 * Strategy:
 *   - CategoriesService is fully mocked (unit boundary at controller layer).
 *   - JwtAuthGuard is overridden with a configurable PassThroughGuard that
 *     injects a fake user so we can exercise both authenticated and
 *     guard-rejection scenarios.
 *   - AdminRoleGuard is overridden with a configurable guard to test admin
 *     access control independently.
 *   - Tests are organised by endpoint to make failures easy to locate.
 *
 * Covers:
 *   1. GET /categories — public paginated list
 *   2. GET /admin/categories — admin paginated list (all)
 *   3. POST /admin/categories — create with validation
 *   4. PATCH /admin/categories/reorder — bulk reorder
 *   5. PATCH /admin/categories/:id — partial update
 *   6. DELETE /admin/categories/:id — soft-delete
 *   7. Guard enforcement on all admin endpoints
 */

import { Test, TestingModule } from '@nestjs/testing';
import { ExecutionContext, INestApplication, ValidationPipe } from '@nestjs/common';
import { APP_PIPE } from '@nestjs/core';
import * as request from 'supertest';
import { CategoriesController } from './categories.controller';
import { AdminCategoriesController } from './admin-categories.controller';
import { CategoriesService } from './categories.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRoleGuard } from '../auth/admin-role.guard';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const CATEGORY_FIXTURE = {
  id: 'cat-uuid-001',
  slug: 'morning-meditation',
  name: 'Morning Meditation',
  icon: '🌅',
  color: '#FF6B35',
  sortOrder: 0,
  isPublished: true,
  createdAt: new Date('2026-01-01T00:00:00.000Z'),
  updatedAt: new Date('2026-01-02T00:00:00.000Z'),
};

const DRAFT_CATEGORY_FIXTURE = {
  ...CATEGORY_FIXTURE,
  id: 'cat-uuid-002',
  slug: 'evening-wind-down',
  name: 'Evening Wind-Down',
  isPublished: false,
};

// ---------------------------------------------------------------------------
// Mock service factory
// ---------------------------------------------------------------------------

function createMockCategoriesService() {
  return {
    listPublished: jest.fn().mockResolvedValue([CATEGORY_FIXTURE]),
    listAll: jest.fn().mockResolvedValue({
      categories: [CATEGORY_FIXTURE, DRAFT_CATEGORY_FIXTURE],
      total: 2,
    }),
    findById: jest.fn().mockResolvedValue(CATEGORY_FIXTURE),
    create: jest.fn().mockResolvedValue({ id: 'cat-uuid-new' }),
    update: jest.fn().mockResolvedValue({ ...CATEGORY_FIXTURE, name: 'Updated Name' }),
    softDelete: jest.fn().mockResolvedValue(undefined),
    reorder: jest.fn().mockResolvedValue(undefined),
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
  mockService: ReturnType<typeof createMockCategoriesService>,
  opts: {
    jwtUser?: Record<string, unknown>; // undefined → JwtAuthGuard rejects
    adminPass?: boolean;               // true → AdminRoleGuard passes; false → rejects
  } = {},
): Promise<INestApplication> {
  const { jwtUser, adminPass = true } = opts;

  const jwtGuard = jwtUser ? makePassThroughGuard(jwtUser) : RejectGuard;
  const adminGuard = adminPass
    ? class { canActivate() { return true; } }
    : class { canActivate() { return false; } };

  const module: TestingModule = await Test.createTestingModule({
    controllers: [CategoriesController, AdminCategoriesController],
    providers: [
      { provide: CategoriesService, useValue: mockService },
      {
        provide: APP_PIPE,
        useValue: new ValidationPipe({ whitelist: true, transform: true }),
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
    new ValidationPipe({ whitelist: true, forbidNonWhitelisted: false, transform: true }),
  );
  await app.init();
  return app;
}

// ---------------------------------------------------------------------------
// Tests — GET /categories (public)
// ---------------------------------------------------------------------------

describe('CategoriesController — GET /categories', () => {
  let app: INestApplication;
  let mockService: ReturnType<typeof createMockCategoriesService>;

  beforeEach(async () => {
    mockService = createMockCategoriesService();
    // Public endpoint — no JWT user needed
    app = await buildApp(mockService);
  });

  afterEach(async () => {
    await app.close();
    jest.restoreAllMocks();
  });

  it('returns paginated list of published categories with default pagination', async () => {
    const res = await request(app.getHttpServer()).get('/categories').expect(200);

    expect(res.body).toMatchObject({
      categories: [
        expect.objectContaining({ id: 'cat-uuid-001', slug: 'morning-meditation' }),
      ],
      total: 1,
      page: 1,
      pageSize: 20,
    });
    expect(mockService.listPublished).toHaveBeenCalledTimes(1);
  });

  it('accepts custom page and pageSize query params', async () => {
    mockService.listPublished.mockResolvedValueOnce(
      Array.from({ length: 25 }, (_, i) => ({ ...CATEGORY_FIXTURE, id: `cat-${i}` })),
    );

    const res = await request(app.getHttpServer())
      .get('/categories?page=2&pageSize=10')
      .expect(200);

    expect(res.body.page).toBe(2);
    expect(res.body.pageSize).toBe(10);
    expect(res.body.categories).toHaveLength(10);
    expect(res.body.total).toBe(25);
  });

  it('clamps pageSize to maximum of 100', async () => {
    mockService.listPublished.mockResolvedValueOnce(
      Array.from({ length: 5 }, (_, i) => ({ ...CATEGORY_FIXTURE, id: `cat-${i}` })),
    );

    const res = await request(app.getHttpServer())
      .get('/categories?pageSize=999')
      .expect(200);

    expect(res.body.pageSize).toBe(100);
  });

  it('defaults to page=1 when page param is invalid', async () => {
    const res = await request(app.getHttpServer())
      .get('/categories?page=abc')
      .expect(200);

    expect(res.body.page).toBe(1);
  });

  it('returns empty list when no categories are published', async () => {
    mockService.listPublished.mockResolvedValueOnce([]);

    const res = await request(app.getHttpServer()).get('/categories').expect(200);

    expect(res.body).toEqual({ categories: [], total: 0, page: 1, pageSize: 20 });
  });

  it('does NOT require authentication (public endpoint)', async () => {
    // buildApp with no jwtUser means JWT guard rejects; but this is a public
    // route so it should still work.
    const publicApp = await buildApp(mockService, { jwtUser: undefined });
    await request(publicApp.getHttpServer()).get('/categories').expect(200);
    await publicApp.close();
  });
});

// ---------------------------------------------------------------------------
// Tests — Admin guard enforcement
// ---------------------------------------------------------------------------

describe('AdminCategoriesController — guard enforcement', () => {
  let mockService: ReturnType<typeof createMockCategoriesService>;

  beforeEach(() => {
    mockService = createMockCategoriesService();
  });

  it.each([
    ['GET', '/admin/categories', undefined, {}],
    ['POST', '/admin/categories', { slug: 'test', name: 'Test' }, {}],
    ['PATCH', '/admin/categories/reorder', { items: [{ id: '00000000-0000-0000-0000-000000000001', sortOrder: 0 }] }, {}],
    ['PATCH', '/admin/categories/cat-uuid-001', { name: 'Updated' }, {}],
    ['DELETE', '/admin/categories/cat-uuid-001', undefined, {}],
  ])(
    '%s %s returns 403 when JwtAuthGuard rejects',
    async (method, path, body) => {
      const app = await buildApp(mockService, { jwtUser: undefined, adminPass: false });
      const req = (request(app.getHttpServer()) as unknown as Record<string, (p: string) => request.Test>)[method.toLowerCase()](path);
      if (body) req.send(body);
      await req.expect(403);
      await app.close();
    },
  );

  it('returns 403 when user is not admin (AdminRoleGuard rejects)', async () => {
    const app = await buildApp(mockService, {
      jwtUser: { sub: 'user-123', role: 'user' },
      adminPass: false,
    });
    await request(app.getHttpServer()).get('/admin/categories').expect(403);
    await app.close();
  });
});

// ---------------------------------------------------------------------------
// Tests — GET /admin/categories
// ---------------------------------------------------------------------------

describe('AdminCategoriesController — GET /admin/categories', () => {
  let app: INestApplication;
  let mockService: ReturnType<typeof createMockCategoriesService>;
  const ADMIN_USER = { sub: 'admin-001', role: 'admin' };

  beforeEach(async () => {
    mockService = createMockCategoriesService();
    app = await buildApp(mockService, { jwtUser: ADMIN_USER });
  });

  afterEach(async () => {
    await app.close();
    jest.restoreAllMocks();
  });

  it('returns paginated list including unpublished categories', async () => {
    const res = await request(app.getHttpServer()).get('/admin/categories').expect(200);

    expect(res.body).toMatchObject({ total: 2 });
    expect(res.body.categories).toHaveLength(2);
    expect(mockService.listAll).toHaveBeenCalledWith(1, 20);
  });

  it('forwards page and pageSize to service', async () => {
    await request(app.getHttpServer())
      .get('/admin/categories?page=3&pageSize=5')
      .expect(200);

    expect(mockService.listAll).toHaveBeenCalledWith(3, 5);
  });
});

// ---------------------------------------------------------------------------
// Tests — POST /admin/categories
// ---------------------------------------------------------------------------

describe('AdminCategoriesController — POST /admin/categories', () => {
  let app: INestApplication;
  let mockService: ReturnType<typeof createMockCategoriesService>;
  const ADMIN_USER = { sub: 'admin-001', role: 'admin' };

  beforeEach(async () => {
    mockService = createMockCategoriesService();
    app = await buildApp(mockService, { jwtUser: ADMIN_USER });
  });

  afterEach(async () => {
    await app.close();
    jest.restoreAllMocks();
  });

  it('creates a category and returns 201 with new id', async () => {
    const res = await request(app.getHttpServer())
      .post('/admin/categories')
      .send({ slug: 'morning-meditation', name: 'Morning Meditation' })
      .expect(201);

    expect(res.body).toEqual({ id: 'cat-uuid-new' });
    expect(mockService.create).toHaveBeenCalledWith(
      expect.objectContaining({ slug: 'morning-meditation', name: 'Morning Meditation' }),
    );
  });

  it('creates a category with all optional fields', async () => {
    await request(app.getHttpServer())
      .post('/admin/categories')
      .send({
        slug: 'sleep',
        name: 'Sleep',
        icon: '🌙',
        color: '#1A1A2E',
        sortOrder: 5,
        isPublished: true,
      })
      .expect(201);

    expect(mockService.create).toHaveBeenCalledWith(
      expect.objectContaining({
        slug: 'sleep',
        name: 'Sleep',
        icon: '🌙',
        color: '#1A1A2E',
        sortOrder: 5,
        isPublished: true,
      }),
    );
  });

  it('returns 400 when slug is missing', async () => {
    await request(app.getHttpServer())
      .post('/admin/categories')
      .send({ name: 'No Slug' })
      .expect(400);
  });

  it('returns 400 when name is missing', async () => {
    await request(app.getHttpServer())
      .post('/admin/categories')
      .send({ slug: 'no-name' })
      .expect(400);
  });

  it('returns 400 when slug contains uppercase letters', async () => {
    await request(app.getHttpServer())
      .post('/admin/categories')
      .send({ slug: 'Morning-Meditation', name: 'Morning Meditation' })
      .expect(400);
  });

  it('returns 400 when slug contains spaces', async () => {
    await request(app.getHttpServer())
      .post('/admin/categories')
      .send({ slug: 'morning meditation', name: 'Morning Meditation' })
      .expect(400);
  });

  it('returns 400 when sortOrder is negative', async () => {
    await request(app.getHttpServer())
      .post('/admin/categories')
      .send({ slug: 'test', name: 'Test', sortOrder: -1 })
      .expect(400);
  });

  it('returns 400 when name exceeds 200 characters', async () => {
    await request(app.getHttpServer())
      .post('/admin/categories')
      .send({ slug: 'test', name: 'a'.repeat(201) })
      .expect(400);
  });
});

// ---------------------------------------------------------------------------
// Tests — PATCH /admin/categories/reorder
// ---------------------------------------------------------------------------

describe('AdminCategoriesController — PATCH /admin/categories/reorder', () => {
  let app: INestApplication;
  let mockService: ReturnType<typeof createMockCategoriesService>;
  const ADMIN_USER = { sub: 'admin-001', role: 'admin' };

  beforeEach(async () => {
    mockService = createMockCategoriesService();
    app = await buildApp(mockService, { jwtUser: ADMIN_USER });
  });

  afterEach(async () => {
    await app.close();
    jest.restoreAllMocks();
  });

  const VALID_ITEMS = [
    { id: '00000000-0000-0000-0000-000000000001', sortOrder: 0 },
    { id: '00000000-0000-0000-0000-000000000002', sortOrder: 1 },
  ];

  it('reorders categories and returns 204 No Content', async () => {
    await request(app.getHttpServer())
      .patch('/admin/categories/reorder')
      .send({ items: VALID_ITEMS })
      .expect(204);

    expect(mockService.reorder).toHaveBeenCalledWith(
      expect.objectContaining({ items: VALID_ITEMS }),
    );
  });

  it('returns 400 when items array is empty', async () => {
    await request(app.getHttpServer())
      .patch('/admin/categories/reorder')
      .send({ items: [] })
      .expect(400);
  });

  it('returns 400 when items field is missing', async () => {
    await request(app.getHttpServer())
      .patch('/admin/categories/reorder')
      .send({})
      .expect(400);
  });

  it('returns 400 when an item id is not a UUID', async () => {
    await request(app.getHttpServer())
      .patch('/admin/categories/reorder')
      .send({ items: [{ id: 'not-a-uuid', sortOrder: 0 }] })
      .expect(400);
  });

  it('returns 400 when an item sortOrder is negative', async () => {
    await request(app.getHttpServer())
      .patch('/admin/categories/reorder')
      .send({ items: [{ id: '00000000-0000-0000-0000-000000000001', sortOrder: -1 }] })
      .expect(400);
  });

  it('is not shadowed by the PATCH :id route (literal takes precedence)', async () => {
    // "reorder" must NOT be treated as an :id param
    await request(app.getHttpServer())
      .patch('/admin/categories/reorder')
      .send({ items: VALID_ITEMS })
      .expect(204);

    expect(mockService.reorder).toHaveBeenCalled();
    expect(mockService.update).not.toHaveBeenCalled();
  });
});

// ---------------------------------------------------------------------------
// Tests — PATCH /admin/categories/:id
// ---------------------------------------------------------------------------

describe('AdminCategoriesController — PATCH /admin/categories/:id', () => {
  let app: INestApplication;
  let mockService: ReturnType<typeof createMockCategoriesService>;
  const ADMIN_USER = { sub: 'admin-001', role: 'admin' };

  beforeEach(async () => {
    mockService = createMockCategoriesService();
    app = await buildApp(mockService, { jwtUser: ADMIN_USER });
  });

  afterEach(async () => {
    await app.close();
    jest.restoreAllMocks();
  });

  it('updates a category and returns updated record', async () => {
    const res = await request(app.getHttpServer())
      .patch('/admin/categories/cat-uuid-001')
      .send({ name: 'Updated Name' })
      .expect(200);

    expect(res.body).toMatchObject({ name: 'Updated Name' });
    expect(mockService.update).toHaveBeenCalledWith(
      'cat-uuid-001',
      expect.objectContaining({ name: 'Updated Name' }),
    );
  });

  it('passes only supplied fields to service (partial update)', async () => {
    await request(app.getHttpServer())
      .patch('/admin/categories/cat-uuid-001')
      .send({ isPublished: false })
      .expect(200);

    expect(mockService.update).toHaveBeenCalledWith(
      'cat-uuid-001',
      expect.objectContaining({ isPublished: false }),
    );
  });

  it('returns 400 when slug has invalid characters', async () => {
    await request(app.getHttpServer())
      .patch('/admin/categories/cat-uuid-001')
      .send({ slug: 'UPPERCASE' })
      .expect(400);
  });

  it('returns 400 when sortOrder is negative', async () => {
    await request(app.getHttpServer())
      .patch('/admin/categories/cat-uuid-001')
      .send({ sortOrder: -5 })
      .expect(400);
  });

  it('propagates NotFoundException from service as 404', async () => {
    const { NotFoundException } = await import('@nestjs/common');
    mockService.update.mockRejectedValueOnce(new NotFoundException('Category not found'));

    await request(app.getHttpServer())
      .patch('/admin/categories/nonexistent-id')
      .send({ name: 'New Name' })
      .expect(404);
  });
});

// ---------------------------------------------------------------------------
// Tests — DELETE /admin/categories/:id
// ---------------------------------------------------------------------------

describe('AdminCategoriesController — DELETE /admin/categories/:id', () => {
  let app: INestApplication;
  let mockService: ReturnType<typeof createMockCategoriesService>;
  const ADMIN_USER = { sub: 'admin-001', role: 'admin' };

  beforeEach(async () => {
    mockService = createMockCategoriesService();
    app = await buildApp(mockService, { jwtUser: ADMIN_USER });
  });

  afterEach(async () => {
    await app.close();
    jest.restoreAllMocks();
  });

  it('soft-deletes a category and returns 204 No Content', async () => {
    await request(app.getHttpServer())
      .delete('/admin/categories/cat-uuid-001')
      .expect(204);

    expect(mockService.softDelete).toHaveBeenCalledWith('cat-uuid-001');
  });

  it('propagates NotFoundException from service as 404', async () => {
    const { NotFoundException } = await import('@nestjs/common');
    mockService.softDelete.mockRejectedValueOnce(new NotFoundException('Category not found'));

    await request(app.getHttpServer())
      .delete('/admin/categories/nonexistent-id')
      .expect(404);
  });

  it('does not hard-delete — only calls softDelete on service', async () => {
    await request(app.getHttpServer())
      .delete('/admin/categories/cat-uuid-001')
      .expect(204);

    // Ensure no hard-delete method was called; service exposes only softDelete
    expect(mockService.softDelete).toHaveBeenCalledTimes(1);
    expect(mockService.softDelete).toHaveBeenCalledWith('cat-uuid-001');
  });
});
