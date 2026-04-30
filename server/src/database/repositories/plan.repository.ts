/**
 * PlanRepository — domain repository for user plan operations.
 *
 * Delegates to the underlying DatabaseService so existing callers are unaffected
 * during the incremental migration from the monolithic DatabaseService god-object
 * to focused, single-responsibility repositories.
 */

import { Injectable } from '@nestjs/common';
import {
  DatabaseService,
  PlanRecord,
  PlanSummaryRecord,
  SavePlanResult,
} from '../database.service';

@Injectable()
export class PlanRepository {
  constructor(private readonly database: DatabaseService) {}

  async savePlan(
    userId: string,
    name: string,
    planJson: string,
    planId?: string,
  ): Promise<SavePlanResult> {
    return this.database.savePlan(userId, name, planJson, planId);
  }

  async getPlanById(planId: string, userId: string): Promise<PlanRecord | null> {
    return this.database.getPlanById(planId, userId);
  }

  async deletePlan(planId: string, userId: string): Promise<void> {
    return this.database.deletePlan(planId, userId);
  }

  async activatePlan(planId: string, userId: string, voiceQuality: string): Promise<void> {
    return this.database.activatePlan(planId, userId, voiceQuality);
  }

  async setTtsStatus(
    planId: string,
    status: string,
    total?: number,
    completed?: number,
  ): Promise<void> {
    return this.database.setTtsStatus(planId, status, total, completed);
  }

  async incrementTtsCompleted(planId: string): Promise<void> {
    return this.database.incrementTtsCompleted(planId);
  }

  async listPlans(userId: string): Promise<PlanSummaryRecord[]> {
    return this.database.listPlans(userId);
  }

  async copyLibraryPlanToUser(
    libraryPlanId: string,
    userId: string,
    voiceQuality: string,
  ): Promise<{ planId: string }> {
    return this.database.copyLibraryPlanToUser(libraryPlanId, userId, voiceQuality);
  }

  // ── Sharing operations ──────────────────────────────────────────────────

  async updatePlanShareToken(planId: string, shareToken: string): Promise<void> {
    return this.database.updatePlanShareToken(planId, shareToken);
  }

  async revokePlanShareToken(userId: string, planId: string): Promise<boolean> {
    return this.database.revokePlanShareToken(userId, planId);
  }

  async getSharedPlan(shareToken: string) {
    return this.database.getSharedPlan(shareToken);
  }
}
