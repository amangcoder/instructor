import { Controller, Get } from '@nestjs/common';

/**
 * GET /api/app-config — public, no-auth runtime feature flags for the mobile app.
 *
 * The Flutter client polls this on startup ([discoverEnabledProvider]) so
 * features can be gated without shipping a new build. Defaults are false on
 * the client when the field is absent or the request fails, so adding/removing
 * fields here is forward/backward compatible.
 */
@Controller('app-config')
export class AppConfigController {
  @Get()
  get(): { discoverEnabled: boolean } {
    return { discoverEnabled: true };
  }
}
