/**
 * AdminCategoriesController — admin endpoints for category management.
 *
 * All routes require JWT authentication AND the 'admin' role.
 *
 * Routes:
 *   GET    /api/admin/categories           — paginated list of all categories (incl. drafts)
 *   POST   /api/admin/categories           — create a new category
 *   PATCH  /api/admin/categories/reorder   — bulk-update sort_order (literal before :id)
 *   PATCH  /api/admin/categories/:id       — update a category
 *   DELETE /api/admin/categories/:id       — soft-delete (sets isPublished=false)
 *
 * SECURITY:
 *   @UseGuards(JwtAuthGuard, AdminRoleGuard) is applied at the class level so
 *   every method inherits both guards. Route order matters: the static
 *   'reorder' segment is declared before ':id' to prevent NestJS from
 *   matching "reorder" as an :id value.
 */

import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Logger,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { CategoriesService } from './categories.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { ReorderCategoriesDto } from './dto/reorder-categories.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRoleGuard } from '../auth/admin-role.guard';

@Controller('admin/categories')
@UseGuards(JwtAuthGuard, AdminRoleGuard)
export class AdminCategoriesController {
  private readonly logger = new Logger(AdminCategoriesController.name);

  constructor(private readonly categoriesService: CategoriesService) {}

  /**
   * GET /api/admin/categories
   * Returns a paginated list of all categories (published and unpublished).
   */
  @Get()
  async listAll(
    @Query('page') pageStr?: string,
    @Query('pageSize') pageSizeStr?: string,
  ) {
    const page = Math.max(1, parseInt(pageStr ?? '1', 10) || 1);
    const pageSize = Math.min(100, Math.max(1, parseInt(pageSizeStr ?? '20', 10) || 20));

    this.logger.log(`GET /admin/categories — page=${page} pageSize=${pageSize}`);
    return this.categoriesService.listAll(page, pageSize);
  }

  /**
   * POST /api/admin/categories
   * Creates a new category. Defaults to draft (isPublished=false).
   */
  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(@Body() dto: CreateCategoryDto) {
    this.logger.log(`POST /admin/categories — slug="${dto.slug}"`);
    return this.categoriesService.create(dto);
  }

  /**
   * PATCH /api/admin/categories/reorder
   * Bulk-updates the sort_order for multiple categories atomically.
   *
   * ROUTE ORDER: This literal path MUST be declared before PATCH ':id'
   * to prevent NestJS from routing "reorder" as an :id parameter.
   */
  @Patch('reorder')
  @HttpCode(HttpStatus.NO_CONTENT)
  async reorder(@Body() dto: ReorderCategoriesDto): Promise<void> {
    this.logger.log(
      `PATCH /admin/categories/reorder — ${dto.items.length} item(s)`,
    );
    await this.categoriesService.reorder(dto);
  }

  /**
   * PATCH /api/admin/categories/:id
   * Partially updates a category. Only provided fields are changed.
   */
  @Patch(':id')
  async update(@Param('id') id: string, @Body() dto: UpdateCategoryDto) {
    this.logger.log(`PATCH /admin/categories/${id}`);
    return this.categoriesService.update(id, dto);
  }

  /**
   * DELETE /api/admin/categories/:id
   * Soft-deletes a category by setting isPublished=false.
   * The record is retained for referential integrity (series still reference it).
   */
  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async softDelete(@Param('id') id: string): Promise<void> {
    this.logger.log(`DELETE /admin/categories/${id}`);
    await this.categoriesService.softDelete(id);
  }
}
