import { Module } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { DynamoDBModule } from './dynamodb/dynamodb.module';
import { SESEmailModule } from './email/ses-email.module';
import { DynamoDBRateLimiterModule } from './ratelimit/dynamodb-ratelimit.module';
import { AuthModule } from './auth/auth.module';
import { TtsModule } from './tts/tts.module';
import { PlansModule } from './plans/plans.module';
import { SyncModule } from './sync/sync.module';
import { HealthController } from './health.controller';
import { ApiLoggerInterceptor } from './common/api-logger.interceptor';

@Module({
  imports: [
    // Global AWS service modules (DynamoDB, SES, rate limiter).
    // These are @Global() — all feature modules can inject their services
    // without importing these modules individually.
    DynamoDBModule,
    SESEmailModule,
    DynamoDBRateLimiterModule,

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
