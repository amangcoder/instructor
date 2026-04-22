/**
 * TtsBatchPregenService
 *
 * Batch TTS pre-generation for all providers:
 *
 * - Gemini: groups all SayStep texts sharing the same voice + locale into a
 *   single API call, slices the returned audio on silence boundaries, and caches
 *   each slice. 10 steps → 1 API call per voice/locale group.
 *
 * - Kokoro / ElevenLabs: synthesises each step individually (no concatenation
 *   API), but still uses the same job queue, status tracking, and S3 caching
 *   as the Gemini path.
 *
 * Cache keys, S3 paths, and downstream playback are identical to the standard flow.
 */
import { Injectable, Logger } from '@nestjs/common';
import {
  LambdaClient,
  InvokeCommand,
  InvocationType,
} from '@aws-sdk/client-lambda';
import { S3Client, HeadObjectCommand } from '@aws-sdk/client-s3';
import { DatabaseService } from '../database/database.service';
import { TtsService } from './tts.service';
import { TtsEnumerationService } from './tts-enumeration.service';
import { GEMINI_VOICE_MAP } from './providers/provider-registry.service';
import { buildWav } from './wav-utils';
import { splitPcmOnSilence } from './pcm-splitter';
import type { TtsBatchPregenWorkerTask } from '../lambda';

const MAX_ATTEMPTS = 3;
const RETRY_DELAY_MS = 1_000;
const STALE_TIMEOUT_MS = 15 * 60 * 1_000;

interface Group {
  voiceId: string;
  locale: string;
  provider: string;
  jobIds: string[];  // ordered — matches concatenation order
}

@Injectable()
export class TtsBatchPregenService {
  private readonly logger = new Logger(TtsBatchPregenService.name);
  private readonly s3: S3Client | null;
  private readonly bucket: string | null;
  private readonly lambda: LambdaClient | null;

  constructor(
    private readonly db: DatabaseService,
    private readonly ttsService: TtsService,
    private readonly enumService: TtsEnumerationService,
  ) {
    this.bucket = process.env.AWS_S3_BUCKET ?? null;
    this.s3 = this.bucket
      ? new S3Client({ region: process.env.AWS_REGION ?? 'ap-south-1' })
      : null;

    const functionName = process.env.AWS_LAMBDA_FUNCTION_NAME;
    this.lambda =
      functionName && !process.env.IS_LOCAL
        ? new LambdaClient({ region: process.env.AWS_REGION ?? 'ap-south-1' })
        : null;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

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
      await this.db.setTtsStatus(planId, 'completed', 0, 0);
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
      await this.db.setTtsStatus(planId, 'completed', 0, 0);
      return;
    }

    this.logger.log(
      `startBatchPregen — ${uncachedPairs.length}/${pairs.length} uncached for planId=${planId}`,
    );

    // Group pairs by effective voice + locale before job creation (pairs carry voiceId/locale).
    const pairGroups = this.groupPairsByVoiceAndLocale(uncachedPairs);

    const jobRecords = await this.db.createTtsJobs(
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

    await this.db.setTtsStatus(planId, 'processing', jobRecords.length, 0);

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

    const status = await this.db.getPlanTtsStatus(task.planId);
    if (status.completed + status.failed >= status.total) {
      await this.db.finalizePlanTtsStatus(task.planId);
      this.logger.log(`processTask — planId=${task.planId} finalized (${status.completed}/${status.total})`);
    }
  }

  async getStatus(planId: string) {
    await this.recoverIfStale(planId);
    return this.db.getPlanTtsStatus(planId);
  }

  // ── Group processing ───────────────────────────────────────────────────────

  private async processGroup(planId: string, group: Group): Promise<void> {
    const allJobs = await this.db.getTtsJobsByIds(group.jobIds);

    // Restore insertion order — DB may return rows in arbitrary order.
    const jobById = new Map(allJobs.map((j) => [j.id, j]));
    const jobs = group.jobIds.map((id) => jobById.get(id)!).filter(Boolean);

    if (jobs.length === 0) return;

    this.logger.log(
      `processGroup — voice=${group.voiceId}, locale=${group.locale}, provider=${group.provider}, steps=${jobs.length}`,
    );

    if (group.provider === 'gemini') {
      await this.processGroupGemini(planId, group, jobs);
    } else {
      await this.processGroupIndividual(planId, jobs);
    }
  }

  private async processGroupGemini(
    planId: string,
    group: Group,
    jobs: Array<{ id: string; text: string; cacheKey: string }>,
  ): Promise<void> {
    let lastErr: Error | undefined;

    for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
      try {
        await this.synthesizeBatchGemini(
          jobs.map((j) => ({ text: j.text, cacheKey: j.cacheKey })),
          group.voiceId,
          group.locale,
        );
        for (const job of jobs) {
          await this.db.updateTtsJobStatus(job.id, 'completed', `tts/${job.cacheKey}.wav`);
          await this.db.incrementTtsCompleted(planId);
          this.logger.log(`processGroupGemini — job ${job.id} done (${job.cacheKey.slice(0, 12)}…)`);
        }
        return;
      } catch (err) {
        lastErr = err instanceof Error ? err : new Error(String(err));
        if (attempt < MAX_ATTEMPTS) {
          this.logger.warn(`processGroup attempt ${attempt}/${MAX_ATTEMPTS} failed: ${lastErr.message}, retrying…`);
          await new Promise((r) => setTimeout(r, RETRY_DELAY_MS * attempt));
        }
      }
    }

    this.logger.error(`processGroup — voice=${group.voiceId} failed after ${MAX_ATTEMPTS} attempts: ${lastErr?.message}`);
    for (const job of jobs) {
      await this.db.updateTtsJobStatus(job.id, 'failed', undefined, lastErr?.message);
    }
  }

  /**
   * Core Gemini batch synthesis pipeline.
   *
   * Takes an array of say-step pairs, skips already-cached entries, concatenates
   * the remaining texts into a single Gemini TTS call, uses STT word timestamps
   * to split the audio at the <break> boundaries, and writes each segment to cache.
   */
  async synthesizeBatchGemini(
    pairs: Array<{ text: string; cacheKey: string }>,
    voiceId: string,
    locale: string,
  ): Promise<void> {
    const checks = await Promise.all(
      pairs.map(async (p) => ({ pair: p, cached: await this.checkS3Exists(`tts/${p.cacheKey}.wav`) })),
    );
    const uncached = checks.filter((c) => !c.cached).map((c) => c.pair);

    if (uncached.length === 0) {
      this.logger.log(`synthesizeBatchGemini — all ${pairs.length} pairs already cached`);
      return;
    }

    this.logger.log(`synthesizeBatchGemini — synthesizing ${uncached.length}/${pairs.length} uncached pairs`);

    const combined = uncached.map((p) => p.text).join('<break time="2500ms"/>');
    const combinedText = `<speak>${combined}</speak>`;

    const promptJson = this.ttsService.geminiTtsRequestBody(combinedText, voiceId, locale);
    await this.ttsService.writeRawToS3(
      `tts/${uncached[0].cacheKey}_batch${uncached.length}_prompt.json`,
      Buffer.from(JSON.stringify(promptJson, null, 2)),
      'application/json',
    );

    // Pass undefined for locale so buildPrompt does not inject a plain-text prefix
    // inside <speak>, which causes Gemini to ignore SSML tags including <break>.
    const pcm = await this.ttsService.synthesizeGeminiRaw(combinedText, voiceId, undefined);

    const combinedKey = `${uncached[0].cacheKey}_batch${uncached.length}`;
    await this.ttsService.writeToCacheByKey(combinedKey, buildWav(pcm));
    this.logger.log(`synthesizeBatchGemini — saved combined audio (${combinedKey.slice(0, 16)}…)`);

    const segments = splitPcmOnSilence(pcm, uncached.length, 1_500);

    for (let i = 0; i < uncached.length; i++) {
      await this.ttsService.writeToCacheByKey(uncached[i].cacheKey, buildWav(segments[i]));
      this.logger.log(`synthesizeBatchGemini — cached ${uncached[i].cacheKey.slice(0, 12)}…`);
    }
  }

  private async processGroupIndividual(
    planId: string,
    allJobs: Array<{ id: string; text: string; voiceId: string; locale: string; provider: string; speechRate: string; cacheKey: string }>,
  ): Promise<void> {
    const jobs = await this.filterAndMarkCached(planId, allJobs);
    if (jobs.length === 0) return;

    for (const job of jobs) {
      let lastErr: Error | undefined;

      for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
        try {
          await this.ttsService.synthesize(
            job.text, job.voiceId, job.locale, job.provider, job.speechRate,
          );
          await this.db.updateTtsJobStatus(job.id, 'completed', `tts/${job.cacheKey}.wav`);
          await this.db.incrementTtsCompleted(planId);
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
        await this.db.updateTtsJobStatus(job.id, 'failed', undefined, lastErr.message);
      }
    }
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
    const status = await this.db.getPlanTtsStatus(planId);
    const isInFlight = status.status === 'pending' || status.status === 'processing';
    if (!isInFlight) return;

    const ageMs = Date.now() - status.updatedAt.getTime();
    if (ageMs < STALE_TIMEOUT_MS) return;

    this.logger.warn(`recoverIfStale — planId=${planId} stale for ${Math.round(ageMs / 60_000)}min, recovering`);
    await this.db.failStalePendingJobs(planId);
    await this.db.finalizePlanTtsStatus(planId);
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
          await this.db.updateTtsJobStatus(job.id, 'completed', `tts/${job.cacheKey}.wav`);
          await this.db.incrementTtsCompleted(planId);
          this.logger.log(`filterAndMarkCached — job ${job.id} already cached, skipping`);
        }),
    );

    return checks.filter((c) => !c.cached).map((c) => c.job);
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
    if (process.env.IS_LOCAL) {
      this.logger.log(`dispatchWorker (local) — planId=${task.planId}, groups=${task.groups.length}`);
      setImmediate(() => {
        this.processTask(task).catch((err) =>
          this.logger.error(`dispatchWorker error: ${err instanceof Error ? err.message : err}`),
        );
      });
      return;
    }

    const functionName = process.env.AWS_LAMBDA_FUNCTION_NAME;
    if (!functionName || !this.lambda) {
      this.logger.warn('dispatchWorker — AWS_LAMBDA_FUNCTION_NAME not set, falling back to setImmediate()');
      setImmediate(() => {
        this.processTask(task).catch((err) =>
          this.logger.error(`dispatchWorker fallback error: ${err instanceof Error ? err.message : err}`),
        );
      });
      return;
    }

    await this.lambda.send(
      new InvokeCommand({
        FunctionName: functionName,
        InvocationType: InvocationType.Event,
        Payload: Buffer.from(JSON.stringify(task)),
      }),
    );
    this.logger.log(`dispatchWorker — invoked Lambda ${functionName} for planId=${task.planId}`);
  }
}
