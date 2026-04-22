/**
 * AdminUsersController — paginated user list, role management, session history, and CSV export.
 *
 * Routes (all require JWT + admin role):
 *   GET   /api/admin/users                  — paginated + searchable list
 *   GET   /api/admin/users/export           — CSV export of users (TASK-007)
 *   GET   /api/admin/users/:id              — user detail with plan summary
 *   GET   /api/admin/users/:id/sessions     — last 20 session completions (TASK-006)
 *   GET   /api/admin/users/:userId/plans/:planId — plan detail
 *   PATCH /api/admin/users/:id/role         — change a user's role
 *
 * Self-demotion is prevented: an admin cannot strip their own role via this
 * endpoint (avoids accidentally locking the last admin out of the dashboard).
 */

import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Query,
  Req,
  Res,
  UseGuards,
  UsePipes,
  ValidationPipe,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRoleGuard } from '../auth/admin-role.guard';
import { AdminUsersService } from './admin-users.service';
import { CsvExportService } from './csv-export.service';
import {
  AdminUsersListResponse,
  ListUsersQueryDto,
  UpdateUserRoleDto,
} from './dto/users-list.dto';
import type { JwtPayload } from '../auth/auth.service';

@Controller('admin/users')
@UseGuards(JwtAuthGuard, AdminRoleGuard)
@UsePipes(new ValidationPipe({ transform: true, whitelist: true }))
export class AdminUsersController {
  constructor(
    private readonly usersService: AdminUsersService,
    private readonly csvExportService: CsvExportService,
  ) {}

  // -------------------------------------------------------------------------
  // NOTE: Static routes MUST come before parametric routes (:id).
  // 'export' is registered first to prevent it being captured by GET ':id'.
  // -------------------------------------------------------------------------

  /**
   * GET /api/admin/users/export
   *
   * Stream a UTF-8 CSV export of users.
   * Columns: id, email, role, created_at, plans_count, last_active_at
   *
   * Query params:
   *   - search (string): filter by email (optional)
   *   - role (string): filter by role (optional)
   */
  @Get('export')
  async exportUsers(
    @Query('search') search?: string,
    @Query('role') role?: string,
    @Res() res?: Response,
  ): Promise<void> {
    return this.csvExportService.streamUsersCsv({ search, role }, res!);
  }

  /**
   * GET /api/admin/users/:id
   *
   * Get full user detail including plan stats and recent plans.
   */
  @Get(':id')
  getDetail(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.usersService.getUserDetail(id);
  }

  /**
   * GET /api/admin/users/:id/sessions
   *
   * Get the last 20 session completions for a user. (TASK-006)
   *
   * @returns { sessions: Array<{ id, planName, completedAt, durationMs }> }
   */
  @Get(':id/sessions')
  getUserSessions(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.usersService.getUserSessions(id);
  }

  /**
   * GET /api/admin/users/:id/plans-summary
   *
   * Get per-plan summary for a user's plans. (TASK-006)
   */
  @Get(':id/plans-summary')
  getPlansWithSummary(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.usersService.getPlansWithSummary(id);
  }

  /**
   * GET /api/admin/users/:userId/plans/:planId
   *
   * Get a specific plan's detail.
   */
  @Get(':userId/plans/:planId')
  getPlanDetail(
    @Param('planId', new ParseUUIDPipe()) planId: string,
  ) {
    return this.usersService.getPlanDetail(planId);
  }

  /**
   * GET /api/admin/users
   *
   * Paginated, searchable list of users.
   */
  @Get()
  list(@Query() query: ListUsersQueryDto): Promise<AdminUsersListResponse> {
    return this.usersService.listUsers({
      page: query.page,
      pageSize: query.pageSize,
      search: query.search,
      role: query.role,
    });
  }

  /**
   * PATCH /api/admin/users/:id/role
   *
   * Demote a user from admin to user. Promotion requires direct DB access.
   */
  @Patch(':id/role')
  async updateRole(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() body: UpdateUserRoleDto,
    @Req() req: Request & { user?: JwtPayload },
  ): Promise<{ id: string; role: 'user' | 'admin' }> {
    // Promotion to admin is never exposed via this API — grant via DB only.
    if (body.role !== 'user') {
      throw new ForbiddenException(
        'Promotion to admin is not permitted via this endpoint',
      );
    }
    // Also block self-demotion so the last admin can't lock themselves out.
    if (req.user?.sub === id) {
      throw new ForbiddenException('Admins cannot remove their own admin role');
    }
    return this.usersService.updateRole(id, 'user');
  }
}
