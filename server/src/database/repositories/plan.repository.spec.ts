import { Test, TestingModule } from '@nestjs/testing';
import { PlanRepository } from './plan.repository';
import { DatabaseService, PlanRecord, PlanSummaryRecord, SavePlanResult } from '../database.service';
import { createMockDatabaseService } from '../testing';

const MOCK_PLAN: PlanRecord = {
  planId: 'plan-1',
  userId: 'user-1',
  name: 'Test Plan',
  planJson: '{}',
  isActive: false,
  ttsStatus: 'none',
  ttsTotal: 0,
  ttsCompleted: 0,
  voiceQuality: 'standard',
  sourceLibraryPlanId: null,
  shareToken: null,
  shareTokenCreatedAt: null,
  createdAt: new Date(),
  updatedAt: new Date(),
};

describe('PlanRepository', () => {
  let repository: PlanRepository;
  let mockDb: Partial<DatabaseService>;

  beforeEach(async () => {
    mockDb = createMockDatabaseService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PlanRepository,
        { provide: DatabaseService, useValue: mockDb },
      ],
    }).compile();

    repository = module.get<PlanRepository>(PlanRepository);
  });

  it('savePlan delegates to DatabaseService', async () => {
    const result = await repository.savePlan('user-1', 'Test Plan', '{}', 'plan-1');
    expect(mockDb.savePlan).toHaveBeenCalledWith('user-1', 'Test Plan', '{}', 'plan-1');
    expect(result).toEqual({ planId: 'plan-1', updatedAt: expect.any(Date) });
  });

  it('getPlanById delegates to DatabaseService', async () => {
    (mockDb.getPlanById as jest.Mock).mockResolvedValue(MOCK_PLAN);
    const result = await repository.getPlanById('plan-1', 'user-1');
    expect(result).toBe(MOCK_PLAN);
    expect(mockDb.getPlanById).toHaveBeenCalledWith('plan-1', 'user-1');
  });

  it('deletePlan delegates to DatabaseService', async () => {
    await repository.deletePlan('plan-1', 'user-1');
    expect(mockDb.deletePlan).toHaveBeenCalledWith('plan-1', 'user-1');
  });

  it('activatePlan delegates to DatabaseService', async () => {
    await repository.activatePlan('plan-1', 'user-1', 'studio');
    expect(mockDb.activatePlan).toHaveBeenCalledWith('plan-1', 'user-1', 'studio');
  });

  it('setTtsStatus delegates to DatabaseService', async () => {
    await repository.setTtsStatus('plan-1', 'completed', 10, 10);
    expect(mockDb.setTtsStatus).toHaveBeenCalledWith('plan-1', 'completed', 10, 10);
  });

  it('incrementTtsCompleted delegates to DatabaseService', async () => {
    await repository.incrementTtsCompleted('plan-1');
    expect(mockDb.incrementTtsCompleted).toHaveBeenCalledWith('plan-1');
  });

  it('listPlans delegates to DatabaseService', async () => {
    const summaries: PlanSummaryRecord[] = [];
    (mockDb.listPlans as jest.Mock).mockResolvedValue(summaries);
    const result = await repository.listPlans('user-1');
    expect(result).toBe(summaries);
    expect(mockDb.listPlans).toHaveBeenCalledWith('user-1');
  });

  it('copyLibraryPlanToUser delegates to DatabaseService', async () => {
    const result = await repository.copyLibraryPlanToUser('lib-1', 'user-1', 'standard');
    expect(mockDb.copyLibraryPlanToUser).toHaveBeenCalledWith('lib-1', 'user-1', 'standard');
    expect(result).toEqual({ planId: 'plan-1' });
  });
});
