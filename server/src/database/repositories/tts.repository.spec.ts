import { Test, TestingModule } from '@nestjs/testing';
import { TtsRepository } from './tts.repository';
import { DatabaseService, TtsJobRecord, TtsPregenStatusRecord } from '../database.service';
import { createMockDatabaseService } from '../testing';

describe('TtsRepository', () => {
  let repository: TtsRepository;
  let mockDb: Partial<DatabaseService>;

  beforeEach(async () => {
    mockDb = createMockDatabaseService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TtsRepository,
        { provide: DatabaseService, useValue: mockDb },
      ],
    }).compile();

    repository = module.get<TtsRepository>(TtsRepository);
  });

  it('createTtsJobs delegates to DatabaseService', async () => {
    const jobs = [
      { planId: 'plan-1', cacheKey: 'key', text: 'Hello', voiceId: 'af_aoede', locale: 'en-us', provider: 'kokoro', speechRate: '1.0' },
    ];
    const rows = [{ id: 'job-1', cacheKey: 'key' }];
    (mockDb.createTtsJobs as jest.Mock).mockResolvedValue(rows);
    const result = await repository.createTtsJobs(jobs);
    expect(result).toBe(rows);
    expect(mockDb.createTtsJobs).toHaveBeenCalledWith(jobs);
  });

  it('getTtsJobsByIds delegates to DatabaseService', async () => {
    await repository.getTtsJobsByIds(['job-1']);
    expect(mockDb.getTtsJobsByIds).toHaveBeenCalledWith(['job-1']);
  });

  it('updateTtsJobStatus delegates to DatabaseService', async () => {
    await repository.updateTtsJobStatus('job-1', 'completed', 's3/key');
    expect(mockDb.updateTtsJobStatus).toHaveBeenCalledWith('job-1', 'completed', 's3/key', undefined);
  });

  it('getPlanTtsStatus delegates to DatabaseService', async () => {
    const status: TtsPregenStatusRecord = {
      status: 'completed', total: 5, completed: 5, failed: 0, ready: true, updatedAt: new Date(),
    };
    (mockDb.getPlanTtsStatus as jest.Mock).mockResolvedValue(status);
    const result = await repository.getPlanTtsStatus('plan-1');
    expect(result).toBe(status);
    expect(mockDb.getPlanTtsStatus).toHaveBeenCalledWith('plan-1');
  });

  it('getCompletedTtsJobs delegates to DatabaseService', async () => {
    await repository.getCompletedTtsJobs('plan-1');
    expect(mockDb.getCompletedTtsJobs).toHaveBeenCalledWith('plan-1');
  });

  it('failStalePendingJobs delegates to DatabaseService', async () => {
    await repository.failStalePendingJobs('plan-1');
    expect(mockDb.failStalePendingJobs).toHaveBeenCalledWith('plan-1');
  });

  it('finalizePlanTtsStatus delegates to DatabaseService', async () => {
    await repository.finalizePlanTtsStatus('plan-1');
    expect(mockDb.finalizePlanTtsStatus).toHaveBeenCalledWith('plan-1');
  });
});
