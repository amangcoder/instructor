/**
 * PlanVoicesRepository — domain repository for plan_voices table operations.
 *
 * Owns all database operations for the plan_voices table including:
 *   - Idempotent upserts (UNIQUE constraint on plan_id, voice_id, locale)
 *   - Status transitions (pending → processing → ready | failed)
 *   - Failed-job pagination for admin monitoring
 *   - hasReadyVoice() for v_published_plans view optimization
 *   - backfillFromTtsStatus() for migrating legacy tts_status data
 *   - createBatch() for atomic multi-row inserts inside a caller transaction
 *
 * Index alignment:
 *   idx_plan_voices_plan_status (plan_id, status) is used by:
 *     1. hasReadyVoice — WHERE plan_id = ? AND status = 'ready' LIMIT 1
 *     2. v_published_plans EXISTS subquery — same predicate
 *     3. listByPlan — leading plan_id prefix
 *     4. listFailed — WHERE status = 'failed' (also covered by idx_plan_voices_status)
 */

import { Injectable } from '@nestjs/common';
import { and, asc, count, desc, eq, sql } from 'drizzle-orm';
import { DatabaseService, type AppDb } from '../database.service';
import { planVoices, ttsJobs, voices } from '../schema';
import type { PlanVoice, NewPlanVoice } from '../schema';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type PlanVoiceStatus = 'pending' | 'processing' | 'ready' | 'failed';

/**
 * Compatible with both the db instance and Drizzle transaction callbacks.
 * Callers pass either `database.getDb()` or a `tx` from `db.transaction()`.
 */
export type DbTransaction = AppDb;

/**
 * A plan_voice row enriched with the joined voice's displayName and slug.
 * Powers the admin voice grid, where rows must show "af_bella" rather than
 * the raw voiceId UUID.
 */
export type PlanVoiceWithVoice = PlanVoice & {
  voice: { displayName: string; slug: string } | null;
};

// ---------------------------------------------------------------------------
// Status mapping helper
// ---------------------------------------------------------------------------

/**
 * Maps legacy plans.tts_status values to the plan_voices.status enum.
 *
 * Legacy values: none | pending | processing | completed | partial | failed
 * New values:    pending | processing | ready | failed
 */
export function mapLegacyTtsStatus(ttsStatus: string): PlanVoiceStatus {
  switch (ttsStatus) {
    case 'completed':
      return 'ready';
    case 'pending':
      return 'pending';
    case 'processing':
      return 'processing';
    case 'failed':
    case 'partial': // partial means some jobs failed — treat as failed for gate
      return 'failed';
    case 'none':
    default:
      return 'pending';
  }
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

@Injectable()
export class PlanVoicesRepository {
  constructor(private readonly database: DatabaseService) {}

  /** Whether the database is running in noop mode (DATABASE_URL unset). */
  get noop(): boolean {
    return this.database.noop;
  }

  // ── Upsert ─────────────────────────────────────────────────────────────────

  /**
   * Inserts or updates a plan_voice row.
   *
   * ON CONFLICT (plan_id, voice_id, locale): updates all mutable fields so
   * the operation is idempotent for backfill and TTS retry workflows.
   *
   * Returns the persisted row.
   */
  async upsertPlanVoice(data: NewPlanVoice): Promise<PlanVoice> {
    const db = this.database.getDb();
    const rows = await db
      .insert(planVoices)
      .values(data)
      .onConflictDoUpdate({
        target: [planVoices.planId, planVoices.voiceId, planVoices.locale],
        set: {
          status: data.status ?? 'pending',
          audioUrl: data.audioUrl ?? null,
          durationMs: data.durationMs ?? null,
          errorMsg: data.errorMsg ?? null,
          generatedAt: data.generatedAt ?? null,
          updatedAt: new Date(),
        },
      })
      .returning();
    return rows[0];
  }

  // ── Status transition ──────────────────────────────────────────────────────

  /**
   * Updates the status and optional audio metadata for a plan_voice row.
   *
   * Only provided optional fields are written — existing values are preserved
   * for fields not passed. generatedAt is set automatically when status='ready'.
   */
  async updateStatus(
    id: string,
    status: PlanVoiceStatus,
    audioUrl?: string,
    durationMs?: number,
    errorMsg?: string,
  ): Promise<void> {
    const db = this.database.getDb();
    const now = new Date();

    await db
      .update(planVoices)
      .set({
        status,
        ...(audioUrl !== undefined && { audioUrl }),
        ...(durationMs !== undefined && { durationMs }),
        ...(errorMsg !== undefined && { errorMsg }),
        ...(status === 'ready' && { generatedAt: now }),
        updatedAt: now,
      })
      .where(eq(planVoices.id, id));
  }

  // ── List queries ───────────────────────────────────────────────────────────

  /**
   * Returns all plan_voice rows for the given plan, ordered by createdAt ASC.
   * Each row carries the joined voice's displayName and slug so admin UIs
   * can render "af_bella" instead of the raw voiceId UUID.
   *
   * Uses the idx_plan_voices_plan_status index (plan_id leading prefix).
   */
  async listByPlan(planId: string): Promise<PlanVoiceWithVoice[]> {
    if (this.noop) return [];
    const db = this.database.getDb();
    const rows = await db
      .select({
        id: planVoices.id,
        planId: planVoices.planId,
        voiceId: planVoices.voiceId,
        locale: planVoices.locale,
        status: planVoices.status,
        audioUrl: planVoices.audioUrl,
        durationMs: planVoices.durationMs,
        errorMsg: planVoices.errorMsg,
        generatedAt: planVoices.generatedAt,
        createdAt: planVoices.createdAt,
        updatedAt: planVoices.updatedAt,
        voiceDisplayName: voices.displayName,
        voiceSlug: voices.slug,
      })
      .from(planVoices)
      .leftJoin(voices, eq(planVoices.voiceId, voices.id))
      .where(eq(planVoices.planId, planId))
      .orderBy(asc(planVoices.createdAt));

    return rows.map(({ voiceDisplayName, voiceSlug, ...planVoice }) => ({
      ...planVoice,
      voice:
        voiceDisplayName !== null && voiceSlug !== null
          ? { displayName: voiceDisplayName, slug: voiceSlug }
          : null,
    }));
  }

  /**
   * Returns paginated plan_voice rows with status='failed'.
   *
   * Uses idx_plan_voices_status for the cross-plan status scan.
   * Orders by updatedAt DESC (most recently failed first) for admin triage.
   */
  async listFailed(
    page: number,
    pageSize: number,
  ): Promise<{ items: PlanVoice[]; total: number }> {
    const db = this.database.getDb();
    const offset = (page - 1) * pageSize;

    const [items, totalRows] = await Promise.all([
      this.database.withRetry(() =>
        db
          .select()
          .from(planVoices)
          .where(eq(planVoices.status, 'failed'))
          .orderBy(desc(planVoices.updatedAt))
          .limit(pageSize)
          .offset(offset),
      ),
      this.database.withRetry(() =>
        db
          .select({ total: count() })
          .from(planVoices)
          .where(eq(planVoices.status, 'failed')),
      ),
    ]);

    return { items, total: Number(totalRows[0]?.total ?? 0) };
  }

  // ── Existence check (v_published_plans gate) ───────────────────────────────

  /**
   * Returns true if the plan has at least one plan_voice row with status='ready'.
   *
   * Uses idx_plan_voices_plan_status (plan_id, status) with LIMIT 1 — the same
   * index path used by the EXISTS subquery in the v_published_plans view, so
   * this check is O(1) regardless of how many voices are associated with the plan.
   *
   * IMPORTANT: This is the key method powering the visibility gate. Keep its
   * query shape consistent with the v_published_plans view definition:
   *   EXISTS (SELECT 1 FROM plan_voices WHERE plan_id = ? AND status = 'ready')
   */
  async hasReadyVoice(planId: string): Promise<boolean> {
    const db = this.database.getDb();
    const rows = await this.database.withRetry(() =>
      db
        .select({ id: planVoices.id })
        .from(planVoices)
        .where(
          and(
            eq(planVoices.planId, planId),
            eq(planVoices.status, 'ready'),
          ),
        )
        .limit(1),
    );
    return rows.length > 0;
  }

  // ── Backfill ───────────────────────────────────────────────────────────────

  /**
   * Creates a plan_voice row from legacy plans.tts_status data.
   *
   * Maps the legacy tts_status string to the new plan_voices.status enum and
   * upserts a row using voice/locale info from the plan's tts_jobs records.
   *
   * Prerequisites:
   *   1. The voices table must be seeded before calling this method — the voice
   *      slug from tts_jobs is looked up by slug to get the voice UUID.
   *   2. The plan must have at least one tts_job row.
   *
   * Throws:
   *   - Error if no tts_jobs exist for the plan
   *   - Error if the voice slug from tts_jobs is not found in the voices table
   */
  async backfillFromTtsStatus(
    planId: string,
    ttsStatus: string,
  ): Promise<PlanVoice> {
    const db = this.database.getDb();
    const mappedStatus = mapLegacyTtsStatus(ttsStatus);

    // Find TTS jobs for the plan — use the first job's voice/locale as the
    // primary rendition to seed the plan_voices row.
    const jobs = await this.database.withRetry(() =>
      db
        .select({
          voiceSlug: ttsJobs.voiceId,
          locale: ttsJobs.locale,
        })
        .from(ttsJobs)
        .where(eq(ttsJobs.planId, planId))
        .limit(1),
    );

    if (jobs.length === 0) {
      throw new Error(
        `No tts_jobs found for plan ${planId} — cannot backfill plan_voices`,
      );
    }

    // Look up the voice UUID by slug (voices table slug corresponds to tts_jobs.voice_id text)
    const voiceSlug = jobs[0].voiceSlug;
    const voiceRows = await this.database.withRetry(() =>
      db
        .select({ id: voices.id })
        .from(voices)
        .where(eq(voices.slug, voiceSlug))
        .limit(1),
    );

    if (voiceRows.length === 0) {
      throw new Error(
        `Voice slug '${voiceSlug}' not found in voices table — seed voices before backfilling`,
      );
    }

    const voiceId = voiceRows[0].id;
    const locale = jobs[0].locale;

    const rows = await this.database.withRetry(() =>
      db
        .insert(planVoices)
        .values({
          planId,
          voiceId,
          locale,
          status: mappedStatus,
        })
        .onConflictDoUpdate({
          target: [planVoices.planId, planVoices.voiceId, planVoices.locale],
          set: {
            status: mappedStatus,
            updatedAt: new Date(),
          },
        })
        .returning(),
    );

    return rows[0];
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  /**
   * Deletes a plan_voice row by (planId, voiceId).
   *
   * Returns the number of rows deleted (0 if no matching row existed).
   * Locale is not part of the predicate — the (planId, voiceId) pair is
   * effectively unique in admin practice and matches the API surface.
   */
  async deleteByPlanAndVoice(
    planId: string,
    voiceId: string,
  ): Promise<number> {
    if (this.noop) return 0;
    const db = this.database.getDb();
    const rows = await this.database.withRetry(() =>
      db
        .delete(planVoices)
        .where(and(eq(planVoices.planId, planId), eq(planVoices.voiceId, voiceId)))
        .returning({ id: planVoices.id }),
    );
    return rows.length;
  }

  // ── Batch insert ───────────────────────────────────────────────────────────

  /**
   * Inserts multiple plan_voice rows atomically within a caller-provided transaction.
   *
   * On conflict (plan_id, voice_id, locale) each row's status and updatedAt are
   * refreshed via EXCLUDED so the batch is idempotent.
   *
   * Usage:
   * ```typescript
   * const db = this.database.getDb();
   * // neon-http doesn't support true transactions; callers use the db instance directly
   * const voiceRows = await planVoicesRepo.createBatch(rows, db);
   * ```
   *
   * @param rows  Array of NewPlanVoice objects to insert (no-op if empty).
   * @param tx    Drizzle db instance or transaction — allows callers to scope the
   *              insert inside a larger atomic operation.
   */
  async createBatch(
    rows: NewPlanVoice[],
    tx: DbTransaction,
  ): Promise<PlanVoice[]> {
    if (rows.length === 0) return [];

    return tx
      .insert(planVoices)
      .values(rows)
      .onConflictDoUpdate({
        target: [planVoices.planId, planVoices.voiceId, planVoices.locale],
        set: {
          status: sql`EXCLUDED.status`,
          audioUrl: sql`EXCLUDED.audio_url`,
          durationMs: sql`EXCLUDED.duration_ms`,
          errorMsg: sql`EXCLUDED.error_msg`,
          generatedAt: sql`EXCLUDED.generated_at`,
          updatedAt: new Date(),
        },
      })
      .returning();
  }
}
