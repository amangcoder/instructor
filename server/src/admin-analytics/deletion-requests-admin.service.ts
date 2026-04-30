import {
  Injectable,
  Logger,
  NotFoundException,
  ConflictException,
  Inject,
} from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { AdminAnalyticsRepository } from '../database/repositories/analytics.repository';
import type {
  DeletionRequestListResponse,
  DeletionRequestRow,
  ProcessedDeletionRequest,
  PendingCountResponse,
  ListDeletionRequestsQueryDto,
} from './dto/deletion-requests-admin.dto';
import { maskEmail } from './utils/mask-email';

const MIN_PAGE = 1;
const MAX_PAGE_SIZE = 100;
const DEFAULT_PAGE_SIZE = 20;

/**
 * DeletionRequestsAdminService — TASK-005
 * Provides admin-facing read/write access to the deletion_requests table.
 *
 * Methods:
 *   - listDeletionRequests() — paginated list with optional search and status filter
 *   - processDeletionRequest() — atomically mark a request as processed
 *   - getPendingCount() — return count of pending requests (for sidebar badge)
 *
 * SECURITY:
 *   - Emails are masked before returning to the client (maskEmail utility)
 *   - processDeletionRequest uses ATOMIC UPDATE pattern (no SELECT then UPDATE)
 *   - ConflictException (409) on race condition (request already processed)
 *   - NotFoundException (404) if request id doesn't exist
 */
@Injectable()
export class DeletionRequestsAdminService {
  private readonly logger = new Logger(DeletionRequestsAdminService.name);
  constructor(
    private readonly db: DatabaseService,
    @Inject(AdminAnalyticsRepository) private readonly repo: AdminAnalyticsRepository,
  ) {}

  /**
   * List deletion requests with pagination and optional search/status filter.
   *
   * @param params  { page, pageSize, search, status }
   * @returns       Paginated list with masked email addresses
   */
  async listDeletionRequests(
    params: ListDeletionRequestsQueryDto,
  ): Promise<DeletionRequestListResponse> {
    return this.db.withRetry(async () => {
      const page = Math.max(MIN_PAGE, Math.floor(params.page ?? 1));
      const pageSize = Math.min(
        MAX_PAGE_SIZE,
        Math.floor(params.pageSize ?? DEFAULT_PAGE_SIZE),
      );

      let rows: any[];
      let total: number;

      const result = await this.repo.listDeletionRequests({
          page,
          pageSize,
          search: params.search,
          status: params.status,
        });
        rows = result.rows;
        total = result.total;

      // Mask emails before returning
      const data: DeletionRequestRow[] = rows.map((row) => ({
        id: row.id,
        email: maskEmail(row.email),
        ipAddress: row.ipAddress ?? null,
        requestedAt: row.requestedAt.toISOString(),
        processedAt: row.processedAt ? row.processedAt.toISOString() : null,
        status: row.status as 'pending' | 'processed',
      }));

      return {
        data,
        total,
        page,
        pageSize,
      };
    });
  }

  /**
   * Mark a deletion request as processed (ATOMIC UPDATE pattern).
   *
   * Uses UPDATE ... RETURNING to atomically update and fetch the result.
   * If the request doesn't exist or is already processed, throws appropriate errors.
   *
   * @param id  The deletion request ID
   * @returns   The updated deletion request with new status and processedAt timestamp
   * @throws    NotFoundException if id doesn't exist
   * @throws    ConflictException if request is already processed (race condition)
   */
  async processDeletionRequest(id: string): Promise<ProcessedDeletionRequest> {
    return this.db.withRetry(async () => {
      let result: Array<{ id: string; status: string; processedAt: Date | null }>;

      result = await this.repo.processDeletionRequestById(id);

      if (result.length === 0) {
        const existing = await this.repo.getDeletionRequestStatus(id);

        if (existing.length === 0) {
          throw new NotFoundException(`Deletion request ${id} not found`);
        }

        // Already processed — return 409 Conflict
        throw new ConflictException(
          `Deletion request ${id} is already processed`,
        );
      }

      return {
        id: result[0].id,
        status: 'processed' as const,
        processedAt: result[0].processedAt!.toISOString(),
      };
    });
  }

  /**
   * Get the count of pending (unprocessed) deletion requests.
   * Used by the admin sidebar to display a badge count.
   *
   * @returns { count: number }
   */
  async getPendingCount(): Promise<PendingCountResponse> {
    return this.db.withRetry(async () => {
      return { count: await this.repo.getPendingDeletionRequestCount() };
    });
  }
}
