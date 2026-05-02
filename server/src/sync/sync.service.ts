/**
 * SyncService — session completion synchronization.
 *
 * Responsibilities:
 *   - Upload (POST) session completion records from client
 *   - Download (GET) session completion records from server
 *   - Handle idempotency via client_id unique constraint
 *   - Filter by timestamp for incremental sync
 *
 * Idempotency:
 *   Each completion can include a client_id (UUID generated on client).
 *   Server uses ON CONFLICT (client_id) DO NOTHING to prevent duplicates.
 *   If client_id is omitted, the server generates one (less idempotent).
 *
 * Data flow:
 *   1. Client records completions locally in session_completions Drift table
 *   2. Client calls POST /api/sync/completions with unsynced records
 *   3. Server stores in PostgreSQL session_completions table (idempotent)
 *   4. Client calls GET /api/sync/completions to pull server state
 *   5. Client marks completions as synced (syncedAt = now)
 *   6. StreakService calculates streaks from combined local + server completions
 */

import { Injectable, Logger, Optional, Inject } from '@nestjs/common';
import { v4 as uuidv4 } from 'uuid';
import { DatabaseService } from '../database/database.service';
import { SyncRepository } from '../database/repositories/sync.repository';
import {
  GetCompletionsResponseDto,
  CompletionResponseDto,
} from './dto/sync-completions.dto';
import {
  GetTriggersResponseDto,
  TriggerDto,
  TriggerRecurrence,
  TriggerResponseDto,
  UploadTriggersResponseDto,
} from './dto/sync-triggers.dto';
import {
  CategoryDto,
  GetCategoriesResponseDto,
  VoiceDto,
  GetVoicesResponseDto,
  PlanVoiceDto,
  GetPlanVoicesResponseDto,
} from './dto/sync-content.dto';

/** Input shape for a single completion when calling uploadCompletions. */
export interface CompletionInput {
  planId: string;
  completedAt: string;
  durationMs: number;
  clientId?: string;
}

/** Options for getCompletions */
export interface GetCompletionsOptions {
  since?: Date;
}

export interface UploadCompletionsResult {
  syncedCount: number;
}

@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);
  private readonly repo: SyncRepository | DatabaseService;

  constructor(
    private readonly db: DatabaseService,
    @Optional() @Inject(SyncRepository) syncRepo?: SyncRepository,
  ) {
    this.repo = syncRepo ?? db;
  }

  /**
   * Upload (upsert) session completions from client.
   *
   * Accepts an array of completion inputs (planId, completedAt, durationMs, clientId?).
   * Idempotency: client_id unique constraint prevents duplicates.
   * Returns: count of completions processed.
   */
  async uploadCompletions(
    userId: string,
    completions: CompletionInput[],
  ): Promise<UploadCompletionsResult> {
    if (!completions || completions.length === 0) {
      return { syncedCount: 0 };
    }

    // Transform to database format; generate clientId if not provided
    const dbCompletions = completions.map((c) => ({
      planId: c.planId,
      completedAt: new Date(c.completedAt),
      durationMs: c.durationMs,
      clientId: c.clientId ?? uuidv4(),
    }));

    // Upsert into PostgreSQL (ON CONFLICT DO NOTHING handles duplicates)
    const syncedCount = await this.repo.upsertSessionCompletions(userId, dbCompletions);

    this.logger.debug(`Session completions uploaded: userId=${userId}, count=${syncedCount}`);

    return { syncedCount };
  }

  /**
   * Download (retrieve) session completions from server.
   *
   * Optionally filters by since Date for incremental sync.
   * Returns: array of completions ordered by completedAt.
   */
  async getCompletions(
    userId: string,
    options: GetCompletionsOptions = {},
  ): Promise<GetCompletionsResponseDto> {
    const completions = await this.repo.getSessionCompletions(userId, options.since);

    // Map to response DTO (exclude internal fields like userId, clientId)
    const response: CompletionResponseDto[] = completions.map((c) => ({
      id: c.id,
      planId: c.planId,
      completedAt: c.completedAt.toISOString(),
      durationMs: c.durationMs,
    }));

    this.logger.debug(
      `Session completions retrieved: userId=${userId}, count=${response.length}, since=${options.since?.toISOString() || 'all'}`,
    );

    return { completions: response };
  }

  // ── Plan triggers ──────────────────────────────────────────────────────────

  /**
   * Upsert plan triggers from the client and return the server-authoritative
   * view of every accepted row (post last-write-wins reconciliation).
   *
   * The response lets the client stamp each local row with the server id +
   * updated_at in one round-trip, avoiding a follow-up GET.
   */
  async uploadPlanTriggers(
    userId: string,
    triggers: TriggerDto[],
  ): Promise<UploadTriggersResponseDto> {
    if (!triggers || triggers.length === 0) {
      return { triggers: [] };
    }

    const dbRows = triggers.map((t) => ({
      clientId: t.clientId,
      planId: t.planId,
      title: t.title,
      startUtc: new Date(t.startUtc),
      durationMinutes: t.durationMinutes,
      recurrence: t.recurrence,
      deletedAt: t.deletedAt ? new Date(t.deletedAt) : null,
      updatedAt: new Date(t.updatedAt),
    }));

    const merged = await this.repo.upsertPlanTriggers(userId, dbRows);

    this.logger.debug(
      `Plan triggers uploaded: userId=${userId}, count=${merged.length}`,
    );

    return {
      triggers: merged.map((r) => this.toTriggerResponse(r)),
    };
  }

  /**
   * Fetch plan triggers changed since the optional timestamp, including
   * tombstones (deletedAt set) so clients can propagate cancellations.
   */
  async getPlanTriggers(
    userId: string,
    options: GetCompletionsOptions = {},
  ): Promise<GetTriggersResponseDto> {
    const rows = await this.repo.getPlanTriggers(userId, options.since);

    this.logger.debug(
      `Plan triggers retrieved: userId=${userId}, count=${rows.length}, since=${options.since?.toISOString() || 'all'}`,
    );

    return {
      triggers: rows.map((r) => this.toTriggerResponse(r)),
    };
  }

  // ── Content cache sync (TASK-018) ─────────────────────────────────────────

  /**
   * Fetch published categories for mobile cache sync.
   *
   * Full sync (no since): returns all is_published=true categories ordered by
   *   sortOrder ASC.
   * Delta sync (since provided): returns categories updated after `since` that
   *   are still published, PLUS deletedIds of categories unpublished since `since`
   *   so the client can evict them from its local Drift cache.
   *
   * Delegates to SyncRepository.getCategories() which enforces the publish gate
   * (REQ-023, AC-021).
   */
  async getCategories(since?: Date): Promise<GetCategoriesResponseDto> {
    const result = await (this.repo as SyncRepository).getCategories(since);

    this.logger.debug(
      `Categories sync: rows=${result.rows.length}, deletedIds=${result.deletedIds.length}, since=${since?.toISOString() ?? 'full'}`,
    );

    return {
      categories: result.rows.map(
        (c): CategoryDto => ({
          id: c.id,
          slug: c.slug,
          name: c.name,
          icon: c.icon ?? null,
          color: c.color ?? null,
          sortOrder: c.sortOrder,
          isPublished: c.isPublished,
          createdAt: c.createdAt.toISOString(),
          updatedAt: c.updatedAt.toISOString(),
        }),
      ),
      deletedIds: result.deletedIds,
    };
  }

  /**
   * Fetch published voices for mobile cache sync.
   *
   * Full sync (no since): returns all is_published=true voices ordered by
   *   locale ASC, displayName ASC.
   * Delta sync (since provided): returns voices updated after `since` that are
   *   still published, PLUS deletedIds for voices unpublished since `since`.
   *
   * Delegates to SyncRepository.getVoices() (REQ-023, AC-021).
   */
  async getVoices(since?: Date): Promise<GetVoicesResponseDto> {
    const result = await (this.repo as SyncRepository).getVoices(since);

    this.logger.debug(
      `Voices sync: rows=${result.rows.length}, deletedIds=${result.deletedIds.length}, since=${since?.toISOString() ?? 'full'}`,
    );

    return {
      voices: result.rows.map(
        (v): VoiceDto => ({
          id: v.id,
          slug: v.slug,
          displayName: v.displayName,
          locale: v.locale,
          provider: v.provider,
          sampleUrl: v.sampleUrl ?? null,
          isPublished: v.isPublished,
          createdAt: v.createdAt.toISOString(),
          updatedAt: v.updatedAt.toISOString(),
        }),
      ),
      deletedIds: result.deletedIds,
    };
  }

  /**
   * Fetch ready plan-voice renditions for mobile cache sync.
   *
   * Only plan_voices rows where status='ready' AND the parent plan has
   * is_published=true are returned — the mobile visibility gate (REQ-023,
   * AC-021, AC-013).
   *
   * Full sync (no since): returns all ready+published plan_voice rows.
   * Delta sync (since provided): returns rows where plan_voices.updatedAt > since
   *   that still pass the gate, PLUS deletedIds for rows that no longer qualify
   *   (status changed away from ready, or parent plan was unpublished).
   *
   * Delegates to SyncRepository.getPlanVoices() which enforces the gate.
   */
  async getPlanVoices(since?: Date): Promise<GetPlanVoicesResponseDto> {
    const result = await (this.repo as SyncRepository).getPlanVoices(since);

    this.logger.debug(
      `PlanVoices sync: rows=${result.rows.length}, deletedIds=${result.deletedIds.length}, since=${since?.toISOString() ?? 'full'}`,
    );

    return {
      planVoices: result.rows.map(
        (pv): PlanVoiceDto => ({
          id: pv.id,
          planId: pv.planId,
          voiceId: pv.voiceId,
          locale: pv.locale,
          status: pv.status,
          audioUrl: pv.audioUrl ?? null,
          durationMs: pv.durationMs ?? null,
          generatedAt: pv.generatedAt ? pv.generatedAt.toISOString() : null,
          createdAt: pv.createdAt.toISOString(),
          updatedAt: pv.updatedAt.toISOString(),
        }),
      ),
      deletedIds: result.deletedIds,
    };
  }

  private toTriggerResponse(r: {
    id: string;
    clientId: string;
    planId: string;
    title: string;
    startUtc: Date;
    durationMinutes: number;
    recurrence: string;
    deletedAt: Date | null;
    updatedAt: Date;
  }): TriggerResponseDto {
    return {
      id: r.id,
      clientId: r.clientId,
      planId: r.planId,
      title: r.title,
      startUtc: r.startUtc.toISOString(),
      durationMinutes: r.durationMinutes,
      recurrence: r.recurrence as TriggerRecurrence,
      deletedAt: r.deletedAt ? r.deletedAt.toISOString() : null,
      updatedAt: r.updatedAt.toISOString(),
    };
  }
}
