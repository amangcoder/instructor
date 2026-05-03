import { Injectable, Logger } from '@nestjs/common';
import { FavoritesRepository } from '../database/repositories/favorites.repository';

@Injectable()
export class FavoritesService {
  private readonly logger = new Logger(FavoritesService.name);

  constructor(private readonly repo: FavoritesRepository) {}

  async addFavorite(userId: string, planId: string) {
    this.logger.log(`addFavorite — userId=${userId}, planId=${planId}`);
    await this.repo.addFavorite(userId, planId);
    return { planId, isFavorite: true };
  }

  async removeFavorite(userId: string, planId: string) {
    this.logger.log(`removeFavorite — userId=${userId}, planId=${planId}`);
    await this.repo.removeFavorite(userId, planId);
    return { planId, isFavorite: false };
  }

  async toggleFavorite(userId: string, planId: string) {
    const already = await this.repo.isFavorite(userId, planId);
    if (already) {
      await this.repo.removeFavorite(userId, planId);
      return { planId, isFavorite: false };
    }
    await this.repo.addFavorite(userId, planId);
    return { planId, isFavorite: true };
  }

  async listFavorites(userId: string) {
    this.logger.log(`listFavorites — userId=${userId}`);
    const rows = await this.repo.listFavorites(userId);
    return { planIds: rows.map((r) => r.planId) };
  }

  async isFavorite(userId: string, planId: string) {
    const favorite = await this.repo.isFavorite(userId, planId);
    return { planId, isFavorite: favorite };
  }
}
