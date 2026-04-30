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

import { Injectable, Logger, Inject } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { AdminAnalyticsRepository } from '../database/repositories/analytics.repository';
import { sanitizeErrorMessage } from '../common/analytics-utils';
import { maskEmail } from './utils/mask-email';
import type { ActivityFeedResponse, ActivityEvent } from './dto/activity-feed.dto';

@Injectable()
export class ActivityFeedService {
  private readonly logger = new Logger(ActivityFeedService.name);

  constructor(
    private readonly db: DatabaseService,
    @Inject(AdminAnalyticsRepository) private readonly repo: AdminAnalyticsRepository,
  ) {}

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
      const events: ActivityEvent[] = [];

      const [signups, ttsFailures, deletions] = await Promise.all([
        this.repo.getRecentSignups(10),
        this.repo.getRecentTtsFailures(10),
        this.repo.getRecentDeletionRequests(10),
      ]);

      for (const row of signups) {
        events.push({
          type: 'signup',
          description: `New user signup: ${maskEmail(row.email)}`,
          occurredAt: row.createdAt,
        });
      }
      for (const row of ttsFailures) {
        events.push({
          type: 'tts_failure',
          description: `TTS failure (${row.provider}): ${sanitizeErrorMessage(row.error)}`,
          occurredAt: row.createdAt,
        });
      }
      for (const row of deletions) {
        events.push({
          type: 'deletion_request',
          description: `Deletion request from ${maskEmail(row.email)}`,
          occurredAt: row.requestedAt,
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
