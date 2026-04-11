import { Controller, Post, Get, Body, Req, UseGuards, Logger, HttpCode } from '@nestjs/common';
import type { Request } from 'express';
import { PlansService } from './plans.service';
import { GeneratePlanDto } from './dto/generate-plan.dto';
import { SavePlanDto } from './dto/save-plan.dto';
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
   * GET /api/plans/list
   * Returns all plan summaries for the authenticated user.
   * Only returns plans owned by the JWT user (userId isolation enforced).
   */
  @Get('list')
  async list(
    @Req() req: Request,
  ): Promise<{ plans: Array<{ planId: string; name: string; createdAt: string; updatedAt: string }> }> {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`GET /plans/list — userId=${user.sub}`);
    const result = await this.plansService.listPlans(user.sub);
    return {
      plans: result.plans.map((p) => ({
        planId: p.planId,
        name: p.name,
        createdAt: p.createdAt.toISOString(),
        updatedAt: p.updatedAt.toISOString(),
      })),
    };
  }
}
