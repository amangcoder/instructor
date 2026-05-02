/**
 * SyncRepository — domain repository for session completion, plan trigger,
 * and content cache synchronization operations.
 *
 * Delegates legacy operations to the underlying DatabaseService so existing
 * callers are unaffected during the incremental migration from the monolithic
 * DatabaseService god-object to focused, single-responsibility repositories.
 *
 * Extended (TASK-017): adds delta-sync read methods for categories, voices,
 * and plan_voices — filtering to only published+ready records so only safe
 * content flows into the mobile Drift cache (REQ-023, AC-013).
 *
 * Sync contract:
 *   Full sync  (no since): returns all records matching the publish/ready gate.
 *   Delta sync (since set): returns records updated after `since` that still
 *     pass the gate PLUS deletedIds of records that no longer pass the gate
 *     but were modified after `since` (client must evict these from its cache).
 */

import { Injectable } from '@nestjs/common';
import { and, asc, eq, gt, ne, or } from 'drizzle-orm';
import { DatabaseService } from '../database.service';
import { categories, planVoices, plans, voices } from '../schema';
import type { Category, PlanVoice, Voice } from '../schema';

// ---------------------------------------------------------------------------
// Sync result shapes
// ---------------------------------------------------------------------------

export interface CategorySyncResult {
  /**
   * Published categories (is_published=true).
   * When `since` is provided, only rows with updatedAt > since are included
   * (delta-sync optimisation — client already holds the rest).
   */
  rows: Category[];
  /**
   * IDs of categories that were updated since `since` but are now unpublished.
   * Client should evict these IDs from its local Drift cache.
   * Always an empty array when no `since` is provided (full sync).
   */
  deletedIds: string[];
}

export interface VoiceSyncResult {
  /**
   * Published voices (is_published=true).
   * When `since` is provided, only rows with updatedAt > since are included.
   */
  rows: Voice[];
  /**
   * IDs of voices that were updated since `since` but are now unpublished.
   * Always an empty array when no `since` is provided.
   */
  deletedIds: string[];
}

export interface PlanVoiceSyncResult {
  /**
   * plan_voices rows with status='ready' for is_published=true plans.
   * When `since` is provided, only rows where plan_voices.updatedAt > since.
   */
  rows: PlanVoice[];
  /**
   * IDs of plan_voice rows that were recently modified (plan_voice or parent
   * plan) but are no longer in the ready+published set.
   * Always an empty array when no `since` is provided.
   */
  deletedIds: string[];
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

@Injectable()
export class SyncRepository {
  constructor(private readonly database: DatabaseService) {}

  // ── Session completions ─────────────────────────────────────────────────

  async upsertSessionCompletions(
    userId: string,
    completions: Array<{
      planId: string;
      completedAt: Date;
      durationMs: number;
      clientId: string;
    }>,
  ): Promise<number> {
    return this.database.upsertSessionCompletions(userId, completions);
  }

  async getSessionCompletions(userId: string, since?: Date) {
    return this.database.getSessionCompletions(userId, since);
  }

  // ── Plan triggers ───────────────────────────────────────────────────────

  async upsertPlanTriggers(
    userId: string,
    rows: Array<{
      clientId: string;
      planId: string;
      title: string;
      startUtc: Date;
      durationMinutes: number;
      recurrence: string;
      deletedAt: Date | null;
      updatedAt: Date;
    }>,
  ) {
    return this.database.upsertPlanTriggers(userId, rows);
  }

  async getPlanTriggers(userId: string, since?: Date) {
    return this.database.getPlanTriggers(userId, since);
  }

  // ── Content cache sync (TASK-017) ───────────────────────────────────────

  /**
   * Returns published categories for mobile cache sync.
   *
   * Full sync (no since): returns all is_published=true categories ordered by
   *   sortOrder ASC.
   * Delta sync (since provided): returns only categories with updatedAt > since
   *   that are still published, PLUS deletedIds of categories that were
   *   unpublished (updatedAt > since AND is_published=false) so the client can
   *   evict them from its local Drift cache.
   *
   * Only is_published=true records flow to the mobile cache (REQ-023).
   */
  async getCategories(since?: Date): Promise<CategorySyncResult> {
    const db = this.database.getDb();

    const publishedCondition = eq(categories.isPublished, true);
    const rowsCondition = since
      ? and(publishedCondition, gt(categories.updatedAt, since))
      : publishedCondition;

    const [rows, deletedRaw] = await Promise.all([
      this.database.withRetry(() =>
        db
          .select()
          .from(categories)
          .where(rowsCondition)
          .orderBy(asc(categories.sortOrder)),
      ),
      since
        ? this.database.withRetry(() =>
            db
              .select({ id: categories.id })
              .from(categories)
              .where(
                and(
                  eq(categories.isPublished, false),
                  gt(categories.updatedAt, since),
                ),
              ),
          )
        : Promise.resolve([]),
    ]);

    return {
      rows,
      deletedIds: (deletedRaw as Array<{ id: string }>).map((r) => r.id),
    };
  }

  /**
   * Returns published voices for mobile cache sync.
   *
   * Full sync (no since): returns all is_published=true voices ordered by
   *   locale ASC, displayName ASC.
   * Delta sync (since provided): returns voices with updatedAt > since that
   *   are still published, PLUS deletedIds of voices that were unpublished
   *   (updatedAt > since AND is_published=false).
   *
   * Only is_published=true records flow to the mobile cache (REQ-023).
   */
  async getVoices(since?: Date): Promise<VoiceSyncResult> {
    const db = this.database.getDb();

    const publishedCondition = eq(voices.isPublished, true);
    const rowsCondition = since
      ? and(publishedCondition, gt(voices.updatedAt, since))
      : publishedCondition;

    const [rows, deletedRaw] = await Promise.all([
      this.database.withRetry(() =>
        db
          .select()
          .from(voices)
          .where(rowsCondition)
          .orderBy(asc(voices.locale), asc(voices.displayName)),
      ),
      since
        ? this.database.withRetry(() =>
            db
              .select({ id: voices.id })
              .from(voices)
              .where(
                and(
                  eq(voices.isPublished, false),
                  gt(voices.updatedAt, since),
                ),
              ),
          )
        : Promise.resolve([]),
    ]);

    return {
      rows,
      deletedIds: (deletedRaw as Array<{ id: string }>).map((r) => r.id),
    };
  }

  /**
   * Returns plan_voices rows for mobile cache sync.
   *
   * Only rows where status='ready' AND the parent plan has is_published=true
   * are included — this is the mobile visibility gate (REQ-023, AC-013).
   *
   * Full sync (no since): returns all ready+published plan_voice rows.
   * Delta sync (since provided): returns rows where plan_voices.updatedAt > since
   *   that are still ready+published.  Adds deletedIds for rows where either
   *   the plan_voice or its parent plan was modified since `since` AND the row
   *   no longer passes the ready+published gate — client must evict those IDs.
   *
   * Column selection is explicit to avoid name collisions between planVoices
   * and plans when using innerJoin.
   */
  async getPlanVoices(since?: Date): Promise<PlanVoiceSyncResult> {
    const db = this.database.getDb();

    // Explicit column list so the result matches the PlanVoice type exactly,
    // without picking up any plans.* columns from the join.
    const planVoiceColumns = {
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
    };

    const readyAndPublished = and(
      eq(planVoices.status, 'ready'),
      eq(plans.isPublished, true),
    );

    const rowsCondition = since
      ? and(readyAndPublished, gt(planVoices.updatedAt, since))
      : readyAndPublished;

    const [rows, deletedRaw] = await Promise.all([
      this.database.withRetry(() =>
        db
          .select(planVoiceColumns)
          .from(planVoices)
          .innerJoin(plans, eq(planVoices.planId, plans.id))
          .where(rowsCondition),
      ),
      since
        ? this.database.withRetry(() =>
            db
              .select({ id: planVoices.id })
              .from(planVoices)
              .innerJoin(plans, eq(planVoices.planId, plans.id))
              .where(
                and(
                  // Row was recently touched: plan_voice updated OR parent plan toggled
                  or(
                    gt(planVoices.updatedAt, since),
                    gt(plans.updatedAt, since),
                  ),
                  // But is now NOT in the ready+published set
                  or(
                    ne(planVoices.status, 'ready'),
                    eq(plans.isPublished, false),
                  ),
                ),
              ),
          )
        : Promise.resolve([]),
    ]);

    return {
      rows: rows as PlanVoice[],
      deletedIds: (deletedRaw as Array<{ id: string }>).map((r) => r.id),
    };
  }
}
