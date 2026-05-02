import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Logger,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { SeriesService } from './series.service';
import { CreateSeriesDto } from './dto/create-series.dto';
import { CreateSeriesPlanDto } from './dto/create-series-plan.dto';
import { UpdateSeriesDto } from './dto/update-series.dto';
import { RecordProgressDto } from './dto/record-progress.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRoleGuard } from '../auth/admin-role.guard';

interface JwtUser {
  sub: string;
  email?: string;
  role?: string;
}

/**
 * SeriesController — multi-session "programs" (e.g. "10 Days to Meditate",
 * "Couch to 5K") and per-user subscription / progress tracking.
 *
 * Public:
 *   GET    /api/series                        — list published series
 *   GET    /api/series/:id                    — series detail incl. sessions
 *
 * Authenticated (user):
 *   GET    /api/series/me/subscriptions       — my subscriptions
 *   POST   /api/series/:id/subscribe          — subscribe (idempotent)
 *   POST   /api/series/:id/pause              — pause subscription
 *   POST   /api/series/:id/resume             — resume subscription
 *   POST   /api/series/:id/unsubscribe        — cancel subscription
 *   POST   /api/series/:id/progress           — record session completion
 *
 * Admin:
 *   GET    /api/series/admin/all              — list all (incl. drafts)
 *   POST   /api/series                        — create
 *   PATCH  /api/series/:id                    — update
 *   DELETE /api/series/:id                    — delete
 *
 * Route order matters: literal segments (admin/all, me/subscriptions) come
 * before parameterized :id routes to prevent shadowing.
 */
@Controller('series')
export class SeriesController {
  private readonly logger = new Logger(SeriesController.name);

  constructor(private readonly seriesService: SeriesService) {}

  // ── Public ───────────────────────────────────────────────────────────────

  @Get()
  async list(@Query('categorySlug') categorySlug?: string) {
    this.logger.log(
      `GET /series${categorySlug ? ` — categorySlug=${categorySlug}` : ''}`,
    );
    return this.seriesService.listPublished(categorySlug);
  }

  // ── Admin (must come before /:id to avoid shadowing) ─────────────────────

  @Get('admin/all')
  @UseGuards(JwtAuthGuard, AdminRoleGuard)
  async listAll() {
    this.logger.log('GET /series/admin/all');
    return this.seriesService.listAll();
  }

  // ── User subscriptions (must come before /:id to avoid shadowing) ────────

  @Get('me/subscriptions')
  @UseGuards(JwtAuthGuard)
  async listMySubscriptions(
    @Req() req: Request,
    @Query('activeOnly') activeOnly?: string,
  ) {
    const user = (req as unknown as { user: JwtUser }).user;
    const onlyActive = activeOnly === 'true' || activeOnly === '1';
    this.logger.log(
      `GET /series/me/subscriptions — userId=${user.sub} activeOnly=${onlyActive}`,
    );
    return this.seriesService.listMySubscriptions(user.sub, onlyActive);
  }

  // ── Public detail ────────────────────────────────────────────────────────

  @Get(':id')
  async getDetail(@Param('id') id: string) {
    this.logger.log(`GET /series/${id}`);
    return this.seriesService.getDetail(id);
  }

  // ── User actions on a series ─────────────────────────────────────────────

  @Post(':id/subscribe')
  @UseGuards(JwtAuthGuard)
  async subscribe(@Req() req: Request, @Param('id') id: string) {
    const user = (req as unknown as { user: JwtUser }).user;
    this.logger.log(`POST /series/${id}/subscribe — userId=${user.sub}`);
    return this.seriesService.subscribe(user.sub, id);
  }

  @Post(':id/pause')
  @UseGuards(JwtAuthGuard)
  async pause(@Req() req: Request, @Param('id') id: string) {
    const user = (req as unknown as { user: JwtUser }).user;
    this.logger.log(`POST /series/${id}/pause — userId=${user.sub}`);
    return this.seriesService.pause(user.sub, id);
  }

  @Post(':id/resume')
  @UseGuards(JwtAuthGuard)
  async resume(@Req() req: Request, @Param('id') id: string) {
    const user = (req as unknown as { user: JwtUser }).user;
    this.logger.log(`POST /series/${id}/resume — userId=${user.sub}`);
    return this.seriesService.resume(user.sub, id);
  }

  @Post(':id/unsubscribe')
  @UseGuards(JwtAuthGuard)
  async unsubscribe(@Req() req: Request, @Param('id') id: string) {
    const user = (req as unknown as { user: JwtUser }).user;
    this.logger.log(`POST /series/${id}/unsubscribe — userId=${user.sub}`);
    return this.seriesService.cancel(user.sub, id);
  }

  @Post(':id/progress')
  @UseGuards(JwtAuthGuard)
  async recordProgress(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: RecordProgressDto,
  ) {
    const user = (req as unknown as { user: JwtUser }).user;
    this.logger.log(
      `POST /series/${id}/progress — userId=${user.sub} sessionIndex=${dto.sessionIndex}`,
    );
    return this.seriesService.recordProgress(user.sub, id, dto.sessionIndex);
  }

  // ── Admin write ──────────────────────────────────────────────────────────

  @Post()
  @UseGuards(JwtAuthGuard, AdminRoleGuard)
  async create(@Body() dto: CreateSeriesDto) {
    this.logger.log(`POST /series — name="${dto.name}", category=${dto.category}`);
    return this.seriesService.createSeries(dto);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard, AdminRoleGuard)
  async update(@Param('id') id: string, @Body() dto: UpdateSeriesDto) {
    this.logger.log(`PATCH /series/${id}`);
    return this.seriesService.updateSeries(id, dto);
  }

  @Patch(':id/publish')
  @UseGuards(JwtAuthGuard, AdminRoleGuard)
  async publish(
    @Param('id') id: string,
    @Body() body: { is_published: boolean },
  ) {
    this.logger.log(`PATCH /series/${id}/publish — is_published=${body.is_published}`);
    return this.seriesService.publishSeries(id, body.is_published);
  }

  @Post(':id/plans')
  @UseGuards(JwtAuthGuard, AdminRoleGuard)
  @HttpCode(HttpStatus.CREATED)
  async createPlan(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: CreateSeriesPlanDto,
  ) {
    const user = (req as unknown as { user: JwtUser }).user;
    this.logger.log(
      `POST /series/${id}/plans — name="${dto.name}" adminUserId=${user.sub}`,
    );
    return this.seriesService.createSeriesPlan(id, user.sub, dto);
  }

  @Patch(':id/reorder-plans')
  @UseGuards(JwtAuthGuard, AdminRoleGuard)
  @HttpCode(HttpStatus.OK)
  async reorderPlans(
    @Param('id') id: string,
    @Body() body: Array<{ planId: string; position: number }>,
  ) {
    this.logger.log(`PATCH /series/${id}/reorder-plans — items=${body.length}`);
    await this.seriesService.reorderSeriesPlans(id, body);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, AdminRoleGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  async delete(@Param('id') id: string) {
    this.logger.log(`DELETE /series/${id}`);
    await this.seriesService.deleteSeries(id);
  }
}
