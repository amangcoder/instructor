import {
  Controller,
  Post,
  Delete,
  Get,
  Param,
  Req,
  UseGuards,
  HttpCode,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import type { Request } from 'express';
import { FavoritesService } from './favorites.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { JwtPayload } from '../auth/auth.service';

/**
 * FavoritesController — user favorites list endpoints (all require JWT).
 *
 * GET    /api/favorites           — list all favorite plan IDs for the current user
 * POST   /api/favorites/:planId   — add a plan to favorites
 * DELETE /api/favorites/:planId   — remove a plan from favorites
 * POST   /api/favorites/:planId/toggle — toggle favorite status (add if absent, remove if present)
 */
@Controller('favorites')
@UseGuards(JwtAuthGuard)
export class FavoritesController {
  private readonly logger = new Logger(FavoritesController.name);

  constructor(private readonly favoritesService: FavoritesService) {}

  @Get()
  async listFavorites(@Req() req: Request) {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`GET /favorites — userId=${user.sub}`);
    return this.favoritesService.listFavorites(user.sub);
  }

  @Post(':planId')
  @HttpCode(HttpStatus.OK)
  async addFavorite(@Req() req: Request, @Param('planId') planId: string) {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`POST /favorites/${planId} — userId=${user.sub}`);
    return this.favoritesService.addFavorite(user.sub, planId);
  }

  @Delete(':planId')
  @HttpCode(HttpStatus.OK)
  async removeFavorite(@Req() req: Request, @Param('planId') planId: string) {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`DELETE /favorites/${planId} — userId=${user.sub}`);
    return this.favoritesService.removeFavorite(user.sub, planId);
  }

  @Post(':planId/toggle')
  @HttpCode(HttpStatus.OK)
  async toggleFavorite(@Req() req: Request, @Param('planId') planId: string) {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`POST /favorites/${planId}/toggle — userId=${user.sub}`);
    return this.favoritesService.toggleFavorite(user.sub, planId);
  }
}
