import {
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { desc, eq } from 'drizzle-orm';
import { SeriesRepository } from '../database/repositories/series.repository';
import { DatabaseService, type PlanRecord, type SeriesRecord, type SeriesSubscriptionRecord } from '../database/database.service';
import { plans } from '../database/schema';
import { CreateSeriesDto } from './dto/create-series.dto';
import { CreateSeriesPlanDto } from './dto/create-series-plan.dto';
import { UpdateSeriesDto } from './dto/update-series.dto';

export interface SeriesDetail extends SeriesRecord {
  sessions: PlanRecord[];
}

@Injectable()
export class SeriesService {
  private readonly logger = new Logger(SeriesService.name);

  constructor(
    private readonly repo: SeriesRepository,
    private readonly db: DatabaseService,
  ) {}

  // ── Read ─────────────────────────────────────────────────────────────────

  listPublished(categorySlug?: string): Promise<SeriesRecord[]> {
    return this.repo.listPublishedSeries(categorySlug);
  }

  listAll(): Promise<SeriesRecord[]> {
    return this.repo.listAllSeries();
  }

  async getDetail(id: string): Promise<SeriesDetail> {
    const series = await this.repo.getSeriesById(id);
    if (!series) throw new NotFoundException(`Series ${id} not found`);
    const sessions = await this.repo.listPlansInSeries(id);
    return { ...series, sessions };
  }

  // ── Admin write ──────────────────────────────────────────────────────────

  createSeries(dto: CreateSeriesDto) {
    return this.repo.createSeries({
      name: dto.name,
      description: dto.description ?? null,
      category: dto.category,
      categoryId: dto.categoryId ?? null,
      tags: dto.tags ?? '',
      defaultVoice: dto.defaultVoice,
      locale: dto.locale ?? 'enUS',
      isPublished: dto.isPublished ?? false,
      sortOrder: dto.sortOrder ?? 0,
    });
  }

  async updateSeries(id: string, dto: UpdateSeriesDto): Promise<SeriesRecord> {
    const updated = await this.repo.updateSeries(id, {
      ...dto,
      // Ensure categoryId null is forwarded correctly (DTO omits the field when
      // not sent, but explicit null means "remove the link")
      ...(dto.categoryId !== undefined ? { categoryId: dto.categoryId ?? null } : {}),
    });
    if (!updated) throw new NotFoundException(`Series ${id} not found`);
    return updated;
  }

  async deleteSeries(id: string): Promise<void> {
    let deleted: boolean;
    try {
      deleted = await this.repo.deleteSeries(id);
    } catch (err) {
      // ON DELETE no action on plans.series_id — trying to delete a series that
      // still has plan rows pointing at it raises a FK violation. Translate to
      // a 409 so the admin sees an actionable message.
      const message = err instanceof Error ? err.message : String(err);
      if (/foreign key|violates/i.test(message)) {
        throw new ConflictException(
          `Cannot delete series ${id} — sessions still reference it. Detach plans first.`,
        );
      }
      throw err;
    }
    if (!deleted) throw new NotFoundException(`Series ${id} not found`);
  }

  /**
   * Toggle the is_published flag for a series (REQ-027).
   *
   * Setting isPublished=true makes the series visible to subscribers on the
   * Discover surface. Setting isPublished=false immediately hides it.
   */
  async publishSeries(id: string, isPublished: boolean): Promise<SeriesRecord> {
    const updated = await this.repo.publish(id, isPublished);
    if (!updated) throw new NotFoundException(`Series ${id} not found`);
    this.logger.log(`Series ${id} published=${isPublished}`);
    return updated;
  }

  /**
   * Admin-only: append a new plan (session) to a series.
   *
   * Plans require a non-null user_id at the schema level. For admin-curated
   * sessions we set user_id to the admin who created it but leave
   * owner_user_id NULL (matches the convention used by promoted plans:
   * "NULL for admin-curated plans"). visibility defaults to 'public' so the
   * row is eligible for v_published_plans once is_published flips true.
   *
   * Position is appended to the end (max(position) + 1 within the series) so
   * the new session shows up at the bottom of the SessionsTable. is_published
   * starts false — the admin must publish per session.
   */
  async createSeriesPlan(
    seriesId: string,
    adminUserId: string,
    dto: CreateSeriesPlanDto,
  ): Promise<PlanRecord> {
    const series = await this.repo.getSeriesById(seriesId);
    if (!series) throw new NotFoundException(`Series ${seriesId} not found`);

    const drizzle = this.db.getDb();

    // Find the next position by reading the largest existing position in the
    // series. New series with no sessions get position=0.
    const lastRows = await this.db.withRetry(() =>
      drizzle
        .select({ position: plans.position })
        .from(plans)
        .where(eq(plans.seriesId, seriesId))
        .orderBy(desc(plans.position))
        .limit(1),
    );
    const nextPosition = lastRows.length === 0 ? 0 : lastRows[0].position + 1;

    const now = new Date();
    const inserted = await this.db.withRetry(() =>
      drizzle
        .insert(plans)
        .values({
          userId: adminUserId,
          name: dto.name,
          planJson: dto.planJson,
          seriesId,
          isActive: false,
          ttsStatus: 'none',
          ttsTotal: 0,
          ttsCompleted: 0,
          voiceQuality: dto.voiceQuality ?? 'standard',
          position: nextPosition,
          visibility: 'public',
          ownerUserId: null,
          isPublished: false,
          createdAt: now,
          updatedAt: now,
        })
        .returning({ id: plans.id }),
    );

    const planId = inserted[0].id;
    this.logger.log(
      `Admin plan created in series: planId=${planId} seriesId=${seriesId} position=${nextPosition}`,
    );

    const sessions = await this.repo.listPlansInSeries(seriesId);
    const created = sessions.find((s) => s.planId === planId);
    if (!created) {
      throw new Error(
        `Plan ${planId} inserted but not returned by listPlansInSeries(${seriesId})`,
      );
    }
    return created;
  }

  /**
   * Bulk-update session order within a series (REQ-027).
   *
   * Accepts an array of { planId, position } pairs. Each planId is validated
   * to belong to the series inside the repository layer (plans with a
   * mismatched series_id are silently ignored, not rejected, so a stale
   * payload from a slow UI does not cause a hard error).
   *
   * @throws NotFoundException if the series does not exist.
   */
  async reorderSeriesPlans(
    id: string,
    items: Array<{ planId: string; position: number }>,
  ): Promise<void> {
    // Verify the series exists before trying to reorder.
    const series = await this.repo.getSeriesById(id);
    if (!series) throw new NotFoundException(`Series ${id} not found`);

    await this.repo.reorderPlans(id, items);
    this.logger.log(`Series ${id}: reordered ${items.length} plan position(s)`);
  }

  // ── Subscriptions ────────────────────────────────────────────────────────

  listMySubscriptions(userId: string, activeOnly = false) {
    return this.repo.listUserSubscriptions(userId, activeOnly);
  }

  getMySubscription(userId: string, seriesId: string) {
    return this.repo.getSubscription(userId, seriesId);
  }

  async subscribe(userId: string, seriesId: string): Promise<SeriesSubscriptionRecord> {
    const series = await this.repo.getSeriesById(seriesId);
    if (!series) throw new NotFoundException(`Series ${seriesId} not found`);
    return this.repo.subscribe(userId, seriesId);
  }

  async pause(userId: string, seriesId: string) {
    const sub = await this.repo.setStatus(userId, seriesId, 'paused');
    if (!sub) throw new NotFoundException(`Subscription not found`);
    return sub;
  }

  async resume(userId: string, seriesId: string) {
    const sub = await this.repo.setStatus(userId, seriesId, 'active');
    if (!sub) throw new NotFoundException(`Subscription not found`);
    return sub;
  }

  async cancel(userId: string, seriesId: string) {
    const sub = await this.repo.setStatus(userId, seriesId, 'cancelled');
    if (!sub) throw new NotFoundException(`Subscription not found`);
    return sub;
  }

  async recordProgress(userId: string, seriesId: string, sessionIndex: number) {
    const sub = await this.repo.recordProgress(userId, seriesId, sessionIndex);
    if (!sub) {
      throw new NotFoundException(
        `No active subscription for user on series ${seriesId}`,
      );
    }
    return sub;
  }
}
