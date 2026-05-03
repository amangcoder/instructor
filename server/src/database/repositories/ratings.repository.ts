import { Injectable } from '@nestjs/common';
import { and, avg, count, eq, inArray, sql } from 'drizzle-orm';
import { DatabaseService } from '../database.service';
import { planRatings } from '../schema';
import type { PlanRating } from '../schema';

export interface RatingStats {
  averageRating: number | null;
  ratingsCount: number;
}

@Injectable()
export class RatingsRepository {
  constructor(private readonly database: DatabaseService) {}

  async upsertRating(userId: string, planId: string, rating: number): Promise<PlanRating> {
    const db = this.database.getDb();
    const [row] = await this.database.withRetry(() =>
      db
        .insert(planRatings)
        .values({ userId, planId, rating })
        .onConflictDoUpdate({
          target: [planRatings.userId, planRatings.planId],
          set: { rating, updatedAt: sql`now()` },
        })
        .returning(),
    );
    return row;
  }

  async getUserRating(userId: string, planId: string): Promise<PlanRating | null> {
    const db = this.database.getDb();
    const [row] = await this.database.withRetry(() =>
      db
        .select()
        .from(planRatings)
        .where(and(eq(planRatings.userId, userId), eq(planRatings.planId, planId))),
    );
    return row ?? null;
  }

  async deleteRating(userId: string, planId: string): Promise<boolean> {
    const db = this.database.getDb();
    const result = await this.database.withRetry(() =>
      db
        .delete(planRatings)
        .where(and(eq(planRatings.userId, userId), eq(planRatings.planId, planId)))
        .returning({ id: planRatings.id }),
    );
    return result.length > 0;
  }

  async getRatingStats(planId: string): Promise<RatingStats> {
    const db = this.database.getDb();
    const [row] = await this.database.withRetry(() =>
      db
        .select({
          averageRating: avg(planRatings.rating),
          ratingsCount: count(planRatings.id),
        })
        .from(planRatings)
        .where(eq(planRatings.planId, planId)),
    );
    return {
      averageRating: row?.averageRating ? parseFloat(row.averageRating) : null,
      ratingsCount: Number(row?.ratingsCount ?? 0),
    };
  }

  async getBulkRatingStats(planIds: string[]): Promise<Map<string, RatingStats>> {
    if (planIds.length === 0) return new Map();
    const db = this.database.getDb();
    const rows = await this.database.withRetry(() =>
      db
        .select({
          planId: planRatings.planId,
          averageRating: avg(planRatings.rating),
          ratingsCount: count(planRatings.id),
        })
        .from(planRatings)
        .where(inArray(planRatings.planId, planIds))
        .groupBy(planRatings.planId),
    );
    const result = new Map<string, RatingStats>();
    for (const row of rows) {
      result.set(row.planId, {
        averageRating: row.averageRating ? parseFloat(row.averageRating) : null,
        ratingsCount: Number(row.ratingsCount),
      });
    }
    return result;
  }

  async getUserRatingsForPlans(userId: string, planIds: string[]): Promise<Map<string, number>> {
    if (planIds.length === 0) return new Map();
    const db = this.database.getDb();
    const rows = await this.database.withRetry(() =>
      db
        .select({ planId: planRatings.planId, rating: planRatings.rating })
        .from(planRatings)
        .where(and(eq(planRatings.userId, userId), inArray(planRatings.planId, planIds))),
    );
    const result = new Map<string, number>();
    for (const row of rows) {
      result.set(row.planId, row.rating);
    }
    return result;
  }
}
