/**
 * AuthRepository — domain repository for OTP and refresh-token operations.
 *
 * Delegates to the underlying DatabaseService so existing callers are unaffected
 * during the incremental migration from the monolithic DatabaseService god-object
 * to focused, single-responsibility repositories.
 */

import { Injectable } from '@nestjs/common';
import { DatabaseService, OtpRecord, RefreshTokenRecord } from '../database.service';

@Injectable()
export class AuthRepository {
  constructor(private readonly database: DatabaseService) {}

  // ── OTP operations ──────────────────────────────────────────────────────────

  async createOtp(email: string, codeHash: string, expiresAt: Date): Promise<void> {
    return this.database.createOtp(email, codeHash, expiresAt);
  }

  async getActiveOtps(email: string): Promise<OtpRecord[]> {
    return this.database.getActiveOtps(email);
  }

  async markOtpUsed(email: string, otpId: string): Promise<void> {
    return this.database.markOtpUsed(email, otpId);
  }

  async incrementOtpAttempts(email: string, otpId: string): Promise<void> {
    return this.database.incrementOtpAttempts(email, otpId);
  }

  async invalidateOtpsForEmail(email: string): Promise<void> {
    return this.database.invalidateOtpsForEmail(email);
  }

  // ── Refresh token operations ────────────────────────────────────────────────

  async createRefreshToken(userId: string, tokenHash: string, expiresAt: Date): Promise<void> {
    return this.database.createRefreshToken(userId, tokenHash, expiresAt);
  }

  async getRefreshToken(tokenHash: string): Promise<RefreshTokenRecord | null> {
    return this.database.getRefreshToken(tokenHash);
  }

  async revokeRefreshToken(userId: string, tokenHash: string): Promise<void> {
    return this.database.revokeRefreshToken(userId, tokenHash);
  }

  async revokeAllRefreshTokens(userId: string): Promise<void> {
    return this.database.revokeAllRefreshTokens(userId);
  }

  // ── OTP cleanup operations ────────────────────────────────────────────────

  /**
   * Delete expired OTP records using a retry-safe database call.
   * Returns the number of deleted rows.
   */
  async cleanupExpiredOtps(): Promise<number> {
    return this.database.withRetry(async () => {
      const db = this.database.getDb();
      const result = await (db as any).execute(
        `DELETE FROM otp_records WHERE expires_at < NOW() - INTERVAL '24 hours'`,
      );
      return (result as any)?.rowCount ?? 0;
    });
  }
}
