/**
 * AppVersionAdminController — TASK-009
 *
 * Admin endpoints for managing app version configuration.
 *
 * Routes (all require JWT + admin role):
 *   GET   /api/admin/app-version  — read current version config
 *   PATCH /api/admin/app-version  — update version config
 *
 * IMPORTANT: The public mobile check endpoint (GET /api/app-version/check)
 * is NOT modified. It continues reading from env vars only.
 */

import {
  Body,
  Controller,
  Get,
  Patch,
  UseGuards,
  UsePipes,
  ValidationPipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRoleGuard } from '../auth/admin-role.guard';
import {
  AppVersionAdminService,
  AppVersionConfigResponse,
} from './app-version-admin.service';
import { UpdateVersionConfigDto } from './dto/update-version-config.dto';

@Controller('admin/app-version')
@UseGuards(JwtAuthGuard, AdminRoleGuard)
@UsePipes(new ValidationPipe({ transform: true, whitelist: true }))
export class AppVersionAdminController {
  constructor(private readonly service: AppVersionAdminService) {}

  /**
   * GET /api/admin/app-version
   *
   * Read the current app version configuration from the database.
   */
  @Get()
  getVersionConfig(): Promise<AppVersionConfigResponse> {
    return this.service.getVersionConfig();
  }

  /**
   * PATCH /api/admin/app-version
   *
   * Update the app version configuration.
   * Only provided fields are updated; others retain current values.
   *
   * Validates that forceVersion >= minVersion for each platform.
   * Returns HTTP 422 if validation fails.
   */
  @Patch()
  updateVersionConfig(
    @Body() dto: UpdateVersionConfigDto,
  ): Promise<AppVersionConfigResponse> {
    return this.service.updateVersionConfig(dto);
  }
}
