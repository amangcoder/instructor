/**
 * PlanRequestPromoteService — promotes a plan_request into a real plan
 * with plan_voices rows and post-commit TTS job enqueuing.
 *
 * ## Transaction semantics
 *
 * Neon HTTP driver (neon-http) sends each query as an independent HTTPS request
 * and does NOT support multi-statement transactions. To achieve atomicity:
 *
 *   1. Insert plan row → get planId
 *   2. Insert N plan_voices rows via PlanVoicesRepository.createBatch()
 *   3. Mark plan_request as processed
 *
 * If any DB write fails, subsequent writes are skipped and the error propagates.
 * The ON CONFLICT / idempotent upsert semantics of createBatch() mean that a
 * retry of the entire promote operation is safe.
 *
 * ## TTS enqueuing
 *
 * TTS jobs are enqueued AFTER all DB writes succeed. This ensures we never
 * dispatch work for a plan that doesn't exist in the database. If TTS
 * enqueuing fails, the plan and plan_voices rows are already committed —
 * the admin can trigger a manual regenerate from the voice grid.
 *
 * NOTE: TTS enqueue happens post-commit. If the TTS queue is unavailable,
 * plan_voices rows remain in 'pending' status and can be retried via the
 * admin regenerate endpoint.
 */

import {
  Injectable,
  Logger,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { AdminRepository } from '../database/repositories/admin.repository';
import { PlanVoicesRepository } from '../database/repositories/plan-voices.repository';
import { TtsBatchPregenService } from '../tts/tts-batch-pregen.service';
import { plans, planRequests, voices } from '../database/schema';
import { eq, inArray } from 'drizzle-orm';
import type { NewPlanVoice } from '../database/schema';

export interface PromoteResult {
  planId: string;
}

@Injectable()
export class PlanRequestPromoteService {
  private readonly logger = new Logger(PlanRequestPromoteService.name);

  constructor(
    private readonly db: DatabaseService,
    private readonly adminRepo: AdminRepository,
    private readonly planVoicesRepo: PlanVoicesRepository,
    private readonly ttsBatchPregen: TtsBatchPregenService,
  ) {}

  /**
   * Promote a plan request into a real plan with plan_voices rows.
   *
   * Steps:
   *   1. Fetch the plan request (must exist and be in 'pending' status)
   *   2. Validate all voiceIds exist in the voices table
   *   3. Create a plan record from the request data
   *   4. Insert N plan_voices rows with status='pending'
   *   5. Mark the plan request as 'processed'
   *   6. (Post-commit) Enqueue TTS batch jobs for each voice
   *
   * @param planRequestId  UUID of the plan_request to promote
   * @param voiceIds       Array of voice UUIDs to create renditions for
   * @param seriesId       Optional series UUID to assign the plan to
   * @param categoryId     Optional category UUID (currently stored for reference)
   * @param position       Optional sort position within the series or top-level
   *
   * @throws NotFoundException if plan request not found or already processed
   * @throws UnprocessableEntityException if any voiceId is invalid
   */
  async promote(
    planRequestId: string,
    voiceIds: string[],
    seriesId?: string,
    categoryId?: string,
    position?: number,
  ): Promise<PromoteResult> {
    const drizzle = this.db.getDb();

    // ── 1. Fetch plan request ───────────────────────────────────────────────

    const requestRows = await this.db.withRetry(() =>
      drizzle
        .select()
        .from(planRequests)
        .where(eq(planRequests.id, planRequestId))
        .limit(1),
    );

    if (requestRows.length === 0) {
      throw new NotFoundException(`Plan request ${planRequestId} not found`);
    }

    const planRequest = requestRows[0];

    if (planRequest.status !== 'pending') {
      throw new UnprocessableEntityException(
        `Plan request ${planRequestId} has status '${planRequest.status}', only 'pending' requests can be promoted`,
      );
    }

    // ── 2. Validate voice IDs exist ─────────────────────────────────────────

    const voiceRows = await this.db.withRetry(() =>
      drizzle
        .select({ id: voices.id, locale: voices.locale, provider: voices.provider })
        .from(voices)
        .where(inArray(voices.id, voiceIds)),
    );

    if (voiceRows.length !== voiceIds.length) {
      const foundIds = new Set(voiceRows.map((v) => v.id));
      const missing = voiceIds.filter((id) => !foundIds.has(id));
      throw new UnprocessableEntityException(
        `Voice IDs not found: ${missing.join(', ')}`,
      );
    }

    // Build a lookup for enqueuing TTS later
    const voiceLookup = new Map(voiceRows.map((v) => [v.id, v]));

    // ── 3. Create plan record (idempotent) ─────────────────────────────────
    //
    // plan_request_id carries a UNIQUE constraint on the plans table (migration 0015).
    // ON CONFLICT DO NOTHING means a re-try after a partial failure (e.g. step 5 failed
    // last time) will hit the conflict guard and return 0 rows instead of inserting a
    // duplicate. We then re-select to recover the planId and continue from step 4.
    //
    // NOTE: plan_json is intentionally seeded with steps: [] because plan_requests only
    // carry title + description at submit time. The admin must populate steps via
    // PATCH /admin/plans/:id after promotion. TTS generation is skipped for empty-step
    // plans (see step 6 below) — plan_voices rows stay 'pending' until the admin
    // triggers a regenerate from the voice grid once steps have been added.

    const now = new Date();

    // Build a minimal plan JSON from the request data
    const planJson = JSON.stringify({
      name: planRequest.title,
      description: planRequest.description,
      steps: [],
    });

    const insertedPlan = await this.db.withRetry(() =>
      drizzle
        .insert(plans)
        .values({
          userId: planRequest.userId!,
          name: planRequest.title,
          planJson,
          seriesId: seriesId ?? null,
          isActive: false,
          ttsStatus: 'pending',
          ttsTotal: 0,
          ttsCompleted: 0,
          voiceQuality: 'studio',
          position: position ?? 0,
          visibility: 'public',
          ownerUserId: planRequest.userId,
          isPublished: false,
          planRequestId: planRequestId,
          createdAt: now,
          updatedAt: now,
        })
        .onConflictDoNothing()
        .returning({ id: plans.id }),
    );

    let planId: string;
    if (insertedPlan.length === 0) {
      // Conflict: a previous promote attempt already created this plan row.
      // Re-select to recover the planId and continue from step 4 onward.
      this.logger.warn(
        `Plan already exists for request ${planRequestId} — recovering planId for idempotent retry`,
      );
      const existing = await this.db.withRetry(() =>
        drizzle
          .select({ id: plans.id })
          .from(plans)
          .where(eq(plans.planRequestId, planRequestId))
          .limit(1),
      );
      if (existing.length === 0) {
        throw new Error(
          `ON CONFLICT fired for plan_request_id=${planRequestId} but no matching plan row found — DB inconsistency`,
        );
      }
      planId = existing[0].id;
    } else {
      planId = insertedPlan[0].id;
    }

    this.logger.log(
      `Plan created from request: planId=${planId}, requestId=${planRequestId}`,
    );

    // ── 4. Insert plan_voices rows ──────────────────────────────────────────

    const planVoiceRows: NewPlanVoice[] = voiceIds.map((voiceId) => ({
      planId,
      voiceId,
      locale: voiceLookup.get(voiceId)!.locale,
      status: 'pending' as const,
    }));

    const db = this.db.getDb();
    await this.planVoicesRepo.createBatch(planVoiceRows, db);

    this.logger.log(
      `Created ${planVoiceRows.length} plan_voices rows for planId=${planId}`,
    );

    // ── 5. Mark plan request as processed ───────────────────────────────────

    await this.adminRepo.markPlanRequestProcessed(planRequestId);

    this.logger.log(
      `Plan request ${planRequestId} marked as processed`,
    );

    // ── 6. Post-commit: Enqueue TTS jobs ────────────────────────────────────
    // NOTE: TTS enqueue happens after all DB writes succeed.
    // If TTS enqueuing fails, plan_voices remain in 'pending' status
    // and can be retried via the admin regenerate endpoint.
    //
    // Guard: skip TTS entirely when planJson has no steps. plan_requests only
    // carry title + description, so promoted plans always start with steps: [].
    // The admin adds steps via PATCH /admin/plans/:id; once steps exist the
    // admin triggers regenerate from the voice grid to queue TTS jobs.

    const parsedPlan = JSON.parse(planJson) as { steps?: unknown[] };
    if (!parsedPlan.steps || parsedPlan.steps.length === 0) {
      this.logger.warn(
        `Plan ${planId} has no steps — TTS generation skipped. ` +
          `Add steps via PATCH /admin/plans/${planId}, then use the voice grid regenerate action.`,
      );
      return { planId };
    }

    for (const voiceId of voiceIds) {
      const voice = voiceLookup.get(voiceId)!;
      try {
        await this.ttsBatchPregen.startBatchPregen(
          planId,
          planJson,
          voiceId,
          voice.locale,
          voice.provider,
          '1.00',
        );
        this.logger.log(
          `TTS batch enqueued: planId=${planId}, voiceId=${voiceId}`,
        );
      } catch (err) {
        // Non-fatal: plan and plan_voices are already committed.
        // Admin can retry via the regenerate endpoint.
        this.logger.error(
          `TTS enqueue failed for planId=${planId}, voiceId=${voiceId}: ${(err as Error).message}`,
        );
      }
    }

    return { planId };
  }
}
