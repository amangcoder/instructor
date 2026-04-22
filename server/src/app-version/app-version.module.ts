import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AppVersionController } from './app-version.controller';
import { AppVersionService } from './app-version.service';
import { AppVersionAdminController } from './app-version-admin.controller';
import { AppVersionAdminService } from './app-version-admin.service';
import { AdminRoleGuard } from '../auth/admin-role.guard';

/**
 * AppVersionModule — exposes the force-update/minimum-version check endpoint
 * and the admin version management endpoints.
 *
 * Public endpoint (no auth): GET /api/app-version/check
 *   - Reads from env vars only (blast-radius protection)
 *
 * Admin endpoints (JWT + admin role): GET/PATCH /api/admin/app-version
 *   - Read/write DB via AppVersionAdminService
 *
 * Why JwtModule.registerAsync():
 *   Admin endpoints need JwtAuthGuard → JwtService for token validation.
 *   Same pattern as AdminAnalyticsModule.
 */
@Module({
  imports: [
    JwtModule.registerAsync({
      useFactory: () => ({
        secret: process.env.JWT_SECRET,
        signOptions: { expiresIn: '15m' },
      }),
    }),
  ],
  controllers: [AppVersionController, AppVersionAdminController],
  providers: [AppVersionService, AppVersionAdminService, AdminRoleGuard],
})
export class AppVersionModule {}
