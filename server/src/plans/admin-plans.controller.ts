import {
  Controller,
  Get,
  Patch,
  Body,
  Param,
  ParseUUIDPipe,
  UseGuards,
  Logger,
  HttpCode,
} from '@nestjs/common';
import { PlansService } from './plans.service';
import { AdminUpdatePlanDto } from './dto/admin-update-plan.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRoleGuard } from '../auth/admin-role.guard';

/**
 * AdminPlansController — admin-only plan management endpoints.
 *
 * SECURITY: Both JwtAuthGuard and AdminRoleGuard are applied at the class level.
 * JwtAuthGuard must come first (populates req.user), then AdminRoleGuard checks role='admin'.
 */
@Controller('admin/plans')
@UseGuards(JwtAuthGuard, AdminRoleGuard)
export class AdminPlansController {
  private readonly logger = new Logger(AdminPlansController.name);

  constructor(private readonly plansService: PlansService) {}

  /**
   * GET /api/admin/plans/:id
   * Returns a plan's hierarchy/publish fields for the admin detail page.
   */
  @Get(':id')
  async getPlan(
    @Param('id', new ParseUUIDPipe({ version: '4' })) planId: string,
  ) {
    this.logger.log(`GET /admin/plans/${planId}`);
    return this.plansService.getAdminPlanDetail(planId);
  }

  /**
   * PATCH /api/admin/plans/:id
   * Update plan hierarchy fields: parent_plan_id, position, visibility, is_published.
   * Enforces max depth of 3 when setting parent_plan_id.
   */
  @Patch(':id')
  @HttpCode(200)
  async updatePlan(
    @Param('id', new ParseUUIDPipe({ version: '4' })) planId: string,
    @Body() dto: AdminUpdatePlanDto,
  ): Promise<{ success: boolean }> {
    this.logger.log(
      `PATCH /admin/plans/${planId} — fields=${Object.keys(dto).join(',')}`,
    );
    await this.plansService.adminUpdatePlan(planId, {
      parentPlanId: dto.parentPlanId,
      position: dto.position,
      visibility: dto.visibility,
      isPublished: dto.isPublished,
      name: dto.name,
      description: dto.description,
      category: dto.category,
      tags: dto.tags,
      defaultVoice: dto.defaultVoice,
      stepEdits: dto.stepEdits,
      planJson: dto.planJson,
    });
    return { success: true };
  }
}
