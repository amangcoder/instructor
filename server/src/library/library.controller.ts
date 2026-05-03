import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  Req,
  Logger,
  NotFoundException,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { LibraryService } from './library.service';
import { CreateLibraryPlanDto } from './dto/create-library-plan.dto';
import { UpdateLibraryPlanDto } from './dto/update-library-plan.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRoleGuard } from '../auth/admin-role.guard';
import type { JwtPayload } from '../auth/auth.service';

/**
 * LibraryController — routes for the curated global plan library.
 *
 * Public endpoints (no auth required):
 *   GET    /api/library/plans            — list published plans
 *   GET    /api/library/plans/:id        — get plan detail
 *
 * Authenticated user endpoints (JWT required):
 *   POST   /api/library/links            — link a library plan to My Plans (idempotent)
 *   DELETE /api/library/links/:linkId    — remove a library link from My Plans
 *
 * Admin-only endpoints (JWT + admin role required):
 *   GET    /api/library/plans/all        — list all plans including drafts
 *   POST   /api/library/plans            — create a new library plan
 *   PATCH  /api/library/plans/:id        — update a library plan
 *   DELETE /api/library/plans/:id        — delete a library plan
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
   * GET /api/library/plans/all
   * Admin only: list all plans regardless of published status.
   * Must be defined before plans/:id to avoid route shadowing.
   */
  @Get('plans/all')
  @UseGuards(JwtAuthGuard, AdminRoleGuard)
  async getAllPlans() {
    this.logger.log('GET /library/plans/all');
    return this.libraryService.getAllPlans();
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
   * Admin only: create a new library plan.
   */
  @Post('plans')
  @UseGuards(JwtAuthGuard, AdminRoleGuard)
  async createPlan(@Body() dto: CreateLibraryPlanDto) {
    this.logger.log(`POST /library/plans — name="${dto.name}", category=${dto.category}`);
    return this.libraryService.createPlan(dto);
  }

  /**
   * PATCH /api/library/plans/:id
   * Admin only: update fields on an existing library plan.
   */
  @Patch('plans/:id')
  @UseGuards(JwtAuthGuard, AdminRoleGuard)
  async updatePlan(@Param('id') id: string, @Body() dto: UpdateLibraryPlanDto) {
    this.logger.log(`PATCH /library/plans/${id}`);
    const plan = await this.libraryService.updatePlan(id, dto);
    if (!plan) {
      throw new NotFoundException(`Library plan ${id} not found`);
    }
    return plan;
  }

  /**
   * DELETE /api/library/plans/:id
   * Admin only: permanently delete a library plan.
   */
  @Delete('plans/:id')
  @UseGuards(JwtAuthGuard, AdminRoleGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  async deletePlan(@Param('id') id: string) {
    this.logger.log(`DELETE /library/plans/${id}`);
    const deleted = await this.libraryService.deletePlan(id);
    if (!deleted) {
      throw new NotFoundException(`Library plan ${id} not found`);
    }
  }

  // ── User library links ────────────────────────────────────────────────────

  /**
   * POST /api/library/links
   * Authenticated: link a library plan to the user's My Plans collection.
   * Idempotent — returns the link id whether new or already existed.
   * Body: { libraryPlanId: string }
   */
  @Post('links')
  @UseGuards(JwtAuthGuard)
  async addLink(
    @Req() req: Request,
    @Body() body: { libraryPlanId: string },
  ): Promise<{ linkId: string }> {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`POST /library/links — userId=${user.sub}, libraryPlanId=${body.libraryPlanId}`);
    return this.libraryService.addLink(user.sub, body.libraryPlanId);
  }

  /**
   * DELETE /api/library/links/:linkId
   * Authenticated: remove a library link from the user's My Plans collection.
   */
  @Delete('links/:linkId')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  async removeLink(@Req() req: Request, @Param('linkId') linkId: string) {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`DELETE /library/links/${linkId} — userId=${user.sub}`);
    await this.libraryService.removeLink(user.sub, linkId);
  }
}
