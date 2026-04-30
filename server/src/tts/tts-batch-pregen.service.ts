/**
 * TtsBatchPregenService
 *
 * Batch TTS pre-generation for all providers:
 *
 * - Gemini: groups all SayStep texts sharing the same voice + locale into a
 *   single API call, splits the returned audio per-text via forced alignment
 *   (kokoro-server /align), and caches each slice. Falls back to silence-based
 *   splitting if alignment is unavailable. 10 steps → 1 API call per group.
 *
 * - Kokoro / ElevenLabs: synthesises each step individually (no concatenation
 *   API), but still uses the same job queue, status tracking, and S3 caching
 *   as the Gemini path.
 *
 * Cache keys, S3 paths, and downstream playback are identical to the standard flow.
 */
import { Injectable, Logger, Optional, Inject } from '@nestjs/common';
import { S3Client, HeadObjectCommand } from '@aws-sdk/client-s3';
import { DatabaseService } from '../database/database.service';
import { TtsRepository } from '../database/repositories/tts.repository';
import { TtsService } from './tts.service';
import { TtsEnumerationService } from './tts-enumeration.service';
import { WorkerDispatchService } from '../worker-dispatch/worker-dispatch.service';
import { GEMINI_VOICE_MAP } from './providers/provider-registry.service';
import { buildWav } from './wav-utils';
import { splitPcmAtBoundaries, splitPcmOnSilence } from './pcm-splitter';
import { TtsAlignmentService } from './tts-alignment.service';
import type { TtsBatchPregenWorkerTask } from '../worker-dispatch/worker-task.interface';
import type { AppConfig } from '../config/app-config.interface';

const MAX_ATTEMPTS = 3;
const RETRY_DELAY_MS = 1_000;
const STALE_TIMEOUT_MS = 15 * 60 * 1_000;
// Sample rate of Gemini TTS PCM output. Matches kokoro-server's WAV output.
const GEMINI_PCM_SAMPLE_RATE = 24_000;

// Caps for a single Gemini :generateContent call. Chosen to stay well under
// (a) ~30 s per-call audio output cap and (b) ~5000 char input cap. A group
// larger than this is split into sub-batches, each retried independently so
// one bad sub-batch does not poison the rest of the plan.
const MAX_STEPS_PER_BATCH = 6;
const MAX_CHARS_PER_BATCH = 3_500;

/** Chunk jobs into sub-batches respecting both step-count and char caps. */
export function chunkJobsForGemini<T extends { text: string }>(
  jobs: T[],
  maxSteps = MAX_STEPS_PER_BATCH,
  maxChars = MAX_CHARS_PER_BATCH,
): T[][] {
  const batches: T[][] = [];
  let current: T[] = [];
  let currentChars = 0;

  for (const job of jobs) {
    const len = job.text.length;
    const wouldOverflow =
      current.length >= maxSteps || (current.length > 0 && currentChars + len > maxChars);
    if (wouldOverflow) {
      batches.push(current);
      current = [];
      currentChars = 0;
    }
    current.push(job);
    currentChars += len;
  }
  if (current.length > 0) batches.push(current);
  return batches;
}

// ISO-639-1 → ISO-639-3 for the languages this app currently supports.
// The aligner uses ISO-639-3; everything else falls back to 'eng'.
const ISO_639_1_TO_3: Record<string, string> = {
  en: 'eng', es: 'spa', fr: 'fra', de: 'deu', ja: 'jpn',
  pt: 'por', it: 'ita', ar: 'ara', zh: 'cmn', ko: 'kor',
  ru: 'rus', hi: 'hin',
};

function localeToIso639_3(locale: string): string {
  const lang = locale.toLowerCase().slice(0, 2);
  return ISO_639_1_TO_3[lang] ?? 'eng';
}

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
  private readonly ttsRepo: TtsRepository | DatabaseService;

  constructor(
    private readonly db: DatabaseService,
    private readonly ttsService: TtsService,
    private readonly enumService: TtsEnumerationService,
    private readonly workerDispatch: WorkerDispatchService,
    private readonly alignmentService: TtsAlignmentService,
    @Optional() @Inject('APP_CONFIG') config?: AppConfig,
    @Optional() @Inject(TtsRepository) ttsRepository?: TtsRepository,
  ) {
    this.ttsRepo = ttsRepository ?? db;
    this.bucket = (config?.awsS3Bucket || process.env.AWS_S3_BUCKET) ?? null;
    this.s3 = this.bucket
      ? new S3Client({ region: config?.awsRegion ?? process.env.AWS_REGION ?? 'ap-south-1' })
      : null;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /**
   * Start batch TTS pre-generation for a plan.
   *
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
      await this.ttsRepo.setTtsStatus(planId, 'completed', 0, 0);
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
      await this.ttsRepo.setTtsStatus(planId, 'completed', 0, 0);
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

    await this.ttsRepo.setTtsStatus(planId, 'processing', jobRecords.length, 0);

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

    const status = await this.ttsRepo.getPlanTtsStatus(task.planId);
    if (status.completed + status.failed >= status.total) {
      await this.ttsRepo.finalizePlanTtsStatus(task.planId);
      this.logger.log(`processTask — planId=${task.planId} finalized (${status.completed}/${status.total})`);
    }
  }

  async getStatus(planId: string) {
    await this.recoverIfStale(planId);
    return this.ttsRepo.getPlanTtsStatus(planId);
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
    const subBatches = chunkJobsForGemini(jobs);
    if (subBatches.length > 1) {
      this.logger.log(
        `processGroupGemini — voice=${group.voiceId} split into ${subBatches.length} sub-batches ` +
          `(sizes=${subBatches.map((b) => b.length).join(',')})`,
      );
    }

    for (let i = 0; i < subBatches.length; i++) {
      await this.processSubBatchGemini(planId, group, subBatches[i], i + 1, subBatches.length);
    }
  }

  /**
   * Synthesise a single sub-batch with up to MAX_ATTEMPTS retries.
   *
   * Failure of one sub-batch does not abort the rest of the group: only the
   * jobs in this sub-batch are marked failed, and processing of the next
   * sub-batch continues. This keeps blast radius small when a long plan hits
   * a transient quota window.
   */
  private async processSubBatchGemini(
    planId: string,
    group: Group,
    jobs: Array<{ id: string; text: string; cacheKey: string }>,
    subBatchIdx: number,
    subBatchTotal: number,
  ): Promise<void> {
    let lastErr: Error | undefined;
    const tag = subBatchTotal > 1 ? ` [sub-batch ${subBatchIdx}/${subBatchTotal}]` : '';

    for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
      try {
        await this.synthesizeBatchGemini(
          jobs.map((j) => ({ text: j.text, cacheKey: j.cacheKey })),
          group.voiceId,
          group.locale,
        );
        for (const job of jobs) {
          await this.ttsRepo.updateTtsJobStatus(job.id, 'completed', `tts/${job.cacheKey}.wav`);
          await this.ttsRepo.incrementTtsCompleted(planId);
          this.logger.log(`processGroupGemini${tag} — job ${job.id} done (${job.cacheKey.slice(0, 12)}…)`);
        }
        return;
      } catch (err) {
        lastErr = err instanceof Error ? err : new Error(String(err));
        if (attempt < MAX_ATTEMPTS) {
          this.logger.warn(`processGroup${tag} attempt ${attempt}/${MAX_ATTEMPTS} failed: ${lastErr.message}, retrying…`);
          await new Promise((r) => setTimeout(r, RETRY_DELAY_MS * attempt));
        }
      }
    }

    this.logger.error(
      `processGroup${tag} — voice=${group.voiceId} failed after ${MAX_ATTEMPTS} attempts: ${lastErr?.message}`,
    );
    for (const job of jobs) {
      await this.ttsRepo.updateTtsJobStatus(job.id, 'failed', undefined, lastErr?.message);
    }
  }

  /**
   * Core Gemini batch synthesis pipeline.
   *
   * Takes an array of say-step pairs, skips already-cached entries, concatenates
   * the remaining texts into a single Gemini TTS call, then splits the returned
   * audio per-text using forced alignment (kokoro-server /align). Falls back to
   * silence-based splitting if alignment is unavailable or returns malformed
   * output, so the pipeline degrades gracefully when Modal is cold or unhealthy.
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

    // Pass the real locale so buildPrompt wraps the SSML body in
    // <lang xml:lang="…">…</lang>. That keeps the locale hint inside the SSML
    // grammar, so the model honours both the accent and the <break> tags
    // between sub-batch chunks.
    const pcm = await this.ttsService.synthesizeGeminiRaw(combinedText, voiceId, locale);

    const combinedKey = `${uncached[0].cacheKey}_batch${uncached.length}`;
    await this.ttsService.writeToCacheByKey(combinedKey, buildWav(pcm));
    this.logger.log(`synthesizeBatchGemini — saved combined audio (${combinedKey.slice(0, 16)}…)`);

    const segments = await this.splitBatchAudio(pcm, uncached.map((p) => p.text), locale);

    for (let i = 0; i < uncached.length; i++) {
      await this.ttsService.writeToCacheByKey(uncached[i].cacheKey, buildWav(segments[i]));
      this.logger.log(`synthesizeBatchGemini — cached ${uncached[i].cacheKey.slice(0, 12)}…`);
    }
  }

  /**
   * Split the concatenated Gemini PCM into one buffer per source text.
   *
   * Tries forced alignment first (text-aware, robust to mid-sentence pauses);
   * falls back to silence-based splitting on any alignment failure.
   */
  private async splitBatchAudio(
    pcm: Buffer,
    texts: string[],
    locale: string,
  ): Promise<Buffer[]> {
    if (texts.length <= 1) return [pcm];

    const language = localeToIso639_3(locale);
    const aligned = await this.alignmentService.align({
      pcm,
      sampleRate: GEMINI_PCM_SAMPLE_RATE,
      texts,
      language,
    });

    if (aligned) {
      this.logger.log(
        `splitBatchAudio — aligned ${texts.length} segments (duration=${aligned.durationMs}ms)`,
      );
      return splitPcmAtBoundaries(pcm, aligned.boundaries, GEMINI_PCM_SAMPLE_RATE);
    }

    this.logger.warn('splitBatchAudio — alignment unavailable, falling back to silence splitter');
    return splitPcmOnSilence(pcm, texts.length, 1_500);
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
          await this.ttsRepo.updateTtsJobStatus(job.id, 'completed', `tts/${job.cacheKey}.wav`);
          await this.ttsRepo.incrementTtsCompleted(planId);
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
          await this.ttsRepo.incrementTtsCompleted(planId);
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
    await this.workerDispatch.dispatchBatchPregen(
      task,
      () => this.processTask(task),
    );
  }
}
