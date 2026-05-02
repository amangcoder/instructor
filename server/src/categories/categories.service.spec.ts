/**
 * Unit tests for CategoriesService.
 *
 * Strategy:
 *   - CategoryRepository is fully mocked so tests are isolated to service logic.
 *   - Each method is tested for happy path, NotFoundException when the repo
 *     returns null/false, and correct delegation of DTO fields to the repo.
 *
 * Covers:
 *   1. listPublished — delegates to repo
 *   2. listAll — delegates with pagination params
 *   3. findById — returns record or throws NotFoundException
 *   4. create — maps DTO fields correctly (defaults applied)
 *   5. update — returns updated record or throws NotFoundException
 *   6. softDelete — returns void or throws NotFoundException
 *   7. reorder — delegates items array to repo
 */

import { NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { CategoriesService } from './categories.service';
import { CategoryRepository } from '../database/repositories/category.repository';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { ReorderCategoriesDto } from './dto/reorder-categories.dto';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const CATEGORY_RECORD = {
  id: 'cat-uuid-001',
  slug: 'morning-meditation',
  name: 'Morning Meditation',
  icon: '🌅',
  color: '#FF6B35',
  sortOrder: 0,
  isPublished: true,
  createdAt: new Date('2026-01-01T00:00:00.000Z'),
  updatedAt: new Date('2026-01-02T00:00:00.000Z'),
};

// ---------------------------------------------------------------------------
// Mock repository factory
// ---------------------------------------------------------------------------

function createMockRepo() {
  return {
    listPublished: jest.fn().mockResolvedValue([CATEGORY_RECORD]),
    listAll: jest.fn().mockResolvedValue({ categories: [CATEGORY_RECORD], total: 1 }),
    findById: jest.fn().mockResolvedValue(CATEGORY_RECORD),
    create: jest.fn().mockResolvedValue({ id: 'cat-uuid-new' }),
    update: jest.fn().mockResolvedValue(CATEGORY_RECORD),
    softDelete: jest.fn().mockResolvedValue(true),
    reorder: jest.fn().mockResolvedValue(undefined),
  };
}

// ---------------------------------------------------------------------------
// Test suite setup
// ---------------------------------------------------------------------------

describe('CategoriesService', () => {
  let service: CategoriesService;
  let repo: ReturnType<typeof createMockRepo>;

  beforeEach(async () => {
    repo = createMockRepo();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CategoriesService,
        { provide: CategoryRepository, useValue: repo },
      ],
    }).compile();

    service = module.get<CategoriesService>(CategoriesService);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  // ── listPublished ─────────────────────────────────────────────────────────

  describe('listPublished', () => {
    it('returns the array from the repository', async () => {
      const result = await service.listPublished();

      expect(result).toEqual([CATEGORY_RECORD]);
      expect(repo.listPublished).toHaveBeenCalledTimes(1);
    });

    it('returns empty array when there are no published categories', async () => {
      repo.listPublished.mockResolvedValueOnce([]);

      const result = await service.listPublished();

      expect(result).toEqual([]);
    });
  });

  // ── listAll ───────────────────────────────────────────────────────────────

  describe('listAll', () => {
    it('delegates to repo with default pagination (page=1, pageSize=20)', async () => {
      const result = await service.listAll();

      expect(result).toEqual({ categories: [CATEGORY_RECORD], total: 1 });
      expect(repo.listAll).toHaveBeenCalledWith(1, 20);
    });

    it('forwards custom page and pageSize to repo', async () => {
      await service.listAll(3, 10);

      expect(repo.listAll).toHaveBeenCalledWith(3, 10);
    });
  });

  // ── findById ─────────────────────────────────────────────────────────────

  describe('findById', () => {
    it('returns the category when found', async () => {
      const result = await service.findById('cat-uuid-001');

      expect(result).toEqual(CATEGORY_RECORD);
      expect(repo.findById).toHaveBeenCalledWith('cat-uuid-001');
    });

    it('throws NotFoundException when the category does not exist', async () => {
      repo.findById.mockResolvedValueOnce(null);

      await expect(service.findById('nonexistent-id')).rejects.toThrow(NotFoundException);
    });

    it('NotFoundException message contains the id', async () => {
      repo.findById.mockResolvedValueOnce(null);

      await expect(service.findById('bad-id')).rejects.toThrow('bad-id');
    });
  });

  // ── create ────────────────────────────────────────────────────────────────

  describe('create', () => {
    const baseDto: CreateCategoryDto = Object.assign(new CreateCategoryDto(), {
      slug: 'sleep',
      name: 'Sleep',
    });

    it('creates a category with required fields and default values', async () => {
      const result = await service.create(baseDto);

      expect(result).toEqual({ id: 'cat-uuid-new' });
      expect(repo.create).toHaveBeenCalledWith({
        slug: 'sleep',
        name: 'Sleep',
        icon: null,
        color: null,
        sortOrder: 0,
        isPublished: false,
      });
    });

    it('passes through optional fields when provided', async () => {
      const fullDto: CreateCategoryDto = Object.assign(new CreateCategoryDto(), {
        slug: 'sleep',
        name: 'Sleep',
        icon: '🌙',
        color: '#1A1A2E',
        sortOrder: 5,
        isPublished: true,
      });

      await service.create(fullDto);

      expect(repo.create).toHaveBeenCalledWith({
        slug: 'sleep',
        name: 'Sleep',
        icon: '🌙',
        color: '#1A1A2E',
        sortOrder: 5,
        isPublished: true,
      });
    });

    it('defaults isPublished to false (draft) when not provided', async () => {
      await service.create(baseDto);

      const callArg = repo.create.mock.calls[0][0];
      expect(callArg.isPublished).toBe(false);
    });

    it('defaults sortOrder to 0 when not provided', async () => {
      await service.create(baseDto);

      const callArg = repo.create.mock.calls[0][0];
      expect(callArg.sortOrder).toBe(0);
    });
  });

  // ── update ────────────────────────────────────────────────────────────────

  describe('update', () => {
    const updateDto: UpdateCategoryDto = Object.assign(new UpdateCategoryDto(), {
      name: 'Updated Name',
    });

    it('returns the updated category record', async () => {
      const updated = { ...CATEGORY_RECORD, name: 'Updated Name' };
      repo.update.mockResolvedValueOnce(updated);

      const result = await service.update('cat-uuid-001', updateDto);

      expect(result).toEqual(updated);
    });

    it('calls repo.update with the category id and dto fields', async () => {
      await service.update('cat-uuid-001', updateDto);

      expect(repo.update).toHaveBeenCalledWith(
        'cat-uuid-001',
        expect.objectContaining({ name: 'Updated Name' }),
      );
    });

    it('throws NotFoundException when the category does not exist', async () => {
      repo.update.mockResolvedValueOnce(null);

      await expect(service.update('nonexistent-id', updateDto)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('only includes provided fields in the repo call (partial update)', async () => {
      const partialDto: UpdateCategoryDto = Object.assign(new UpdateCategoryDto(), {
        isPublished: false,
      });

      await service.update('cat-uuid-001', partialDto);

      const callArg = repo.update.mock.calls[0][1];
      expect(callArg).toEqual({ isPublished: false });
      expect(callArg).not.toHaveProperty('name');
      expect(callArg).not.toHaveProperty('slug');
    });

    it('includes all provided fields when all fields are supplied', async () => {
      const fullDto: UpdateCategoryDto = Object.assign(new UpdateCategoryDto(), {
        slug: 'new-slug',
        name: 'New Name',
        icon: '🆕',
        color: '#000',
        sortOrder: 10,
        isPublished: true,
      });

      await service.update('cat-uuid-001', fullDto);

      expect(repo.update).toHaveBeenCalledWith('cat-uuid-001', {
        slug: 'new-slug',
        name: 'New Name',
        icon: '🆕',
        color: '#000',
        sortOrder: 10,
        isPublished: true,
      });
    });
  });

  // ── softDelete ────────────────────────────────────────────────────────────

  describe('softDelete', () => {
    it('resolves without error when the category exists', async () => {
      repo.softDelete.mockResolvedValueOnce(true);

      await expect(service.softDelete('cat-uuid-001')).resolves.toBeUndefined();
      expect(repo.softDelete).toHaveBeenCalledWith('cat-uuid-001');
    });

    it('throws NotFoundException when the category does not exist', async () => {
      repo.softDelete.mockResolvedValueOnce(false);

      await expect(service.softDelete('nonexistent-id')).rejects.toThrow(NotFoundException);
    });

    it('NotFoundException message contains the id', async () => {
      repo.softDelete.mockResolvedValueOnce(false);

      await expect(service.softDelete('missing-id')).rejects.toThrow('missing-id');
    });
  });

  // ── reorder ───────────────────────────────────────────────────────────────

  describe('reorder', () => {
    const reorderDto: ReorderCategoriesDto = Object.assign(new ReorderCategoriesDto(), {
      items: [
        { id: '00000000-0000-0000-0000-000000000001', sortOrder: 0 },
        { id: '00000000-0000-0000-0000-000000000002', sortOrder: 1 },
      ],
    });

    it('delegates items to repo.reorder', async () => {
      await service.reorder(reorderDto);

      expect(repo.reorder).toHaveBeenCalledWith(reorderDto.items);
    });

    it('resolves without error on success', async () => {
      await expect(service.reorder(reorderDto)).resolves.toBeUndefined();
    });

    it('propagates errors from repo (e.g. DB failure)', async () => {
      repo.reorder.mockRejectedValueOnce(new Error('DB error'));

      await expect(service.reorder(reorderDto)).rejects.toThrow('DB error');
    });
  });
});
