import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AdminAnalyticsController } from './admin-analytics.controller';
import { AdminAnalyticsService } from './admin-analytics.service';
import { AdminUsersController } from './admin-users.controller';
import { AdminUsersService } from './admin-users.service';
import { RetentionAnalyticsService } from './retention-analytics.service';
import { TtsHealthService } from './tts-health.service';
import { LibraryCategoryService } from './library-category.service';
import { DeletionRequestsAdminController } from './deletion-requests-admin.controller';
import { DeletionRequestsAdminService } from './deletion-requests-admin.service';
import { PlanRequestsAdminController } from './plan-requests-admin.controller';
import { PlanRequestsAdminService } from './plan-requests-admin.service';
import { ActivityFeedService } from './activity-feed.service';
import { CsvExportService } from './csv-export.service';
import { AdminRoleGuard } from '../auth/admin-role.guard';

/**
 * AdminAnalyticsModule — analytics and admin management endpoints.
 *
 * Why JwtModule.registerAsync() and NOT AuthModule:
 *   AuthModule → SESEmailModule → (server root) creates a circular dependency.
 *   Importing JwtModule directly gives us JwtService (needed by JwtAuthGuard)
 *   without pulling in the rest of the auth dependency chain.
 *
 * Why NOT DatabaseModule:
 *   DatabaseModule is @Global() — DatabaseService is available for injection
 *   in every module without importing DatabaseModule explicitly.
 *
 * Why NOT UpstashRateLimiterModule:
 *   UpstashRateLimiterModule is @Global() — UpstashRateLimitService is
 *   available for injection without importing the module explicitly.
 */
@Module({
  imports: [
    JwtModule.registerAsync({
      useFactory: () => ({
        secret: process.env.JWT_SECRET,
        signOptions: { expiresIn: '15m' },
      }),
    }),
  ],
  controllers: [
    AdminAnalyticsController,
    AdminUsersController,
    DeletionRequestsAdminController,
    PlanRequestsAdminController,
  ],
  providers: [
    AdminAnalyticsService,
    AdminUsersService,
    RetentionAnalyticsService,
    TtsHealthService,
    LibraryCategoryService,
    DeletionRequestsAdminService,
    PlanRequestsAdminService,
    ActivityFeedService,
    CsvExportService,
    AdminRoleGuard,
  ],
})
export class AdminAnalyticsModule {}
