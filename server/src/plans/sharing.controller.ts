/**
 * SharingController — plan sharing endpoints.
 *
 * Routes:
 *   - POST /plans/:id/share — generate or return existing share token (auth required)
 *   - DELETE /plans/:id/share — revoke sharing (auth required)
 *   - GET /plans/shared/:shareToken — fetch shared plan metadata (no auth, rate-limited)
 *
 * SECURITY:
 *   - POST/DELETE are guarded by JwtAuthGuard — owner verification via userId.sub
 *   - GET is public (no auth) but rate-limited to prevent enumeration attacks
 *   - Response DTOs exclude sensitive fields (userId, internal metadata)
 *   - Share tokens are URL-safe 12-char nanoid — collision-resistant
 */

import {
  Controller,
  Post,
  Delete,
  Get,
  UseGuards,
  Req,
  Param,
  HttpCode,
  HttpStatus,
  BadRequestException,
  ForbiddenException,
  NotFoundException,
  InternalServerErrorException,
} from '@nestjs/common';
import { Request } from 'express';
import { SharingService } from './sharing.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireUser } from '../auth/decode-token.util';
import { UpstashRateLimitService } from '../ratelimit/upstash-ratelimit.service';
import { SharedPlanResponseDto } from './dto/shared-plan-response.dto';

@Controller('plans')
export class SharingController {
  constructor(
    private readonly sharingService: SharingService,
    private readonly rateLimiter: UpstashRateLimitService,
  ) {}

  /**
   * POST /api/plans/:id/share
   * Generate a new share token for a plan (or return existing token).
   *
   * Auth: Required (JwtAuthGuard)
   * Ownership: Verified — only the plan owner can share their own plan
   */
  @Post(':id/share')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.CREATED)
  async generateShareToken(@Req() req: Request, @Param('id') planId: string) {
    const userId = requireUser(req).sub;

    if (!planId || planId.trim().length === 0) {
      throw new BadRequestException('Plan ID is required');
    }

    try {
      const result = await this.sharingService.generateShareToken(userId, planId);
      return {
        shareToken: result.shareToken,
        shareUrl: result.shareUrl,
      };
    } catch (error) {
      if (error instanceof ForbiddenException) {
        throw error;
      }
      if (error instanceof NotFoundException) {
        throw error;
      }
      throw new InternalServerErrorException('Failed to generate share token');
    }
  }

  /**
   * DELETE /api/plans/:id/share
   * Revoke sharing for a plan.
   *
   * Auth: Required (JwtAuthGuard)
   * Ownership: Verified — only the plan owner can revoke
   */
  @Delete(':id/share')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async revokeShareToken(@Req() req: Request, @Param('id') planId: string) {
    const userId = requireUser(req).sub;

    if (!planId || planId.trim().length === 0) {
      throw new BadRequestException('Plan ID is required');
    }

    try {
      const success = await this.sharingService.revokeShareToken(userId, planId);
      if (!success) {
        throw new NotFoundException('Plan not found or not owned by you');
      }
      return { success: true };
    } catch (error) {
      if (error instanceof NotFoundException) {
        throw error;
      }
      throw new InternalServerErrorException('Failed to revoke share token');
    }
  }

  /**
   * GET /api/plans/shared/:shareToken
   * Fetch shared plan metadata by share token (public, no auth).
   *
   * Auth: NOT required
   * Rate limit: 30 req/min per IP to prevent enumeration
   * Response: Excludes userId, internal metadata — only name, description, steps
   */
  @Get('shared/:shareToken')
  @HttpCode(HttpStatus.OK)
  async getSharedPlan(
    @Req() req: Request,
    @Param('shareToken') shareToken: string,
  ): Promise<SharedPlanResponseDto> {
    if (!shareToken || shareToken.trim().length === 0) {
      throw new BadRequestException('Share token is required');
    }

    // Rate limit: 30 requests per minute per IP
    const clientIp = (req.ip || 'unknown') as string;
    const rateLimitResult = await this.rateLimiter.consume('shared-plan', clientIp, 30, 60);
    if (!rateLimitResult.allowed) {
      throw new BadRequestException(
        `Rate limit exceeded. Retry after ${rateLimitResult.retryAfterSec} seconds.`,
      );
    }

    try {
      const planData = await this.sharingService.getSharedPlan(shareToken);
      if (!planData) {
        throw new NotFoundException('Plan not found or share link has been revoked');
      }
      return planData;
    } catch (error) {
      if (error instanceof NotFoundException) {
        throw error;
      }
      throw new InternalServerErrorException('Failed to fetch shared plan');
    }
  }
}
