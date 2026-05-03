/**
 * TtsPregenService
 *
 * Coordinates server-side TTS pre-generation for a plan:
 *   1. startPregen()  — called after plan activation (studio quality).
 *                       Enumerates TTS pairs, creates tts_jobs rows, and
 *                       dispatches a Lambda worker task (or setImmediate() locally).
 *   2. processJobs()  — called by the Lambda worker.
 *                       Synthesizes each job via TtsService and updates the DB.
 *
 * Local-dev mode (IS_LOCAL=true): uses setImmediate() instead of Lambda self-invocation.
 */
import { Injectable, Logger, Optional, Inject } from '@nestjs/common';
import { S3Client, HeadObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { DatabaseService } from '../database/database.service';
import { TtsRepository } from '../database/repositories/tts.repository';
import { PlanRepository } from '../database/repositories/plan.repository';
import { TtsService } from './tts.service';
import { TtsEnumerationService } from './tts-enumeration.service';
import { WorkerDispatchService } from '../worker-dispatch/worker-dispatch.service';
import type { TtsPregenWorkerTask } from '../worker-dispatch/worker-task.interface';
import type { AppConfig } from '../config/app-config.interface';

/** How many TTS jobs to dispatch per Lambda worker invocation. */
const CHUNK_SIZE = 10;

/** Total synthesis attempts per job (1 initial + 2 retries). */
const MAX_SYNTHESIS_ATTEMPTS = 3;

/**
 * How long a plan may stay in `pending` or `processing` without any DB write
 * before it is considered abandoned (worker crashed). After this window the
 * next status poll auto-recovers the plan to `partial` or `failed`.
 */
const STALE_TIMEOUT_MS = 15 * 60 * 1000; // 15 minutes

/** Delay between synthesis retries in milliseconds. */
const RETRY_DELAY_MS = 1_000;

/** Pre-signed URL TTL in seconds (1 hour). */
const PRESIGN_TTL_SECONDS = 3600;

@Injectable()
export class TtsPregenService {
  private readonly logger = new Logger(TtsPregenService.name);
  private readonly s3: S3Client | null;
  private readonly bucket: string | null;
  private readonly ttsRepo: TtsRepository | DatabaseService;
  private readonly planRepo: PlanRepository | DatabaseService;

  constructor(
    private readonly db: DatabaseService,
    private readonly ttsService: TtsService,
    private readonly enumService: TtsEnumerationService,
    private readonly workerDispatch: WorkerDispatchService,
    @Optional() @Inject('APP_CONFIG') config?: AppConfig,
    @Optional() @Inject(TtsRepository) ttsRepository?: TtsRepository,
    @Optional() @Inject(PlanRepository) planRepository?: PlanRepository,
  ) {
    this.ttsRepo = ttsRepository ?? db;
    this.planRepo = planRepository ?? db;
    this.bucket = (config?.awsS3Bucket || process.env.AWS_S3_BUCKET) ?? null;
    this.s3 = this.bucket
      ? new S3Client({ region: config?.awsRegion ?? process.env.AWS_REGION ?? 'ap-south-1' })
      : null;
  }

  /**
   * Begin TTS pre-generation for a plan.
   * Called after plan activation with voiceQuality='studio'.
   *
   * @param speechRate Speech rate as a pre-formatted string (e.g. '1.0').
   *                   Conversion from NUMERIC happens at the repository boundary.
   */
  async startPregen(
    planId: string,
    planJson: string,
    voiceId: string,
    locale: string,
    provider: string,
    speechRate: string,
  ): Promise<void> {
    this.logger.log(`startPregen — planId=${planId}, provider=${provider}`);

    // Clean up any dangling jobs from a previous crashed run before starting fresh.
    await this.recoverIfStale(planId);

    const pairs = this.enumService.enumerate(planJson, voiceId, locale, provider, speechRate);

    if (pairs.length === 0) {
      this.logger.warn(`startPregen — no TTS pairs found for planId=${planId}, marking complete`);
      await this.ttsRepo.setTtsStatus(planId, 'completed', 0, 0);
      return;
    }

    // Check S3 cache for every pair before creating jobs — skip any whose
    // audio file is already present so we don't re-synthesise or dispatch
    // unnecessary workers.
    const cacheChecks = await Promise.all(
      pairs.map(async (p) => {
        const s3Key = `tts/${p.cacheKey}.wav`;
        const cached = await this.checkS3Exists(s3Key);
        return { pair: p, cached };
      }),
    );

    const uncachedPairs = cacheChecks.filter((c) => !c.cached).map((c) => c.pair);

    if (uncachedPairs.length === 0) {
      this.logger.log(`startPregen — all ${pairs.length} TTS files already cached for planId=${planId}, marking complete`);
      await this.ttsRepo.setTtsStatus(planId, 'completed', 0, 0);
      return;
    }

    if (uncachedPairs.length < pairs.length) {
      this.logger.log(
        `startPregen — ${pairs.length - uncachedPairs.length}/${pairs.length} already cached, creating ${uncachedPairs.length} jobs for planId=${planId}`,
      );
    }

    // Create job records only for the uncached pairs.
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

    await this.ttsRepo.setTtsStatus(planId, 'processing', jobRecords.length, 0);
    this.logger.log(`startPregen — created ${jobRecords.length} jobs for planId=${planId}`);

    // Dispatch worker(s) — chunked to stay within Lambda payload/timeout limits.
    const jobIds = jobRecords.map((j) => j.id);
    for (let i = 0; i < jobIds.length; i += CHUNK_SIZE) {
      const chunk = jobIds.slice(i, i + CHUNK_SIZE);
      const task: TtsPregenWorkerTask = { task: 'ttsPregen', planId, jobIds: chunk };
      await this.dispatchWorker(task);
    }
  }

  /**
   * Process a batch of TTS jobs (called by the Lambda worker task handler).
   * Synthesizes each job, uploads audio to S3, and updates job + plan status.
   */
  async processJobs(planId: string, jobIds: string[]): Promise<void> {
    this.logger.log(`processJobs — planId=${planId}, jobs=${jobIds.length}`);

    const jobs = await this.ttsRepo.getTtsJobsByIds(jobIds);

    for (const job of jobs) {
      let lastErr: Error | undefined;

      for (let attempt = 1; attempt <= MAX_SYNTHESIS_ATTEMPTS; attempt++) {
        try {
          // synthesize() owns the full cache contract: key → check (L1+L2) → synthesize if miss → save to L1+L2.
          await this.ttsService.synthesize(
            job.text,
            job.voiceId,
            job.locale,
            job.provider,
            job.speechRate,
          );
          lastErr = undefined;
          break;
        } catch (err) {
          lastErr = err instanceof Error ? err : new Error(String(err));
          if (attempt < MAX_SYNTHESIS_ATTEMPTS) {
            this.logger.warn(
              `processJobs — job ${job.id} attempt ${attempt}/${MAX_SYNTHESIS_ATTEMPTS} failed: ${lastErr.message}, retrying in ${RETRY_DELAY_MS}ms…`,
            );
            await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY_MS));
          }
        }
      }

      if (!lastErr) {
        const s3Key = `tts/${job.cacheKey}.wav`;
        await this.ttsRepo.updateTtsJobStatus(job.id, 'completed', s3Key);
        await this.ttsRepo.incrementTtsCompleted(planId);
        this.logger.log(`processJobs — job ${job.id} completed (${job.cacheKey.slice(0, 12)}…)`);
      } else {
        this.logger.error(
          `processJobs — job ${job.id} failed after ${MAX_SYNTHESIS_ATTEMPTS} attempts: ${lastErr.message}`,
        );
        await this.ttsRepo.updateTtsJobStatus(job.id, 'failed', undefined, lastErr.message);
      }
    }

    // Check whether all jobs for this plan are now done.
    const status = await this.ttsRepo.getPlanTtsStatus(planId);
    const allDone = status.completed + status.failed >= status.total;
    if (allDone) {
      await this.ttsRepo.finalizePlanTtsStatus(planId);
      this.logger.log(`processJobs — planId=${planId} finalized (${status.completed}/${status.total})`);
    }
  }

  /**
   * Get TTS pre-generation status for a plan.
   * Automatically recovers stale plans whose worker crashed mid-synthesis.
   */
  async getStatus(planId: string) {
    await this.recoverIfStale(planId);
    return this.ttsRepo.getPlanTtsStatus(planId);
  }

  /**
   * Detects and recovers a plan whose TTS worker crashed before finishing.
   *
   * A plan is considered stale when its status is `pending` or `processing`
   * and the plan row has not been updated for longer than [STALE_TIMEOUT_MS].
   * Recovery: mark all remaining `pending` jobs as failed, then finalize the
   * plan status — which produces `partial` (some completed) or `failed` (none).
   */
  private async recoverIfStale(planId: string): Promise<void> {
    const status = await this.ttsRepo.getPlanTtsStatus(planId);

    const isInFlight = status.status === 'pending' || status.status === 'processing';
    if (!isInFlight) return;

    const ageMs = Date.now() - status.updatedAt.getTime();
    if (ageMs < STALE_TIMEOUT_MS) return;

    this.logger.warn(
      `recoverIfStale — planId=${planId} has been ${status.status} for ${Math.round(ageMs / 60_000)}min, recovering`,
    );

    await this.ttsRepo.failStalePendingJobs(planId);
    await this.ttsRepo.finalizePlanTtsStatus(planId);
  }

  /**
   * Get pre-signed S3 audio URLs for all completed TTS jobs of a plan.
   * Returns an empty map when S3 is not configured.
   */
  async getAudioUrls(planId: string): Promise<Record<string, string>> {
    if (!this.s3 || !this.bucket) {
      this.logger.warn(`getAudioUrls — S3 not configured, returning empty map for planId=${planId}`);
      return {};
    }

    const jobs = await this.ttsRepo.getCompletedTtsJobs(planId);
    const urlMap: Record<string, string> = {};

    await Promise.all(
      jobs.map(async (job) => {
        if (!job.s3Key) return;
        try {
          const url = await getSignedUrl(
            this.s3!,
            new GetObjectCommand({ Bucket: this.bucket!, Key: job.s3Key }),
            { expiresIn: PRESIGN_TTL_SECONDS },
          );
          urlMap[job.cacheKey] = url;
        } catch (err) {
          this.logger.warn(
            `getAudioUrls — presign failed for job ${job.id}: ${err instanceof Error ? err.message : err}`,
          );
        }
      }),
    );

    this.logger.log(`getAudioUrls — returning ${Object.keys(urlMap).length} URLs for planId=${planId}`);
    return urlMap;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  private async checkS3Exists(key: string): Promise<boolean> {
    if (!this.s3 || !this.bucket) return false;
    try {
      await this.s3.send(new HeadObjectCommand({ Bucket: this.bucket, Key: key }));
      return true;
    } catch {
      return false;
    }
  }

  private async dispatchWorker(task: TtsPregenWorkerTask): Promise<void> {
    await this.workerDispatch.dispatchTtsPregen(
      task,
      () => this.processJobs(task.planId, task.jobIds),
    );
  }
}
