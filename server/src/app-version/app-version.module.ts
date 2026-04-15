import { Module } from '@nestjs/common';
import { AppVersionController } from './app-version.controller';
import { AppVersionService } from './app-version.service';

/**
 * AppVersionModule — exposes the force-update/minimum-version check endpoint.
 *
 * Configuration is env-driven (see AppVersionService); no dependencies on the
 * database or auth. Safe to expose without authentication so that logged-out
 * clients can also learn they need to upgrade.
 */
@Module({
  controllers: [AppVersionController],
  providers: [AppVersionService],
})
export class AppVersionModule {}
