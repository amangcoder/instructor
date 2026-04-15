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

import { Injectable, Logger } from '@nestjs/common';
import { v4 as uuidv4 } from 'uuid';
import { DatabaseService } from '../database/database.service';
import {
  GetCompletionsResponseDto,
  CompletionResponseDto,
} from './dto/sync-completions.dto';

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

  constructor(private readonly db: DatabaseService) {}

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
    const syncedCount = await this.db.upsertSessionCompletions(userId, dbCompletions);

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
    const completions = await this.db.getSessionCompletions(userId, options.since);

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
}
