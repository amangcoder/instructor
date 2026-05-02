import {
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { CategoryRepository } from '../database/repositories/category.repository';
import type { CategoryRecord } from '../database/database.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { ReorderCategoriesDto } from './dto/reorder-categories.dto';

@Injectable()
export class CategoriesService {
  private readonly logger = new Logger(CategoriesService.name);

  constructor(private readonly repo: CategoryRepository) {}

  // ── Public read ───────────────────────────────────────────────────────────

  /**
   * Return all published categories ordered by sortOrder.
   * Used by the mobile Discover surface (public — no auth required).
   */
  listPublished(): Promise<CategoryRecord[]> {
    return this.repo.listPublished();
  }

  // ── Admin read ────────────────────────────────────────────────────────────

  /**
   * Return all categories (published and unpublished) with pagination.
   * Used by the admin panel.
   */
  listAll(
    page = 1,
    pageSize = 20,
  ): Promise<{ categories: CategoryRecord[]; total: number }> {
    return this.repo.listAll(page, pageSize);
  }

  /**
   * Return a single category by ID or throw NotFoundException.
   */
  async findById(id: string): Promise<CategoryRecord> {
    const category = await this.repo.findById(id);
    if (!category) {
      throw new NotFoundException(`Category ${id} not found`);
    }
    return category;
  }

  // ── Admin write ───────────────────────────────────────────────────────────

  /**
   * Create a new category. Defaults to draft (isPublished=false) unless
   * explicitly set by the admin.
   */
  create(dto: CreateCategoryDto): Promise<{ id: string }> {
    this.logger.log(`Creating category slug="${dto.slug}"`);
    return this.repo.create({
      slug: dto.slug,
      name: dto.name,
      icon: dto.icon ?? null,
      color: dto.color ?? null,
      sortOrder: dto.sortOrder ?? 0,
      isPublished: dto.isPublished ?? false,
    });
  }

  /**
   * Update an existing category. Returns the updated record or throws
   * NotFoundException if the ID does not exist.
   */
  async update(id: string, dto: UpdateCategoryDto): Promise<CategoryRecord> {
    this.logger.log(`Updating category id=${id}`);
    const updated = await this.repo.update(id, {
      ...(dto.slug !== undefined && { slug: dto.slug }),
      ...(dto.name !== undefined && { name: dto.name }),
      ...(dto.icon !== undefined && { icon: dto.icon }),
      ...(dto.color !== undefined && { color: dto.color }),
      ...(dto.sortOrder !== undefined && { sortOrder: dto.sortOrder }),
      ...(dto.isPublished !== undefined && { isPublished: dto.isPublished }),
    });
    if (!updated) {
      throw new NotFoundException(`Category ${id} not found`);
    }
    return updated;
  }

  /**
   * Soft-delete a category by setting isPublished=false.
   * The record is retained in the database for referential integrity.
   */
  async softDelete(id: string): Promise<void> {
    this.logger.log(`Soft-deleting category id=${id}`);
    const deleted = await this.repo.softDelete(id);
    if (!deleted) {
      throw new NotFoundException(`Category ${id} not found`);
    }
  }

  /**
   * Atomically reorder multiple categories in a single transaction.
   */
  reorder(dto: ReorderCategoriesDto): Promise<void> {
    this.logger.log(`Reordering ${dto.items.length} categories`);
    return this.repo.reorder(dto.items);
  }
}
