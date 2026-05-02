/**
 * PlanVoicesService — business logic for per-voice TTS regeneration
 * and failed-job monitoring.
 *
 * Visibility gate contract (REQ-028):
 *   A plan is visible to end-users only when the v_published_plans view
 *   returns it. That view requires:
 *     1. plans.is_published = true
 *     2. plans.visibility = 'public'
 *     3. EXISTS (SELECT 1 FROM plan_voices WHERE plan_id = ? AND status = 'ready')
 *
 *   This service's regenerateVoice() method resets a failed plan_voices row
 *   to 'pending' and re-queues TTS synthesis. When synthesis completes
 *   successfully the row transitions to 'ready', satisfying condition 3 and
 *   making the plan visible.
 */

import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../database/database.service';
import { PlanVoicesRepository, type PlanVoiceWithVoice } from '../database/repositories/plan-voices.repository';
import { VoiceRepository } from '../database/repositories/voice.repository';
import { TtsBatchPregenService } from '../tts/tts-batch-pregen.service';
import { TtsService } from '../tts/tts.service';
import { plans } from '../database/schema';
import type { Voice } from '../database/schema';
import type { GenerateResponseDto, ListFailedResponseDto, RegenerateResponseDto } from './plan-voice.dto';

@Injectable()
export class PlanVoicesService {
  private readonly logger = new Logger(PlanVoicesService.name);

  constructor(
    private readonly db: DatabaseService,
    private readonly planVoicesRepo: PlanVoicesRepository,
    private readonly voiceRepo: VoiceRepository,
    private readonly ttsBatchPregen: TtsBatchPregenService,
    private readonly ttsService: TtsService,
  ) {}

  // ── Regenerate ─────────────────────────────────────────────────────────────

  /**
   * Queue TTS regeneration for a specific (plan, voice) combination.
   *
   * Steps:
   *   1. Look up the plan_voices row to obtain the locale.
   *   2. Look up the voice row to obtain the TTS provider.
   *   3. Fetch the plan's plan_json for step enumeration (admin query — no
   *      userId restriction, plans are admin-curated content).
   *   4. Call TtsBatchPregenService.regenerateVoice() which resets the
   *      plan_voices row to 'pending' and queues a new TTS batch.
   *   5. Return a correlation jobId (UUID) for the caller to track.
   *
   * @throws NotFoundException if no plan_voice row exists for the given pair.
   * @throws NotFoundException if the voice does not exist.
   * @throws NotFoundException if the plan does not exist.
   */
  async regenerateVoice(
    planId: string,
    voiceId: string,
  ): Promise<RegenerateResponseDto> {
    this.logger.log(`regenerateVoice planId=${planId} voiceId=${voiceId}`);

    // 1. Resolve locale from the existing plan_voices row.
    const planVoiceRows = await this.planVoicesRepo.listByPlan(planId);
    const planVoice = planVoiceRows.find((pv) => pv.voiceId === voiceId);
    if (!planVoice) {
      throw new NotFoundException(
        `No plan_voice record found for plan=${planId} voice=${voiceId}. ` +
          'Ensure the voice was previously associated with this plan.',
      );
    }

    // 2. Resolve TTS provider from the voices table.
    const voice = await this.voiceRepo.findById(voiceId);
    if (!voice) {
      throw new NotFoundException(`Voice ${voiceId} not found`);
    }

    // 3. Fetch plan_json for step enumeration.
    //    Admin-level query: no userId filter — admin endpoints manage
    //    curated plans that may have no ownerUserId.
    const database = this.db.getDb();
    if (!database) {
      // noop mode (no DATABASE_URL configured) — return a synthetic jobId.
      this.logger.warn('Database in noop mode — skipping TTS regeneration');
      return { jobId: randomUUID(), planId, voiceId, status: 'pending' };
    }

    const planRows = await this.db.withRetry(() =>
      database
        .select({ planJson: plans.planJson })
        .from(plans)
        .where(eq(plans.id, planId))
        .limit(1),
    );
    if (planRows.length === 0) {
      throw new NotFoundException(`Plan ${planId} not found`);
    }
    const { planJson } = planRows[0];

    // 4. Queue regeneration via TtsBatchPregenService.
    //    Pass voice.slug — the slug flows down to the TTS provider call, which
    //    needs the provider's catalog name (e.g. 'af_bella'), not the UUID.
    //    TtsBatchPregenService.regenerateVoice resolves slug→UUID internally
    //    for the plan_voices upsert via resolveVoiceUuid().
    //    Speech rate defaults to '1.00' — the plan_voices table does not store
    //    per-rendition speech rates and the voice table has no speechRate column.
    await this.ttsBatchPregen.regenerateVoice(
      planId,
      voice.slug,
      planVoice.locale,
      planJson,
      voice.provider,
    );

    this.logger.log(
      `Queued TTS regeneration planId=${planId} voiceId=${voiceId} slug=${voice.slug} locale=${planVoice.locale} provider=${voice.provider}`,
    );

    return { jobId: randomUUID(), planId, voiceId, status: 'pending' };
  }

  // ── Generate (create + queue) ──────────────────────────────────────────────

  /**
   * Create a new plan_voice row (or reset an existing one) and queue TTS.
   *
   * Unlike {@link regenerateVoice}, this does not require an existing
   * plan_voices row — the caller can supply either a voice UUID or the
   * voice's slug (e.g. the plan's `defaultVoice`). The voice's own locale
   * is used for the rendition.
   *
   * @throws BadRequestException if neither voiceId nor voiceSlug is provided.
   * @throws NotFoundException if the voice or plan cannot be found.
   */
  async generateVoice(
    planId: string,
    params: { voiceId?: string; voiceSlug?: string },
  ): Promise<GenerateResponseDto> {
    if (!params.voiceId && !params.voiceSlug) {
      throw new BadRequestException(
        'Either voiceId (UUID) or voiceSlug must be provided.',
      );
    }

    // 1. Resolve the voice by UUID or slug.
    let voice: Voice | null = null;
    if (params.voiceId) {
      voice = await this.voiceRepo.findById(params.voiceId);
    } else if (params.voiceSlug) {
      voice = await this.voiceRepo.findBySlug(params.voiceSlug);
    }
    if (!voice) {
      const lookup = params.voiceId ?? params.voiceSlug;
      throw new NotFoundException(`Voice ${lookup} not found`);
    }

    // 2. Fetch the plan_json for step enumeration.
    const database = this.db.getDb();
    if (!database) {
      this.logger.warn('Database in noop mode — skipping TTS generation');
      return {
        jobId: randomUUID(),
        planId,
        voiceId: voice.id,
        locale: voice.locale,
        status: 'pending',
      };
    }

    const planRows = await this.db.withRetry(() =>
      database
        .select({ planJson: plans.planJson })
        .from(plans)
        .where(eq(plans.id, planId))
        .limit(1),
    );
    if (planRows.length === 0) {
      throw new NotFoundException(`Plan ${planId} not found`);
    }
    const { planJson } = planRows[0];

    // 3. Queue via TtsBatchPregenService — this upserts the plan_voices row
    //    to 'pending' (creating it if needed) and dispatches the TTS batch.
    //    Pass voice.slug — the slug is what reaches the TTS provider (Kokoro
    //    expects 'af_bella', not a UUID). resolveVoiceUuid() inside the batch
    //    service handles the slug→UUID lookup needed for plan_voices.
    await this.ttsBatchPregen.regenerateVoice(
      planId,
      voice.slug,
      voice.locale,
      planJson,
      voice.provider,
    );

    this.logger.log(
      `Queued TTS generation planId=${planId} voiceId=${voice.id} ` +
        `slug=${voice.slug} locale=${voice.locale} provider=${voice.provider}`,
    );

    return {
      jobId: randomUUID(),
      planId,
      voiceId: voice.id,
      locale: voice.locale,
      status: 'pending',
    };
  }

  // ── List failed ────────────────────────────────────────────────────────────

  /**
   * Return a paginated list of plan_voices rows with status='failed'.
   *
   * Ordered by updatedAt DESC (most recently failed first) so admins
   * see the newest failures at the top of the triage queue.
   *
   * @param page     Page number (1-indexed). Clamped to ≥ 1.
   * @param pageSize Records per page. Clamped to [1, 100].
   */
  async listFailed(page = 1, pageSize = 20): Promise<ListFailedResponseDto> {
    const clampedPage = Math.max(1, page);
    const clampedPageSize = Math.min(100, Math.max(1, pageSize));

    const { items, total } = await this.planVoicesRepo.listFailed(
      clampedPage,
      clampedPageSize,
    );

    return {
      items,
      total,
      page: clampedPage,
      pageSize: clampedPageSize,
    };
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /**
   * Return all plan_voices rows for a given plan, each enriched with the
   * voice's displayName and slug for admin grid rendering.
   */
  async listByPlan(planId: string): Promise<PlanVoiceWithVoice[]> {
    return this.planVoicesRepo.listByPlan(planId);
  }

  /**
   * Return published voices for the admin default-voice dropdown.
   * Mirrors VoiceRepository.listPublished — ordered by locale, then displayName.
   */
  async listVoices(): Promise<Voice[]> {
    return this.voiceRepo.listPublished();
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /**
   * Remove the plan_voice row for the given (plan, voice) pair.
   * Idempotent — silently returns when no row matches.
   *
   * @throws NotFoundException if the plan or voice does not exist as a row,
   *         distinguishing "no such voice" from "voice exists but no rendition".
   *         To keep the admin DELETE handler ergonomic the implementation
   *         treats a missing rendition as a no-op success.
   */
  async deleteVoice(planId: string, voiceId: string): Promise<{ deleted: number }> {
    this.logger.log(`deleteVoice planId=${planId} voiceId=${voiceId}`);
    const deleted = await this.planVoicesRepo.deleteByPlanAndVoice(planId, voiceId);
    return { deleted };
  }

  // ── Per-step synth ────────────────────────────────────────────────────────

  /**
   * Synthesize a single say-step's audio against a chosen voice and write the
   * result to the shared TTS cache. Used by the admin "Synth this step"
   * action so admins can iterate on copy without regenerating the entire plan.
   *
   * Resolution order for the voice argument:
   *   1. voiceId (UUID) — direct lookup by id
   *   2. voiceSlug      — looked up via VoiceRepository.findBySlug
   *   3. fallback       — the plan's defaultVoice slug from planJson
   *
   * @returns the resolved voice slug, locale, provider, and synthesized text
   *          length so the caller can confirm what was written to cache.
   *
   * @throws BadRequestException if neither the request nor planJson resolves
   *         to a voice.
   * @throws NotFoundException if the plan / step / voice cannot be found.
   */
  async synthStep(
    planId: string,
    params: { stepId: string; voiceId?: string; voiceSlug?: string },
  ): Promise<{
    stepId: string;
    voiceSlug: string;
    locale: string;
    provider: string;
    textLength: number;
  }> {
    const database = this.db.getDb();
    if (!database) {
      throw new BadRequestException('Database is in noop mode — cannot synthesize.');
    }

    // 1. Load planJson and find the step.
    const planRows = await this.db.withRetry(() =>
      database
        .select({ planJson: plans.planJson })
        .from(plans)
        .where(eq(plans.id, planId))
        .limit(1),
    );
    if (planRows.length === 0) {
      throw new NotFoundException(`Plan ${planId} not found`);
    }
    let parsed: { steps?: unknown; defaultVoice?: unknown };
    try {
      parsed = JSON.parse(planRows[0].planJson) as { steps?: unknown; defaultVoice?: unknown };
    } catch {
      throw new BadRequestException(`Plan ${planId} has malformed plan_json`);
    }

    const step = findSayStep(
      Array.isArray(parsed.steps) ? (parsed.steps as Array<Record<string, unknown>>) : [],
      params.stepId,
    );
    if (!step) {
      throw new NotFoundException(
        `Say step ${params.stepId} not found in plan ${planId}`,
      );
    }

    // 2. Resolve voice.
    let voice: Voice | null = null;
    if (params.voiceId) voice = await this.voiceRepo.findById(params.voiceId);
    if (!voice && params.voiceSlug) voice = await this.voiceRepo.findBySlug(params.voiceSlug);
    if (!voice && typeof parsed.defaultVoice === 'string' && parsed.defaultVoice.length > 0) {
      voice = await this.voiceRepo.findBySlug(parsed.defaultVoice);
    }
    if (!voice) {
      throw new BadRequestException(
        'No voice could be resolved (provide voiceId / voiceSlug, or set the plan defaultVoice).',
      );
    }

    // 3. Synthesize through TtsService — populates the shared S3 + L1 cache.
    //    speechRate '1.00' matches the cache key the mobile client constructs
    //    when it requests audio for this step.
    await this.ttsService.synthesize(
      step.text,
      voice.slug,
      voice.locale,
      voice.provider,
      '1.00',
    );

    this.logger.log(
      `synthStep planId=${planId} stepId=${params.stepId} voice=${voice.slug} locale=${voice.locale} provider=${voice.provider} chars=${step.text.length}`,
    );

    return {
      stepId: params.stepId,
      voiceSlug: voice.slug,
      locale: voice.locale,
      provider: voice.provider,
      textLength: step.text.length,
    };
  }

  // ── Preview ────────────────────────────────────────────────────────────────

  /**
   * Synthesize the plan's first non-empty say step against the chosen voice
   * and return the WAV bytes so admins can preview how a rendition sounds.
   *
   * Cache HIT path is the common case once the rendition is in 'ready' state —
   * the cache key matches what TtsBatchPregenService used during pre-generation
   * (speech rate '1.00', voice slug, locale, provider). On a miss the audio is
   * synthesized and written to L1 + S3, so subsequent previews are free.
   *
   * @throws NotFoundException if the plan, voice, or any say-step is missing.
   * @throws BadRequestException if the database is in noop mode.
   */
  async previewVoice(
    planId: string,
    voiceId: string,
  ): Promise<{ audio: Buffer; voiceSlug: string; locale: string; provider: string }> {
    this.logger.log(`previewVoice planId=${planId} voiceId=${voiceId}`);

    const planVoiceRows = await this.planVoicesRepo.listByPlan(planId);
    const planVoice = planVoiceRows.find((pv) => pv.voiceId === voiceId);
    if (!planVoice) {
      throw new NotFoundException(
        `No plan_voice record found for plan=${planId} voice=${voiceId}.`,
      );
    }

    const voice = await this.voiceRepo.findById(voiceId);
    if (!voice) {
      throw new NotFoundException(`Voice ${voiceId} not found`);
    }

    const database = this.db.getDb();
    if (!database) {
      throw new BadRequestException('Database is in noop mode — cannot synthesize.');
    }

    const planRows = await this.db.withRetry(() =>
      database
        .select({ planJson: plans.planJson })
        .from(plans)
        .where(eq(plans.id, planId))
        .limit(1),
    );
    if (planRows.length === 0) {
      throw new NotFoundException(`Plan ${planId} not found`);
    }

    let parsed: { steps?: unknown };
    try {
      parsed = JSON.parse(planRows[0].planJson) as { steps?: unknown };
    } catch {
      throw new BadRequestException(`Plan ${planId} has malformed plan_json`);
    }

    const step = findFirstSayStep(
      Array.isArray(parsed.steps) ? (parsed.steps as Array<Record<string, unknown>>) : [],
    );
    if (!step) {
      throw new NotFoundException(
        `Plan ${planId} has no say-step to preview. Add at least one say step.`,
      );
    }

    const audio = await this.ttsService.synthesize(
      step.text,
      voice.slug,
      planVoice.locale,
      voice.provider,
      '1.00',
    );

    return {
      audio,
      voiceSlug: voice.slug,
      locale: planVoice.locale,
      provider: voice.provider,
    };
  }
}

/**
 * Walks the step tree (descending into repeat.children) and returns the say
 * step whose id matches. Returns null when no match is found or the matched
 * step is not a say-step.
 */
function findSayStep(
  steps: Array<Record<string, unknown>>,
  stepId: string,
): { text: string } | null {
  for (const step of steps) {
    if (step.id === stepId && step.runtimeType === 'say') {
      const text = typeof step.text === 'string' ? step.text : '';
      return { text };
    }
    if (step.runtimeType === 'repeat' && Array.isArray(step.children)) {
      const found = findSayStep(step.children as Array<Record<string, unknown>>, stepId);
      if (found) return found;
    }
  }
  return null;
}

function findFirstSayStep(
  steps: Array<Record<string, unknown>>,
): { text: string } | null {
  for (const step of steps) {
    if (step.runtimeType === 'say') {
      const text = typeof step.text === 'string' ? step.text.trim() : '';
      if (text.length > 0) return { text };
    }
    if (step.runtimeType === 'repeat' && Array.isArray(step.children)) {
      const found = findFirstSayStep(step.children as Array<Record<string, unknown>>);
      if (found) return found;
    }
  }
  return null;
}
