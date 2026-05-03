import { Injectable, Logger } from '@nestjs/common';
import { RatingsRepository } from '../database/repositories/ratings.repository';
import type { RatingStats } from '../database/repositories/ratings.repository';

@Injectable()
export class RatingsService {
  private readonly logger = new Logger(RatingsService.name);

  constructor(private readonly repo: RatingsRepository) {}

  async ratePlan(userId: string, planId: string, rating: number) {
    this.logger.log(`ratePlan — userId=${userId}, planId=${planId}, rating=${rating}`);
    const row = await this.repo.upsertRating(userId, planId, rating);
    const stats = await this.repo.getRatingStats(planId);
    return { ...stats, userRating: row.rating };
  }

  async deleteRating(userId: string, planId: string): Promise<{ deleted: boolean }> {
    this.logger.log(`deleteRating — userId=${userId}, planId=${planId}`);
    const deleted = await this.repo.deleteRating(userId, planId);
    return { deleted };
  }

  async getPlanRatingStats(planId: string): Promise<RatingStats> {
    return this.repo.getRatingStats(planId);
  }

  async getPlanRatingForUser(
    userId: string,
    planId: string,
  ): Promise<{ userRating: number | null } & RatingStats> {
    const [userRow, stats] = await Promise.all([
      this.repo.getUserRating(userId, planId),
      this.repo.getRatingStats(planId),
    ]);
    return { ...stats, userRating: userRow?.rating ?? null };
  }
}
