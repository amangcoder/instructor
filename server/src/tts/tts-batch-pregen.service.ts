/**
 * TtsBatchPregenService
 *
 * Per-step TTS pre-generation for all providers. Each say-step is synthesised
 * individually via the standard `TtsService.synthesize` path, sharing the same
 * job queue, status tracking, and S3 caching as the on-demand flow.
 *
 * Cache keys, S3 paths, and downstream playback are identical to the standard flow.
 *
 * ## Dual-write behaviour (feature flag: use_plan_voices_gate)
 *
 * When `use_plan_voices_gate = false` (AC-006 — transition / dual-write mode):
 *   • Both `plans.tts_status` (via TtsRepository) AND `plan_voices.status` are updated.
 *   • Existing callers and mobile clients that still read `plans.tts_status` remain
 *     functional during the rollout window.
 *
 * When `use_plan_voices_gate = true` (AC-007 — new-gate mode):
 *   • ONLY `plan_voices.status` is updated.
 *   • `plans.tts_status`, `tts_completed`, and `finalizePlanTtsStatus` calls are skipped.
 *   • TTS job rows (`tts_jobs`) are still written for S3 caching and recovery.
 *
 * PlanVoicesRepository is injected as `@Optional()`. If the provider is not
 * registered (e.g. in legacy test modules), plan_voices writes are silently skipped
 * and the service degrades to legacy-only behaviour.
 */
import { Injectable, Logger, Optional, Inject } from '@nestjs/common';
import { S3Client, HeadObjectCommand } from '@aws-sdk/client-s3';
import { DatabaseService } from '../database/database.service';
import { TtsRepository } from '../database/repositories/tts.repository';
import { PlanVoicesRepository } from '../database/repositories/plan-voices.repository';
import type { PlanVoiceStatus } from '../database/repositories/plan-voices.repository';
import { VoiceRepository } from '../database/repositories/voice.repository';
import { TtsService } from './tts.service';
import { TtsEnumerationService } from './tts-enumeration.service';
import { WorkerDispatchService } from '../worker-dispatch/worker-dispatch.service';
import { GEMINI_VOICE_MAP } from './providers/provider-registry.service';
import type { TtsBatchPregenWorkerTask } from '../worker-dispatch/worker-task.interface';
import type { AppConfig } from '../config/app-config.interface';

const MAX_ATTEMPTS = 3;
const RETRY_DELAY_MS = 1_000;
const STALE_TIMEOUT_MS = 15 * 60 * 1_000;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

interface Group {
  voiceId: string;
  locale: string;
  provider: string;
  jobIds: string[];  // ordered — matches enumeration order
}

@Injectable()
export class TtsBatchPregenService {
  private readonly logger = new Logger(TtsBatchPregenService.name);
  private readonly s3: S3Client | null;
  private readonly bucket: string | null;
  private readonly ttsRepo: TtsRepository | DatabaseService;
  private readonly planVoicesRepo: PlanVoicesRepository | null;
  private readonly voiceRepo: VoiceRepository | null;
  private readonly usePlanVoicesGate: boolean;

  constructor(
    private readonly db: DatabaseService,
    private readonly ttsService: TtsService,
    private readonly enumService: TtsEnumerationService,
    private readonly workerDispatch: WorkerDispatchService,
    @Optional() @Inject('APP_CONFIG') config?: AppConfig,
    @Optional() @Inject(TtsRepository) ttsRepository?: TtsRepository,
    @Optional() @Inject(PlanVoicesRepository) planVoicesRepo?: PlanVoicesRepository,
    @Optional() @Inject(VoiceRepository) voiceRepo?: VoiceRepository,
  ) {
    this.ttsRepo = ttsRepository ?? db;
    this.planVoicesRepo = planVoicesRepo ?? null;
    this.voiceRepo = voiceRepo ?? null;
    this.usePlanVoicesGate = config?.usePlanVoicesGate
      ?? (process.env.USE_PLAN_VOICES_GATE === 'true');
    this.bucket = (config?.awsS3Bucket || process.env.AWS_S3_BUCKET) ?? null;
    this.s3 = this.bucket
      ? new S3Client({ region: config?.awsRegion ?? process.env.AWS_REGION ?? 'ap-south-1' })
      : null;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /**
   * Start batch TTS pre-generation for a plan.
   *
   * @param planId     UUID of the plan.
   * @param planJson   Serialised plan JSON used by TtsEnumerationService to extract steps.
   * @param voiceId    Voice identifier. When the plan_voices gate is active this must be
   *                   the UUID of the voice row in the `voices` table so that plan_voices
   *                   upserts resolve the correct FK. Legacy callers may pass a slug —
   *                   in that case plan_voices writes are still attempted but the FK
   *                   constraint will fail unless the slug happens to match a UUID.
   * @param locale     BCP-47 locale string (e.g. 'enUS').
   * @param provider   TTS provider identifier (e.g. 'gemini', 'kokoro').
   * @param speechRate Speech rate as a pre-formatted string (e.g. '1.00').
   *                   Conversion from NUMERIC happens at the repository boundary.
   */
  async startBatchPregen(
    planId: string,
    planJson: string,
    voiceId: string,
    locale: string,
    provider: string,
    speechRate: string,
  ): Promise<void> {
    this.logger.log(`startBatchPregen — planId=${planId}`);

    await this.recoverIfStale(planId);

    const pairs = this.enumService.enumerate(planJson, voiceId, locale, provider, speechRate);

    if (pairs.length === 0) {
      this.logger.warn(`startBatchPregen — no TTS pairs for planId=${planId}, marking complete`);
      // Dual-write: update plans.tts_status only when gate flag is OFF.
      if (!this.usePlanVoicesGate) {
        await this.ttsRepo.setTtsStatus(planId, 'completed', 0, 0);
      }
      // Always write plan_voices when repository is available.
      await this.writePlanVoiceStatus(planId, voiceId, locale, 'ready');
      return;
    }

    const cacheChecks = await Promise.all(
      pairs.map(async (p) => ({
        pair: p,
        cached: await this.checkS3Exists(`tts/${p.cacheKey}.wav`),
      })),
    );
    const uncachedPairs = cacheChecks.filter((c) => !c.cached).map((c) => c.pair);

    if (uncachedPairs.length === 0) {
      this.logger.log(`startBatchPregen — all ${pairs.length} files cached for planId=${planId}`);
      // Dual-write: update plans.tts_status only when gate flag is OFF.
      if (!this.usePlanVoicesGate) {
        await this.ttsRepo.setTtsStatus(planId, 'completed', 0, 0);
      }
      // Always write plan_voices when repository is available.
      await this.writePlanVoiceStatus(planId, voiceId, locale, 'ready');
      return;
    }

    this.logger.log(
      `startBatchPregen — ${uncachedPairs.length}/${pairs.length} uncached for planId=${planId}`,
    );

    // Group pairs by effective voice + locale before job creation (pairs carry voiceId/locale).
    const pairGroups = this.groupPairsByVoiceAndLocale(uncachedPairs);

    const jobRecords = await this.ttsRepo.createTtsJobs(
      uncachedPairs.map((p) => ({
        planId,
        cacheKey: p.cacheKey,
        text: p.text,
        voiceId: p.voiceId,
        locale: p.locale,
        provider: p.provider,
        speechRate: p.speechRate,
      })),
    );

    // Dual-write: update plans.tts_status only when gate flag is OFF.
    if (!this.usePlanVoicesGate) {
      await this.ttsRepo.setTtsStatus(planId, 'processing', jobRecords.length, 0);
    }
    // Always write plan_voices when repository is available.
    await this.writePlanVoiceStatus(planId, voiceId, locale, 'processing');

    // Resolve pair cache keys → job IDs using the DB-returned map.
    const cacheKeyToId = new Map(jobRecords.map((r) => [r.cacheKey, r.id]));
    const groups: Group[] = pairGroups.map((pg) => ({
      voiceId: pg.voiceId,
      locale: pg.locale,
      provider: pg.provider,
      jobIds: pg.cacheKeys.map((ck) => cacheKeyToId.get(ck)!).filter(Boolean),
    }));

    const task: TtsBatchPregenWorkerTask = { task: 'ttsBatchPregen', planId, groups };
    await this.dispatchWorker(task);
  }

  async processTask(task: TtsBatchPregenWorkerTask): Promise<void> {
    this.logger.log(`processTask — planId=${task.planId}, groups=${task.groups.length}`);

    for (const group of task.groups) {
      await this.processGroup(task.planId, group);
    }

    // Finalize plans.tts_status only in legacy / dual-write mode.
    if (!this.usePlanVoicesGate) {
      const status = await this.ttsRepo.getPlanTtsStatus(task.planId);
      if (status.completed + status.failed >= status.total) {
        await this.ttsRepo.finalizePlanTtsStatus(task.planId);
        this.logger.log(`processTask — planId=${task.planId} finalized (${status.completed}/${status.total})`);
      }
    }
  }

  async getStatus(planId: string) {
    await this.recoverIfStale(planId);
    return this.ttsRepo.getPlanTtsStatus(planId);
  }

  /**
   * Create (or reset) a plan_voices row to `pending` and queue a new TTS batch job.
   *
   * Designed for the admin "Regenerate" action on a failed plan_voice. The
   * caller is responsible for passing the UUID voice identifier so that the
   * plan_voices FK resolves correctly.
   *
   * @param planId     UUID of the plan to regenerate audio for.
   * @param voiceId    UUID of the voice (from the `voices` table).
   * @param locale     BCP-47 locale (must match the existing plan_voices row locale).
   * @param planJson   Serialised plan JSON for TTS step enumeration.
   * @param provider   TTS provider identifier (e.g. 'gemini', 'kokoro').
   * @param speechRate Speech rate string (e.g. '1.00').
   */
  async regenerateVoice(
    planId: string,
    voiceId: string,
    locale: string,
    planJson: string,
    provider: string,
    speechRate: string = '1.00',
  ): Promise<void> {
    if (!this.planVoicesRepo) {
      this.logger.warn(`regenerateVoice — PlanVoicesRepository not available, skipping planId=${planId}`);
      return;
    }

    this.logger.log(`regenerateVoice — planId=${planId}, voiceId=${voiceId}`);

    const resolvedVoiceId = await this.resolveVoiceUuid(voiceId);
    if (!resolvedVoiceId) {
      this.logger.warn(
        `regenerateVoice — could not resolve voiceId='${voiceId}' to a UUID; skipping planId=${planId}`,
      );
      return;
    }

    // Reset / create the plan_voices row to 'pending' so the UI reflects the
    // enqueued state immediately while the TTS worker picks up the batch.
    await this.planVoicesRepo.upsertPlanVoice({
      planId,
      voiceId: resolvedVoiceId,
      locale,
      status: 'pending',
    });

    // Queue the full TTS batch for this plan+voice combination.
    // startBatchPregen will re-enumerate steps, skip already-cached S3 keys,
    // create tts_jobs rows, and dispatch the worker task.
    await this.startBatchPregen(planId, planJson, voiceId, locale, provider, speechRate);
  }

  // ── Group processing ───────────────────────────────────────────────────────

  private async processGroup(planId: string, group: Group): Promise<void> {
    const allJobs = await this.ttsRepo.getTtsJobsByIds(group.jobIds);

    // Restore insertion order — DB may return rows in arbitrary order.
    const jobById = new Map(allJobs.map((j) => [j.id, j]));
    const jobs = group.jobIds.map((id) => jobById.get(id)!).filter(Boolean);

    if (jobs.length === 0) return;

    this.logger.log(
      `processGroup — voice=${group.voiceId}, locale=${group.locale}, provider=${group.provider}, steps=${jobs.length}`,
    );

    await this.processGroupIndividual(planId, jobs);
  }

  private async processGroupIndividual(
    planId: string,
    allJobs: Array<{ id: string; text: string; voiceId: string; locale: string; provider: string; speechRate: string; cacheKey: string }>,
  ): Promise<void> {
    const jobs = await this.filterAndMarkCached(planId, allJobs);

    // All jobs for this voice+locale were already in S3 — mark voice ready.
    if (jobs.length === 0) {
      if (allJobs.length > 0) {
        await this.writePlanVoiceStatus(planId, allJobs[0].voiceId, allJobs[0].locale, 'ready');
      }
      return;
    }

    let anyFailed = false;

    for (const job of jobs) {
      let lastErr: Error | undefined;

      for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
        try {
          await this.ttsService.synthesize(
            job.text, job.voiceId, job.locale, job.provider, job.speechRate,
          );
          await this.ttsRepo.updateTtsJobStatus(job.id, 'completed', `tts/${job.cacheKey}.wav`);
          // Increment plans.tts_completed counter only in legacy / dual-write mode.
          if (!this.usePlanVoicesGate) {
            await this.ttsRepo.incrementTtsCompleted(planId);
          }
          this.logger.log(`processGroup — job ${job.id} cached (${job.cacheKey.slice(0, 12)}…)`);
          lastErr = undefined;
          break;
        } catch (err) {
          lastErr = err instanceof Error ? err : new Error(String(err));
          if (attempt < MAX_ATTEMPTS) {
            this.logger.warn(
              `processGroup job ${job.id} attempt ${attempt}/${MAX_ATTEMPTS} failed: ${lastErr.message}, retrying…`,
            );
            await new Promise((r) => setTimeout(r, RETRY_DELAY_MS * attempt));
          }
        }
      }

      if (lastErr) {
        this.logger.error(`processGroup — job ${job.id} failed after ${MAX_ATTEMPTS} attempts: ${lastErr.message}`);
        await this.ttsRepo.updateTtsJobStatus(job.id, 'failed', undefined, lastErr.message);
        anyFailed = true;
      }
    }

    // Update plan_voices with final synthesis result for this voice+locale group.
    const finalStatus: PlanVoiceStatus = anyFailed ? 'failed' : 'ready';
    await this.writePlanVoiceStatus(planId, allJobs[0].voiceId, allJobs[0].locale, finalStatus);
  }

  // ── Grouping ───────────────────────────────────────────────────────────────

  private groupPairsByVoiceAndLocale(
    pairs: Array<{ voiceId: string; locale: string; provider: string; cacheKey: string }>,
  ): Array<{ voiceId: string; locale: string; provider: string; cacheKeys: string[] }> {
    const groupMap = new Map<string, { voiceId: string; locale: string; provider: string; cacheKeys: string[] }>();

    for (const pair of pairs) {
      // Gemini remaps Kokoro/ElevenLabs voices to the nearest Gemini voice.
      // Other providers use the voice ID as-is.
      const effectiveVoice = pair.provider === 'gemini'
        ? (GEMINI_VOICE_MAP[pair.voiceId] ?? pair.voiceId)
        : pair.voiceId;
      const key = `${effectiveVoice}|${pair.locale}|${pair.provider}`;

      if (!groupMap.has(key)) {
        groupMap.set(key, { voiceId: effectiveVoice, locale: pair.locale, provider: pair.provider, cacheKeys: [] });
      }
      groupMap.get(key)!.cacheKeys.push(pair.cacheKey);
    }

    return [...groupMap.values()];
  }

  // ── Stale recovery ─────────────────────────────────────────────────────────

  private async recoverIfStale(planId: string): Promise<void> {
    const status = await this.ttsRepo.getPlanTtsStatus(planId);
    const isInFlight = status.status === 'pending' || status.status === 'processing';
    if (!isInFlight) return;

    const ageMs = Date.now() - status.updatedAt.getTime();
    if (ageMs < STALE_TIMEOUT_MS) return;

    this.logger.warn(`recoverIfStale — planId=${planId} stale for ${Math.round(ageMs / 60_000)}min, recovering`);
    await this.ttsRepo.failStalePendingJobs(planId);
    await this.ttsRepo.finalizePlanTtsStatus(planId);
  }

  // ── Cache filter ───────────────────────────────────────────────────────────

  /**
   * Checks S3 for each job's cache key, marks already-cached jobs completed in DB,
   * and returns only the jobs that still need synthesis.
   */
  private async filterAndMarkCached<T extends { id: string; cacheKey: string }>(
    planId: string,
    jobs: T[],
  ): Promise<T[]> {
    const checks = await Promise.all(
      jobs.map(async (j) => ({ job: j, cached: await this.checkS3Exists(`tts/${j.cacheKey}.wav`) })),
    );

    await Promise.all(
      checks
        .filter((c) => c.cached)
        .map(async ({ job }) => {
          await this.ttsRepo.updateTtsJobStatus(job.id, 'completed', `tts/${job.cacheKey}.wav`);
          // Increment plans.tts_completed counter only in legacy / dual-write mode.
          if (!this.usePlanVoicesGate) {
            await this.ttsRepo.incrementTtsCompleted(planId);
          }
          this.logger.log(`filterAndMarkCached — job ${job.id} already cached, skipping`);
        }),
    );

    return checks.filter((c) => !c.cached).map((c) => c.job);
  }

  // ── Plan-voices write helper ────────────────────────────────────────────────

  /**
   * Upserts a plan_voices row for (planId, voiceId, locale) with the given status.
   *
   * No-op when PlanVoicesRepository is not injected (legacy test/module context).
   *
   * Accepts either a voice UUID or a voice slug for `voiceId`. Slugs are
   * resolved via VoiceRepository.findBySlug so that callers from legacy code
   * paths (e.g. plans.activatePlan, which receives client-supplied slugs)
   * don't trigger the plan_voices.voice_id UUID FK violation.
   */
  private async writePlanVoiceStatus(
    planId: string,
    voiceId: string,
    locale: string,
    status: PlanVoiceStatus,
  ): Promise<void> {
    if (!this.planVoicesRepo) return;
    const resolvedVoiceId = await this.resolveVoiceUuid(voiceId);
    if (!resolvedVoiceId) {
      this.logger.warn(
        `writePlanVoiceStatus — could not resolve voiceId='${voiceId}' to a UUID; skipping plan_voices upsert for planId=${planId}`,
      );
      return;
    }
    await this.planVoicesRepo.upsertPlanVoice({
      planId,
      voiceId: resolvedVoiceId,
      locale,
      status,
    });
  }

  /**
   * Resolve a voice identifier to its UUID. Returns the input unchanged if it
   * already looks like a UUID; otherwise looks up the slug via VoiceRepository.
   * Returns null when the slug is not registered.
   */
  private async resolveVoiceUuid(voiceId: string): Promise<string | null> {
    if (UUID_RE.test(voiceId)) return voiceId;
    if (!this.voiceRepo) return null;
    const voice = await this.voiceRepo.findBySlug(voiceId);
    return voice?.id ?? null;
  }

  // ── S3 helpers ─────────────────────────────────────────────────────────────

  private async checkS3Exists(key: string): Promise<boolean> {
    if (!this.s3 || !this.bucket) return false;
    try {
      await this.s3.send(new HeadObjectCommand({ Bucket: this.bucket, Key: key }));
      return true;
    } catch {
      return false;
    }
  }

  // ── Worker dispatch ────────────────────────────────────────────────────────

  private async dispatchWorker(task: TtsBatchPregenWorkerTask): Promise<void> {
    await this.workerDispatch.dispatchBatchPregen(
      task,
      () => this.processTask(task),
    );
  }
}
