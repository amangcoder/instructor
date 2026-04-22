/**
 * ActivityFeedService — TASK-008
 *
 * Returns the last 10 platform events in reverse-chronological order:
 *   - New signups (with masked email)
 *   - TTS failures (with sanitized error message)
 *   - Deletion requests (with masked email)
 *
 * Implementation:
 *   Three queries run in parallel via Promise.all() (NOT a SQL UNION).
 *   Parallel Promise.all() avoids 3 sequential HTTP round trips in Neon HTTP mode.
 *   Results are merged and re-sorted in TypeScript, then the top 10 are returned.
 *
 * Email masking uses the shared maskEmail() utility to handle the single-char
 * local-part edge case correctly.
 */

import { Injectable, Logger } from '@nestjs/common';
import { sql } from 'drizzle-orm';
import { DatabaseService } from '../database/database.service';
import { sanitizeErrorMessage } from './admin-analytics.service';
import { maskEmail } from './utils/mask-email';
import type { ActivityFeedResponse, ActivityEvent } from './dto/activity-feed.dto';

@Injectable()
export class ActivityFeedService {
  private readonly logger = new Logger(ActivityFeedService.name);

  constructor(private readonly db: DatabaseService) {}

  /**
   * Get the 10 most recent platform events.
   *
   * Runs three parallel queries:
   *   1. Last 10 new signups (users table)
   *   2. Last 10 TTS failures (tts_jobs WHERE status='failed')
   *   3. Last 10 deletion requests (deletion_requests table)
   *
   * Merges results, sorts by occurredAt DESC, and returns top 10.
   *
   * @returns ActivityFeedResponse with events array (max 10 entries)
   */
  async getRecentActivity(): Promise<ActivityFeedResponse> {
    return this.db.withRetry(async () => {
      const drizzle = this.db.getDb();

      const [signupRows, ttsFailureRows, deletionRows] = await Promise.all([
        // 1. New signups
        drizzle.execute(sql`
          SELECT id, email, created_at
          FROM users
          ORDER BY created_at DESC
          LIMIT 10
        `),

        // 2. TTS failures (uses idx_tts_jobs_failed partial index)
        drizzle.execute(sql`
          SELECT id, provider, error, created_at
          FROM tts_jobs
          WHERE status = 'failed'
          ORDER BY created_at DESC
          LIMIT 10
        `),

        // 3. Deletion requests (uses idx_deletion_requests_created_at)
        drizzle.execute(sql`
          SELECT id, email, requested_at
          FROM deletion_requests
          ORDER BY requested_at DESC
          LIMIT 10
        `),
      ]);

      const events: ActivityEvent[] = [];

      // Map signups
      for (const row of signupRows.rows as Array<Record<string, unknown>>) {
        const email = String(row.email ?? '');
        const createdAt = row.created_at;
        events.push({
          type: 'signup',
          description: `New user signup: ${maskEmail(email)}`,
          occurredAt: createdAt instanceof Date
            ? createdAt.toISOString()
            : new Date(createdAt as string).toISOString(),
        });
      }

      // Map TTS failures
      for (const row of ttsFailureRows.rows as Array<Record<string, unknown>>) {
        const provider = String(row.provider ?? 'unknown');
        const error = String(row.error ?? 'Unknown error');
        const createdAt = row.created_at;
        events.push({
          type: 'tts_failure',
          description: `TTS failure (${provider}): ${sanitizeErrorMessage(error)}`,
          occurredAt: createdAt instanceof Date
            ? createdAt.toISOString()
            : new Date(createdAt as string).toISOString(),
        });
      }

      // Map deletion requests
      for (const row of deletionRows.rows as Array<Record<string, unknown>>) {
        const email = String(row.email ?? '');
        const requestedAt = row.requested_at;
        events.push({
          type: 'deletion_request',
          description: `Deletion request from ${maskEmail(email)}`,
          occurredAt: requestedAt instanceof Date
            ? requestedAt.toISOString()
            : new Date(requestedAt as string).toISOString(),
        });
      }

      // Sort by occurredAt DESC and take top 10
      events.sort((a, b) =>
        new Date(b.occurredAt).getTime() - new Date(a.occurredAt).getTime(),
      );

      return { events: events.slice(0, 10) };
    });
  }
}
