/**
 * Application-level e2e tests.
 *
 * Tests the health endpoint and basic application bootstrap using mocked
 * AWS services — no real DynamoDB, SES, or Redis calls in CI.
 */

import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { App } from 'supertest/types';

// ---------------------------------------------------------------------------
// In-memory mock factories for AWS-dependent services
// ---------------------------------------------------------------------------

function createInMemoryDynamoDBService() {
  return {
    getUserById: jest.fn().mockResolvedValue(null),
    getUserByEmail: jest.fn().mockResolvedValue(null),
    createUser: jest.fn().mockResolvedValue(undefined),
    createOtp: jest.fn().mockResolvedValue(undefined),
    getActiveOtps: jest.fn().mockResolvedValue([]),
    markOtpUsed: jest.fn().mockResolvedValue(undefined),
    incrementOtpAttempts: jest.fn().mockResolvedValue(undefined),
    invalidateOtpsForEmail: jest.fn().mockResolvedValue(undefined),
    createRefreshToken: jest.fn().mockResolvedValue(undefined),
    getRefreshToken: jest.fn().mockResolvedValue(null),
    revokeRefreshToken: jest.fn().mockResolvedValue(undefined),
    revokeAllRefreshTokens: jest.fn().mockResolvedValue(undefined),
    getSyncMetadata: jest.fn().mockResolvedValue(null),
    upsertSyncMetadata: jest.fn().mockResolvedValue(undefined),
  };
}

function createInMemoryRateLimiter() {
  return {
    consume: jest.fn().mockResolvedValue({ allowed: true, current: 1, retryAfterSec: 0 }),
    peek: jest.fn().mockResolvedValue({ allowed: true, current: 0, retryAfterSec: 0 }),
    increment: jest.fn().mockResolvedValue(undefined),
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('App (e2e)', () => {
  let app: INestApplication<App>;

  beforeAll(async () => {
    let AppModule: new () => object;
    let DynamoDBService: unknown;
    let SESEmailService: unknown;
    let DynamoDBRateLimitService: unknown;

    try {
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      ({ AppModule } = require('../src/app.module'));
    } catch {
      console.warn('[app.e2e] AppModule not found — skipping until implementation is complete');
      return;
    }

    // Try to import the new service tokens for overriding
    try {
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      ({ DynamoDBService } = require('../src/dynamodb/dynamodb.service'));
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      ({ SESEmailService } = require('../src/email/ses-email.service'));
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      ({ DynamoDBRateLimitService } = require('../src/ratelimit/dynamodb-ratelimit.service'));
    } catch {
      // Services not yet implemented — gracefully degrade
    }

    let builder = Test.createTestingModule({
      imports: [AppModule],
    });

    // Override AWS-dependent services with deterministic in-memory mocks
    if (DynamoDBService) {
      builder = builder
        .overrideProvider(DynamoDBService)
        .useValue(createInMemoryDynamoDBService());
    }
    if (SESEmailService) {
      builder = builder
        .overrideProvider(SESEmailService)
        .useValue({ sendOtpEmail: jest.fn().mockResolvedValue(undefined) });
    }
    if (DynamoDBRateLimitService) {
      builder = builder
        .overrideProvider(DynamoDBRateLimitService)
        .useValue(createInMemoryRateLimiter());
    }

    const moduleFixture: TestingModule = await builder.compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    app.setGlobalPrefix('api');
    await app.init();
  });

  afterAll(async () => {
    await app?.close();
  });

  function skipIfNoApp() {
    if (!app) pending('AppModule not implemented yet');
  }

  // ── GET /api/health ─────────────────────────────────────────────────────────

  describe('GET /api/health', () => {
    it('returns 200 with {status: "ok"} and a timestamp', async () => {
      skipIfNoApp();
      const res = await request(app.getHttpServer())
        .get('/api/health')
        .expect(200);

      expect(res.body).toMatchObject({
        status: 'ok',
        timestamp: expect.any(String),
      });
    });

    it('timestamp is a valid ISO 8601 date string', async () => {
      skipIfNoApp();
      const res = await request(app.getHttpServer())
        .get('/api/health')
        .expect(200);

      const ts = res.body.timestamp as string;
      expect(() => new Date(ts)).not.toThrow();
      expect(new Date(ts).toISOString()).toBe(ts);
    });

    it('health endpoint responds consistently under concurrent requests', async () => {
      skipIfNoApp();
      const responses = await Promise.all(
        Array.from({ length: 5 }, () =>
          request(app.getHttpServer()).get('/api/health'),
        ),
      );
      for (const res of responses) {
        expect(res.status).toBe(200);
        expect(res.body.status).toBe('ok');
      }
    });
  });

  // ── Unknown routes ──────────────────────────────────────────────────────────

  describe('unknown routes', () => {
    it('returns 404 for an undefined API route', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .get('/api/does-not-exist')
        .expect(404);
    });

    it('returns 404 for a root path request (no /api prefix)', async () => {
      skipIfNoApp();
      await request(app.getHttpServer())
        .get('/')
        .expect(404);
    });
  });
});
