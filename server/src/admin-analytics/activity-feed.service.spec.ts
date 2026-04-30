/**
 * Unit tests for ActivityFeedService (TASK-008).
 *
 * Tests:
 *   - getRecentActivity() returns at most 10 events
 *   - Events are sorted by occurredAt DESC (most recent first)
 *   - Signup events have masked email
 *   - TTS failure events have sanitized error messages
 *   - Deletion request events have masked email
 *   - Handles empty results gracefully
 *   - Merges events from all three sources correctly
 */

import { Test, TestingModule } from '@nestjs/testing';
import { ActivityFeedService } from './activity-feed.service';
import { DatabaseService } from '../database/database.service';
import { createMockDatabaseService } from '../database/testing';

const BASE_DATE = new Date('2026-04-21T12:00:00Z');

function dateOffset(minutesAgo: number): string {
  return new Date(BASE_DATE.getTime() - minutesAgo * 60 * 1000).toISOString();
}

describe('ActivityFeedService', () => {
  let service: ActivityFeedService;
  let dbService: ReturnType<typeof createMockDatabaseService>;

  beforeEach(async () => {
    dbService = createMockDatabaseService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ActivityFeedService,
        { provide: DatabaseService, useValue: dbService },
      ],
    }).compile();

    service = module.get<ActivityFeedService>(ActivityFeedService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  // -------------------------------------------------------------------------
  // getRecentActivity
  // -------------------------------------------------------------------------

  describe('getRecentActivity()', () => {
    it('returns empty events array when all queries return empty', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: [] })  // signups
        .mockResolvedValueOnce({ rows: [] })  // tts failures
        .mockResolvedValueOnce({ rows: [] }); // deletion requests

      const result = await service.getRecentActivity();

      expect(result.events).toBeDefined();
      expect(Array.isArray(result.events)).toBe(true);
      expect(result.events.length).toBe(0);
    });

    it('returns max 10 events even if more are available', async () => {
      // Return 5 signups + 5 TTS failures + 3 deletion requests = 13 total, capped at 10
      const signups = Array.from({ length: 5 }, (_, i) => ({
        id: `user-${i}`,
        email: `user${i}@example.com`,
        created_at: dateOffset(i * 2),
      }));
      const ttsFailures = Array.from({ length: 5 }, (_, i) => ({
        id: `tts-${i}`,
        provider: 'kokoro',
        error: 'synthesis failed',
        created_at: dateOffset(i * 2 + 1),
      }));
      const deletionRequests = Array.from({ length: 3 }, (_, i) => ({
        id: `dr-${i}`,
        email: `delete${i}@example.com`,
        requested_at: dateOffset(i * 2 + 20),
      }));

      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: signups })
        .mockResolvedValueOnce({ rows: ttsFailures })
        .mockResolvedValueOnce({ rows: deletionRequests });

      const result = await service.getRecentActivity();

      expect(result.events.length).toBeLessThanOrEqual(10);
    });

    it('sorts events by occurredAt DESC (most recent first)', async () => {
      const signups = [
        { id: 'u1', email: 'old@example.com', created_at: dateOffset(60) },
        { id: 'u2', email: 'new@example.com', created_at: dateOffset(5) },
      ];

      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: signups })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [] });

      const result = await service.getRecentActivity();

      expect(result.events.length).toBe(2);
      // Most recent first
      expect(new Date(result.events[0].occurredAt).getTime()).toBeGreaterThan(
        new Date(result.events[1].occurredAt).getTime(),
      );
    });

    it('masks email in signup events', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce({
          rows: [{ id: 'u1', email: 'john@gmail.com', created_at: BASE_DATE.toISOString() }],
        })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [] });

      const result = await service.getRecentActivity();

      expect(result.events[0].type).toBe('signup');
      expect(result.events[0].description).toContain('jo***@gmail.com');
      expect(result.events[0].description).not.toContain('john@gmail.com');
    });

    it('sanitizes error message in TTS failure events', async () => {
      const rawError = 'synthesis failed for /internal/path/to/file user@provider.com';

      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({
          rows: [{
            id: 'tts-1',
            provider: 'elevenlabs',
            error: rawError,
            created_at: BASE_DATE.toISOString(),
          }],
        })
        .mockResolvedValueOnce({ rows: [] });

      const result = await service.getRecentActivity();

      expect(result.events[0].type).toBe('tts_failure');
      expect(result.events[0].description).toContain('elevenlabs');
      // PII/paths should be sanitized
      expect(result.events[0].description).not.toContain('user@provider.com');
      expect(result.events[0].description).not.toContain('/internal/path/to/file');
    });

    it('masks email in deletion request events', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({
          rows: [{ id: 'dr-1', email: 'privacy@test.com', requested_at: BASE_DATE.toISOString() }],
        });

      const result = await service.getRecentActivity();

      expect(result.events[0].type).toBe('deletion_request');
      expect(result.events[0].description).toContain('pr***@test.com');
      expect(result.events[0].description).not.toContain('privacy@test.com');
    });

    it('includes correct event types', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce({
          rows: [{ id: 'u1', email: 'a@b.com', created_at: dateOffset(30) }],
        })
        .mockResolvedValueOnce({
          rows: [{ id: 't1', provider: 'kokoro', error: 'err', created_at: dateOffset(20) }],
        })
        .mockResolvedValueOnce({
          rows: [{ id: 'd1', email: 'c@d.com', requested_at: dateOffset(10) }],
        });

      const result = await service.getRecentActivity();

      const types = result.events.map((e) => e.type);
      expect(types).toContain('signup');
      expect(types).toContain('tts_failure');
      expect(types).toContain('deletion_request');
    });

    it('returns valid ISO 8601 occurredAt timestamps', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce({
          rows: [{ id: 'u1', email: 'x@y.com', created_at: BASE_DATE }], // Date object
        })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [] });

      const result = await service.getRecentActivity();

      expect(() => new Date(result.events[0].occurredAt)).not.toThrow();
      expect(new Date(result.events[0].occurredAt).toISOString()).toBeTruthy();
    });
  });
});
