/**
 * SyncController — session completion, plan-trigger, and content-cache sync endpoints.
 *
 * Routes:
 *   - POST /api/sync/completions     — upload completions (auth required)
 *   - GET  /api/sync/completions     — download completions (auth required, optional since param)
 *   - POST /api/sync/triggers        — upload plan triggers (auth required)
 *   - GET  /api/sync/triggers        — download plan triggers (auth required, optional since param)
 *   - GET  /api/sync/categories      — published categories for mobile cache (auth required)
 *   - GET  /api/sync/voices          — published voices for mobile cache (auth required)
 *   - GET  /api/sync/plan-voices     — ready plan-voice renditions for mobile cache (auth required)
 *
 * SECURITY:
 *   - All endpoints require JwtAuthGuard
 *   - userId derived from JWT, never from request body (completions / triggers)
 *   - Content-cache endpoints (categories, voices, plan-voices) return global
 *     published content — not user-scoped, but still require authentication
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
import type { Request } from 'express';
import { SyncService } from './sync.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { JwtPayload } from '../auth/auth.service';
import {
  UploadCompletionsDto,
  UploadCompletionsResponseDto,
  GetCompletionsResponseDto,
} from './dto/sync-completions.dto';
import {
  GetTriggersResponseDto,
  UploadTriggersDto,
  UploadTriggersResponseDto,
} from './dto/sync-triggers.dto';
import {
  GetCategoriesResponseDto,
  GetVoicesResponseDto,
  GetPlanVoicesResponseDto,
} from './dto/sync-content.dto';

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
    const userId = ((req as any).user as JwtPayload).sub;

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
    const userId = ((req as any).user as JwtPayload).sub;

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

  // ── Plan triggers ────────────────────────────────────────────────────────

  /**
   * POST /api/sync/triggers
   * Upload plan-start triggers (scheduled auto-start entries) from the client.
   *
   * Request body: { triggers: [{ clientId, planId, title, startUtc,
   *                              durationMinutes, recurrence, deletedAt?,
   *                              updatedAt }, ...] }
   *
   * Returns: { triggers: TriggerResponseDto[] } — the server-authoritative view
   *   of every accepted row after LWW reconciliation on updatedAt. Clients
   *   write back serverId + updatedAt into their Drift rows to clear
   *   dirty state in one round-trip.
   *
   * Idempotency: (userId, clientId) upsert.
   *
   * Auth: Required (JwtAuthGuard).
   */
  @Post('triggers')
  @HttpCode(HttpStatus.OK)
  async uploadTriggers(
    @Req() req: Request,
    @Body() dto: UploadTriggersDto,
  ): Promise<UploadTriggersResponseDto> {
    const userId = ((req as any).user as JwtPayload).sub;

    if (!dto.triggers || !Array.isArray(dto.triggers)) {
      throw new BadRequestException('triggers array is required');
    }

    if (dto.triggers.length === 0) {
      return { triggers: [] };
    }

    try {
      return await this.syncService.uploadPlanTriggers(userId, dto.triggers);
    } catch (error) {
      throw new InternalServerErrorException('Failed to upload triggers');
    }
  }

  /**
   * GET /api/sync/triggers?since=ISO8601
   * Download plan triggers. Includes tombstones (deletedAt set) so clients
   * can cancel the corresponding native alarms / notifications.
   *
   * Auth: Required (JwtAuthGuard).
   */
  @Get('triggers')
  @HttpCode(HttpStatus.OK)
  async getTriggers(
    @Req() req: Request,
    @Query('since') since?: string,
  ): Promise<GetTriggersResponseDto> {
    const userId = ((req as any).user as JwtPayload).sub;

    let sinceDate: Date | undefined;
    if (since) {
      const parsed = new Date(since);
      if (isNaN(parsed.getTime())) {
        throw new BadRequestException('Invalid since timestamp. Use ISO 8601 format.');
      }
      sinceDate = parsed;
    }

    try {
      return await this.syncService.getPlanTriggers(userId, { since: sinceDate });
    } catch (error) {
      throw new InternalServerErrorException('Failed to retrieve triggers');
    }
  }

  // ── Content cache sync ───────────────────────────────────────────────────

  /**
   * GET /api/sync/categories?since=ISO8601
   * Download published categories for mobile Drift cache sync.
   *
   * Query params:
   *   - since (optional): ISO 8601 timestamp.
   *       Omitted  → full sync:  all is_published=true categories.
   *       Provided → delta sync: categories with updatedAt > since that are
   *                  still published, PLUS deletedIds of any that were
   *                  unpublished after `since` (client must evict them).
   *
   * Returns: { categories: CategoryDto[], deletedIds: string[] }
   *
   * Auth: Required (JwtAuthGuard). Not user-scoped — returns global published
   * content identical for every authenticated caller.
   */
  @Get('categories')
  @HttpCode(HttpStatus.OK)
  async getCategories(
    @Query('since') since?: string,
  ): Promise<GetCategoriesResponseDto> {
    let sinceDate: Date | undefined;
    if (since) {
      const parsed = new Date(since);
      if (isNaN(parsed.getTime())) {
        throw new BadRequestException('Invalid since timestamp. Use ISO 8601 format.');
      }
      sinceDate = parsed;
    }

    try {
      return await this.syncService.getCategories(sinceDate);
    } catch (error) {
      throw new InternalServerErrorException('Failed to retrieve categories');
    }
  }

  /**
   * GET /api/sync/voices?since=ISO8601
   * Download published voices for mobile Drift cache sync.
   *
   * Query params:
   *   - since (optional): ISO 8601 timestamp.
   *       Omitted  → full sync:  all is_published=true voices.
   *       Provided → delta sync: voices with updatedAt > since that are
   *                  still published, PLUS deletedIds for unpublished voices.
   *
   * Returns: { voices: VoiceDto[], deletedIds: string[] }
   *
   * Auth: Required (JwtAuthGuard). Global published content — not user-scoped.
   */
  @Get('voices')
  @HttpCode(HttpStatus.OK)
  async getVoices(
    @Query('since') since?: string,
  ): Promise<GetVoicesResponseDto> {
    let sinceDate: Date | undefined;
    if (since) {
      const parsed = new Date(since);
      if (isNaN(parsed.getTime())) {
        throw new BadRequestException('Invalid since timestamp. Use ISO 8601 format.');
      }
      sinceDate = parsed;
    }

    try {
      return await this.syncService.getVoices(sinceDate);
    } catch (error) {
      throw new InternalServerErrorException('Failed to retrieve voices');
    }
  }

  /**
   * GET /api/sync/plan-voices?since=ISO8601
   * Download ready plan-voice renditions for mobile Drift cache sync.
   *
   * Only plan_voices with status='ready' for is_published=true plans are
   * returned — these are the rows that gate audio playback on the client
   * (REQ-023, AC-021).
   *
   * Query params:
   *   - since (optional): ISO 8601 timestamp.
   *       Omitted  → full sync:  all ready+published plan_voice rows.
   *       Provided → delta sync: rows where plan_voices.updatedAt > since
   *                  that are still ready+published, PLUS deletedIds for
   *                  rows that no longer qualify (status changed, or parent
   *                  plan unpublished — client must evict them).
   *
   * Returns: { planVoices: PlanVoiceDto[], deletedIds: string[] }
   *
   * Auth: Required (JwtAuthGuard). Global published content — not user-scoped.
   */
  @Get('plan-voices')
  @HttpCode(HttpStatus.OK)
  async getPlanVoices(
    @Query('since') since?: string,
  ): Promise<GetPlanVoicesResponseDto> {
    let sinceDate: Date | undefined;
    if (since) {
      const parsed = new Date(since);
      if (isNaN(parsed.getTime())) {
        throw new BadRequestException('Invalid since timestamp. Use ISO 8601 format.');
      }
      sinceDate = parsed;
    }

    try {
      return await this.syncService.getPlanVoices(sinceDate);
    } catch (error) {
      throw new InternalServerErrorException('Failed to retrieve plan voices');
    }
  }
}
