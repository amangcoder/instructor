import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { CategoriesController } from './categories.controller';
import { AdminCategoriesController } from './admin-categories.controller';
import { CategoriesService } from './categories.service';

/**
 * CategoriesModule — manages the categories taxonomy.
 *
 * Public surface:
 *   GET /api/categories — paginated list of published categories
 *
 * Admin surface (JWT + admin role required):
 *   GET    /api/admin/categories
 *   POST   /api/admin/categories
 *   PATCH  /api/admin/categories/reorder
 *   PATCH  /api/admin/categories/:id
 *   DELETE /api/admin/categories/:id
 *
 * CategoryRepository is provided by the global DatabaseModule and injected
 * into CategoriesService automatically — no explicit import needed here.
 */
@Module({
  imports: [AuthModule],
  controllers: [CategoriesController, AdminCategoriesController],
  providers: [CategoriesService],
  exports: [CategoriesService],
})
export class CategoriesModule {}
