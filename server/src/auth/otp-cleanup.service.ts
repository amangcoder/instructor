import { Injectable, Logger, OnModuleDestroy, OnModuleInit, Inject } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { AuthRepository } from '../database/repositories/auth.repository';

/**
 * OtpCleanupService — periodic job to clean up expired OTP records.
 *
 * The otp_records table accumulates indefinitely if not cleaned. This service
 * uses a 24-hour setInterval (started in onModuleInit, cleared in
 * onModuleDestroy) to purge records that expired more than 24 hours ago,
 * preventing unbounded table growth.
 *
 * Implementation note: uses Node's built-in setInterval rather than
 * @nestjs/schedule so the server has no hard dependency on that optional
 * package. The scheduling semantics (fire every 24 h) are sufficient for
 * a background cleanup job.
 */
@Injectable()
export class OtpCleanupService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(OtpCleanupService.name);
  private cleanupTimer: NodeJS.Timeout | null = null;

  /** Raw SQL used for deletion — kept as a constant for testability. */
  static readonly DELETE_SQL =
    `DELETE FROM otp_records WHERE expires_at < NOW() - INTERVAL '24 hours'`;

  /** Cleanup interval in milliseconds (24 hours). Exposed for testability. */
  static readonly INTERVAL_MS = 24 * 60 * 60 * 1000;

  constructor(
    private readonly database: DatabaseService,
    @Inject(AuthRepository) private readonly repo: AuthRepository,
  ) {}

  onModuleInit(): void {
    this.cleanupTimer = setInterval(
      () => void this.cleanupExpiredOtps(),
      OtpCleanupService.INTERVAL_MS,
    );
  }

  onModuleDestroy(): void {
    if (this.cleanupTimer !== null) {
      clearInterval(this.cleanupTimer);
      this.cleanupTimer = null;
    }
  }

  /**
   * Delete all OTP records that expired more than 24 hours ago.
   * Called by the internal interval timer every 24 hours.
   * Logs the number of deleted rows at INFO level.
   */
  async cleanupExpiredOtps(): Promise<void> {
    try {
      const deletedCount = await this.repo.cleanupExpiredOtps();

      this.logger.log(
        `Cleaned up ${deletedCount} expired OTP record(s)`,
      );
    } catch (err) {
      this.logger.error(
        `Failed to clean up expired OTP records: ${err instanceof Error ? err.message : err}`,
        err instanceof Error ? err.stack : undefined,
      );
      // Log the error but don't re-throw — a single cleanup failure shouldn't crash the app
    }
  }
}
