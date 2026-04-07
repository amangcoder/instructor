import {
  Controller,
  Post,
  Body,
  Req,
  UseGuards,
  Logger,
  HttpCode,
} from '@nestjs/common';
import type { Request } from 'express';
import { PlansService } from './plans.service';
import { GeneratePlanDto } from './dto/generate-plan.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { JwtPayload } from '../auth/auth.service';

@Controller('plans')
export class PlansController {
  private readonly logger = new Logger(PlansController.name);

  constructor(private readonly plansService: PlansService) {}

  /**
   * POST /api/plans/generate
   * Accepts a natural-language prompt and generates a structured Plan using
   * Gemini 2.0 Flash. Requires JWT authentication.
   */
  @Post('generate')
  @HttpCode(200)
  @UseGuards(JwtAuthGuard)
  async generate(
    @Body() dto: GeneratePlanDto,
    @Req() req: Request,
  ) {
    const user = (req as any).user as JwtPayload;
    this.logger.log(
      `POST /plans/generate — userId=${user.sub}, prompt="${dto.prompt.slice(0, 80)}…"`,
    );
    return this.plansService.generatePlan(dto.prompt, user.sub, dto.category);
  }
}
