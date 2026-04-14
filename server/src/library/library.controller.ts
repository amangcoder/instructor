import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  Headers,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { timingSafeEqual } from 'crypto';
import { LibraryService } from './library.service';
import { CreateLibraryPlanDto } from './dto/create-library-plan.dto';

/**
 * LibraryController — routes for the curated global plan library.
 *
 * Public endpoints (no auth required):
 *   GET  /api/library/plans            — list published plans (REQ-003)
 *   GET  /api/library/plans/:id        — get plan detail (REQ-004)
 *
 * Admin-only endpoint (API key required):
 *   POST /api/library/plans            — create a new library plan (REQ-005)
 */
@Controller('library')
export class LibraryController {
  private readonly logger = new Logger(LibraryController.name);

  constructor(private readonly libraryService: LibraryService) {}

  /**
   * GET /api/library/plans
   * Public: list published library plans with optional pagination and filtering.
   * Query params: page (default 1), category, search
   */
  @Get('plans')
  async listPlans(
    @Query('page') page?: string,
    @Query('category') category?: string,
    @Query('search') search?: string,
  ) {
    const pageNum = Math.max(1, parseInt(page ?? '1', 10) || 1);
    this.logger.log(
      `GET /library/plans — page=${pageNum}, category=${category ?? 'all'}, search=${search ?? 'none'}`,
    );
    return this.libraryService.listPlans(pageNum, category, search);
  }

  /**
   * GET /api/library/plans/:id
   * Public: retrieve full details of a single library plan.
   */
  @Get('plans/:id')
  async getPlanById(@Param('id') id: string) {
    this.logger.log(`GET /library/plans/${id}`);
    const plan = await this.libraryService.getPlanById(id);
    if (!plan) {
      throw new NotFoundException(`Library plan ${id} not found`);
    }
    return plan;
  }

  /**
   * POST /api/library/plans
   * Admin only (x-api-key required): create a new library plan.
   */
  @Post('plans')
  async createPlan(
    @Body() dto: CreateLibraryPlanDto,
    @Headers('x-api-key') apiKey: string | undefined,
  ) {
    this.checkAdminKey(apiKey);
    this.logger.log(`POST /library/plans — name="${dto.name}", category=${dto.category}`);
    return this.libraryService.createPlan(dto);
  }

  // ── Auth helper ──────────────────────────────────────────────────────────

  private checkAdminKey(apiKey: string | undefined): void {
    const serverKey = process.env.API_KEY;
    if (!serverKey) {
      throw new UnauthorizedException('Admin API key not configured');
    }
    if (!apiKey) {
      throw new UnauthorizedException('x-api-key header is required');
    }
    try {
      const keyBuf = Buffer.from(apiKey);
      const serverBuf = Buffer.from(serverKey);
      if (keyBuf.length === serverBuf.length && timingSafeEqual(keyBuf, serverBuf)) {
        return;
      }
    } catch {
      // Fall through to reject
    }
    throw new UnauthorizedException('Invalid API key');
  }
}
