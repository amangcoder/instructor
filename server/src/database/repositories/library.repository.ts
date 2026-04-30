/**
 * LibraryRepository — domain repository for library plan operations.
 *
 * Delegates to the underlying DatabaseService so existing callers are unaffected
 * during the incremental migration from the monolithic DatabaseService god-object
 * to focused, single-responsibility repositories.
 */

import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../database.service';

@Injectable()
export class LibraryRepository {
  constructor(private readonly database: DatabaseService) {}

  async listAllLibraryPlans() {
    return this.database.listAllLibraryPlans();
  }

  async listLibraryPlans(page: number, category?: string, search?: string) {
    return this.database.listLibraryPlans(page, category, search);
  }

  async getLibraryPlanById(id: string) {
    return this.database.getLibraryPlanById(id);
  }

  async createLibraryPlan(data: {
    name: string;
    description: string;
    category: string;
    tags: string;
    defaultVoice: string;
    planJson: string;
    locale: string;
    isPublished: boolean;
    sortOrder: number;
  }) {
    return this.database.createLibraryPlan(data);
  }

  async updateLibraryPlan(id: string, data: Record<string, unknown>) {
    return this.database.updateLibraryPlan(id, data);
  }

  async deleteLibraryPlan(id: string): Promise<boolean> {
    return this.database.deleteLibraryPlan(id);
  }
}
