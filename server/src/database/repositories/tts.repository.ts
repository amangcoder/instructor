/**
 * TtsRepository — domain repository for TTS job operations.
 *
 * Delegates to the underlying DatabaseService so existing callers are unaffected
 * during the incremental migration from the monolithic DatabaseService god-object
 * to focused, single-responsibility repositories.
 */

import { Injectable } from '@nestjs/common';
import { DatabaseService, TtsJobRecord, TtsPregenStatusRecord } from '../database.service';

@Injectable()
export class TtsRepository {
  constructor(private readonly database: DatabaseService) {}

  async createTtsJobs(
    jobs: {
      planId: string;
      cacheKey: string;
      text: string;
      voiceId: string;
      locale: string;
      provider: string;
      speechRate: string;
    }[],
  ): Promise<{ id: string; cacheKey: string }[]> {
    return this.database.createTtsJobs(jobs);
  }

  async getTtsJobsByIds(jobIds: string[]): Promise<TtsJobRecord[]> {
    return this.database.getTtsJobsByIds(jobIds);
  }

  async updateTtsJobStatus(
    jobId: string,
    status: string,
    s3Key?: string,
    error?: string,
  ): Promise<void> {
    return this.database.updateTtsJobStatus(jobId, status, s3Key, error);
  }

  async getPlanTtsStatus(planId: string): Promise<TtsPregenStatusRecord> {
    return this.database.getPlanTtsStatus(planId);
  }

  async getCompletedTtsJobs(planId: string): Promise<TtsJobRecord[]> {
    return this.database.getCompletedTtsJobs(planId);
  }

  async failStalePendingJobs(planId: string): Promise<void> {
    return this.database.failStalePendingJobs(planId);
  }

  async finalizePlanTtsStatus(planId: string): Promise<void> {
    return this.database.finalizePlanTtsStatus(planId);
  }

  async setTtsStatus(
    planId: string,
    status: string,
    total?: number,
    completed?: number,
  ): Promise<void> {
    return this.database.setTtsStatus(planId, status, total, completed);
  }

  async incrementTtsCompleted(planId: string): Promise<void> {
    return this.database.incrementTtsCompleted(planId);
  }
}
