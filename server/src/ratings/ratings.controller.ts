import {
  Controller,
  Post,
  Delete,
  Get,
  Body,
  Param,
  Req,
  UseGuards,
  HttpCode,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import type { Request } from 'express';
import { RatingsService } from './ratings.service';
import { RatePlanDto } from './dto/rate-plan.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { JwtPayload } from '../auth/auth.service';

/**
 * RatingsController — plan rating endpoints (all require JWT).
 *
 * POST   /api/ratings/:planId   — upsert a 1–5 star rating for a plan
 * DELETE /api/ratings/:planId   — remove the current user's rating
 * GET    /api/ratings/:planId   — get aggregate stats + current user's rating
 */
@Controller('ratings')
@UseGuards(JwtAuthGuard)
export class RatingsController {
  private readonly logger = new Logger(RatingsController.name);

  constructor(private readonly ratingsService: RatingsService) {}

  @Post(':planId')
  @HttpCode(HttpStatus.OK)
  async ratePlan(
    @Req() req: Request,
    @Param('planId') planId: string,
    @Body() dto: RatePlanDto,
  ) {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`POST /ratings/${planId} — userId=${user.sub}, rating=${dto.rating}`);
    return this.ratingsService.ratePlan(user.sub, planId, dto.rating);
  }

  @Delete(':planId')
  @HttpCode(HttpStatus.OK)
  async deleteRating(@Req() req: Request, @Param('planId') planId: string) {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`DELETE /ratings/${planId} — userId=${user.sub}`);
    return this.ratingsService.deleteRating(user.sub, planId);
  }

  @Get(':planId')
  @HttpCode(HttpStatus.OK)
  async getPlanRating(@Req() req: Request, @Param('planId') planId: string) {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`GET /ratings/${planId} — userId=${user.sub}`);
    return this.ratingsService.getPlanRatingForUser(user.sub, planId);
  }
}
