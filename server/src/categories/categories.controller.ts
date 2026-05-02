/**
 * CategoriesController — public category listing endpoint.
 *
 * Public:
 *   GET  /api/categories       — paginated list of published categories
 *
 * No authentication is required. The response contains only categories
 * where isPublished=true, ordered by sortOrder ascending.
 *
 * Admin endpoints (POST, PATCH, DELETE) live in AdminCategoriesController
 * under the /api/admin/categories prefix so they are naturally separated
 * from public routes and consistently guarded.
 */

import {
  Controller,
  Get,
  Logger,
  Query,
} from '@nestjs/common';
import { CategoriesService } from './categories.service';

@Controller('categories')
export class CategoriesController {
  private readonly logger = new Logger(CategoriesController.name);

  constructor(private readonly categoriesService: CategoriesService) {}

  /**
   * GET /api/categories
   *
   * Returns a paginated list of all published categories sorted by sortOrder.
   *
   * Query params:
   *   page     — 1-based page number (default: 1)
   *   pageSize — items per page (default: 20, max: 100)
   */
  @Get()
  async list(
    @Query('page') pageStr?: string,
    @Query('pageSize') pageSizeStr?: string,
  ) {
    const page = Math.max(1, parseInt(pageStr ?? '1', 10) || 1);
    const pageSize = Math.min(100, Math.max(1, parseInt(pageSizeStr ?? '20', 10) || 20));

    this.logger.log(`GET /categories — page=${page} pageSize=${pageSize}`);

    const all = await this.categoriesService.listPublished();
    const total = all.length;
    const start = (page - 1) * pageSize;
    const categories = all.slice(start, start + pageSize);

    return { categories, total, page, pageSize };
  }
}
