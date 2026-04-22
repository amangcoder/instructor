import {
  Injectable,
  Logger,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { count, eq, and, ilike, sql } from 'drizzle-orm';
import { DatabaseService } from '../database/database.service';
import { deletionRequests } from '../database/schema';
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

  constructor(private readonly db: DatabaseService) {}

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
      const drizzle = this.db.getDb();

      const page = Math.max(MIN_PAGE, Math.floor(params.page ?? 1));
      const pageSize = Math.min(
        MAX_PAGE_SIZE,
        Math.floor(params.pageSize ?? DEFAULT_PAGE_SIZE),
      );
      const offset = (page - 1) * pageSize;

      // Build WHERE clause
      const conditions: Parameters<typeof and>[0][] = [];

      if (params.search) {
        conditions.push(ilike(deletionRequests.email, `%${params.search}%`));
      }

      if (params.status) {
        conditions.push(eq(deletionRequests.status, params.status));
      }

      const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

      // Fetch total count
      const totalResult = await drizzle
        .select({ value: count() })
        .from(deletionRequests)
        .where(whereClause);

      const total = totalResult[0].value;

      // Fetch paginated rows
      const rows = await drizzle
        .select()
        .from(deletionRequests)
        .where(whereClause)
        .orderBy(deletionRequests.createdAt)
        .limit(pageSize)
        .offset(offset);

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
      const drizzle = this.db.getDb();

      // ATOMIC UPDATE pattern: Update and return in a single query
      // This prevents race conditions where two admins might process the same request.
      const result = await drizzle
        .update(deletionRequests)
        .set({
          status: 'processed',
          processedAt: new Date(),
        })
        .where(
          and(
            eq(deletionRequests.id, id),
            eq(deletionRequests.status, 'pending'),
          ),
        )
        .returning({
          id: deletionRequests.id,
          status: deletionRequests.status,
          processedAt: deletionRequests.processedAt,
        });

      // If returning() is empty, the request either doesn't exist or was already processed
      if (result.length === 0) {
        // Check if it exists with status='processed'
        const existing = await drizzle
          .select({ status: deletionRequests.status })
          .from(deletionRequests)
          .where(eq(deletionRequests.id, id));

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
      const drizzle = this.db.getDb();

      const result = await drizzle
        .select({ value: count() })
        .from(deletionRequests)
        .where(eq(deletionRequests.status, 'pending'));

      return {
        count: result[0].value,
      };
    });
  }
}
