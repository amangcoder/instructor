/**
 * AppVersionAdminService — TASK-009
 *
 * Provides admin-facing read/write access to the app_version_config DB table.
 *
 * IMPORTANT: This service reads/writes the DB exclusively.
 * AppVersionService.check() is NOT modified — the public mobile check endpoint
 * continues reading env vars only for blast-radius protection (DB outage should
 * not block all mobile app launches).
 *
 * Uses compareVersions() from AppVersionService to validate that force version
 * is >= min version (rejects with HTTP 422 if invalid).
 */

import {
  Injectable,
  Logger,
  NotFoundException,
  UnprocessableEntityException,
  Inject,
} from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { AdminAnalyticsRepository } from '../database/repositories/analytics.repository';
import { compareVersions } from './app-version.service';
import type { UpdateVersionConfigDto } from './dto/update-version-config.dto';

export interface AppVersionConfigResponse {
  ios: {
    minVersion: string | null;
    forceUpdateVersion: string | null;
  };
  android: {
    minVersion: string | null;
    forceUpdateVersion: string | null;
  };
  enabled: boolean;
}

@Injectable()
export class AppVersionAdminService {
  private readonly logger = new Logger(AppVersionAdminService.name);
  constructor(
    private readonly db: DatabaseService,
    @Inject(AdminAnalyticsRepository) private readonly repo: AdminAnalyticsRepository,
  ) {}

  /**
   * Read the current version configuration from the DB.
   *
   * @returns AppVersionConfigResponse
   * @throws NotFoundException if no config row exists
   */
  async getVersionConfig(): Promise<AppVersionConfigResponse> {
    return this.db.withRetry(async () => {
      let config: any;

      config = await this.repo.getAppVersionConfig();

      if (!config) {
        throw new NotFoundException('App version config not found');
      }

      return {
        ios: {
          minVersion: config.iosMinVersion,
          forceUpdateVersion: config.iosForceVersion,
        },
        android: {
          minVersion: config.androidMinVersion,
          forceUpdateVersion: config.androidForceVersion,
        },
        enabled: config.forceUpdateEnabled,
      };
    });
  }

  /**
   * Update the version configuration in the DB.
   *
   * Validates that force version >= min version for each platform.
   * Only updates fields that are provided in the DTO.
   *
   * @param dto  Partial update DTO
   * @returns    Updated AppVersionConfigResponse
   * @throws UnprocessableEntityException if forceVersion < minVersion
   */
  async updateVersionConfig(
    dto: UpdateVersionConfigDto,
  ): Promise<AppVersionConfigResponse> {
    return this.db.withRetry(async () => {
      let current: any;

      current = await this.repo.getAppVersionConfig();

      if (!current) {
        throw new NotFoundException('App version config not found');
      }

      // Merge DTO with current values
      const iosMin = dto.iosMinVersion ?? current.iosMinVersion;
      const iosForce = dto.iosForceVersion ?? current.iosForceVersion;
      const androidMin = dto.androidMinVersion ?? current.androidMinVersion;
      const androidForce = dto.androidForceVersion ?? current.androidForceVersion;

      // Validate: force version must be >= min version
      if (iosMin && iosForce && compareVersions(iosForce, iosMin) < 0) {
        throw new UnprocessableEntityException(
          `iOS force version (${iosForce}) must be >= min version (${iosMin})`,
        );
      }
      if (androidMin && androidForce && compareVersions(androidForce, androidMin) < 0) {
        throw new UnprocessableEntityException(
          `Android force version (${androidForce}) must be >= min version (${androidMin})`,
        );
      }

      // Build SET clause from provided DTO fields
      const setClause: Record<string, unknown> = { updatedAt: new Date() };
      if (dto.iosMinVersion !== undefined) setClause.iosMinVersion = dto.iosMinVersion;
      if (dto.androidMinVersion !== undefined) setClause.androidMinVersion = dto.androidMinVersion;
      if (dto.iosForceVersion !== undefined) setClause.iosForceVersion = dto.iosForceVersion;
      if (dto.androidForceVersion !== undefined) setClause.androidForceVersion = dto.androidForceVersion;
      if (dto.forceUpdateEnabled !== undefined) setClause.forceUpdateEnabled = dto.forceUpdateEnabled;

      const result = await this.repo.updateAppVersionConfig(current.id, setClause);

      if (result.length === 0) {
        throw new NotFoundException('App version config not found');
      }

      const updated = result[0];
      this.logger.log('App version config updated');

      return {
        ios: {
          minVersion: updated.iosMinVersion,
          forceUpdateVersion: updated.iosForceVersion,
        },
        android: {
          minVersion: updated.androidMinVersion,
          forceUpdateVersion: updated.androidForceVersion,
        },
        enabled: updated.forceUpdateEnabled,
      };
    });
  }
}
