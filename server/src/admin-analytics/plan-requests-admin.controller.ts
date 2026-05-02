import {
  Controller,
  Get,
  Param,
  Patch,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRoleGuard } from '../auth/admin-role.guard';
import {
  PlanRequestsAdminService,
  type PlanRequestListResponse,
  type PlanRequestRow,
} from './plan-requests-admin.service';

/**
 * PlanRequestsAdminController — admin dashboard endpoints for the
 * "Request a Plan" submissions queue.
 *
 * Endpoints:
 *   GET   /api/admin/analytics/plan-requests               — paginated list
 *   GET   /api/admin/analytics/plan-requests/pending-count — sidebar badge count
 *   PATCH /api/admin/analytics/plan-requests/:id/process   — mark as processed
 *
 * Requires admin role on the JWT (JwtAuthGuard + AdminRoleGuard).
 */
@Controller('admin/analytics/plan-requests')
@UseGuards(JwtAuthGuard, AdminRoleGuard)
export class PlanRequestsAdminController {
  constructor(private readonly service: PlanRequestsAdminService) {}

  @Get()
  list(
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
    @Query('search') search?: string,
    @Query('status') status?: string,
  ): Promise<PlanRequestListResponse> {
    return this.service.list({
      page: page ? Number(page) : undefined,
      pageSize: pageSize ? Number(pageSize) : undefined,
      search,
      status,
    });
  }

  @Get('pending-count')
  pendingCount(): Promise<{ count: number }> {
    return this.service.getPendingCount();
  }

  @Patch(':id/process')
  process(@Param('id') id: string): Promise<PlanRequestRow> {
    return this.service.markProcessed(id);
  }
}
