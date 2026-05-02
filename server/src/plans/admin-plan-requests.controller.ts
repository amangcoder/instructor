/**
 * AdminPlanRequestsController — admin-only plan-request management endpoints.
 *
 * SECURITY: Both JwtAuthGuard and AdminRoleGuard are applied at the class level.
 * JwtAuthGuard must come first (populates req.user), then AdminRoleGuard checks role='admin'.
 */

import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Logger,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRoleGuard } from '../auth/admin-role.guard';
import { PlanRequestPromoteService } from './plan-request-promote.service';
import { PromotePlanRequestDto } from './dto/promote-plan-request.dto';

@Controller('admin/plan-requests')
@UseGuards(JwtAuthGuard, AdminRoleGuard)
export class AdminPlanRequestsController {
  private readonly logger = new Logger(AdminPlanRequestsController.name);

  constructor(
    private readonly promoteService: PlanRequestPromoteService,
  ) {}

  /**
   * POST /api/admin/plan-requests/:id/promote
   *
   * Atomically creates a plan + N plan_voices rows from a pending plan request,
   * then enqueues TTS batch jobs post-commit.
   *
   * Returns 201 with { planId }.
   */
  @Post(':id/promote')
  @HttpCode(HttpStatus.CREATED)
  async promote(
    @Param('id', new ParseUUIDPipe({ version: '4' })) planRequestId: string,
    @Body() dto: PromotePlanRequestDto,
  ): Promise<{ planId: string }> {
    this.logger.log(
      `POST /admin/plan-requests/${planRequestId}/promote — voices=${dto.voiceIds.length}`,
    );

    const result = await this.promoteService.promote(
      planRequestId,
      dto.voiceIds,
      dto.seriesId,
      dto.categoryId,
      dto.position,
    );

    return { planId: result.planId };
  }
}
