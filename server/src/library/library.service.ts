import { Injectable, Logger } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { CreateLibraryPlanDto } from './dto/create-library-plan.dto';

@Injectable()
export class LibraryService {
  private readonly logger = new Logger(LibraryService.name);

  constructor(private readonly db: DatabaseService) {}

  /**
   * List published library plans with optional filtering and pagination.
   */
  async listPlans(page: number, category?: string, search?: string) {
    this.logger.log(
      `listPlans — page=${page}, category=${category ?? 'all'}, search=${search ?? 'none'}`,
    );
    return this.db.listLibraryPlans(page, category, search);
  }

  /**
   * Fetch a single library plan by ID (public access).
   * Returns null if not found.
   */
  async getPlanById(id: string) {
    this.logger.log(`getPlanById — id=${id}`);
    return this.db.getLibraryPlanById(id);
  }

  /**
   * Create a new library plan (admin only).
   */
  async createPlan(dto: CreateLibraryPlanDto) {
    this.logger.log(`createPlan — name="${dto.name}", category=${dto.category}`);
    return this.db.createLibraryPlan({
      name: dto.name,
      description: dto.description,
      category: dto.category,
      tags: dto.tags ?? '',
      defaultVoice: dto.defaultVoice,
      planJson: dto.planJson,
      locale: dto.locale ?? 'enUS',
      isPublished: dto.isPublished ?? false,
      sortOrder: dto.sortOrder ?? 0,
    });
  }
}
