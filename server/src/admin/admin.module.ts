import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';

/**
 * AdminModule — handles internal admin operations.
 *
 * Providers:
 *   AdminController  — POST /api/admin/deletion-requests
 *   AdminService     — processes deletion requests and sends admin emails
 *
 * Imports:
 *   Empty — DatabaseService, SESEmailService, and UpstashRateLimitService are
 *   all @Global() and are available for injection without importing their modules.
 */
@Module({
  imports: [],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
