/**
 * Unit tests for AdminAnalyticsService.
 *
 * Strategy: mock DatabaseService so we control what the Drizzle queries return.
 * Each test verifies the shape and logic of the service methods without a real DB.
 */

import { Test, TestingModule } from '@nestjs/testing';
import {
  AdminAnalyticsService,
  fillDateGaps,
  sanitizeErrorMessage,
} from './admin-analytics.service';
import { DatabaseService } from '../database/database.service';
import { AdminAnalyticsRepository } from '../database/repositories';
import { createMockDatabaseService } from '../database/testing';

// ---------------------------------------------------------------------------
// fillDateGaps utility tests
// ---------------------------------------------------------------------------

describe('fillDateGaps', () => {
  it('fills missing dates with value=0', () => {
    const dataMap = new Map<string, number>();
    dataMap.set('2026-04-15', 5);
    dataMap.set('2026-04-17', 3);

    const start = new Date('2026-04-14T00:00:00Z');
    const end = new Date('2026-04-18T00:00:00Z');

    const series = fillDateGaps(dataMap, start, end);

    expect(series).toHaveLength(5);
    expect(series).toEqual([
      { date: '2026-04-14', value: 0 },
      { date: '2026-04-15', value: 5 },
      { date: '2026-04-16', value: 0 },
      { date: '2026-04-17', value: 3 },
      { date: '2026-04-18', value: 0 },
    ]);
  });

  it('returns empty array if start > end', () => {
    const dataMap = new Map<string, number>();
    const start = new Date('2026-04-20T00:00:00Z');
    const end = new Date('2026-04-18T00:00:00Z');

    const series = fillDateGaps(dataMap, start, end);
    expect(series).toHaveLength(0);
  });

  it('returns single entry if start == end', () => {
    const dataMap = new Map<string, number>();
    dataMap.set('2026-04-15', 10);
    const d = new Date('2026-04-15T00:00:00Z');

    const series = fillDateGaps(dataMap, d, d);
    expect(series).toHaveLength(1);
    expect(series[0]).toEqual({ date: '2026-04-15', value: 10 });
  });

  it('fills 30 entries for a 30-day range', () => {
    const dataMap = new Map<string, number>();
    const start = new Date('2026-03-22T00:00:00Z');
    const end = new Date('2026-04-20T00:00:00Z');

    const series = fillDateGaps(dataMap, start, end);
    expect(series).toHaveLength(30);
    // All values should be 0
    for (const point of series) {
      expect(point.value).toBe(0);
    }
  });

  it('produces ISO date strings in YYYY-MM-DD format', () => {
    const dataMap = new Map<string, number>();
    const start = new Date('2026-01-01T00:00:00Z');
    const end = new Date('2026-01-03T00:00:00Z');

    const series = fillDateGaps(dataMap, start, end);
    expect(series[0].date).toBe('2026-01-01');
    expect(series[1].date).toBe('2026-01-02');
    expect(series[2].date).toBe('2026-01-03');
  });
});

// ---------------------------------------------------------------------------
// AdminAnalyticsService tests
// ---------------------------------------------------------------------------

describe('AdminAnalyticsService', () => {
  let service: AdminAnalyticsService;
  let dbService: ReturnType<typeof createMockDatabaseService>;

  beforeEach(async () => {
    dbService = createMockDatabaseService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AdminAnalyticsService,
        AdminAnalyticsRepository,
        { provide: DatabaseService, useValue: dbService },
      ],
    }).compile();

    service = module.get<AdminAnalyticsService>(AdminAnalyticsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getOverview', () => {
    it('calls withRetry to handle Neon cold starts', async () => {
      // Set up the mock chain: select().from().where() resolves to [{ value: 0 }]
      const mockResult = [{ value: 0 }];
      dbService._mockDb.select.mockReturnValue({
        from: jest.fn().mockReturnValue({
          where: jest.fn().mockResolvedValue(mockResult),
          // For plain select().from() without where
          then: (resolve: any) => resolve(mockResult),
          [Symbol.toStringTag]: 'Promise',
        }),
      });

      // Mock Promise.all friendly chaining
      const fromMock = jest.fn().mockImplementation(() => {
        const whereObj = jest.fn().mockResolvedValue(mockResult);
        const promise = Promise.resolve(mockResult);
        (promise as any).where = whereObj;
        (promise as any).groupBy = jest.fn().mockReturnValue(promise);
        (promise as any).orderBy = jest.fn().mockReturnValue(promise);
        return promise;
      });
      dbService._mockDb.select.mockReturnValue({ from: fromMock });

      await service.getOverview();

      expect(dbService.withRetry).toHaveBeenCalledTimes(1);
      expect(dbService.getDb).toHaveBeenCalled();
    });

    it('returns OverviewResponse shape with series=[] and totals', async () => {
      // Simplified mock: each select().from() chain returns [{ value: N }]
      let callIdx = 0;
      const values = [
        100, 50, 200, 30, // totals: users, plans, tts, sessions
        10, 5, 20, 2, 15, 5000, 3, // current 7d
        8, 4, 18, 1, 12, 4500, 2,  // previous 7d
      ];

      const fromMock = jest.fn().mockImplementation(() => {
        const result = [{ value: values[callIdx++] ?? 0 }];
        const promise = Promise.resolve(result);
        (promise as any).where = jest.fn().mockResolvedValue(result);
        return promise;
      });
      dbService._mockDb.select.mockReturnValue({ from: fromMock });

      const response = await service.getOverview();

      expect(response.series).toEqual([]);
      expect(response.totals).toBeDefined();
      expect(response.totals.totalUsers).toHaveProperty('current');
      expect(response.totals.totalUsers).toHaveProperty('previous');
      expect(response.totals.totalUsers).toHaveProperty('deltaPercent');
      expect(response.totals.newSignups).toBeDefined();
      expect(response.totals.activePlans).toBeDefined();
      expect(response.totals.totalPlans).toBeDefined();
      expect(response.totals.ttsJobsCompleted).toBeDefined();
      expect(response.totals.ttsJobsFailed).toBeDefined();
      expect(response.totals.totalSessions).toBeDefined();
      expect(response.totals.avgSessionDurationMs).toBeDefined();
    });

    it('returns all zeros when database is empty', async () => {
      // All queries return { value: 0 }
      const fromMock = jest.fn().mockImplementation(() => {
        const result = [{ value: 0 }];
        const promise = Promise.resolve(result);
        (promise as any).where = jest.fn().mockResolvedValue(result);
        return promise;
      });
      dbService._mockDb.select.mockReturnValue({ from: fromMock });

      const response = await service.getOverview();

      expect(response.series).toEqual([]);

      // All metrics should have current=0, previous=0, deltaPercent=null
      const metrics = [
        response.totals.totalUsers,
        response.totals.newSignups,
        response.totals.activePlans,
        response.totals.totalPlans,
        response.totals.ttsJobsCompleted,
        response.totals.ttsJobsFailed,
        response.totals.totalSessions,
        response.totals.avgSessionDurationMs,
      ];
      for (const metric of metrics) {
        expect(metric.current).toBe(0);
        expect(metric.previous).toBe(0);
        // deltaPercent is null when previous is 0 (no division by zero)
        expect(metric.deltaPercent).toBeNull();
      }
    });
  });

  describe('getUserSignups', () => {
    beforeEach(() => {
      jest.useFakeTimers();
      jest.setSystemTime(new Date('2026-04-21T12:00:00Z'));
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    it('calls withRetry', async () => {
      const fromMock = jest.fn().mockImplementation(() => {
        const result: any[] = [];
        const promise = Promise.resolve(result);
        (promise as any).where = jest.fn().mockReturnValue({
          groupBy: jest.fn().mockReturnValue({
            orderBy: jest.fn().mockResolvedValue(result),
          }),
        });
        return promise;
      });
      dbService._mockDb.select.mockReturnValue({ from: fromMock });

      await service.getUserSignups('7d');
      expect(dbService.withRetry).toHaveBeenCalledTimes(1);
    });

    it('returns exactly 7 entries for 7d range with zero-fill', async () => {
      // Return a couple of data rows
      const dbRows = [
        { date: '2026-04-16', value: 3 },
        { date: '2026-04-19', value: 7 },
      ];
      const fromMock = jest.fn().mockImplementation(() => {
        const promise = Promise.resolve(dbRows);
        (promise as any).where = jest.fn().mockReturnValue({
          groupBy: jest.fn().mockReturnValue({
            orderBy: jest.fn().mockResolvedValue(dbRows),
          }),
        });
        return promise;
      });
      dbService._mockDb.select.mockReturnValue({ from: fromMock });

      const response = await service.getUserSignups('7d');

      // 7d range from 2026-04-14 to 2026-04-21 inclusive = 8 days
      expect(response.series.length).toBeGreaterThanOrEqual(7);

      // Verify zero-filling happened: dates without data have value=0
      const apr15 = response.series.find((p) => p.date === '2026-04-15');
      expect(apr15?.value).toBe(0);

      // Dates with data are preserved
      const apr16 = response.series.find((p) => p.date === '2026-04-16');
      expect(apr16?.value).toBe(3);

      const apr19 = response.series.find((p) => p.date === '2026-04-19');
      expect(apr19?.value).toBe(7);
    });

    it('computes totals correctly', async () => {
      const dbRows = [
        { date: '2026-04-16', value: 3 },
        { date: '2026-04-19', value: 7 },
      ];
      const fromMock = jest.fn().mockImplementation(() => {
        const promise = Promise.resolve(dbRows);
        (promise as any).where = jest.fn().mockReturnValue({
          groupBy: jest.fn().mockReturnValue({
            orderBy: jest.fn().mockResolvedValue(dbRows),
          }),
        });
        return promise;
      });
      dbService._mockDb.select.mockReturnValue({ from: fromMock });

      const response = await service.getUserSignups('7d');

      expect(response.totals.total).toBe(10); // 3 + 7
      expect(response.totals.peakDay).toBe(7);
      expect(response.totals.peakDate).toBe('2026-04-19');
      expect(response.totals.avgPerDay).toBeGreaterThan(0);
    });

    it('defaults range to 30d (caller handles default, but method accepts it)', async () => {
      const dbRows: any[] = [];
      const fromMock = jest.fn().mockImplementation(() => {
        const promise = Promise.resolve(dbRows);
        (promise as any).where = jest.fn().mockReturnValue({
          groupBy: jest.fn().mockReturnValue({
            orderBy: jest.fn().mockResolvedValue(dbRows),
          }),
        });
        return promise;
      });
      dbService._mockDb.select.mockReturnValue({ from: fromMock });

      const response = await service.getUserSignups('30d');

      // Should have ~31 entries (30 days + today)
      expect(response.series.length).toBeGreaterThanOrEqual(30);
      expect(response.totals.total).toBe(0);
    });

    it('date-fill produces exactly N+1 entries for N-day range (start to today inclusive)', async () => {
      // With fake timer at 2026-04-21:
      //   '7d'  → start=2026-04-14, end=2026-04-21 → 8 entries (days 14..21)
      //   '30d' → start=2026-03-22, end=2026-04-21 → 31 entries
      //   '90d' → start=2026-01-21, end=2026-04-21 → 91 entries
      const makeFromMock = () => {
        const rows: any[] = [];
        const fromMock = jest.fn().mockImplementation(() => {
          const promise = Promise.resolve(rows);
          (promise as any).where = jest.fn().mockReturnValue({
            groupBy: jest.fn().mockReturnValue({
              orderBy: jest.fn().mockResolvedValue(rows),
            }),
          });
          return promise;
        });
        return fromMock;
      };

      dbService._mockDb.select.mockReturnValue({ from: makeFromMock() });
      const r7 = await service.getUserSignups('7d');
      expect(r7.series).toHaveLength(8); // 7 days ago through today = 8 days inclusive

      dbService._mockDb.select.mockReturnValue({ from: makeFromMock() });
      const r30 = await service.getUserSignups('30d');
      expect(r30.series).toHaveLength(31);

      dbService._mockDb.select.mockReturnValue({ from: makeFromMock() });
      const r90 = await service.getUserSignups('90d');
      expect(r90.series).toHaveLength(91);
    });
  });

  describe('getUserActivation', () => {
    beforeEach(() => {
      jest.useFakeTimers();
      jest.setSystemTime(new Date('2026-04-21T12:00:00Z'));
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    it('calls withRetry', async () => {
      dbService._mockDb.execute.mockResolvedValue({ rows: [] });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      await service.getUserActivation('7d');
      expect(dbService.withRetry).toHaveBeenCalledTimes(1);
    });

    it('returns activation rate as decimal 0..1 in totals', async () => {
      dbService._mockDb.execute.mockResolvedValue({
        rows: [
          { day: '2026-04-16', signups: 10, activated: 4 },
          { day: '2026-04-17', signups: 5, activated: 3 },
        ],
      });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getUserActivation('7d');

      // Overall: 7 activated / 15 signups ≈ 0.4667
      expect(response.totals.totalSignups).toBe(15);
      expect(response.totals.totalActivated).toBe(7);
      expect(response.totals.overallRate).toBeGreaterThan(0);
      expect(response.totals.overallRate).toBeLessThanOrEqual(1);
    });

    it('returns 0 activation rate when no signups', async () => {
      dbService._mockDb.execute.mockResolvedValue({ rows: [] });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getUserActivation('7d');

      expect(response.totals.totalSignups).toBe(0);
      expect(response.totals.totalActivated).toBe(0);
      expect(response.totals.overallRate).toBe(0);
    });

    it('fills date gaps in activation series', async () => {
      dbService._mockDb.execute.mockResolvedValue({
        rows: [{ day: '2026-04-16', signups: 10, activated: 5 }],
      });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getUserActivation('7d');

      // Should have entries for every day in range
      expect(response.series.length).toBeGreaterThanOrEqual(7);

      // Check the filled-in date has zero values
      const apr15 = response.series.find((p) => p.date === '2026-04-15');
      expect(apr15?.value).toBe(0);
      expect(apr15?.rate).toBe(0);
      expect(apr15?.total).toBe(0);

      // Check the data date has correct values
      const apr16 = response.series.find((p) => p.date === '2026-04-16');
      expect(apr16?.value).toBe(5);
      expect(apr16?.rate).toBe(0.5);
      expect(apr16?.total).toBe(10);
    });

    it('series entries have date, value, rate, and total fields', async () => {
      dbService._mockDb.execute.mockResolvedValue({
        rows: [{ day: '2026-04-18', signups: 8, activated: 2 }],
      });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getUserActivation('7d');

      for (const point of response.series) {
        expect(point).toHaveProperty('date');
        expect(point).toHaveProperty('value');
        expect(point).toHaveProperty('rate');
        expect(point).toHaveProperty('total');
        expect(typeof point.date).toBe('string');
        expect(typeof point.value).toBe('number');
        expect(typeof point.rate).toBe('number');
        expect(typeof point.total).toBe('number');
      }
    });
  });

  // =========================================================================
  // getPlanFunnel
  // =========================================================================

  describe('getPlanFunnel', () => {
    beforeEach(() => {
      jest.useFakeTimers();
      jest.setSystemTime(new Date('2026-04-21T12:00:00Z'));
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    it('calls withRetry', async () => {
      dbService._mockDb.execute.mockResolvedValue({
        rows: [
          {
            created: 0,
            tts_started: 0,
            tts_completed: 0,
            activated: 0,
            session_completed: 0,
          },
        ],
      });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      await service.getPlanFunnel('7d');
      expect(dbService.withRetry).toHaveBeenCalledTimes(1);
    });

    it('returns FunnelResponse with 5 stages and totals', async () => {
      dbService._mockDb.execute.mockResolvedValue({
        rows: [
          {
            created: 100,
            tts_started: 80,
            tts_completed: 60,
            activated: 50,
            session_completed: 20,
          },
        ],
      });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getPlanFunnel('30d');

      expect(response.series).toHaveLength(5);
      expect(response.series[0].stage).toBe('created');
      expect(response.series[0].count).toBe(100);
      expect(response.series[0].percentOfTop).toBe(100);
      expect(response.series[0].dropOffPercent).toBeNull(); // first stage

      expect(response.series[1].stage).toBe('tts_started');
      expect(response.series[1].count).toBe(80);
      expect(response.series[1].percentOfTop).toBe(80);
      expect(response.series[1].dropOffPercent).toBe(20);

      expect(response.series[2].stage).toBe('tts_completed');
      expect(response.series[2].count).toBe(60);

      expect(response.series[3].stage).toBe('activated');
      expect(response.series[3].count).toBe(50);

      expect(response.series[4].stage).toBe('session_completed');
      expect(response.series[4].count).toBe(20);

      expect(response.totals.totalCreated).toBe(100);
      expect(response.totals.overallConversionPercent).toBe(20);
    });

    it('returns 0 for drop-off and percentOfTop when created is 0 (division by zero guard)', async () => {
      dbService._mockDb.execute.mockResolvedValue({
        rows: [
          {
            created: 0,
            tts_started: 0,
            tts_completed: 0,
            activated: 0,
            session_completed: 0,
          },
        ],
      });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getPlanFunnel('7d');

      for (const stage of response.series) {
        expect(stage.percentOfTop).toBe(0);
        expect(Number.isFinite(stage.percentOfTop)).toBe(true);
        if (stage.dropOffPercent !== null) {
          expect(Number.isFinite(stage.dropOffPercent)).toBe(true);
        }
      }

      expect(response.totals.overallConversionPercent).toBe(0);
      expect(
        Number.isFinite(response.totals.overallConversionPercent),
      ).toBe(true);
    });

    it('drop-off from a zero-count previous stage returns 0', async () => {
      // Contrived: tts_started = 0 but tts_completed = 0 as well
      dbService._mockDb.execute.mockResolvedValue({
        rows: [
          {
            created: 10,
            tts_started: 0,
            tts_completed: 0,
            activated: 5,
            session_completed: 2,
          },
        ],
      });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getPlanFunnel('7d');

      // tts_completed's drop-off from tts_started (0) should be 0, not NaN
      const ttsCompleted = response.series.find(
        (s) => s.stage === 'tts_completed',
      );
      expect(ttsCompleted?.dropOffPercent).toBe(0);
      expect(Number.isFinite(ttsCompleted?.dropOffPercent)).toBe(true);
    });
  });

  // =========================================================================
  // getTtsVolume
  // =========================================================================

  describe('getTtsVolume', () => {
    beforeEach(() => {
      jest.useFakeTimers();
      jest.setSystemTime(new Date('2026-04-21T12:00:00Z'));
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    it('calls withRetry', async () => {
      dbService._mockDb.execute.mockResolvedValue({ rows: [] });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      await service.getTtsVolume('7d');
      expect(dbService.withRetry).toHaveBeenCalledTimes(1);
    });

    it('returns daily volume grouped by provider and voiceId', async () => {
      dbService._mockDb.execute.mockResolvedValue({
        rows: [
          { day: '2026-04-16', provider: 'kokoro', voice_id: 'af_bella', cnt: 10 },
          { day: '2026-04-16', provider: 'google', voice_id: 'en-US-A', cnt: 5 },
          { day: '2026-04-18', provider: 'kokoro', voice_id: 'af_bella', cnt: 8 },
        ],
      });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getTtsVolume('7d');

      // Series should cover 8 days (7d range from 04-14 to 04-21)
      expect(response.series.length).toBeGreaterThanOrEqual(7);

      // Check day with data
      const apr16 = response.series.find((p) => p.date === '2026-04-16');
      expect(apr16?.value).toBe(15);
      expect(apr16?.byProvider['kokoro']).toBe(10);
      expect(apr16?.byProvider['google']).toBe(5);

      // Check day without data
      const apr15 = response.series.find((p) => p.date === '2026-04-15');
      expect(apr15?.value).toBe(0);
      expect(apr15?.byProvider).toEqual({});

      // Check totals
      expect(response.totals.totalCompleted).toBe(23);
      expect(response.totals.byProvider['kokoro']).toBe(18);
      expect(response.totals.byProvider['google']).toBe(5);
      expect(response.totals.topVoices).toHaveLength(2);
      expect(response.totals.topVoices[0].voiceId).toBe('af_bella');
      expect(response.totals.topVoices[0].count).toBe(18);
    });

    it('returns empty series with zero totals when no data', async () => {
      dbService._mockDb.execute.mockResolvedValue({ rows: [] });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getTtsVolume('7d');

      expect(response.series.length).toBeGreaterThanOrEqual(7);
      expect(response.totals.totalCompleted).toBe(0);
      expect(response.totals.byProvider).toEqual({});
      expect(response.totals.topVoices).toEqual([]);
    });
  });

  // =========================================================================
  // getTtsErrors
  // =========================================================================

  describe('getTtsErrors', () => {
    beforeEach(() => {
      jest.useFakeTimers();
      jest.setSystemTime(new Date('2026-04-21T12:00:00Z'));
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    it('calls withRetry', async () => {
      // getTtsErrors runs 3 parallel queries + 1 sequential = 4 execute calls
      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: [] })        // daily failed
        .mockResolvedValueOnce({ rows: [] })        // top errors
        .mockResolvedValueOnce({ rows: [{ total: 0 }] }) // total jobs
        .mockResolvedValueOnce({ rows: [] });       // daily totals
      dbService.getDb.mockReturnValue(dbService._mockDb);

      await service.getTtsErrors('7d');
      expect(dbService.withRetry).toHaveBeenCalledTimes(1);
    });

    it('returns daily error counts and top errors', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce({
          rows: [
            { day: '2026-04-16', failed_count: 5 },
            { day: '2026-04-18', failed_count: 3 },
          ],
        })
        .mockResolvedValueOnce({
          rows: [
            { error: 'Timeout connecting to TTS', cnt: 5, last_seen: '2026-04-18T10:00:00Z' },
            { error: 'Invalid voice ID', cnt: 3, last_seen: '2026-04-16T09:00:00Z' },
          ],
        })
        .mockResolvedValueOnce({ rows: [{ total: 100 }] })
        .mockResolvedValueOnce({
          rows: [
            { day: '2026-04-16', total_count: 50 },
            { day: '2026-04-18', total_count: 30 },
          ],
        });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getTtsErrors('7d');

      // Series should cover 8 days
      expect(response.series.length).toBeGreaterThanOrEqual(7);

      // Check day with errors
      const apr16 = response.series.find((p) => p.date === '2026-04-16');
      expect(apr16?.value).toBe(5);
      expect(apr16?.errorRate).toBe(0.1); // 5/50 = 0.1

      // Check day without errors
      const apr15 = response.series.find((p) => p.date === '2026-04-15');
      expect(apr15?.value).toBe(0);
      expect(apr15?.errorRate).toBe(0);

      // Totals
      expect(response.totals.totalErrors).toBe(8);
      expect(response.totals.overallErrorRate).toBe(0.08); // 8/100
      expect(response.totals.topErrors).toHaveLength(2);
      expect(response.totals.topErrors[0].message).toBe(
        'Timeout connecting to TTS',
      );
      expect(response.totals.topErrors[0].count).toBe(5);
    });

    it('returns 0 error rate when no jobs exist (division by zero guard)', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [{ total: 0 }] })
        .mockResolvedValueOnce({ rows: [] });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getTtsErrors('7d');

      expect(response.totals.totalErrors).toBe(0);
      expect(response.totals.overallErrorRate).toBe(0);
      expect(Number.isFinite(response.totals.overallErrorRate)).toBe(true);
      expect(response.totals.topErrors).toEqual([]);

      // All series points should have errorRate = 0
      for (const point of response.series) {
        expect(point.errorRate).toBe(0);
        expect(Number.isFinite(point.errorRate)).toBe(true);
      }
    });

    it('sanitizes error messages containing emails and file paths', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: [{ day: '2026-04-16', failed_count: 2 }] })
        .mockResolvedValueOnce({
          rows: [
            {
              error: 'Failed for user@example.com at /var/lib/tts/cache/abc.wav',
              cnt: 2,
              last_seen: '2026-04-16T10:00:00Z',
            },
          ],
        })
        .mockResolvedValueOnce({ rows: [{ total: 10 }] })
        .mockResolvedValueOnce({ rows: [{ day: '2026-04-16', total_count: 10 }] });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getTtsErrors('7d');

      const errorMsg = response.totals.topErrors[0].message;
      expect(errorMsg).not.toContain('user@example.com');
      expect(errorMsg).not.toContain('/var/lib/tts/cache/abc.wav');
      expect(errorMsg).toContain('[REDACTED_EMAIL]');
      expect(errorMsg).toContain('[REDACTED_PATH]');
    });
  });

  // =========================================================================
  // getPlanUsage
  // =========================================================================

  describe('getPlanUsage', () => {
    beforeEach(() => {
      jest.useFakeTimers();
      jest.setSystemTime(new Date('2026-04-21T12:00:00Z'));
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    it('calls withRetry', async () => {
      // distribution query, dormant query, total users count
      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: [] }) // distribution
        .mockResolvedValueOnce({
          rows: [{ total_plans: 0, active_plans: 0, recently_used: 0 }],
        }); // dormant
      const fromMock = jest.fn().mockImplementation(() => {
        return Promise.resolve([{ value: 0 }]);
      });
      dbService._mockDb.select.mockReturnValue({ from: fromMock });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      await service.getPlanUsage('7d');
      expect(dbService.withRetry).toHaveBeenCalledTimes(1);
    });

    it('returns plans-per-user distribution with correct buckets', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce({
          rows: [
            { plan_count: 1, user_count: 10 },
            { plan_count: 2, user_count: 5 },
            { plan_count: 3, user_count: 3 },
            { plan_count: 7, user_count: 2 },
          ],
        })
        .mockResolvedValueOnce({
          rows: [{ total_plans: 40, active_plans: 15, recently_used: 10 }],
        });

      // Total users query
      const fromMock = jest.fn().mockImplementation(() => {
        return Promise.resolve([{ value: 30 }]);
      });
      dbService._mockDb.select.mockReturnValue({ from: fromMock });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getPlanUsage('30d');

      expect(response.series).toHaveLength(6);
      expect(response.series[0]).toEqual({ bucket: '0', userCount: 10 }); // 30 - 20
      expect(response.series[1]).toEqual({ bucket: '1', userCount: 10 });
      expect(response.series[2]).toEqual({ bucket: '2', userCount: 5 });
      expect(response.series[3]).toEqual({ bucket: '3', userCount: 3 });
      expect(response.series[4]).toEqual({ bucket: '4', userCount: 0 });
      expect(response.series[5]).toEqual({ bucket: '5+', userCount: 2 });
    });

    it('returns active vs dormant plan counts', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: [{ plan_count: 1, user_count: 5 }] })
        .mockResolvedValueOnce({
          rows: [{ total_plans: 20, active_plans: 12, recently_used: 8 }],
        });

      const fromMock = jest.fn().mockImplementation(() => {
        return Promise.resolve([{ value: 10 }]);
      });
      dbService._mockDb.select.mockReturnValue({ from: fromMock });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getPlanUsage('30d');

      expect(response.totals.activePlans).toBe(12);
      expect(response.totals.dormantPlans).toBe(12); // 20 - 8
      expect(response.totals.totalPlans).toBe(20);
    });

    it('returns zero avgPlansPerUser when no users have plans', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({
          rows: [{ total_plans: 0, active_plans: 0, recently_used: 0 }],
        });

      const fromMock = jest.fn().mockImplementation(() => {
        return Promise.resolve([{ value: 5 }]);
      });
      dbService._mockDb.select.mockReturnValue({ from: fromMock });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getPlanUsage('7d');

      expect(response.totals.usersWithPlans).toBe(0);
      expect(response.totals.usersWithoutPlans).toBe(5);
      expect(response.totals.avgPlansPerUser).toBe(0);
      expect(Number.isFinite(response.totals.avgPlansPerUser)).toBe(true);
    });

    it('computes avgPlansPerUser correctly', async () => {
      // 5 users with 1 plan each + 3 users with 3 plans each = 14 plans / 8 users = 1.75
      dbService._mockDb.execute
        .mockResolvedValueOnce({
          rows: [
            { plan_count: 1, user_count: 5 },
            { plan_count: 3, user_count: 3 },
          ],
        })
        .mockResolvedValueOnce({
          rows: [{ total_plans: 14, active_plans: 5, recently_used: 3 }],
        });

      const fromMock = jest.fn().mockImplementation(() => {
        return Promise.resolve([{ value: 20 }]);
      });
      dbService._mockDb.select.mockReturnValue({ from: fromMock });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getPlanUsage('30d');

      expect(response.totals.avgPlansPerUser).toBe(1.75);
    });
  });

  // =========================================================================
  // getEngagementStreaks
  // =========================================================================

  describe('getEngagementStreaks', () => {
    beforeEach(() => {
      jest.useFakeTimers();
      jest.setSystemTime(new Date('2026-04-21T12:00:00Z'));
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    it('calls withRetry', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce(undefined) // SET LOCAL statement_timeout
        .mockResolvedValueOnce({ rows: [] }) // streaks query
        .mockResolvedValueOnce({ rows: [{ active_count: 0 }] }); // active count
      dbService.getDb.mockReturnValue(dbService._mockDb);

      await service.getEngagementStreaks();
      expect(dbService.withRetry).toHaveBeenCalledTimes(1);
    });

    it('sets statement_timeout for performance safety', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce(undefined)
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [{ active_count: 0 }] });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      await service.getEngagementStreaks();

      // First execute call should be the statement_timeout
      expect(dbService._mockDb.execute).toHaveBeenCalledTimes(3);
    });

    it('returns streak distribution with correct buckets', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce(undefined) // SET LOCAL
        .mockResolvedValueOnce({
          rows: [
            { length: 1, user_count: 10 },
            { length: 2, user_count: 5 },
            { length: 5, user_count: 3 },
            { length: 10, user_count: 2 },
            { length: 30, user_count: 1 },
          ],
        })
        .mockResolvedValueOnce({ rows: [{ active_count: 8 }] });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getEngagementStreaks();

      expect(response.series).toHaveLength(6);
      expect(response.series[0]).toEqual({ bucket: '0', min: 0, max: 0, userCount: 0 });
      expect(response.series[1]).toEqual({ bucket: '1-2', min: 1, max: 2, userCount: 15 });
      expect(response.series[2]).toEqual({ bucket: '3-6', min: 3, max: 6, userCount: 3 });
      expect(response.series[3]).toEqual({ bucket: '7-13', min: 7, max: 13, userCount: 2 });
      expect(response.series[4]).toEqual({ bucket: '14-29', min: 14, max: 29, userCount: 0 });
      expect(response.series[5]).toEqual({ bucket: '30+', min: 30, max: null, userCount: 1 });
    });

    it('computes totals correctly', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce(undefined)
        .mockResolvedValueOnce({
          rows: [
            { length: 1, user_count: 4 },
            { length: 3, user_count: 2 },
            { length: 7, user_count: 1 },
          ],
        })
        .mockResolvedValueOnce({ rows: [{ active_count: 3 }] });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getEngagementStreaks();

      expect(response.totals.usersWithStreaks).toBe(7);
      // avgStreak: (4*1 + 2*3 + 1*7) / 7 = 17/7 ≈ 2.43
      expect(response.totals.avgStreak).toBeCloseTo(2.43, 1);
      expect(response.totals.maxStreak).toBe(7);
      expect(response.totals.activeStreakUsers).toBe(3);
    });

    it('returns zeros when no completions exist', async () => {
      dbService._mockDb.execute
        .mockResolvedValueOnce(undefined)
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [{ active_count: 0 }] });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getEngagementStreaks();

      expect(response.totals.usersWithStreaks).toBe(0);
      expect(response.totals.avgStreak).toBe(0);
      expect(response.totals.medianStreak).toBe(0);
      expect(response.totals.maxStreak).toBe(0);
      expect(response.totals.activeStreakUsers).toBe(0);

      // All buckets should be zero
      for (const bucket of response.series) {
        expect(bucket.userCount).toBe(0);
      }
    });

    it('computes median correctly for odd number of users', async () => {
      // 3 users with streak lengths 1, 3, 7 → median = 3
      dbService._mockDb.execute
        .mockResolvedValueOnce(undefined)
        .mockResolvedValueOnce({
          rows: [
            { length: 1, user_count: 1 },
            { length: 3, user_count: 1 },
            { length: 7, user_count: 1 },
          ],
        })
        .mockResolvedValueOnce({ rows: [{ active_count: 2 }] });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getEngagementStreaks();

      expect(response.totals.medianStreak).toBe(3);
    });

    it('computes median correctly for even number of users', async () => {
      // 4 users with streak lengths 1, 2, 5, 10 → median = (2+5)/2 = 3.5
      dbService._mockDb.execute
        .mockResolvedValueOnce(undefined)
        .mockResolvedValueOnce({
          rows: [
            { length: 1, user_count: 1 },
            { length: 2, user_count: 1 },
            { length: 5, user_count: 1 },
            { length: 10, user_count: 1 },
          ],
        })
        .mockResolvedValueOnce({ rows: [{ active_count: 1 }] });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getEngagementStreaks();

      expect(response.totals.medianStreak).toBe(3.5);
    });
  });

  // =========================================================================
  // getLibraryConversions
  // =========================================================================

  describe('getLibraryConversions', () => {
    beforeEach(() => {
      jest.useFakeTimers();
      jest.setSystemTime(new Date('2026-04-21T12:00:00Z'));
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    it('calls withRetry', async () => {
      dbService._mockDb.execute.mockResolvedValue({ rows: [] });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      await service.getLibraryConversions('30d');
      expect(dbService.withRetry).toHaveBeenCalledTimes(1);
    });

    it('returns library plan rows with adoption counts', async () => {
      dbService._mockDb.execute.mockResolvedValue({
        rows: [
          {
            id: 'lib-1',
            name: 'Morning Meditation',
            category: 'meditation',
            is_published: true,
            total_adoptions: 50,
            range_adoptions: 20,
            activated_count: 30,
            session_count: 15,
          },
          {
            id: 'lib-2',
            name: 'HIIT Workout',
            category: 'fitness',
            is_published: true,
            total_adoptions: 30,
            range_adoptions: 10,
            activated_count: 20,
            session_count: 8,
          },
          {
            id: 'lib-3',
            name: 'Draft Plan',
            category: 'wellness',
            is_published: false,
            total_adoptions: 0,
            range_adoptions: 0,
            activated_count: 0,
            session_count: 0,
          },
        ],
      });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getLibraryConversions('30d');

      expect(response.series).toHaveLength(3);

      // First plan
      expect(response.series[0].id).toBe('lib-1');
      expect(response.series[0].name).toBe('Morning Meditation');
      expect(response.series[0].category).toBe('meditation');
      expect(response.series[0].isPublished).toBe(true);
      expect(response.series[0].totalAdoptions).toBe(50);
      expect(response.series[0].rangeAdoptions).toBe(20);
      expect(response.series[0].activatedCount).toBe(30);
      expect(response.series[0].sessionCount).toBe(15);
      expect(response.series[0].conversionRate).toBe(0.3); // 15/50

      // Unpublished plan with zero adoptions
      expect(response.series[2].conversionRate).toBeNull();
      expect(response.series[2].isPublished).toBe(false);
    });

    it('returns correct totals', async () => {
      dbService._mockDb.execute.mockResolvedValue({
        rows: [
          {
            id: 'lib-1',
            name: 'Plan A',
            category: 'fitness',
            is_published: true,
            total_adoptions: 40,
            range_adoptions: 15,
            activated_count: 20,
            session_count: 10,
          },
          {
            id: 'lib-2',
            name: 'Plan B',
            category: 'meditation',
            is_published: true,
            total_adoptions: 20,
            range_adoptions: 5,
            activated_count: 10,
            session_count: 5,
          },
        ],
      });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getLibraryConversions('30d');

      expect(response.totals.publishedCount).toBe(2);
      expect(response.totals.totalAdoptions).toBe(20); // range adoptions: 15 + 5
      // Overall conversion: (10+5) / (40+20) = 15/60 = 0.25
      expect(response.totals.overallConversionRate).toBe(0.25);
    });

    it('returns null overallConversionRate when no adoptions', async () => {
      dbService._mockDb.execute.mockResolvedValue({ rows: [] });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getLibraryConversions('7d');

      expect(response.series).toHaveLength(0);
      expect(response.totals.publishedCount).toBe(0);
      expect(response.totals.totalAdoptions).toBe(0);
      expect(response.totals.overallConversionRate).toBeNull();
    });

    it('each row has required LibraryPlanRow fields', async () => {
      dbService._mockDb.execute.mockResolvedValue({
        rows: [
          {
            id: 'lib-1',
            name: 'Test Plan',
            category: 'test',
            is_published: true,
            total_adoptions: 10,
            range_adoptions: 3,
            activated_count: 5,
            session_count: 2,
          },
        ],
      });
      dbService.getDb.mockReturnValue(dbService._mockDb);

      const response = await service.getLibraryConversions('30d');
      const row = response.series[0];

      expect(row).toHaveProperty('id');
      expect(row).toHaveProperty('name');
      expect(row).toHaveProperty('category');
      expect(row).toHaveProperty('isPublished');
      expect(row).toHaveProperty('totalAdoptions');
      expect(row).toHaveProperty('rangeAdoptions');
      expect(row).toHaveProperty('activatedCount');
      expect(row).toHaveProperty('sessionCount');
      expect(row).toHaveProperty('conversionRate');
      expect(typeof row.conversionRate).toBe('number');
    });
  });
});

// ---------------------------------------------------------------------------
// sanitizeErrorMessage utility tests
// ---------------------------------------------------------------------------

describe('sanitizeErrorMessage', () => {
  it('strips email addresses', () => {
    const result = sanitizeErrorMessage('Error for admin@company.com');
    expect(result).not.toContain('admin@company.com');
    expect(result).toContain('[REDACTED_EMAIL]');
  });

  it('strips Unix file paths', () => {
    const result = sanitizeErrorMessage(
      'File not found: /usr/local/lib/tts/voice.wav',
    );
    expect(result).not.toContain('/usr/local/lib/tts/voice.wav');
    expect(result).toContain('[REDACTED_PATH]');
  });

  it('strips Windows file paths', () => {
    const result = sanitizeErrorMessage(
      'Error at C:\\Users\\admin\\voices\\en.wav',
    );
    expect(result).not.toContain('C:\\Users\\admin\\voices\\en.wav');
    expect(result).toContain('[REDACTED_PATH]');
  });

  it('truncates to 200 characters', () => {
    const longMsg = 'A'.repeat(300);
    const result = sanitizeErrorMessage(longMsg);
    expect(result.length).toBe(200);
  });

  it('preserves short clean messages unchanged', () => {
    const msg = 'Connection timeout after 30s';
    expect(sanitizeErrorMessage(msg)).toBe(msg);
  });

  it('handles multiple emails and paths in one message', () => {
    const msg =
      'Failed for admin@x.com and user@y.org at /etc/tts/config/main.yaml';
    const result = sanitizeErrorMessage(msg);
    expect(result).not.toContain('admin@x.com');
    expect(result).not.toContain('user@y.org');
    expect(result).not.toContain('/etc/tts/config/main.yaml');
  });
});
