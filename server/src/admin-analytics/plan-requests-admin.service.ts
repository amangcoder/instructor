/**
 * PlanRequestsAdminService — admin-facing read/write access to the
 * plan_requests table. Wraps AdminRepository with pagination clamps and
 * coerces rows into a stable DTO shape for the dashboard.
 */

import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { AdminRepository } from '../database/repositories/admin.repository';

export interface PlanRequestRow {
  id: string;
  email: string;
  title: string;
  description: string;
  category: string | null;
  status: 'pending' | 'processed' | 'rejected';
  processedAt: string | null;
  createdAt: string;
}

export interface PlanRequestListResponse {
  data: PlanRequestRow[];
  total: number;
  page: number;
  pageSize: number;
}

const MIN_PAGE = 1;
const MAX_PAGE_SIZE = 100;
const DEFAULT_PAGE_SIZE = 20;

@Injectable()
export class PlanRequestsAdminService {
  private readonly logger = new Logger(PlanRequestsAdminService.name);

  constructor(private readonly repo: AdminRepository) {}

  async list(params: {
    page?: number;
    pageSize?: number;
    search?: string;
    status?: string;
  }): Promise<PlanRequestListResponse> {
    const page = Math.max(MIN_PAGE, Math.floor(params.page ?? 1));
    const pageSize = Math.min(
      MAX_PAGE_SIZE,
      Math.max(1, Math.floor(params.pageSize ?? DEFAULT_PAGE_SIZE)),
    );

    const { rows, total } = await this.repo.listPlanRequests({
      page,
      pageSize,
      search: params.search,
      status: params.status,
    });

    return {
      data: rows.map((row) => ({
        id: row.id,
        email: row.email,
        title: row.title,
        description: row.description,
        category: row.category ?? null,
        status: row.status as PlanRequestRow['status'],
        processedAt: row.processedAt ? row.processedAt.toISOString() : null,
        createdAt: row.createdAt.toISOString(),
      })),
      total,
      page,
      pageSize,
    };
  }

  async markProcessed(id: string): Promise<PlanRequestRow> {
    const updated = await this.repo.markPlanRequestProcessed(id);
    if (!updated) {
      throw new NotFoundException(
        `Plan request ${id} not found or already processed`,
      );
    }
    return {
      id: updated.id,
      email: updated.email,
      title: updated.title,
      description: updated.description,
      category: updated.category ?? null,
      status: updated.status as PlanRequestRow['status'],
      processedAt: updated.processedAt
        ? updated.processedAt.toISOString()
        : null,
      createdAt: updated.createdAt.toISOString(),
    };
  }

  async getPendingCount(): Promise<{ count: number }> {
    return { count: await this.repo.getPendingPlanRequestCount() };
  }
}
