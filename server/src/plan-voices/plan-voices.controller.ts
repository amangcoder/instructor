/**
 * PlanVoicesController — admin-only endpoints for per-voice TTS management.
 *
 * Endpoints:
 *   POST /api/admin/plans/:id/voices
 *     Create (or reset) a plan_voice row for the given voice and queue TTS.
 *     Body: { voiceId? | voiceSlug? } — used by the empty-state Generate button.
 *
 *   POST /api/admin/plans/:id/voices/:voiceId/regenerate
 *     Queue TTS synthesis for a failed or pending plan_voice rendition.
 *     Returns 202 Accepted with a correlation jobId.
 *
 *   GET /api/admin/plan-voices?status=failed
 *     List paginated plan_voice rows filtered by status ('failed').
 *
 * SECURITY: Both JwtAuthGuard and AdminRoleGuard are applied at the class
 * level. JwtAuthGuard must come first (populates req.user), then
 * AdminRoleGuard checks role='admin'. No user-scoped data is returned;
 * all data is admin-curated content.
 */

import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Logger,
  NotFoundException,
  Param,
  Post,
  Query,
  Res,
  UseGuards,
  ValidationPipe,
} from '@nestjs/common';
import type { Response } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRoleGuard } from '../auth/admin-role.guard';
import { PlanVoicesService } from './plan-voices.service';
import { GenerateVoiceBodyDto, ListPlanVoicesQueryDto, SynthStepBodyDto } from './plan-voice.dto';
import type {
  DeleteVoiceResponseDto,
  GenerateResponseDto,
  ListFailedResponseDto,
  RegenerateResponseDto,
  SynthStepResponseDto,
} from './plan-voice.dto';
import type { Voice } from '../database/schema';
import type { PlanVoiceWithVoice } from '../database/repositories/plan-voices.repository';

@Controller('admin')
@UseGuards(JwtAuthGuard, AdminRoleGuard)
export class PlanVoicesController {
  private readonly logger = new Logger(PlanVoicesController.name);

  constructor(private readonly planVoicesService: PlanVoicesService) {}

  // ── POST /admin/plans/:id/voices/:voiceId/regenerate ───────────────────────

  /**
   * POST /api/admin/plans/:id/voices/:voiceId/regenerate
   *
   * Resets the plan_voice row to 'pending' and queues a new TTS batch job.
   * The operation is idempotent — re-triggering for an already-pending row
   * has no side effects (TtsBatchPregenService handles the reset).
   *
   * REQ-011: Admin must be able to retrigger TTS generation for failed voices.
   *
   * @param planId   UUID of the plan.
   * @param voiceId  UUID of the voice (from the voices table).
   * @returns 202 Accepted with { jobId, planId, voiceId, status: 'pending' }.
   * @throws 404 if no plan_voice exists for the (planId, voiceId) pair.
   * @throws 404 if the plan or voice does not exist.
   */
  @Post('plans/:id/voices/:voiceId/regenerate')
  @HttpCode(HttpStatus.ACCEPTED) // 202
  async regenerate(
    @Param('id') planId: string,
    @Param('voiceId') voiceId: string,
  ): Promise<RegenerateResponseDto> {
    this.logger.log(
      `POST /admin/plans/${planId}/voices/${voiceId}/regenerate`,
    );
    return this.planVoicesService.regenerateVoice(planId, voiceId);
  }

  // ── POST /admin/plans/:id/voices ───────────────────────────────────────────

  /**
   * POST /api/admin/plans/:id/voices
   *
   * Creates (or resets) a plan_voice row for the given (plan, voice) pair and
   * queues a TTS batch job. Lets admins generate audio for a plan that has no
   * voice renditions yet — for example, the plan's `defaultVoice` slug from
   * the empty-state in the admin VoiceGrid.
   *
   * Body: { voiceId?: string; voiceSlug?: string } — at least one is required.
   *
   * @returns 202 Accepted with { jobId, planId, voiceId, locale, status: 'pending' }.
   * @throws 400 if neither voiceId nor voiceSlug is provided.
   * @throws 404 if the voice or plan does not exist.
   */
  @Post('plans/:id/voices')
  @HttpCode(HttpStatus.ACCEPTED)
  async generate(
    @Param('id') planId: string,
    @Body(new ValidationPipe({ transform: true, whitelist: true }))
    body: GenerateVoiceBodyDto,
  ): Promise<GenerateResponseDto> {
    this.logger.log(
      `POST /admin/plans/${planId}/voices voiceId=${body.voiceId ?? '-'} voiceSlug=${body.voiceSlug ?? '-'}`,
    );
    return this.planVoicesService.generateVoice(planId, {
      voiceId: body.voiceId,
      voiceSlug: body.voiceSlug,
    });
  }

  // ── GET /admin/plans/:id/voices ────────────────────────────────────────────

  /**
   * GET /api/admin/plans/:id/voices
   *
   * Returns all plan_voices rows for the given plan, ordered by createdAt ASC.
   * Powers the admin voice-grid panel on the plan detail page.
   */
  @Get('plans/:id/voices')
  async listByPlan(@Param('id') planId: string): Promise<PlanVoiceWithVoice[]> {
    this.logger.log(`GET /admin/plans/${planId}/voices`);
    return this.planVoicesService.listByPlan(planId);
  }

  // ── GET /admin/voices ──────────────────────────────────────────────────────

  /**
   * GET /api/admin/voices
   *
   * Returns published voices for admin voice-selector dropdowns
   * (e.g. PlanDetailsEditor's default-voice picker).
   */
  @Get('voices')
  async listVoices(): Promise<Voice[]> {
    this.logger.log('GET /admin/voices');
    return this.planVoicesService.listVoices();
  }

  // ── DELETE /admin/plans/:id/voices/:voiceId ────────────────────────────────

  /**
   * DELETE /api/admin/plans/:id/voices/:voiceId
   *
   * Removes a single plan_voice rendition. Idempotent — returns 200 with
   * `{ deleted: 0 }` when no row matches so admin clients can call this
   * without first checking existence.
   */
  @Delete('plans/:id/voices/:voiceId')
  async deleteVoice(
    @Param('id') planId: string,
    @Param('voiceId') voiceId: string,
  ): Promise<DeleteVoiceResponseDto> {
    this.logger.log(`DELETE /admin/plans/${planId}/voices/${voiceId}`);
    return this.planVoicesService.deleteVoice(planId, voiceId);
  }

  // ── POST /admin/plans/:id/voices/:voiceId/preview ─────────────────────────

  /**
   * POST /api/admin/plans/:id/voices/:voiceId/preview
   *
   * Synthesizes (or pulls from cache) the audio for the first non-empty say
   * step of the plan against the chosen voice and streams the WAV bytes.
   * Used by the admin VoiceGrid Play button so reviewers can audition a
   * rendition without leaving the dashboard.
   *
   * Returns 200 with `Content-Type: audio/wav` on success.
   *
   * @throws 404 if the plan, the (plan, voice) pair, or any say step is missing.
   */
  @Post('plans/:id/voices/:voiceId/preview')
  @HttpCode(HttpStatus.OK)
  async preview(
    @Param('id') planId: string,
    @Param('voiceId') voiceId: string,
    @Res() res: Response,
  ): Promise<void> {
    this.logger.log(`POST /admin/plans/${planId}/voices/${voiceId}/preview`);
    const { audio } = await this.planVoicesService.previewVoice(planId, voiceId);
    res.status(200).set({
      'Content-Type': 'audio/wav',
      'Content-Length': audio.length.toString(),
      'Cache-Control': 'private, max-age=300',
    });
    res.send(audio);
  }

  // ── POST /admin/plans/:id/synth-step ───────────────────────────────────────

  /**
   * POST /api/admin/plans/:id/synth-step
   *
   * Synthesizes a single say-step's audio against the requested voice
   * (or the plan's `defaultVoice` when neither voiceId nor voiceSlug is
   * provided) and writes the result to the shared TTS cache so the mobile
   * client can fetch it without re-synthesis.
   *
   * Body: { stepId, voiceId?, voiceSlug? }
   */
  @Post('plans/:id/synth-step')
  async synthStep(
    @Param('id') planId: string,
    @Body(new ValidationPipe({ transform: true, whitelist: true }))
    body: SynthStepBodyDto,
  ): Promise<SynthStepResponseDto> {
    this.logger.log(
      `POST /admin/plans/${planId}/synth-step stepId=${body.stepId} voiceId=${body.voiceId ?? '-'} voiceSlug=${body.voiceSlug ?? '-'}`,
    );
    return this.planVoicesService.synthStep(planId, {
      stepId: body.stepId,
      voiceId: body.voiceId,
      voiceSlug: body.voiceSlug,
    });
  }

  // ── GET /admin/plan-voices ─────────────────────────────────────────────────

  /**
   * GET /api/admin/plan-voices?status=failed[&page=1&pageSize=20]
   *
   * Returns a paginated list of plan_voice rows filtered by status.
   * The primary intended filter is status=failed for admin triage.
   *
   * Pagination defaults:
   *   page     = 1   (1-indexed)
   *   pageSize = 20  (clamped to max 100)
   *
   * REQ-011: Admin must be able to monitor and retry failed TTS jobs.
   */
  @Get('plan-voices')
  async listFailed(
    @Query(new ValidationPipe({ transform: true, whitelist: true }))
    query: ListPlanVoicesQueryDto,
  ): Promise<ListFailedResponseDto> {
    // Only 'failed' status is supported by the repository. Any other status
    // value passes validation (IsIn guard) and results in an empty list.
    if (query.status && query.status !== 'failed') {
      return { items: [], total: 0, page: query.page ?? 1, pageSize: query.pageSize ?? 20 };
    }

    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? 20;

    this.logger.log(
      `GET /admin/plan-voices status=${query.status ?? 'all'} page=${page} pageSize=${pageSize}`,
    );

    return this.planVoicesService.listFailed(page, pageSize);
  }
}
