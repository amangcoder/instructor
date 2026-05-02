/**
 * CategoryRepository — domain repository for category CRUD and reorder operations.
 *
 * Thin wrapper over DatabaseService, following the existing repository pattern
 * so callers can be unit-tested with a mocked repository while the service
 * delegates to Drizzle ORM.
 */

import { Injectable } from '@nestjs/common';
import { DatabaseService, type CategoryRecord } from '../database.service';

@Injectable()
export class CategoryRepository {
  constructor(private readonly database: DatabaseService) {}

  /**
   * List all published categories, ordered by sortOrder.
   * Used by the mobile app Discover surface.
   */
  async listPublished(): Promise<CategoryRecord[]> {
    return this.database.listPublishedCategories();
  }

  /**
   * List all categories (published and unpublished) with pagination.
   * Used by the admin panel.
   */
  async listAll(page: number = 1, pageSize: number = 20): Promise<{ categories: CategoryRecord[]; total: number }> {
    return this.database.listAllCategories(page, pageSize);
  }

  /**
   * Get a single category by ID.
   */
  async findById(id: string): Promise<CategoryRecord | null> {
    return this.database.getCategoryById(id);
  }

  /**
   * Create a new category.
   */
  async create(data: {
    slug: string;
    name: string;
    icon?: string | null;
    color?: string | null;
    sortOrder?: number;
    isPublished?: boolean;
  }): Promise<{ id: string }> {
    return this.database.createCategory(data);
  }

  /**
   * Update an existing category.
   */
  async update(
    id: string,
    data: Partial<{
      slug: string;
      name: string;
      icon: string | null;
      color: string | null;
      sortOrder: number;
      isPublished: boolean;
    }>,
  ): Promise<CategoryRecord | null> {
    return this.database.updateCategory(id, data);
  }

  /**
   * Soft delete a category by setting isPublished to false.
   */
  async softDelete(id: string): Promise<boolean> {
    return this.database.softDeleteCategory(id);
  }

  /**
   * Reorder multiple categories atomically.
   * Accepts an array of { id, sortOrder } objects.
   */
  async reorder(items: Array<{ id: string; sortOrder: number }>): Promise<void> {
    return this.database.reorderCategories(items);
  }
}
