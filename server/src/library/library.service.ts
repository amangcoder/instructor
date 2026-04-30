import { Injectable, Logger, Optional, Inject } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { LibraryRepository } from '../database/repositories/library.repository';
import { CreateLibraryPlanDto } from './dto/create-library-plan.dto';
import { UpdateLibraryPlanDto } from './dto/update-library-plan.dto';

@Injectable()
export class LibraryService {
  private readonly logger = new Logger(LibraryService.name);
  private readonly repo: LibraryRepository | DatabaseService;

  constructor(
    private readonly db: DatabaseService,
    @Optional() @Inject(LibraryRepository) libraryRepo?: LibraryRepository,
  ) {
    this.repo = libraryRepo ?? db;
  }

  /**
   * List all library plans regardless of publish status (admin only).
   */
  async getAllPlans() {
    this.logger.log('getAllPlans — admin');
    return this.repo.listAllLibraryPlans();
  }

  /**
   * List published library plans with optional filtering and pagination.
   */
  async listPlans(page: number, category?: string, search?: string) {
    this.logger.log(
      `listPlans — page=${page}, category=${category ?? 'all'}, search=${search ?? 'none'}`,
    );
    return this.repo.listLibraryPlans(page, category, search);
  }

  /**
   * Fetch a single library plan by ID (public access).
   * Returns null if not found.
   */
  async getPlanById(id: string) {
    this.logger.log(`getPlanById — id=${id}`);
    return this.repo.getLibraryPlanById(id);
  }

  /**
   * Create a new library plan (admin only).
   */
  async createPlan(dto: CreateLibraryPlanDto) {
    this.logger.log(`createPlan — name="${dto.name}", category=${dto.category}`);
    return this.repo.createLibraryPlan({
      name: dto.name,
      description: dto.description ?? '',
      category: dto.category,
      tags: dto.tags ?? '',
      defaultVoice: dto.defaultVoice,
      planJson: dto.planJson,
      locale: dto.locale ?? 'enUS',
      isPublished: dto.isPublished ?? false,
      sortOrder: dto.sortOrder ?? 0,
    });
  }

  /**
   * Update an existing library plan (admin only).
   * Returns null if not found.
   */
  async updatePlan(id: string, dto: UpdateLibraryPlanDto) {
    this.logger.log(`updatePlan — id=${id}`);
    return this.repo.updateLibraryPlan(id, dto);
  }

  /**
   * Delete a library plan (admin only).
   * Returns true if deleted, false if not found.
   */
  async deletePlan(id: string): Promise<boolean> {
    this.logger.log(`deletePlan — id=${id}`);
    return this.repo.deleteLibraryPlan(id);
  }
}
