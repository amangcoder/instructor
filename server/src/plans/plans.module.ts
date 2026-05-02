import { Module } from '@nestjs/common';
import { PlansController } from './plans.controller';
import { PlansService } from './plans.service';
import { SharingController } from './sharing.controller';
import { SharingService } from './sharing.service';
import { PlanRequestsController } from './plan-requests.controller';
import { PlanRequestsService } from './plan-requests.service';
import { AdminPlansController } from './admin-plans.controller';
import { AdminPlanRequestsController } from './admin-plan-requests.controller';
import { PlanRequestPromoteService } from './plan-request-promote.service';
import { AuthModule } from '../auth/auth.module';
import { TtsModule } from '../tts/tts.module';
import { UpstashRateLimiterModule } from '../ratelimit/upstash-ratelimit.module';

@Module({
  imports: [AuthModule, TtsModule, UpstashRateLimiterModule],
  controllers: [PlansController, SharingController, PlanRequestsController, AdminPlansController, AdminPlanRequestsController],
  providers: [PlansService, SharingService, PlanRequestsService, PlanRequestPromoteService],
})
export class PlansModule {}
