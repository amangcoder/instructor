/**
 * AdminUsersService — paginated list + role management.
 *
 * Queries use this.db.withRetry() with AdminAnalyticsRepository for all data
 * access, so Neon cold-starts are handled transparently.
 */

import { Injectable, Logger, NotFoundException, Inject } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { AdminAnalyticsRepository } from '../database/repositories/analytics.repository';
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

  constructor(
    private readonly db: DatabaseService,
    @Inject(AdminAnalyticsRepository) private readonly repo: AdminAnalyticsRepository,
  ) {}

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

    return this.db.withRetry(async () => {
      let total: number;
      let rows: Array<Record<string, unknown>>;

      const result = await this.repo.listAdminUsers({
        page,
        pageSize,
        searchPattern: searchPattern,
        role: params.role,
      });
      rows = result.rows;
      total = result.total;

      const mapped: AdminUserRow[] = rows.map((r) => ({
        id: r.id as string,
        email: r.email as string,
        name: r.name as string | null,
        username: r.username as string | null,
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
      let user: Record<string, unknown> | null;

      user = await this.repo.getAdminUserById(id) as Record<string, unknown> | null;

      if (!user) {
        throw new NotFoundException(`User ${id} not found`);
      }

      let planStats: any, sessionStats: any, ttsStats: any, recentPlans: any[];

      const stats = await this.repo.getUserDetailStats(id);
      planStats = stats.planStats;
      sessionStats = stats.sessionStats;
      ttsStats = stats.ttsStats;
      recentPlans = stats.recentPlans;

      const planIds = recentPlans.map((p: any) => p.id);
      let planSessionStats: any[];
      planSessionStats = await this.repo.getPlanSessionStats(planIds);
      const sessionMap = new Map(planSessionStats.map((s) => [s.planId, s]));

      const toIso = (v: unknown): string | null => {
        if (v === null || v === undefined) return null;
        if (v instanceof Date) return v.toISOString();
        return new Date(v as string).toISOString();
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
      let p: Record<string, unknown> | null;

      p = await this.repo.getAdminPlanDetail(planId) as Record<string, unknown> | null;

      if (!p) {
        throw new NotFoundException(`Plan ${planId} not found`);
      }
      const toIso = (v: unknown): string | null => {
        if (!v) return null;
        if (v instanceof Date) return v.toISOString();
        return new Date(v as string).toISOString();
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
      let rawRows: Array<Record<string, unknown>>;

      rawRows = await this.repo.getAdminUserSessions(userId, 20);

      const sessions = rawRows.map((r) => ({
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
      let rawRows: Array<Record<string, unknown>>;

      rawRows = await this.repo.getAdminPlansWithSummary(userId, 25);

      return rawRows.map((r) => ({
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
      let result: Array<{ id: string; role: string | null }>;

      result = await this.repo.updateAdminUserRole(id, role);

      if (result.length === 0) {
        throw new NotFoundException(`User ${id} not found`);
      }

      this.logger.log(`Role updated for user ${id} → ${role}`);
      return { id: result[0].id, role: role };
    });
  }
}
