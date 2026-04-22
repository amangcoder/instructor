/**
 * Unit tests for AdminAnalyticsController.
 *
 * Tests:
 *   - All handlers delegate to the correct service method
 *   - Range-accepting handlers default to '30d' when ?range is omitted
 *   - Invalid ?range values throw BadRequestException (400) — AC-013
 *   - Endpoints without range call service directly
 *   - New TASK-002/003/004/008 endpoints delegate correctly
 *   - Rate limiting on overview endpoint
 *
 * Guard behaviour (AC-004 role='user'→403, AC-005 no token→401) is exercised
 * in e2e tests; here guards are overridden so we can test handler logic in isolation.
 */

import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, HttpException } from '@nestjs/common';
import { AdminAnalyticsController } from './admin-analytics.controller';
import { AdminAnalyticsService } from './admin-analytics.service';
import { RetentionAnalyticsService } from './retention-analytics.service';
import { TtsHealthService } from './tts-health.service';
import { LibraryCategoryService } from './library-category.service';
import { ActivityFeedService } from './activity-feed.service';
import { UpstashRateLimitService } from '../ratelimit/upstash-ratelimit.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRoleGuard } from '../auth/admin-role.guard';
import type {
  OverviewResponse,
  SignupsResponse,
  ActivationResponse,
  FunnelResponse,
  PlanUsageResponse,
  TtsVolumeResponse,
  TtsErrorsResponse,
  StreaksResponse,
  LibraryResponse,
} from '../admin/dto/analytics.dto';
import type { RetentionResponse, ActiveUsersResponse } from './dto/retention.dto';
import type { TtsHealthResponse } from './dto/tts-health.dto';
import type { LibraryCategoryResponse } from './dto/library-category.dto';
import type { ActivityFeedResponse } from './dto/activity-feed.dto';

// ---------------------------------------------------------------------------
// Mock factories
// ---------------------------------------------------------------------------

function createMockAnalyticsService(): jest.Mocked<AdminAnalyticsService> {
  return {
    getOverview: jest
      .fn()
      .mockResolvedValue({ series: [], totals: {} } as unknown as OverviewResponse),
    getUserSignups: jest
      .fn()
      .mockResolvedValue({ series: [], totals: {} } as unknown as SignupsResponse),
    getUserActivation: jest
      .fn()
      .mockResolvedValue({ series: [], totals: {} } as unknown as ActivationResponse),
    getPlanFunnel: jest
      .fn()
      .mockResolvedValue({ series: [], totals: {} } as unknown as FunnelResponse),
    getPlanUsage: jest
      .fn()
      .mockResolvedValue({ series: [], totals: {} } as unknown as PlanUsageResponse),
    getTtsVolume: jest
      .fn()
      .mockResolvedValue({ series: [], totals: {} } as unknown as TtsVolumeResponse),
    getTtsErrors: jest
      .fn()
      .mockResolvedValue({ series: [], totals: {} } as unknown as TtsErrorsResponse),
    getEngagementStreaks: jest
      .fn()
      .mockResolvedValue({ distribution: [], totals: {} } as unknown as StreaksResponse),
    getLibraryConversions: jest
      .fn()
      .mockResolvedValue({ rows: [], totals: {} } as unknown as LibraryResponse),
  } as unknown as jest.Mocked<AdminAnalyticsService>;
}

function createMockRetentionService(): jest.Mocked<RetentionAnalyticsService> {
  return {
    getRetention: jest.fn().mockResolvedValue({
      d7: { rate: 0.15, cohortSize: 100, retainedCount: 15, delta: 2.1 },
      d30: { rate: 0.08, cohortSize: 100, retainedCount: 8, delta: -1.0 },
    } as RetentionResponse),
    getActiveUsers: jest.fn().mockResolvedValue({
      dau: [],
      wau: [],
      mau: [],
    } as ActiveUsersResponse),
  } as unknown as jest.Mocked<RetentionAnalyticsService>;
}

function createMockTtsHealthService(): jest.Mocked<TtsHealthService> {
  return {
    getTtsHealth: jest.fn().mockResolvedValue({
      providers: [
        { provider: 'kokoro', status: 'healthy', errorRateLast60m: 0.01, lastSuccessAt: new Date().toISOString() },
      ],
    } as TtsHealthResponse),
  } as unknown as jest.Mocked<TtsHealthService>;
}

function createMockLibraryCategoryService(): jest.Mocked<LibraryCategoryService> {
  return {
    getLibraryCategories: jest.fn().mockResolvedValue({
      categories: [],
    } as LibraryCategoryResponse),
  } as unknown as jest.Mocked<LibraryCategoryService>;
}

function createMockActivityFeedService(): jest.Mocked<ActivityFeedService> {
  return {
    getRecentActivity: jest.fn().mockResolvedValue({
      events: [],
    } as ActivityFeedResponse),
  } as unknown as jest.Mocked<ActivityFeedService>;
}

function createMockRateLimiter(): jest.Mocked<UpstashRateLimitService> {
  return {
    consume: jest.fn().mockResolvedValue({ allowed: true, retryAfterSec: 0 }),
  } as unknown as jest.Mocked<UpstashRateLimitService>;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('AdminAnalyticsController', () => {
  let controller: AdminAnalyticsController;
  let analyticsService: jest.Mocked<AdminAnalyticsService>;
  let retentionService: jest.Mocked<RetentionAnalyticsService>;
  let ttsHealthService: jest.Mocked<TtsHealthService>;
  let libraryCategoryService: jest.Mocked<LibraryCategoryService>;
  let activityFeedService: jest.Mocked<ActivityFeedService>;
  let rateLimit: jest.Mocked<UpstashRateLimitService>;

  beforeEach(async () => {
    analyticsService = createMockAnalyticsService();
    retentionService = createMockRetentionService();
    ttsHealthService = createMockTtsHealthService();
    libraryCategoryService = createMockLibraryCategoryService();
    activityFeedService = createMockActivityFeedService();
    rateLimit = createMockRateLimiter();

    const module: TestingModule = await Test.createTestingModule({
      controllers: [AdminAnalyticsController],
      providers: [
        { provide: AdminAnalyticsService, useValue: analyticsService },
        { provide: RetentionAnalyticsService, useValue: retentionService },
        { provide: TtsHealthService, useValue: ttsHealthService },
        { provide: LibraryCategoryService, useValue: libraryCategoryService },
        { provide: ActivityFeedService, useValue: activityFeedService },
        { provide: UpstashRateLimitService, useValue: rateLimit },
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({ canActivate: () => true })
      .overrideGuard(AdminRoleGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<AdminAnalyticsController>(AdminAnalyticsController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  // -------------------------------------------------------------------------
  // Guard metadata
  // -------------------------------------------------------------------------

  describe('Guard metadata', () => {
    it('applies JwtAuthGuard at class level', () => {
      const guards = Reflect.getMetadata('__guards__', AdminAnalyticsController);
      expect(guards).toBeDefined();
      expect(guards).toContain(JwtAuthGuard);
    });

    it('applies AdminRoleGuard at class level', () => {
      const guards = Reflect.getMetadata('__guards__', AdminAnalyticsController);
      expect(guards).toBeDefined();
      expect(guards).toContain(AdminRoleGuard);
    });

    it('JwtAuthGuard is listed before AdminRoleGuard (order matters: auth before role)', () => {
      const guards = Reflect.getMetadata('__guards__', AdminAnalyticsController);
      const jwtIdx = guards.indexOf(JwtAuthGuard);
      const adminIdx = guards.indexOf(AdminRoleGuard);
      expect(jwtIdx).toBeGreaterThanOrEqual(0);
      expect(adminIdx).toBeGreaterThanOrEqual(0);
      expect(jwtIdx).toBeLessThan(adminIdx);
    });
  });

  // -------------------------------------------------------------------------
  // 1. overview — with range + rate limiting (TASK-001)
  // -------------------------------------------------------------------------

  describe('getOverview()', () => {
    it('delegates to analyticsService.getOverview() with default 30d range', async () => {
      await controller.getOverview();
      expect(analyticsService.getOverview).toHaveBeenCalledWith('30d');
    });

    it('passes validated range to service', async () => {
      await controller.getOverview('7d');
      expect(analyticsService.getOverview).toHaveBeenCalledWith('7d');
    });

    it('passes 90d range to service', async () => {
      await controller.getOverview('90d');
      expect(analyticsService.getOverview).toHaveBeenCalledWith('90d');
    });

    it('throws BadRequestException for invalid range', async () => {
      await expect(controller.getOverview('15d')).rejects.toBeInstanceOf(BadRequestException);
    });

    it('enforces rate limiting when req is provided', async () => {
      const req = { user: { sub: 'admin-123' } } as any;
      await controller.getOverview(undefined, req);
      expect(rateLimit.consume).toHaveBeenCalledWith(
        'admin-analytics',
        'admin-123',
        60,
        60,
      );
    });

    it('throws 429 when rate limit is exceeded', async () => {
      rateLimit.consume.mockResolvedValueOnce({ allowed: false, retryAfterSec: 30 } as any);
      const req = { user: { sub: 'admin-123' } } as any;
      await expect(controller.getOverview(undefined, req)).rejects.toThrow(HttpException);
    });
  });

  // -------------------------------------------------------------------------
  // 2. users/signups — range
  // -------------------------------------------------------------------------

  describe('getUserSignups()', () => {
    it('defaults to 30d when range is undefined', async () => {
      await controller.getUserSignups(undefined);
      expect(analyticsService.getUserSignups).toHaveBeenCalledWith('30d');
    });

    it('defaults to 30d when range is empty string', async () => {
      await controller.getUserSignups('');
      expect(analyticsService.getUserSignups).toHaveBeenCalledWith('30d');
    });

    it('passes 7d range to service', async () => {
      await controller.getUserSignups('7d');
      expect(analyticsService.getUserSignups).toHaveBeenCalledWith('7d');
    });

    it('throws BadRequestException for invalid range "15d" — AC-013', async () => {
      await expect(controller.getUserSignups('15d')).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  // -------------------------------------------------------------------------
  // 3. users/activation — range
  // -------------------------------------------------------------------------

  describe('getUserActivation()', () => {
    it('defaults to 30d when range is undefined', async () => {
      await controller.getUserActivation(undefined);
      expect(analyticsService.getUserActivation).toHaveBeenCalledWith('30d');
    });

    it('throws 400 for invalid range "60d"', async () => {
      await expect(controller.getUserActivation('60d')).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  // -------------------------------------------------------------------------
  // 4. plans/funnel — range
  // -------------------------------------------------------------------------

  describe('getPlanFunnel()', () => {
    it('defaults to 30d when range is undefined', async () => {
      await controller.getPlanFunnel(undefined);
      expect(analyticsService.getPlanFunnel).toHaveBeenCalledWith('30d');
    });

    it('throws 400 for invalid range "1d"', async () => {
      await expect(controller.getPlanFunnel('1d')).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  // -------------------------------------------------------------------------
  // 5. plans/usage — range
  // -------------------------------------------------------------------------

  describe('getPlanUsage()', () => {
    it('defaults to 30d when range is undefined', async () => {
      await controller.getPlanUsage(undefined);
      expect(analyticsService.getPlanUsage).toHaveBeenCalledWith('30d');
    });

    it('passes 90d range', async () => {
      await controller.getPlanUsage('90d');
      expect(analyticsService.getPlanUsage).toHaveBeenCalledWith('90d');
    });
  });

  // -------------------------------------------------------------------------
  // 6. tts/volume — range
  // -------------------------------------------------------------------------

  describe('getTtsVolume()', () => {
    it('defaults to 30d when range is undefined', async () => {
      await controller.getTtsVolume(undefined);
      expect(analyticsService.getTtsVolume).toHaveBeenCalledWith('30d');
    });

    it('throws 400 for invalid range "15d"', async () => {
      await expect(controller.getTtsVolume('15d')).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  // -------------------------------------------------------------------------
  // 7. tts/errors — range
  // -------------------------------------------------------------------------

  describe('getTtsErrors()', () => {
    it('defaults to 30d when range is undefined', async () => {
      await controller.getTtsErrors(undefined);
      expect(analyticsService.getTtsErrors).toHaveBeenCalledWith('30d');
    });

    it('throws 400 for invalid range "week"', async () => {
      await expect(controller.getTtsErrors('week')).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  // -------------------------------------------------------------------------
  // 8. engagement/streaks — no range
  // -------------------------------------------------------------------------

  describe('getEngagementStreaks()', () => {
    it('delegates to analyticsService.getEngagementStreaks() with no args', async () => {
      await controller.getEngagementStreaks();
      expect(analyticsService.getEngagementStreaks).toHaveBeenCalledTimes(1);
    });
  });

  // -------------------------------------------------------------------------
  // 9. library — range
  // -------------------------------------------------------------------------

  describe('getLibraryConversions()', () => {
    it('defaults to 30d when range is undefined', async () => {
      await controller.getLibraryConversions(undefined);
      expect(analyticsService.getLibraryConversions).toHaveBeenCalledWith('30d');
    });

    it('throws 400 for invalid range "15d" — AC-013', async () => {
      await expect(controller.getLibraryConversions('15d')).rejects.toBeInstanceOf(BadRequestException);
    });

    it('passes 7d range', async () => {
      await controller.getLibraryConversions('7d');
      expect(analyticsService.getLibraryConversions).toHaveBeenCalledWith('7d');
    });
  });

  // -------------------------------------------------------------------------
  // 10. engagement/retention — TASK-002 (no range)
  // -------------------------------------------------------------------------

  describe('getRetention()', () => {
    it('delegates to retentionService.getRetention()', async () => {
      const result = await controller.getRetention();
      expect(retentionService.getRetention).toHaveBeenCalledTimes(1);
      expect(result).toHaveProperty('d7');
      expect(result).toHaveProperty('d30');
    });
  });

  // -------------------------------------------------------------------------
  // 11. engagement/active-users — TASK-002 (range)
  // -------------------------------------------------------------------------

  describe('getActiveUsers()', () => {
    it('defaults to 30d when range is undefined', async () => {
      await controller.getActiveUsers(undefined);
      expect(retentionService.getActiveUsers).toHaveBeenCalledWith('30d');
    });

    it('passes 7d range to retentionService', async () => {
      await controller.getActiveUsers('7d');
      expect(retentionService.getActiveUsers).toHaveBeenCalledWith('7d');
    });

    it('throws 400 for invalid range', async () => {
      await expect(controller.getActiveUsers('2w')).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  // -------------------------------------------------------------------------
  // 12. tts/health — TASK-003 (no range)
  // -------------------------------------------------------------------------

  describe('getTtsHealth()', () => {
    it('delegates to ttsHealthService.getTtsHealth()', async () => {
      const result = await controller.getTtsHealth();
      expect(ttsHealthService.getTtsHealth).toHaveBeenCalledTimes(1);
      expect(result).toHaveProperty('providers');
    });
  });

  // -------------------------------------------------------------------------
  // 13. library/categories — TASK-004 (range)
  // -------------------------------------------------------------------------

  describe('getLibraryCategories()', () => {
    it('defaults to 30d when range is undefined', async () => {
      await controller.getLibraryCategories(undefined);
      expect(libraryCategoryService.getLibraryCategories).toHaveBeenCalledWith('30d');
    });

    it('passes 90d range', async () => {
      await controller.getLibraryCategories('90d');
      expect(libraryCategoryService.getLibraryCategories).toHaveBeenCalledWith('90d');
    });

    it('throws 400 for invalid range', async () => {
      await expect(controller.getLibraryCategories('1y')).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  // -------------------------------------------------------------------------
  // 18. overview/activity — TASK-008 (no range)
  // -------------------------------------------------------------------------

  describe('getRecentActivity()', () => {
    it('delegates to activityFeedService.getRecentActivity()', async () => {
      const result = await controller.getRecentActivity();
      expect(activityFeedService.getRecentActivity).toHaveBeenCalledTimes(1);
      expect(result).toHaveProperty('events');
    });
  });

  // -------------------------------------------------------------------------
  // AC-013 — exhaustive invalid range check across all range-accepting endpoints
  // -------------------------------------------------------------------------

  describe('AC-013 — invalid range returns 400 for all range-accepting endpoints', () => {
    const INVALID_RANGES = ['15d', '1d', '100d', 'week', '30D'];

    type EndpointEntry = { name: string; call: (r: string) => Promise<unknown> };

    const endpoints: EndpointEntry[] = [
      { name: 'getUserSignups', call: (r) => controller.getUserSignups(r) },
      { name: 'getUserActivation', call: (r) => controller.getUserActivation(r) },
      { name: 'getPlanFunnel', call: (r) => controller.getPlanFunnel(r) },
      { name: 'getPlanUsage', call: (r) => controller.getPlanUsage(r) },
      { name: 'getTtsVolume', call: (r) => controller.getTtsVolume(r) },
      { name: 'getTtsErrors', call: (r) => controller.getTtsErrors(r) },
      { name: 'getLibraryConversions', call: (r) => controller.getLibraryConversions(r) },
      { name: 'getActiveUsers', call: (r) => controller.getActiveUsers(r) },
      { name: 'getLibraryCategories', call: (r) => controller.getLibraryCategories(r) },
    ];

    for (const endpoint of endpoints) {
      for (const range of INVALID_RANGES) {
        it(`${endpoint.name}('${range}') → BadRequestException`, async () => {
          await expect(endpoint.call(range)).rejects.toBeInstanceOf(
            BadRequestException,
          );
        });
      }
    }
  });
});
