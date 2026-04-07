import {
  Controller,
  Get,
  Post,
  Body,
  Req,
  UseGuards,
  Logger,
  HttpCode,
} from '@nestjs/common';
import type { Request } from 'express';
import { IsNumber, IsOptional } from 'class-validator';
import { SyncService } from './sync.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { JwtPayload } from '../auth/auth.service';

class ConfirmSyncDto {
  @IsOptional()
  @IsNumber()
  sizeBytes?: number;
}

@Controller('sync')
@UseGuards(JwtAuthGuard)
export class SyncController {
  private readonly logger = new Logger(SyncController.name);

  constructor(private readonly syncService: SyncService) {}

  /**
   * POST /api/sync/upload
   * Returns a pre-signed S3 PUT URL for the authenticated user to upload
   * their local SQLite database directly to S3.
   */
  @Post('upload')
  @HttpCode(200)
  async getUploadUrl(@Req() req: Request) {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`POST /sync/upload — userId=${user.sub}`);
    return this.syncService.getUploadUrl(user.sub);
  }

  /**
   * GET /api/sync/download
   * Returns a pre-signed S3 GET URL for the authenticated user to download
   * their most recent database backup.
   */
  @Get('download')
  async getDownloadUrl(@Req() req: Request) {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`GET /sync/download — userId=${user.sub}`);
    return this.syncService.getDownloadUrl(user.sub);
  }

  /**
   * GET /api/sync/status
   * Returns the last sync timestamp and database size for the authenticated user.
   */
  @Get('status')
  async getSyncStatus(@Req() req: Request) {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`GET /sync/status — userId=${user.sub}`);
    return this.syncService.getSyncStatus(user.sub);
  }

  /**
   * POST /api/sync/confirm
   * Called by the Flutter client after successfully uploading to S3.
   * Updates the server-side sync metadata (lastSyncAt, sizeBytes).
   */
  @Post('confirm')
  @HttpCode(200)
  async confirmSync(
    @Req() req: Request,
    @Body() body: ConfirmSyncDto,
  ) {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`POST /sync/confirm — userId=${user.sub}, sizeBytes=${body.sizeBytes}`);
    await this.syncService.confirmSync(user.sub, body.sizeBytes);
    return { ok: true };
  }
}
