import { Module } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { SentryModule } from '@sentry/nestjs/setup';
import { DatabaseModule } from './database/database.module';
import { SESEmailModule } from './email/ses-email.module';
import { UpstashRateLimiterModule } from './ratelimit/upstash-ratelimit.module';
import { AuthModule } from './auth/auth.module';
import { TtsModule } from './tts/tts.module';
import { PlansModule } from './plans/plans.module';
import { SyncModule } from './sync/sync.module';
import { HealthController } from './health.controller';
import { ApiLoggerInterceptor } from './common/api-logger.interceptor';

@Module({
  imports: [
    SentryModule.forRoot(),

    // Global service modules (Neon PostgreSQL, SES, Upstash rate limiter).
    // These are @Global() — all feature modules can inject their services
    // without importing these modules individually.
    DatabaseModule,
    SESEmailModule,
    UpstashRateLimiterModule,

    // Feature modules.
    AuthModule,
    TtsModule,
    PlansModule,
    SyncModule,
  ],
  controllers: [HealthController],
  providers: [
    { provide: APP_INTERCEPTOR, useClass: ApiLoggerInterceptor },
  ],
})
export class AppModule {}
