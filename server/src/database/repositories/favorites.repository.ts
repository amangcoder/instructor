import { Injectable } from '@nestjs/common';
import { and, asc, eq, inArray } from 'drizzle-orm';
import { DatabaseService } from '../database.service';
import { userFavorites } from '../schema';
import type { UserFavorite } from '../schema';

@Injectable()
export class FavoritesRepository {
  constructor(private readonly database: DatabaseService) {}

  async addFavorite(userId: string, planId: string): Promise<UserFavorite> {
    const db = this.database.getDb();
    const [row] = await this.database.withRetry(() =>
      db
        .insert(userFavorites)
        .values({ userId, planId })
        .onConflictDoNothing()
        .returning(),
    );
    // If onConflictDoNothing fires, re-fetch the existing row
    if (!row) {
      const [existing] = await this.database.withRetry(() =>
        db
          .select()
          .from(userFavorites)
          .where(and(eq(userFavorites.userId, userId), eq(userFavorites.planId, planId))),
      );
      return existing;
    }
    return row;
  }

  async removeFavorite(userId: string, planId: string): Promise<boolean> {
    const db = this.database.getDb();
    const result = await this.database.withRetry(() =>
      db
        .delete(userFavorites)
        .where(and(eq(userFavorites.userId, userId), eq(userFavorites.planId, planId)))
        .returning({ id: userFavorites.id }),
    );
    return result.length > 0;
  }

  async isFavorite(userId: string, planId: string): Promise<boolean> {
    const db = this.database.getDb();
    const [row] = await this.database.withRetry(() =>
      db
        .select({ id: userFavorites.id })
        .from(userFavorites)
        .where(and(eq(userFavorites.userId, userId), eq(userFavorites.planId, planId))),
    );
    return !!row;
  }

  async listFavorites(userId: string): Promise<UserFavorite[]> {
    const db = this.database.getDb();
    return this.database.withRetry(() =>
      db
        .select()
        .from(userFavorites)
        .where(eq(userFavorites.userId, userId))
        .orderBy(asc(userFavorites.createdAt)),
    );
  }

  async getFavoritePlanIds(userId: string): Promise<Set<string>> {
    const db = this.database.getDb();
    const rows = await this.database.withRetry(() =>
      db
        .select({ planId: userFavorites.planId })
        .from(userFavorites)
        .where(eq(userFavorites.userId, userId)),
    );
    return new Set(rows.map((r) => r.planId));
  }

  async getBulkFavoriteStatus(userId: string, planIds: string[]): Promise<Set<string>> {
    if (planIds.length === 0) return new Set();
    const db = this.database.getDb();
    const rows = await this.database.withRetry(() =>
      db
        .select({ planId: userFavorites.planId })
        .from(userFavorites)
        .where(and(eq(userFavorites.userId, userId), inArray(userFavorites.planId, planIds))),
    );
    return new Set(rows.map((r) => r.planId));
  }
}
