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

import { Injectable, Logger } from '@nestjs/common';
import { sql } from 'drizzle-orm';
import { DatabaseService } from '../database/database.service';
import type {
  TtsHealthResponse,
  TtsProviderHealth,
  TtsProviderStatus,
} from './dto/tts-health.dto';

const PROVIDERS = ['kokoro', 'elevenlabs'] as const;

@Injectable()
export class TtsHealthService {
  private readonly logger = new Logger(TtsHealthService.name);

  constructor(private readonly db: DatabaseService) {}

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
      const drizzle = this.db.getDb();
      const sixtyMinAgo = new Date(Date.now() - 60 * 60 * 1000);

      // Run all provider queries in parallel
      const results = await Promise.all(
        PROVIDERS.map(async (provider): Promise<TtsProviderHealth> => {
          const [countsResult, lastSuccessResult] = await Promise.all([
            // Total + failed count in last 60min
            drizzle.execute(sql`
              SELECT
                COUNT(*)::int AS total,
                COUNT(*) FILTER (WHERE status = 'failed')::int AS failed
              FROM tts_jobs
              WHERE created_at >= ${sixtyMinAgo}
                AND provider = ${provider}
            `),
            // Last successful job timestamp
            drizzle.execute(sql`
              SELECT MAX(created_at) AS last_success_at
              FROM tts_jobs
              WHERE status = 'completed'
                AND provider = ${provider}
            `),
          ]);

          const countsRow = (countsResult.rows as Array<Record<string, unknown>>)[0] ?? {};
          const total = Number(countsRow.total ?? 0);
          const failed = Number(countsRow.failed ?? 0);

          const lastSuccessRow = (lastSuccessResult.rows as Array<Record<string, unknown>>)[0] ?? {};
          const lastSuccessRaw = lastSuccessRow.last_success_at;
          const lastSuccessAt = lastSuccessRaw ? new Date(lastSuccessRaw as string) : null;

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
