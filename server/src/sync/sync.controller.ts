/**
 * SyncController — session completion sync endpoints.
 *
 * Routes:
 *   - POST /api/sync/completions — upload completions (auth required)
 *   - GET /api/sync/completions — download completions (auth required, optional since param)
 *
 * SECURITY:
 *   - Both endpoints require JwtAuthGuard
 *   - userId derived from JWT, never from request body
 *   - No cross-user data leakage
 *   - Rate limiting considered for future (not in MVP)
 */

import {
  Controller,
  Post,
  Get,
  UseGuards,
  Req,
  Body,
  Query,
  HttpCode,
  HttpStatus,
  BadRequestException,
  InternalServerErrorException,
} from '@nestjs/common';
import { Request } from 'express';
import { SyncService } from './sync.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireUser } from '../auth/decode-token.util';
import {
  UploadCompletionsDto,
  UploadCompletionsResponseDto,
  GetCompletionsResponseDto,
} from './dto/sync-completions.dto';

@Controller('sync')
@UseGuards(JwtAuthGuard)
export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  /**
   * POST /api/sync/completions
   * Upload session completions from client.
   *
   * Request body: { completions: [{ planId, completedAt, durationMs, clientId? }, ...] }
   * Returns: { syncedCount: number }
   *
   * Idempotency:
   *   Each completion has an optional clientId (UUID). Server prevents duplicates via
   *   ON CONFLICT (client_id) DO NOTHING. If clientId is omitted, server generates one.
   *
   * Auth: Required (JwtAuthGuard)
   */
  @Post('completions')
  @HttpCode(HttpStatus.CREATED)
  async uploadCompletions(
    @Req() req: Request,
    @Body() dto: UploadCompletionsDto,
  ): Promise<UploadCompletionsResponseDto> {
    const userId = requireUser(req).sub;

    if (!dto.completions || !Array.isArray(dto.completions)) {
      throw new BadRequestException('completions array is required');
    }

    if (dto.completions.length === 0) {
      return { syncedCount: 0 };
    }

    try {
      // Extract the array from DTO and pass to service
      return await this.syncService.uploadCompletions(userId, dto.completions);
    } catch (error) {
      throw new InternalServerErrorException('Failed to upload completions');
    }
  }

  /**
   * GET /api/sync/completions?since=ISO8601
   * Download session completions from server.
   *
   * Query params:
   *   - since (optional): ISO 8601 timestamp. Returns only completions after this date.
   *
   * Returns: { completions: [{ id, planId, completedAt, durationMs }, ...] }
   *   Ordered by completedAt ascending.
   *
   * Auth: Required (JwtAuthGuard)
   */
  @Get('completions')
  @HttpCode(HttpStatus.OK)
  async getCompletions(
    @Req() req: Request,
    @Query('since') since?: string,
  ): Promise<GetCompletionsResponseDto> {
    const userId = requireUser(req).sub;

    // Validate and convert since parameter if provided
    let sinceDate: Date | undefined;
    if (since) {
      const parsed = new Date(since);
      if (isNaN(parsed.getTime())) {
        throw new BadRequestException('Invalid since timestamp. Use ISO 8601 format.');
      }
      sinceDate = parsed;
    }

    try {
      return await this.syncService.getCompletions(userId, { since: sinceDate });
    } catch (error) {
      throw new InternalServerErrorException('Failed to retrieve completions');
    }
  }
}
