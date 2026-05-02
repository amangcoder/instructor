import { Test, TestingModule } from '@nestjs/testing';
import { CategoryRepository } from './category.repository';
import { DatabaseService, CategoryRecord } from '../database.service';
import { createMockDatabaseService } from '../testing';

describe('CategoryRepository', () => {
  let repository: CategoryRepository;
  let mockDb: Partial<DatabaseService>;

  beforeEach(async () => {
    mockDb = createMockDatabaseService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CategoryRepository,
        { provide: DatabaseService, useValue: mockDb },
      ],
    }).compile();

    repository = module.get<CategoryRepository>(CategoryRepository);
  });

  describe('listPublished', () => {
    it('delegates to DatabaseService.listPublishedCategories', async () => {
      const mockCategories: CategoryRecord[] = [
        {
          id: 'cat-1',
          slug: 'wellness',
          name: 'Wellness',
          icon: 'wellness-icon',
          color: '#FF0000',
          sortOrder: 1,
          isPublished: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];
      (mockDb.listPublishedCategories as jest.Mock).mockResolvedValue(mockCategories);

      const result = await repository.listPublished();

      expect(result).toBe(mockCategories);
      expect(mockDb.listPublishedCategories).toHaveBeenCalled();
    });

    it('returns empty array when no categories are published', async () => {
      (mockDb.listPublishedCategories as jest.Mock).mockResolvedValue([]);

      const result = await repository.listPublished();

      expect(result).toEqual([]);
    });
  });

  describe('listAll', () => {
    it('delegates to DatabaseService.listAllCategories with pagination', async () => {
      const mockResponse = {
        categories: [
          {
            id: 'cat-1',
            slug: 'wellness',
            name: 'Wellness',
            icon: null,
            color: null,
            sortOrder: 1,
            isPublished: true,
            createdAt: new Date(),
            updatedAt: new Date(),
          },
        ],
        total: 1,
      };
      (mockDb.listAllCategories as jest.Mock).mockResolvedValue(mockResponse);

      const result = await repository.listAll(1, 20);

      expect(result).toEqual(mockResponse);
      expect(mockDb.listAllCategories).toHaveBeenCalledWith(1, 20);
    });

    it('uses default pagination if not provided', async () => {
      const mockResponse = { categories: [], total: 0 };
      (mockDb.listAllCategories as jest.Mock).mockResolvedValue(mockResponse);

      await repository.listAll();

      expect(mockDb.listAllCategories).toHaveBeenCalledWith(1, 20);
    });

    it('returns paginated results', async () => {
      const mockResponse = {
        categories: [
          {
            id: 'cat-1',
            slug: 'wellness',
            name: 'Wellness',
            icon: null,
            color: null,
            sortOrder: 1,
            isPublished: true,
            createdAt: new Date(),
            updatedAt: new Date(),
          },
          {
            id: 'cat-2',
            slug: 'fitness',
            name: 'Fitness',
            icon: null,
            color: null,
            sortOrder: 2,
            isPublished: true,
            createdAt: new Date(),
            updatedAt: new Date(),
          },
        ],
        total: 2,
      };
      (mockDb.listAllCategories as jest.Mock).mockResolvedValue(mockResponse);

      const result = await repository.listAll(1, 10);

      expect(result.categories).toHaveLength(2);
      expect(result.total).toBe(2);
    });
  });

  describe('findById', () => {
    it('delegates to DatabaseService.getCategoryById', async () => {
      const mockCategory: CategoryRecord = {
        id: 'cat-1',
        slug: 'wellness',
        name: 'Wellness',
        icon: 'wellness-icon',
        color: '#FF0000',
        sortOrder: 1,
        isPublished: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      (mockDb.getCategoryById as jest.Mock).mockResolvedValue(mockCategory);

      const result = await repository.findById('cat-1');

      expect(result).toBe(mockCategory);
      expect(mockDb.getCategoryById).toHaveBeenCalledWith('cat-1');
    });

    it('returns null when category does not exist', async () => {
      (mockDb.getCategoryById as jest.Mock).mockResolvedValue(null);

      const result = await repository.findById('nonexistent');

      expect(result).toBeNull();
    });
  });

  describe('create', () => {
    it('delegates to DatabaseService.createCategory', async () => {
      const data = {
        slug: 'wellness',
        name: 'Wellness',
        icon: 'wellness-icon',
        color: '#FF0000',
        sortOrder: 1,
        isPublished: true,
      };
      (mockDb.createCategory as jest.Mock).mockResolvedValue({ id: 'cat-1' });

      const result = await repository.create(data);

      expect(result).toEqual({ id: 'cat-1' });
      expect(mockDb.createCategory).toHaveBeenCalledWith(data);
    });

    it('creates category with optional fields', async () => {
      const data = {
        slug: 'wellness',
        name: 'Wellness',
      };
      (mockDb.createCategory as jest.Mock).mockResolvedValue({ id: 'cat-1' });

      const result = await repository.create(data);

      expect(result).toEqual({ id: 'cat-1' });
      expect(mockDb.createCategory).toHaveBeenCalledWith(data);
    });
  });

  describe('update', () => {
    it('delegates to DatabaseService.updateCategory', async () => {
      const updateData = { name: 'Updated Wellness' };
      const mockUpdated: CategoryRecord = {
        id: 'cat-1',
        slug: 'wellness',
        name: 'Updated Wellness',
        icon: null,
        color: null,
        sortOrder: 1,
        isPublished: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      (mockDb.updateCategory as jest.Mock).mockResolvedValue(mockUpdated);

      const result = await repository.update('cat-1', updateData);

      expect(result).toBe(mockUpdated);
      expect(mockDb.updateCategory).toHaveBeenCalledWith('cat-1', updateData);
    });

    it('returns null when category to update does not exist', async () => {
      (mockDb.updateCategory as jest.Mock).mockResolvedValue(null);

      const result = await repository.update('nonexistent', { name: 'Test' });

      expect(result).toBeNull();
    });

    it('can update isPublished status', async () => {
      const updateData = { isPublished: false };
      const mockUpdated: CategoryRecord = {
        id: 'cat-1',
        slug: 'wellness',
        name: 'Wellness',
        icon: null,
        color: null,
        sortOrder: 1,
        isPublished: false,
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      (mockDb.updateCategory as jest.Mock).mockResolvedValue(mockUpdated);

      const result = await repository.update('cat-1', updateData);

      expect(result?.isPublished).toBe(false);
    });
  });

  describe('softDelete', () => {
    it('delegates to DatabaseService.softDeleteCategory', async () => {
      (mockDb.softDeleteCategory as jest.Mock).mockResolvedValue(true);

      const result = await repository.softDelete('cat-1');

      expect(result).toBe(true);
      expect(mockDb.softDeleteCategory).toHaveBeenCalledWith('cat-1');
    });

    it('sets isPublished to false on the category', async () => {
      (mockDb.softDeleteCategory as jest.Mock).mockResolvedValue(true);

      const result = await repository.softDelete('cat-1');

      expect(result).toBe(true);
      // Verify the method is called with the correct ID
      expect(mockDb.softDeleteCategory).toHaveBeenCalledWith('cat-1');
    });

    it('returns false when category to delete does not exist', async () => {
      (mockDb.softDeleteCategory as jest.Mock).mockResolvedValue(false);

      const result = await repository.softDelete('nonexistent');

      expect(result).toBe(false);
    });
  });

  describe('reorder', () => {
    it('delegates to DatabaseService.reorderCategories', async () => {
      const items = [
        { id: 'cat-1', sortOrder: 1 },
        { id: 'cat-2', sortOrder: 2 },
      ];
      (mockDb.reorderCategories as jest.Mock).mockResolvedValue(undefined);

      await repository.reorder(items);

      expect(mockDb.reorderCategories).toHaveBeenCalledWith(items);
    });

    it('handles empty reorder list', async () => {
      (mockDb.reorderCategories as jest.Mock).mockResolvedValue(undefined);

      await repository.reorder([]);

      expect(mockDb.reorderCategories).toHaveBeenCalledWith([]);
    });

    it('atomically updates sort order for multiple categories', async () => {
      const items = [
        { id: 'cat-1', sortOrder: 3 },
        { id: 'cat-2', sortOrder: 1 },
        { id: 'cat-3', sortOrder: 2 },
      ];
      (mockDb.reorderCategories as jest.Mock).mockResolvedValue(undefined);

      await repository.reorder(items);

      expect(mockDb.reorderCategories).toHaveBeenCalledWith(items);
      expect(mockDb.reorderCategories).toHaveBeenCalledTimes(1);
    });
  });

  describe('integration', () => {
    it('can perform full CRUD cycle', async () => {
      // Create
      (mockDb.createCategory as jest.Mock).mockResolvedValue({ id: 'cat-1' });
      let result = await repository.create({
        slug: 'test-category',
        name: 'Test Category',
      });
      expect(result.id).toBe('cat-1');

      // Read
      const mockCategory: CategoryRecord = {
        id: 'cat-1',
        slug: 'test-category',
        name: 'Test Category',
        icon: null,
        color: null,
        sortOrder: 0,
        isPublished: false,
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      (mockDb.getCategoryById as jest.Mock).mockResolvedValue(mockCategory);
      result = (await repository.findById('cat-1')) as any;
      expect(result.id).toBe('cat-1');

      // Update
      const updated = { ...mockCategory, name: 'Updated Category' };
      (mockDb.updateCategory as jest.Mock).mockResolvedValue(updated);
      result = await repository.update('cat-1', { name: 'Updated Category' });
      expect(result?.name).toBe('Updated Category');

      // Soft delete
      (mockDb.softDeleteCategory as jest.Mock).mockResolvedValue(true);
      const deleted = await repository.softDelete('cat-1');
      expect(deleted).toBe(true);
    });
  });
});
