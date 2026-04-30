/**
 * TtsHealthService — TASK-003
 *
 * Derives real-time TTS provider health status exclusively from the tts_jobs
 * table. No outbound network calls to TTS providers.
 *
 * For each provider ('kokoro', 'elevenlabs'):
 *   - Total jobs in the last 60 minutes
 *   - Failed jobs (uses idx_tts_jobs_failed partial index)
 *   - Error rate = failed / total
 *   - Last successful job timestamp
 *
 * Status determination:
 *   - 'healthy':  errorRate < 0.05 AND lastSuccessAt within 60min
 *   - 'degraded': errorRate 0.05-0.20 OR lastSuccessAt > 60min ago
 *   - 'unknown':  no jobs in last 60min (totalCount === 0)
 */

import { Injectable, Logger, Inject } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { AdminAnalyticsRepository } from '../database/repositories/analytics.repository';
import type {
  TtsHealthResponse,
  TtsProviderHealth,
  TtsProviderStatus,
} from './dto/tts-health.dto';

const PROVIDERS = ['kokoro', 'elevenlabs'] as const;

@Injectable()
export class TtsHealthService {
  private readonly logger = new Logger(TtsHealthService.name);
  constructor(
    private readonly db: DatabaseService,
    @Inject(AdminAnalyticsRepository) private readonly repo: AdminAnalyticsRepository,
  ) {}

  /**
   * Get TTS provider health status for all providers.
   *
   * Runs parallel queries for each provider (2 queries per provider):
   *   1. Total + failed count in last 60min
   *   2. Last successful job timestamp
   *
   * @returns TtsHealthResponse with provider array
   */
  async getTtsHealth(): Promise<TtsHealthResponse> {
    return this.db.withRetry(async () => {
      const sixtyMinAgo = new Date(Date.now() - 60 * 60 * 1000);

      // Run all provider queries in parallel
      const results = await Promise.all(
        PROVIDERS.map(async (provider): Promise<TtsProviderHealth> => {
          let total: number;
          let failed: number;
          let lastSuccessAt: Date | null;

          const [counts, lastSuccess] = await Promise.all([
              this.repo.getTtsProviderCounts(provider, sixtyMinAgo),
              this.repo.getTtsLastSuccess(provider),
            ]);
            total = counts.total;
            failed = counts.failed;
            lastSuccessAt = lastSuccess;

          // Calculate error rate
          const errorRate = total > 0 ? failed / total : 0;

          // Determine status
          let status: TtsProviderStatus;
          if (total === 0) {
            status = 'unknown';
          } else if (
            errorRate < 0.05 &&
            lastSuccessAt !== null &&
            lastSuccessAt.getTime() >= sixtyMinAgo.getTime()
          ) {
            status = 'healthy';
          } else if (errorRate > 0.20) {
            status = 'degraded';
          } else if (
            lastSuccessAt === null ||
            lastSuccessAt.getTime() < sixtyMinAgo.getTime()
          ) {
            status = 'degraded';
          } else if (errorRate >= 0.05) {
            status = 'degraded';
          } else {
            status = 'healthy';
          }

          return {
            provider,
            status,
            errorRateLast60m: Math.round(errorRate * 10000) / 10000,
            lastSuccessAt: lastSuccessAt ? lastSuccessAt.toISOString() : null,
          };
        }),
      );

      return { providers: results };
    });
  }
}
