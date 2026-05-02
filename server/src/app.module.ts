import { Module } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { SentryModule } from '@sentry/nestjs/setup';
import { AppConfigModule } from './config/app-config.module';
import { DatabaseModule } from './database/database.module';
import { SESEmailModule } from './email/ses-email.module';
import { UpstashRateLimiterModule } from './ratelimit/upstash-ratelimit.module';
import { WorkerDispatchModule } from './worker-dispatch/worker-dispatch.module';
import { AuthModule } from './auth/auth.module';
import { TtsModule } from './tts/tts.module';
import { PlansModule } from './plans/plans.module';
import { LibraryModule } from './library/library.module';
import { SeriesModule } from './series/series.module';
import { CategoriesModule } from './categories/categories.module';
import { PlanVoicesModule } from './plan-voices/plan-voices.module';
import { AdminModule } from './admin/admin.module';
import { AdminAnalyticsModule } from './admin-analytics/admin-analytics.module';
import { SyncModule } from './sync/sync.module';
import { AppVersionModule } from './app-version/app-version.module';
import { AppConfigRuntimeModule } from './app-config/app-config-runtime.module';
import { HealthController } from './health.controller';
import { ApiLoggerInterceptor } from './common/api-logger.interceptor';

@Module({
  imports: [
    SentryModule.forRoot(),

    // Global service modules — @Global() so all feature modules can inject
    // their services without importing these modules individually.
    AppConfigModule,
    DatabaseModule,
    SESEmailModule,
    UpstashRateLimiterModule,
    WorkerDispatchModule,

    // Feature modules.
    AuthModule,
    TtsModule,
    PlansModule,
    LibraryModule,
    SeriesModule,
    CategoriesModule,
    PlanVoicesModule,
    AdminModule,
    AdminAnalyticsModule,
    SyncModule,
    AppVersionModule,
    AppConfigRuntimeModule,
  ],
  controllers: [HealthController],
  providers: [
    { provide: APP_INTERCEPTOR, useClass: ApiLoggerInterceptor },
  ],
})
export class AppModule {}
