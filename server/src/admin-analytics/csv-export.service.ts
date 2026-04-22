/**
 * CsvExportService — TASK-007
 *
 * Streams CSV exports for users and deletion requests using paginated DB
 * queries (1000 rows per page), capping at 10,000 rows total.
 *
 * CSV rows are written directly to the response stream (res.write()) in
 * batches. This prevents buffering large exports entirely in server memory.
 *
 * Headers:
 *   Content-Type: text/csv; charset=utf-8
 *   Content-Disposition: attachment; filename=<type>_export_YYYY-MM-DD.csv
 */

import { Injectable, Logger } from '@nestjs/common';
import { sql, ilike, eq, and, desc } from 'drizzle-orm';
import type { Response } from 'express';
import { DatabaseService } from '../database/database.service';
import { users, plans, sessionCompletions, deletionRequests } from '../database/schema';

const BATCH_SIZE = 1000;
const MAX_ROWS = 10000;

@Injectable()
export class CsvExportService {
  private readonly logger = new Logger(CsvExportService.name);

  constructor(private readonly db: DatabaseService) {}

  /**
   * Stream a CSV export of users.
   *
   * Columns: id, email, role, created_at, plans_count, last_active_at
   *
   * @param params  Optional search and role filters
   * @param res     Express Response for streaming
   */
  async streamUsersCsv(
    params: { search?: string; role?: string },
    res: Response,
  ): Promise<void> {
    const today = new Date().toISOString().slice(0, 10);
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename=users_export_${today}.csv`,
    );

    // Write CSV header
    res.write('id,email,role,created_at,plans_count,last_active_at\n');

    let offset = 0;
    let totalWritten = 0;

    while (totalWritten < MAX_ROWS) {
      const batchSize = Math.min(BATCH_SIZE, MAX_ROWS - totalWritten);

      const rows = await this.db.withRetry(async () => {
        const drizzle = this.db.getDb();

        // Build conditions
        const conditions: Array<ReturnType<typeof eq>> = [];
        if (params.search) {
          conditions.push(
            ilike(users.email, `%${params.search}%`) as unknown as ReturnType<typeof eq>,
          );
        }
        if (params.role) {
          conditions.push(eq(users.role, params.role));
        }

        const whereClause = conditions.length > 0
          ? and(...conditions)
          : undefined;

        return drizzle
          .select({
            id: users.id,
            email: users.email,
            role: users.role,
            createdAt: users.createdAt,
            planCount: sql<number>`(
              SELECT COUNT(*)::int FROM ${plans} WHERE ${plans.userId} = ${users.id}
            )`,
            lastActiveAt: sql<Date | null>`(
              SELECT MAX(${sessionCompletions.completedAt})
              FROM ${sessionCompletions}
              WHERE ${sessionCompletions.userId} = ${users.id}
            )`,
          })
          .from(users)
          .where(whereClause)
          .orderBy(desc(users.createdAt))
          .limit(batchSize)
          .offset(offset);
      });

      if (rows.length === 0) break;

      for (const row of rows) {
        const createdAt = row.createdAt instanceof Date
          ? row.createdAt.toISOString()
          : String(row.createdAt ?? '');
        const lastActiveAt = row.lastActiveAt instanceof Date
          ? row.lastActiveAt.toISOString()
          : row.lastActiveAt
            ? String(row.lastActiveAt)
            : '';

        res.write(
          `${csvEscape(row.id)},${csvEscape(row.email)},${csvEscape(row.role)},${csvEscape(createdAt)},${row.planCount ?? 0},${csvEscape(lastActiveAt)}\n`,
        );
      }

      totalWritten += rows.length;
      offset += rows.length;

      if (rows.length < batchSize) break;
    }

    res.end();
  }

  /**
   * Stream a CSV export of deletion requests.
   *
   * Columns: id, email, ip_address, requested_at, processed_at, status
   * NOTE: Email is unmasked for CSV export (admin context).
   *
   * @param params  Optional search and status filters
   * @param res     Express Response for streaming
   */
  async streamDeletionRequestsCsv(
    params: { search?: string; status?: string },
    res: Response,
  ): Promise<void> {
    const today = new Date().toISOString().slice(0, 10);
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename=deletion_requests_export_${today}.csv`,
    );

    // Write CSV header
    res.write('id,email,ip_address,requested_at,processed_at,status\n');

    let offset = 0;
    let totalWritten = 0;

    while (totalWritten < MAX_ROWS) {
      const batchSize = Math.min(BATCH_SIZE, MAX_ROWS - totalWritten);

      const rows = await this.db.withRetry(async () => {
        const drizzle = this.db.getDb();

        const conditions: Array<ReturnType<typeof eq>> = [];
        if (params.search) {
          conditions.push(
            ilike(deletionRequests.email, `%${params.search}%`) as unknown as ReturnType<typeof eq>,
          );
        }
        if (params.status) {
          conditions.push(eq(deletionRequests.status, params.status));
        }

        const whereClause = conditions.length > 0
          ? and(...conditions)
          : undefined;

        return drizzle
          .select()
          .from(deletionRequests)
          .where(whereClause)
          .orderBy(desc(deletionRequests.createdAt))
          .limit(batchSize)
          .offset(offset);
      });

      if (rows.length === 0) break;

      for (const row of rows) {
        const requestedAt = row.requestedAt instanceof Date
          ? row.requestedAt.toISOString()
          : String(row.requestedAt ?? '');
        const processedAt = row.processedAt instanceof Date
          ? row.processedAt.toISOString()
          : row.processedAt
            ? String(row.processedAt)
            : '';

        res.write(
          `${csvEscape(row.id)},${csvEscape(row.email)},${csvEscape(row.ipAddress ?? '')},${csvEscape(requestedAt)},${csvEscape(processedAt)},${csvEscape(row.status)}\n`,
        );
      }

      totalWritten += rows.length;
      offset += rows.length;

      if (rows.length < batchSize) break;
    }

    res.end();
  }
}

/**
 * Escape a CSV field value. Wraps in double quotes if the field contains
 * comma, newline, or double quote characters.
 */
function csvEscape(value: string): string {
  if (value.includes(',') || value.includes('\n') || value.includes('"')) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}
