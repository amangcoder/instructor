/**
 * AdminAnalyticsController — analytics endpoints for the admin dashboard.
 *
 * All routes: GET/PATCH /api/admin/analytics/*
 *
 * SECURITY: @UseGuards(JwtAuthGuard, AdminRoleGuard) is applied at the class level
 * so every endpoint is protected by default.
 *   - JwtAuthGuard  → validates Bearer token, populates req.user (401 on failure)
 *   - AdminRoleGuard → checks req.user.role === 'admin' (403 on non-admin)
 *
 * Rate limiting: 60 requests/min per admin JWT sub via UpstashRateLimitService.
 *
 * Range validation: range-accepting handlers call validateRange() from the DTO,
 * which defaults to '30d' and throws BadRequestException (400) on invalid values.
 */

import {
  Controller,
  Get,
  HttpException,
  HttpStatus,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRoleGuard } from '../auth/admin-role.guard';
import { AdminAnalyticsService } from './admin-analytics.service';
import { RetentionAnalyticsService } from './retention-analytics.service';
import { TtsHealthService } from './tts-health.service';
import { LibraryCategoryService } from './library-category.service';
import { ActivityFeedService } from './activity-feed.service';
import { UpstashRateLimitService } from '../ratelimit/upstash-ratelimit.service';
import { validateRange } from './dto/range-query.dto';
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
import type { JwtPayload } from '../auth/auth.service';

/** 60 admin analytics requests per minute per admin JWT sub */
const ADMIN_ANALYTICS_RATE_LIMIT = 60;
const ADMIN_ANALYTICS_RATE_WINDOW_SEC = 60;

@Controller('admin/analytics')
@UseGuards(JwtAuthGuard, AdminRoleGuard)
export class AdminAnalyticsController {
  constructor(
    private readonly analyticsService: AdminAnalyticsService,
    private readonly retentionService: RetentionAnalyticsService,
    private readonly ttsHealthService: TtsHealthService,
    private readonly libraryCategoryService: LibraryCategoryService,
    private readonly activityFeedService: ActivityFeedService,
    private readonly rateLimit: UpstashRateLimitService,
  ) {}

  /**
   * Enforce per-admin rate limiting (60 req/min per admin JWT sub).
   */
  private async enforceRateLimit(req: Request & { user?: JwtPayload }): Promise<void> {
    const sub = req.user?.sub ?? 'unknown';
    const result = await this.rateLimit.consume(
      'admin-analytics',
      sub,
      ADMIN_ANALYTICS_RATE_LIMIT,
      ADMIN_ANALYTICS_RATE_WINDOW_SEC,
    );
    if (!result.allowed) {
      throw new HttpException(
        `Too many requests. Try again in ${result.retryAfterSec} seconds.`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  // -------------------------------------------------------------------------
  // 1. GET /api/admin/analytics/overview?range=7d|30d|90d
  //    Top-line counts with range-configurable deltas (default 30d).
  //    Includes weeklyPlansPlayed with sparkline and planCompletionRate.
  // -------------------------------------------------------------------------

  @Get('overview')
  async getOverview(
    @Query('range') range?: string,
    @Req() req?: Request & { user?: JwtPayload },
  ): Promise<OverviewResponse> {
    if (req) await this.enforceRateLimit(req);
    return this.analyticsService.getOverview(validateRange(range));
  }

  // -------------------------------------------------------------------------
  // 2. GET /api/admin/analytics/users/signups?range=7d|30d|90d
  //    Daily time series of new user registrations.
  // -------------------------------------------------------------------------

  @Get('users/signups')
  getUserSignups(@Query('range') range?: string): Promise<SignupsResponse> {
    return this.analyticsService.getUserSignups(validateRange(range));
  }

  // -------------------------------------------------------------------------
  // 3. GET /api/admin/analytics/users/activation?range=7d|30d|90d
  //    Daily activation rate (created plan within 24h of signup).
  // -------------------------------------------------------------------------

  @Get('users/activation')
  getUserActivation(
    @Query('range') range?: string,
  ): Promise<ActivationResponse> {
    return this.analyticsService.getUserActivation(validateRange(range));
  }

  // -------------------------------------------------------------------------
  // 4. GET /api/admin/analytics/plans/funnel?range=7d|30d|90d
  //    Plan lifecycle funnel: created → tts_started → tts_completed → activated.
  // -------------------------------------------------------------------------

  @Get('plans/funnel')
  getPlanFunnel(@Query('range') range?: string): Promise<FunnelResponse> {
    return this.analyticsService.getPlanFunnel(validateRange(range));
  }

  // -------------------------------------------------------------------------
  // 5. GET /api/admin/analytics/plans/usage?range=7d|30d|90d
  //    Plans-per-user distribution + active vs dormant breakdown.
  // -------------------------------------------------------------------------

  @Get('plans/usage')
  getPlanUsage(@Query('range') range?: string): Promise<PlanUsageResponse> {
    return this.analyticsService.getPlanUsage(validateRange(range));
  }

  // -------------------------------------------------------------------------
  // 6. GET /api/admin/analytics/tts/volume?range=7d|30d|90d
  //    Daily TTS job counts grouped by provider and voiceId.
  // -------------------------------------------------------------------------

  @Get('tts/volume')
  getTtsVolume(@Query('range') range?: string): Promise<TtsVolumeResponse> {
    return this.analyticsService.getTtsVolume(validateRange(range));
  }

  // -------------------------------------------------------------------------
  // 7. GET /api/admin/analytics/tts/errors?range=7d|30d|90d
  //    Daily TTS error counts + top sanitized error messages.
  // -------------------------------------------------------------------------

  @Get('tts/errors')
  getTtsErrors(@Query('range') range?: string): Promise<TtsErrorsResponse> {
    return this.analyticsService.getTtsErrors(validateRange(range));
  }

  // -------------------------------------------------------------------------
  // 8. GET /api/admin/analytics/engagement/streaks
  //    Distribution of active streak lengths. No range — uses fixed 90d window.
  // -------------------------------------------------------------------------

  @Get('engagement/streaks')
  getEngagementStreaks(): Promise<StreaksResponse> {
    return this.analyticsService.getEngagementStreaks();
  }

  // -------------------------------------------------------------------------
  // 9. GET /api/admin/analytics/library?range=7d|30d|90d
  //    Library plan adoption and conversion table.
  // -------------------------------------------------------------------------

  @Get('library')
  getLibraryConversions(
    @Query('range') range?: string,
  ): Promise<LibraryResponse> {
    return this.analyticsService.getLibraryConversions(validateRange(range));
  }

  // -------------------------------------------------------------------------
  // 10. GET /api/admin/analytics/engagement/retention (TASK-002)
  //     D7 and D30 cohort retention rates.
  // -------------------------------------------------------------------------

  @Get('engagement/retention')
  getRetention(): Promise<RetentionResponse> {
    return this.retentionService.getRetention();
  }

  // -------------------------------------------------------------------------
  // 11. GET /api/admin/analytics/engagement/active-users?range (TASK-002)
  //     DAU/WAU/MAU time series.
  // -------------------------------------------------------------------------

  @Get('engagement/active-users')
  getActiveUsers(
    @Query('range') range?: string,
  ): Promise<ActiveUsersResponse> {
    return this.retentionService.getActiveUsers(validateRange(range));
  }

  // -------------------------------------------------------------------------
  // 12. GET /api/admin/analytics/tts/health (TASK-003)
  //     TTS provider health status derived from tts_jobs table.
  // -------------------------------------------------------------------------

  @Get('tts/health')
  getTtsHealth(): Promise<TtsHealthResponse> {
    return this.ttsHealthService.getTtsHealth();
  }

  // -------------------------------------------------------------------------
  // 13. GET /api/admin/analytics/library/categories?range (TASK-004)
  //     Library plan category breakdown.
  // -------------------------------------------------------------------------

  @Get('library/categories')
  getLibraryCategories(
    @Query('range') range?: string,
  ): Promise<LibraryCategoryResponse> {
    return this.libraryCategoryService.getLibraryCategories(validateRange(range));
  }

  // -------------------------------------------------------------------------
  // 14-17. Deletion requests (TASK-005, TASK-007)
  //     All deletion-request endpoints are handled by the dedicated
  //     DeletionRequestsAdminController (admin/analytics/deletion-requests).
  //     This avoids duplicate route registrations.
  // -------------------------------------------------------------------------

  // -------------------------------------------------------------------------
  // 18. GET /api/admin/analytics/overview/activity (TASK-008)
  //     Recent activity feed (last 10 events).
  // -------------------------------------------------------------------------

  @Get('overview/activity')
  getRecentActivity(): Promise<ActivityFeedResponse> {
    return this.activityFeedService.getRecentActivity();
  }
}
