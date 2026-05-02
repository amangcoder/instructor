/**
 * AdminRepository — domain repository for admin-level operations
 * such as deletion requests and plan requests.
 *
 * Delegates to the underlying DatabaseService so existing callers are unaffected
 * during the incremental migration from the monolithic DatabaseService god-object
 * to focused, single-responsibility repositories.
 */

import { Injectable } from '@nestjs/common';
import { and, count, desc, eq, ilike } from 'drizzle-orm';
import { DatabaseService } from '../database.service';
import { planRequests, type PlanRequest } from '../schema';

@Injectable()
export class AdminRepository {
  constructor(private readonly database: DatabaseService) {}

  /** Whether the database is running in noop mode (DATABASE_URL unset). */
  get noop(): boolean {
    return this.database.noop;
  }

  async insertDeletionRequest(data: {
    id: string;
    email: string;
    scope: string;
    reason: string | null;
    requestedAt: Date;
    createdAt: Date;
  }): Promise<void> {
    return this.database.insertDeletionRequest(data);
  }

  // ── Plan requests ─────────────────────────────────────────────────────────

  /**
   * Persist a "Request a Plan" submission. Returns silently in noop mode so
   * tests and bootstrap flows without a live DB don't fail.
   */
  async insertPlanRequest(data: {
    id: string;
    userId: string | null;
    email: string;
    title: string;
    description: string;
    category: string | null;
    createdAt: Date;
  }): Promise<void> {
    if (this.noop) return;
    const drizzle = this.database.getDb();
    await drizzle.insert(planRequests).values(data);
  }

  /** List plan requests for the admin dashboard, paginated and search-filtered. */
  async listPlanRequests(params: {
    page: number;
    pageSize: number;
    search?: string;
    status?: string;
  }): Promise<{ rows: PlanRequest[]; total: number }> {
    if (this.noop) return { rows: [], total: 0 };

    const drizzle = this.database.getDb();
    const offset = (params.page - 1) * params.pageSize;

    const conditions: Parameters<typeof and>[0][] = [];
    if (params.search) {
      conditions.push(ilike(planRequests.email, `%${params.search}%`));
    }
    if (params.status) {
      conditions.push(eq(planRequests.status, params.status));
    }
    const where = conditions.length > 0 ? and(...conditions) : undefined;

    const totalResult = await drizzle
      .select({ value: count() })
      .from(planRequests)
      .where(where);

    const rows = await drizzle
      .select()
      .from(planRequests)
      .where(where)
      .orderBy(desc(planRequests.createdAt))
      .limit(params.pageSize)
      .offset(offset);

    return { rows, total: totalResult[0]?.value ?? 0 };
  }

  /** Mark a plan request as processed. Returns the updated row, or null. */
  async markPlanRequestProcessed(id: string): Promise<PlanRequest | null> {
    if (this.noop) return null;
    const drizzle = this.database.getDb();
    const rows = await drizzle
      .update(planRequests)
      .set({ status: 'processed', processedAt: new Date() })
      .where(and(eq(planRequests.id, id), eq(planRequests.status, 'pending')))
      .returning();
    return rows[0] ?? null;
  }

  /** Pending count — used by the admin sidebar badge. */
  async getPendingPlanRequestCount(): Promise<number> {
    if (this.noop) return 0;
    const drizzle = this.database.getDb();
    const result = await drizzle
      .select({ value: count() })
      .from(planRequests)
      .where(eq(planRequests.status, 'pending'));
    return result[0]?.value ?? 0;
  }
}
