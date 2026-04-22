import {
  Controller,
  Get,
  Patch,
  Param,
  Query,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRoleGuard } from '../auth/admin-role.guard';
import { DeletionRequestsAdminService } from './deletion-requests-admin.service';
import { CsvExportService } from './csv-export.service';
import type {
  DeletionRequestListResponse,
  ProcessedDeletionRequest,
  PendingCountResponse,
  ListDeletionRequestsQueryDto,
} from './dto/deletion-requests-admin.dto';

/**
 * DeletionRequestsAdminController — TASK-005 + TASK-007
 *
 * Endpoints:
 *   GET   /api/admin/analytics/deletion-requests               — paginated list
 *   GET   /api/admin/analytics/deletion-requests/pending-count — count pending
 *   GET   /api/admin/analytics/deletion-requests/export        — CSV export (TASK-007)
 *   PATCH /api/admin/analytics/deletion-requests/:id/process   — mark as processed
 *
 * SECURITY: @UseGuards(JwtAuthGuard, AdminRoleGuard)
 *   All endpoints require admin role. Non-admin users receive 403.
 *
 * NOTE: Static routes (pending-count, export) MUST be declared before
 *       the parametric route (:id) to avoid being captured by it.
 */
@Controller('admin/analytics/deletion-requests')
@UseGuards(JwtAuthGuard, AdminRoleGuard)
export class DeletionRequestsAdminController {
  constructor(
    private readonly service: DeletionRequestsAdminService,
    private readonly csvExportService: CsvExportService,
  ) {}

  /**
   * GET /api/admin/analytics/deletion-requests
   *
   * List deletion requests with pagination and optional search/status filter.
   *
   * Query parameters:
   *   - page (number): 1-indexed page number (default: 1)
   *   - pageSize (number): items per page, max 100 (default: 20)
   *   - search (string): filter by email (case-insensitive, partial match)
   *   - status (string): filter by status ('pending' | 'processed')
   *
   * Response: { data: DeletionRequestRow[], total, page, pageSize }
   */
  @Get()
  listDeletionRequests(
    @Query() query: ListDeletionRequestsQueryDto,
  ): Promise<DeletionRequestListResponse> {
    return this.service.listDeletionRequests(query);
  }

  /**
   * GET /api/admin/analytics/deletion-requests/pending-count
   *
   * Get the count of pending (unprocessed) deletion requests.
   * Used by the admin sidebar to display a badge count.
   *
   * Response: { count: number }
   */
  @Get('pending-count')
  getPendingCount(): Promise<PendingCountResponse> {
    return this.service.getPendingCount();
  }

  /**
   * GET /api/admin/analytics/deletion-requests/export
   *
   * Stream a UTF-8 CSV export of deletion requests. (TASK-007)
   * Columns: id, email, ip_address, requested_at, processed_at, status
   *
   * NOTE: Email is UNMASKED in the CSV (admin context export).
   * Maximum 10,000 rows streamed; data is not buffered in server memory.
   *
   * Query params:
   *   - search (string): filter by email (optional)
   *   - status (string): filter by status ('pending' | 'processed', optional)
   */
  @Get('export')
  async exportDeletionRequests(
    @Query('search') search?: string,
    @Query('status') status?: string,
    @Res() res?: Response,
  ): Promise<void> {
    return this.csvExportService.streamDeletionRequestsCsv({ search, status }, res!);
  }

  /**
   * PATCH /api/admin/analytics/deletion-requests/:id/process
   *
   * Mark a deletion request as processed.
   * Uses atomic update to prevent race conditions.
   *
   * Path parameters:
   *   - id: the deletion request UUID
   *
   * Response: { id, status: 'processed', processedAt }
   *
   * Status codes:
   *   - 200: Success
   *   - 404: Request not found
   *   - 409: Request already processed (race condition)
   *   - 403: User is not admin
   */
  @Patch(':id/process')
  processDeletionRequest(@Param('id') id: string): Promise<ProcessedDeletionRequest> {
    return this.service.processDeletionRequest(id);
  }
}
