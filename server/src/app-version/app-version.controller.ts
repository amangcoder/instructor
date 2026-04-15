import { Controller, Get, Query } from '@nestjs/common';
import { AppVersionService } from './app-version.service';
import type { AppVersionCheckResult } from './app-version.service';
import { CheckVersionDto } from './dto/check-version.dto';

/**
 * Public endpoint — the app calls this on startup (no auth) to discover
 * whether a force-update is required for the current build.
 *
 *   GET /api/app-version/check?platform=ios&version=1.0.4
 */
@Controller('app-version')
export class AppVersionController {
  constructor(private readonly service: AppVersionService) {}

  @Get('check')
  check(@Query() query: CheckVersionDto): AppVersionCheckResult {
    return this.service.check(query.platform, query.version);
  }
}
