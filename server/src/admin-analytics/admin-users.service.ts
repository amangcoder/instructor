/**
 * AdminUsersService — paginated list + role management.
 *
 * Queries use this.db.withRetry() + this.db.getDb() in line with the rest of
 * the admin-analytics module, so Neon cold-starts are handled transparently.
 */

import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { and, asc, avg, count, desc, eq, ilike, inArray, or, sql, sum } from 'drizzle-orm';
import { DatabaseService } from '../database/database.service';
import { plans, sessionCompletions, ttsJobs, users, libraryPlans } from '../database/schema';
import type {
  AdminUserRow,
  AdminUsersListResponse,
} from './dto/users-list.dto';
import {
  DEFAULT_PAGE_SIZE,
  MAX_PAGE_SIZE,
  MAX_SEARCH_LENGTH,
  MIN_PAGE,
} from './dto/users-list.dto';

@Injectable()
export class AdminUsersService {
  private readonly logger = new Logger(AdminUsersService.name);

  constructor(private readonly db: DatabaseService) {}

  async listUsers(params: {
    page?: number;
    pageSize?: number;
    search?: string;
    role?: 'user' | 'admin';
  }): Promise<AdminUsersListResponse> {
    const page = Math.max(MIN_PAGE, Math.floor(params.page ?? 1));
    const pageSize = Math.min(
      MAX_PAGE_SIZE,
      Math.max(1, Math.floor(params.pageSize ?? DEFAULT_PAGE_SIZE)),
    );

    const rawSearch = (params.search ?? '').trim().slice(0, MAX_SEARCH_LENGTH);
    // Escape LIKE wildcards so a '%' in user input is treated literally.
    const escaped = rawSearch.replace(/[\\%_]/g, (ch) => `\\${ch}`);
    const searchPattern = escaped ? `%${escaped}%` : null;

    const searchClause = searchPattern
      ? or(
          ilike(users.email, searchPattern),
          ilike(users.name, searchPattern),
          ilike(users.username, searchPattern),
        )
      : undefined;
    const roleClause = params.role ? eq(users.role, params.role) : undefined;
    const whereClause =
      searchClause && roleClause
        ? and(searchClause, roleClause)
        : (searchClause ?? roleClause);

    return this.db.withRetry(async () => {
      const drizzle = this.db.getDb();

      // Precompute per-user aggregates as subqueries to avoid correlated subquery issues
      // with Drizzle's neon-http driver.
      const planCounts = drizzle
        .select({
          userId: plans.userId,
          planCount: count().as('plan_count'),
        })
        .from(plans)
        .groupBy(plans.userId)
        .as('plan_counts');

      const lastActivity = drizzle
        .select({
          userId: sessionCompletions.userId,
          lastActivityAt: sql<Date | null>`MAX(${sessionCompletions.completedAt})`.as('last_activity_at'),
        })
        .from(sessionCompletions)
        .groupBy(sessionCompletions.userId)
        .as('last_activity');

      const [totalResult, rows] = await Promise.all([
        drizzle
          .select({ value: count() })
          .from(users)
          .where(whereClause ?? sql`true`),

        drizzle
          .select({
            id: users.id,
            email: users.email,
            name: users.name,
            username: users.username,
            role: users.role,
            createdAt: users.createdAt,
            planCount: planCounts.planCount,
            lastActivityAt: lastActivity.lastActivityAt,
          })
          .from(users)
          .leftJoin(planCounts, eq(planCounts.userId, users.id))
          .leftJoin(lastActivity, eq(lastActivity.userId, users.id))
          .where(whereClause ?? sql`true`)
          .orderBy(desc(users.createdAt), asc(users.id))
          .limit(pageSize)
          .offset((page - 1) * pageSize),
      ]);

      const total = totalResult[0]?.value ?? 0;

      const mapped: AdminUserRow[] = rows.map((r) => ({
        id: r.id,
        email: r.email,
        name: r.name,
        username: r.username,
        role: r.role === 'admin' ? 'admin' : 'user',
        createdAt:
          r.createdAt instanceof Date
            ? r.createdAt.toISOString()
            : new Date(r.createdAt as unknown as string).toISOString(),
        planCount: Number(r.planCount ?? 0),
        lastActivityAt:
          r.lastActivityAt instanceof Date
            ? r.lastActivityAt.toISOString()
            : r.lastActivityAt
              ? new Date(r.lastActivityAt as unknown as string).toISOString()
              : null,
      }));

      return { users: mapped, total, page, pageSize };
    });
  }

  async getUserDetail(id: string) {
    return this.db.withRetry(async () => {
      const drizzle = this.db.getDb();

      const userRows = await drizzle
        .select({
          id: users.id,
          email: users.email,
          name: users.name,
          username: users.username,
          role: users.role,
          photoUrl: users.photoUrl,
          createdAt: users.createdAt,
        })
        .from(users)
        .where(eq(users.id, id))
        .limit(1);

      if (userRows.length === 0) {
        throw new NotFoundException(`User ${id} not found`);
      }
      const user = userRows[0];

      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

      const [
        planStats,
        sessionStats,
        ttsStats,
        recentPlans,
      ] = await Promise.all([
        drizzle
          .select({
            total: count(),
            active: sql<number>`COUNT(*) FILTER (WHERE ${plans.isActive} = true)::int`,
          })
          .from(plans)
          .where(eq(plans.userId, id)),
        drizzle
          .select({
            total: count(),
            avgDurationMs: avg(sessionCompletions.durationMs),
            totalDurationMs: sum(sessionCompletions.durationMs),
            lastCompletedAt: sql<Date | null>`MAX(${sessionCompletions.completedAt})`,
          })
          .from(sessionCompletions)
          .where(eq(sessionCompletions.userId, id)),
        drizzle
          .select({
            total: count(),
            completed: sql<number>`COUNT(*) FILTER (WHERE ${ttsJobs.status} = 'completed')::int`,
            failed: sql<number>`COUNT(*) FILTER (WHERE ${ttsJobs.status} = 'failed')::int`,
          })
          .from(ttsJobs)
          .innerJoin(plans, eq(ttsJobs.planId, plans.id))
          .where(eq(plans.userId, id)),
        drizzle
          .select({
            id: plans.id,
            name: plans.name,
            isActive: plans.isActive,
            ttsStatus: plans.ttsStatus,
            createdAt: plans.createdAt,
          })
          .from(plans)
          .where(eq(plans.userId, id))
          .orderBy(desc(plans.createdAt))
          .limit(25),
      ]);

      const planIds = recentPlans.map((p) => p.id);
      const planSessionStats = planIds.length > 0
        ? await drizzle
            .select({
              planId: sessionCompletions.planId,
              runCount: count(),
              lastRunAt: sql<Date | null>`MAX(${sessionCompletions.completedAt})`,
            })
            .from(sessionCompletions)
            .where(inArray(sessionCompletions.planId, planIds))
            .groupBy(sessionCompletions.planId)
        : [];
      const sessionMap = new Map(planSessionStats.map((s) => [s.planId, s]));

      const toIso = (v: Date | string | null): string | null => {
        if (v === null || v === undefined) return null;
        if (v instanceof Date) return v.toISOString();
        return new Date(v as unknown as string).toISOString();
      };

      return {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          username: user.username,
          role: user.role === 'admin' ? 'admin' : 'user',
          photoUrl: user.photoUrl,
          createdAt: toIso(user.createdAt)!,
        },
        stats: {
          totalPlans: Number(planStats[0]?.total ?? 0),
          activePlans: Number(planStats[0]?.active ?? 0),
          totalSessions: Number(sessionStats[0]?.total ?? 0),
          avgSessionDurationMs: Math.round(
            Number(sessionStats[0]?.avgDurationMs ?? 0),
          ),
          totalSessionDurationMs: Number(
            sessionStats[0]?.totalDurationMs ?? 0,
          ),
          lastActivityAt: toIso(sessionStats[0]?.lastCompletedAt ?? null),
          ttsJobsTotal: Number(ttsStats[0]?.total ?? 0),
          ttsJobsCompleted: Number(ttsStats[0]?.completed ?? 0),
          ttsJobsFailed: Number(ttsStats[0]?.failed ?? 0),
        },
        plansWithSummary: recentPlans.map((p) => ({
          planId: p.id,
          name: p.name,
          createdAt: toIso(p.createdAt)!,
          ttsStatus: (p.ttsStatus ?? 'pending') as string,
          runCount: Number(sessionMap.get(p.id)?.runCount ?? 0),
          lastRunAt: toIso(sessionMap.get(p.id)?.lastRunAt ?? null),
          isActive: p.isActive ?? false,
        })),
      };
    });
  }

  async getPlanDetail(planId: string) {
    return this.db.withRetry(async () => {
      const drizzle = this.db.getDb();

      const rows = await drizzle
        .select({
          id: plans.id,
          userId: plans.userId,
          name: plans.name,
          planJson: plans.planJson,
          isActive: plans.isActive,
          ttsStatus: plans.ttsStatus,
          ttsTotal: plans.ttsTotal,
          ttsCompleted: plans.ttsCompleted,
          voiceQuality: plans.voiceQuality,
          shareToken: plans.shareToken,
          createdAt: plans.createdAt,
          updatedAt: plans.updatedAt,
        })
        .from(plans)
        .where(eq(plans.id, planId))
        .limit(1);

      if (rows.length === 0) {
        throw new NotFoundException(`Plan ${planId} not found`);
      }

      const p = rows[0];
      const toIso = (v: Date | string | null): string | null => {
        if (!v) return null;
        if (v instanceof Date) return v.toISOString();
        return new Date(v as unknown as string).toISOString();
      };

      return {
        id: p.id,
        userId: p.userId,
        name: p.name,
        planJson: p.planJson,
        isActive: p.isActive,
        ttsStatus: p.ttsStatus,
        ttsTotal: p.ttsTotal,
        ttsCompleted: p.ttsCompleted,
        voiceQuality: p.voiceQuality,
        shareToken: p.shareToken,
        createdAt: toIso(p.createdAt)!,
        updatedAt: toIso(p.updatedAt)!,
      };
    });
  }

  /**
   * TASK-006: Get the last 20 session completions for a user.
   *
   * Plan name uses library plan name when available, falls back to user plan title.
   *
   * @param userId  User UUID
   * @returns       { sessions: Array<{ id, planName, completedAt, durationMs }> }
   */
  async getUserSessions(userId: string) {
    return this.db.withRetry(async () => {
      const drizzle = this.db.getDb();

      const rows = await drizzle.execute(sql`
        SELECT
          sc.id,
          COALESCE(lp.name, p.name, 'Unknown Plan') AS plan_name,
          sc.completed_at,
          sc.duration_ms
        FROM session_completions sc
        LEFT JOIN plans p ON p.id = sc.plan_id
        LEFT JOIN library_plans lp ON lp.id = p.source_library_plan_id
        WHERE sc.user_id = ${userId}
        ORDER BY sc.completed_at DESC
        LIMIT 20
      `);

      const sessions = (rows.rows as Array<Record<string, unknown>>).map((r) => ({
        id: String(r.id ?? ''),
        planName: String(r.plan_name ?? 'Unknown Plan'),
        completedAt: r.completed_at instanceof Date
          ? r.completed_at.toISOString()
          : new Date(r.completed_at as string).toISOString(),
        durationMs: Number(r.duration_ms ?? 0),
      }));

      return { sessions };
    });
  }

  /**
   * TASK-006: Get per-plan summary for a user's plans.
   *
   * For each plan: runCount, lastRunAt, isActive, ttsStatus.
   *
   * @param userId  User UUID
   * @returns       Array of plan summaries
   */
  async getPlansWithSummary(userId: string) {
    return this.db.withRetry(async () => {
      const drizzle = this.db.getDb();
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

      const rows = await drizzle.execute(sql`
        SELECT
          p.id,
          p.name,
          p.is_active,
          p.tts_status,
          p.created_at,
          COUNT(sc.id)::int AS run_count,
          MAX(sc.completed_at) AS last_run_at,
          CASE WHEN MAX(sc.completed_at) >= ${thirtyDaysAgo} THEN true ELSE false END AS has_recent_session
        FROM plans p
        LEFT JOIN session_completions sc ON sc.plan_id = p.id
        WHERE p.user_id = ${userId}
        GROUP BY p.id, p.name, p.is_active, p.tts_status, p.created_at
        ORDER BY p.created_at DESC
        LIMIT 25
      `);

      return (rows.rows as Array<Record<string, unknown>>).map((r) => ({
        id: String(r.id ?? ''),
        name: String(r.name ?? ''),
        isActive: Boolean(r.is_active),
        ttsStatus: String(r.tts_status ?? 'none'),
        runCount: Number(r.run_count ?? 0),
        lastRunAt: r.last_run_at
          ? (r.last_run_at instanceof Date
            ? r.last_run_at.toISOString()
            : new Date(r.last_run_at as string).toISOString())
          : null,
        hasRecentSession: Boolean(r.has_recent_session),
      }));
    });
  }

  async updateRole(
    id: string,
    role: 'user' | 'admin',
  ): Promise<{ id: string; role: 'user' | 'admin' }> {
    return this.db.withRetry(async () => {
      const drizzle = this.db.getDb();
      const result = await drizzle
        .update(users)
        .set({ role })
        .where(eq(users.id, id))
        .returning({ id: users.id, role: users.role });

      if (result.length === 0) {
        throw new NotFoundException(`User ${id} not found`);
      }

      this.logger.log(`Role updated for user ${id} → ${role}`);
      return { id: result[0].id, role: role };
    });
  }
}
