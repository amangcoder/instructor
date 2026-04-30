/**
 * SyncRepository — domain repository for session completion and plan trigger
 * synchronization operations.
 *
 * Delegates to the underlying DatabaseService so existing callers are unaffected
 * during the incremental migration from the monolithic DatabaseService god-object
 * to focused, single-responsibility repositories.
 */

import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../database.service';

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
}
