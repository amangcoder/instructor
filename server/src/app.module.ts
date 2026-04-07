import { Module } from '@nestjs/common';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { DatabaseModule } from './database/database.module';
import { RedisModule } from './redis/redis.module';
import { RedisThrottlerStorage } from './redis/redis-throttler.storage';
import { AuthModule } from './auth/auth.module';
import { TtsModule } from './tts/tts.module';
import { PlansModule } from './plans/plans.module';
import { SyncModule } from './sync/sync.module';
import { HealthController } from './health.controller';
import { ApiLoggerInterceptor } from './common/api-logger.interceptor';

@Module({
  imports: [
    // Global Redis connection (must be before ThrottlerModule).
    RedisModule,

    // Rate limit: 60 requests per minute per IP (Redis-backed).
    ThrottlerModule.forRootAsync({
      useFactory: (storage: RedisThrottlerStorage) => ({
        throttlers: [{ ttl: 60_000, limit: 60 }],
        storage,
      }),
      inject: [RedisThrottlerStorage],
    }),

    // Foundation: global database service.
    DatabaseModule,

    // Feature modules.
    AuthModule,
    TtsModule,
    PlansModule,
    SyncModule,
  ],
  controllers: [HealthController],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_INTERCEPTOR, useClass: ApiLoggerInterceptor },
  ],
})
export class AppModule {}
