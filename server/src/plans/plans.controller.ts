import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  Req,
  Param,
  UseGuards,
  Logger,
  HttpCode,
  NotFoundException,
} from '@nestjs/common';
import type { Request } from 'express';
import { PlansService } from './plans.service';
import { GeneratePlanDto } from './dto/generate-plan.dto';
import { SavePlanDto } from './dto/save-plan.dto';
import { ActivatePlanDto } from './dto/activate-plan.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { JwtPayload } from '../auth/auth.service';

/**
 * PlansController — all routes require JWT authentication.
 *
 * SECURITY: @UseGuards(JwtAuthGuard) is applied at the class level so that
 * every endpoint (including future additions) is protected by default.
 * userId is always derived from req.user.sub (the JWT "sub" claim), never
 * from the request body — this prevents Insecure Direct Object Reference (IDOR).
 */
@Controller('plans')
@UseGuards(JwtAuthGuard)
export class PlansController {
  private readonly logger = new Logger(PlansController.name);

  constructor(private readonly plansService: PlansService) {}

  /**
   * POST /api/plans/generate
   * Accepts a natural-language prompt and generates a structured Plan using
   * the configured LLM backend (Gemini 2.5 Flash or Ollama). Requires JWT.
   */
  @Post('generate')
  @HttpCode(200)
  async generate(
    @Req() req: Request,
    @Body() dto: GeneratePlanDto,
  ) {
    const user = (req as any).user as JwtPayload;
    this.logger.log(
      `POST /plans/generate — userId=${user.sub}, prompt="${dto.prompt.slice(0, 80)}…"`,
    );
    return this.plansService.generatePlan(dto.prompt, user.sub, dto.language);
  }

  /**
   * POST /api/plans/save
   * Upserts a plan entry for the authenticated user.
   * - If dto.planId is provided: updates the existing plan (ownership verified).
   * - If dto.planId is absent: creates a new plan and returns the generated planId.
   *
   * SECURITY: userId is taken from req.user.sub (JWT), NOT from the request body.
   */
  @Post('save')
  @HttpCode(200)
  async save(
    @Req() req: Request,
    @Body() dto: SavePlanDto,
  ): Promise<{ planId: string; updatedAt: string }> {
    const user = (req as any).user as JwtPayload;
    this.logger.log(
      `POST /plans/save — userId=${user.sub}, planId=${dto.planId ?? 'NEW'}, name="${dto.name}"`,
    );
    const result = await this.plansService.savePlan(user.sub, dto);
    return { planId: result.planId, updatedAt: result.updatedAt.toISOString() };
  }

  /**
   * POST /api/plans/activate
   * Activates a plan for the authenticated user, setting voice quality.
   * For studio quality, triggers TTS pre-generation (ttsStatus → pending).
   * SECURITY: planId ownership verified against JWT userId.
   */
  @Post('activate')
  @HttpCode(200)
  async activate(
    @Req() req: Request,
    @Body() dto: ActivatePlanDto,
  ): Promise<{ success: boolean }> {
    const user = (req as any).user as JwtPayload;
    this.logger.log(
      `POST /plans/activate — userId=${user.sub}, planId=${dto.planId}, voiceQuality=${dto.voiceQuality}, voice=${dto.voice}, locale=${dto.locale}, speechRate=${dto.speechRate}`,
    );
    await this.plansService.activatePlan(
      user.sub,
      dto.planId,
      dto.voiceQuality,
      dto.voice,
      dto.locale,
      dto.speechRate,
    );
    return { success: true };
  }

  /**
   * GET /api/plans/list
   * Returns all plan summaries for the authenticated user.
   * Only returns plans owned by the JWT user (userId isolation enforced).
   * Includes TTS status fields per REQ-030.
   */
  @Get('list')
  async list(
    @Req() req: Request,
  ): Promise<{
    plans: Array<{
      planId: string;
      name: string;
      planJson: string;
      isActive: boolean;
      ttsStatus: string;
      ttsCompleted: number;
      ttsTotal: number;
      voiceQuality: string;
      createdAt: string;
      updatedAt: string;
    }>;
  }> {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`GET /plans/list — userId=${user.sub}`);
    const result = await this.plansService.listPlans(user.sub);
    return {
      plans: result.plans.map((p) => ({
        planId: p.planId,
        name: p.name,
        planJson: p.planJson,
        isActive: p.isActive,
        ttsStatus: p.ttsStatus,
        ttsCompleted: p.ttsCompleted,
        ttsTotal: p.ttsTotal,
        voiceQuality: p.voiceQuality,
        createdAt: p.createdAt.toISOString(),
        updatedAt: p.updatedAt.toISOString(),
      })),
    };
  }

  /**
   * GET /api/plans/:id
   * Returns a single plan by ID for the authenticated user (IDOR-safe).
   */
  @Get(':id')
  async getById(
    @Req() req: Request,
    @Param('id') planId: string,
  ) {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`GET /plans/${planId} — userId=${user.sub}`);
    const plan = await this.plansService.getPlanById(user.sub, planId);
    if (!plan) {
      throw new NotFoundException(`Plan ${planId} not found`);
    }
    return {
      planId: plan.planId,
      name: plan.name,
      planJson: plan.planJson,
      isActive: plan.isActive,
      ttsStatus: plan.ttsStatus,
      ttsCompleted: plan.ttsCompleted,
      ttsTotal: plan.ttsTotal,
      voiceQuality: plan.voiceQuality,
      sourceLibraryPlanId: plan.sourceLibraryPlanId,
      createdAt: plan.createdAt.toISOString(),
      updatedAt: plan.updatedAt.toISOString(),
    };
  }

  /**
   * DELETE /api/plans/:id
   * Deletes a plan for the authenticated user. Cascades to tts_jobs.
   * SECURITY: userId check prevents deleting another user's plan.
   */
  @Delete(':id')
  @HttpCode(200)
  async deleteById(
    @Req() req: Request,
    @Param('id') planId: string,
  ): Promise<{ success: boolean }> {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`DELETE /plans/${planId} — userId=${user.sub}`);
    await this.plansService.deletePlan(user.sub, planId);
    return { success: true };
  }
}
