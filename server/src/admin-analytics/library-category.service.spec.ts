/**
 * Unit tests for LibraryCategoryService (TASK-004).
 *
 * Tests:
 *   - Returns category breakdown with expected fields
 *   - Includes all known categories even with zero values
 *   - Includes unknown categories from DB results
 *   - Computes conversionRate correctly (0 when totalAdoptions=0)
 */

import { Test, TestingModule } from '@nestjs/testing';
import { LibraryCategoryService } from './library-category.service';
import { DatabaseService } from '../database/database.service';
import { createMockDatabaseService } from '../database/testing';

describe('LibraryCategoryService', () => {
  let service: LibraryCategoryService;
  let dbService: ReturnType<typeof createMockDatabaseService>;

  beforeEach(async () => {
    dbService = createMockDatabaseService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        LibraryCategoryService,
        { provide: DatabaseService, useValue: dbService },
      ],
    }).compile();

    service = module.get<LibraryCategoryService>(LibraryCategoryService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getLibraryCategories()', () => {
    it('returns category breakdown with known categories', async () => {
      dbService._mockDb.execute.mockResolvedValueOnce({
        rows: [
          { category: 'yoga', published_plans: 3, total_adoptions: 50, total_sessions: 120 },
          { category: 'meditation', published_plans: 2, total_adoptions: 30, total_sessions: 60 },
        ],
      });

      const result = await service.getLibraryCategories('30d');

      expect(result.categories).toBeDefined();
      expect(Array.isArray(result.categories)).toBe(true);

      // Should include all known categories
      const names = result.categories.map((c) => c.category);
      expect(names).toContain('yoga');
      expect(names).toContain('meditation');
      expect(names).toContain('workout');
      expect(names).toContain('cooking');
      expect(names).toContain('routine');
      expect(names).toContain('focus');
      expect(names).toContain('custom');
    });

    it('fills zero values for categories not in query result', async () => {
      dbService._mockDb.execute.mockResolvedValueOnce({
        rows: [
          { category: 'yoga', published_plans: 1, total_adoptions: 10, total_sessions: 5 },
        ],
      });

      const result = await service.getLibraryCategories('30d');

      const workout = result.categories.find((c) => c.category === 'workout');
      expect(workout).toBeDefined();
      expect(workout!.publishedPlans).toBe(0);
      expect(workout!.totalAdoptions).toBe(0);
      expect(workout!.totalSessions).toBe(0);
      expect(workout!.conversionRate).toBe(0);
    });

    it('computes conversionRate correctly', async () => {
      dbService._mockDb.execute.mockResolvedValueOnce({
        rows: [
          { category: 'yoga', published_plans: 2, total_adoptions: 100, total_sessions: 50 },
        ],
      });

      const result = await service.getLibraryCategories('7d');
      const yoga = result.categories.find((c) => c.category === 'yoga');
      expect(yoga!.conversionRate).toBe(0.5); // 50/100
    });

    it('returns conversionRate=0 when totalAdoptions is 0', async () => {
      dbService._mockDb.execute.mockResolvedValueOnce({
        rows: [
          { category: 'yoga', published_plans: 2, total_adoptions: 0, total_sessions: 0 },
        ],
      });

      const result = await service.getLibraryCategories('7d');
      const yoga = result.categories.find((c) => c.category === 'yoga');
      expect(yoga!.conversionRate).toBe(0);
    });

    it('includes unexpected categories from DB', async () => {
      dbService._mockDb.execute.mockResolvedValueOnce({
        rows: [
          { category: 'sports', published_plans: 1, total_adoptions: 5, total_sessions: 2 },
        ],
      });

      const result = await service.getLibraryCategories('30d');
      const names = result.categories.map((c) => c.category);
      expect(names).toContain('sports');
    });
  });
});
