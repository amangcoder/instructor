/**
 * AuthService — email + OTP authentication with JWT token issuance.
 *
 * Migrated from:
 *   DynamoDBService               → DatabaseService (Neon PostgreSQL/Drizzle)
 *   Nodemailer SMTP               → SESEmailService
 *   DynamoDBRateLimitService      → UpstashRateLimitService
 *
 * onModuleInit is intentionally removed — all dependencies are lazy
 * (Neon/SES clients connect on first use) so cold start is fast.
 */

import {
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { randomInt, createHmac, createHash, timingSafeEqual } from 'crypto';
import { v4 as uuidv4 } from 'uuid';
import { DatabaseService } from '../database/database.service';
import { SESEmailService } from '../email/ses-email.service';
import { UpstashRateLimitService } from '../ratelimit/upstash-ratelimit.service';

// ── Constants ────────────────────────────────────────────────────────────────

const OTP_TTL_MS = 5 * 60 * 1000;          // 5 minutes
const OTP_MAX_ATTEMPTS = 5;
const OTP_RATE_LIMIT = 3;
const OTP_RATE_WINDOW_SEC = 5 * 60;        // 5 minutes
const ACCESS_TOKEN_TTL = '15m';
const REFRESH_TOKEN_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

// ── Types ────────────────────────────────────────────────────────────────────

export interface JwtPayload {
  sub: string;
  email: string;
}

export interface AuthResult {
  accessToken: string;
  refreshToken: string;
  user: { id: string; email: string };
}

// ── Service ──────────────────────────────────────────────────────────────────

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  /** True when DATABASE_URL is not configured — OTP is bypassed for local dev. */
  private readonly localBypass: boolean;

  constructor(
    private readonly db: DatabaseService,
    private readonly ses: SESEmailService,
    private readonly rateLimit: UpstashRateLimitService,
    private readonly jwt: JwtService,
  ) {
    this.localBypass = !process.env.DATABASE_URL;
    if (this.localBypass) {
      this.logger.warn(
        'DATABASE_URL not set — OTP verification bypassed. ' +
        'Any OTP code will be accepted (local dev mode).',
      );
    }
  }

  // ── OTP request ───────────────────────────────────────────────────────────

  async requestOtp(email: string): Promise<{ message: string }> {
    const normalizedEmail = email.toLowerCase().trim();

    if (this.localBypass) {
      this.logger.log(`[LOCAL] OTP requested for ${normalizedEmail} — use any 6-digit code to verify`);
      return { message: 'OTP sent' };
    }

    // Enforce rate limit: 3 per 5 minutes per email (Upstash Redis-backed, atomic).
    await this.checkOtpRateLimit(normalizedEmail);

    const code = this.generateOtp();
    const hashedCode = this.hashOtp(code);
    const expiresAt = new Date(Date.now() + OTP_TTL_MS);

    // Invalidate all previous unused OTPs for this email (single-active-OTP invariant).
    await this.db.invalidateOtpsForEmail(normalizedEmail);

    // Store new OTP record — the hash, never plaintext.
    await this.db.createOtp(normalizedEmail, hashedCode, expiresAt);

    // Send plaintext code via SES (fire-and-forget — don't block the response).
    this.ses
      .sendOtpEmail(normalizedEmail, code)
      .catch((err: Error) =>
        this.logger.error(`Failed to send OTP email to ${normalizedEmail}: ${err.message}`),
      );

    this.logger.log(`OTP requested for ${normalizedEmail}`);
    return { message: 'OTP sent' };
  }

  // ── OTP verification ──────────────────────────────────────────────────────

  async verifyOtp(email: string, otp: string): Promise<AuthResult> {
    const normalizedEmail = email.toLowerCase().trim();

    // ── Local dev bypass: accept any OTP, use a deterministic user ID ──
    if (this.localBypass) {
      const userId = uuidv4();
      this.logger.log(`[LOCAL] OTP bypassed for ${normalizedEmail} — issuing tokens (userId=${userId})`);
      const tokens = await this.issueLocalTokens(userId, normalizedEmail);
      return { ...tokens, user: { id: userId, email: normalizedEmail } };
    }

    // Retrieve all active (unused, non-expired) OTP records for this email.
    const records = await this.db.getActiveOtps(normalizedEmail);

    // Use the most recently created record (highest sort key = most recent ISO timestamp).
    const record = records.length > 0 ? records[records.length - 1] : null;

    if (!record) {
      throw new UnauthorizedException('OTP expired or not found. Please request a new one.');
    }

    // Brute-force guard: check attempt count BEFORE validating.
    if (record.attempts >= OTP_MAX_ATTEMPTS) {
      throw new UnauthorizedException(
        'Too many failed attempts. Please request a new OTP.',
      );
    }

    // Timing-safe hash comparison (prevents timing side-channel attacks).
    const hashedSubmitted = this.hashOtp(otp);
    const storedHash = record.code;
    const otpMatch = timingSafeEqual(
      Buffer.from(storedHash, 'hex'),
      Buffer.from(hashedSubmitted, 'hex'),
    );

    if (!otpMatch) {
      await this.db.incrementOtpAttempts(normalizedEmail, record.sk);

      const remaining = OTP_MAX_ATTEMPTS - (record.attempts + 1);
      throw new UnauthorizedException(
        `Invalid OTP. ${remaining} attempt(s) remaining.`,
      );
    }

    // Mark OTP as used (single-use enforcement).
    await this.db.markOtpUsed(normalizedEmail, record.sk);

    // Upsert user record (create on first successful login).
    let user = await this.db.getUserByEmail(normalizedEmail);

    if (!user) {
      const newUser = {
        id: uuidv4(),
        email: normalizedEmail,
        createdAt: new Date(),
      };
      await this.db.createUser(newUser);
      user = newUser;
      this.logger.log(`New user created: ${normalizedEmail} (id=${newUser.id})`);
    }

    // Issue access token + refresh token.
    const tokens = await this.issueTokens(user.id, user.email);
    this.logger.log(`OTP verified for ${normalizedEmail}`);
    return { ...tokens, user: { id: user.id, email: user.email } };
  }

  // ── Refresh token ─────────────────────────────────────────────────────────

  async refreshAccessToken(
    token: string,
  ): Promise<{ accessToken: string; refreshToken: string }> {
    const hashedToken = this.hashRefreshToken(token);

    // Look up the refresh token by its hash.
    const record = await this.db.getRefreshToken(hashedToken);

    if (!record || record.revoked || record.expiresAt <= new Date()) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const user = await this.db.getUserById(record.userId);
    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    // Revoke the current token (token rotation — limits blast radius of theft).
    await this.db.revokeRefreshToken(record.userId, hashedToken);

    // Issue a fresh access token AND a new refresh token.
    const tokens = await this.issueTokens(user.id, user.email);

    this.logger.log(`Tokens rotated for user ${user.id}`);
    return tokens;
  }

  // ── Logout / token revocation ─────────────────────────────────────────────

  /**
   * Revoke a single refresh token (e.g. logout from one device).
   * Silently succeeds if the token is already revoked or doesn't exist.
   */
  async revokeRefreshToken(token: string): Promise<void> {
    const hashedToken = this.hashRefreshToken(token);
    // The database update is a no-op if the item doesn't exist or is already revoked.
    await this.db.revokeRefreshToken('', hashedToken);
  }

  /**
   * Revoke all refresh tokens for a user (logout-all / security reset).
   */
  async revokeAllRefreshTokens(userId: string): Promise<void> {
    await this.db.revokeAllRefreshTokens(userId);
    this.logger.log(`All refresh tokens revoked for user ${userId}`);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  private async issueTokens(
    userId: string,
    email: string,
  ): Promise<{ accessToken: string; refreshToken: string }> {
    const accessToken = this.jwt.sign(
      { sub: userId, email } satisfies JwtPayload,
      { expiresIn: ACCESS_TOKEN_TTL },
    );

    const refreshToken = uuidv4();
    const hashedRefreshToken = this.hashRefreshToken(refreshToken);
    const expiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_MS);

    await this.db.createRefreshToken(userId, hashedRefreshToken, expiresAt);

    return { accessToken, refreshToken };
  }

  /** Issue tokens without persisting the refresh token to the database (local dev only). */
  private issueLocalTokens(
    userId: string,
    email: string,
  ): { accessToken: string; refreshToken: string } {
    const accessToken = this.jwt.sign(
      { sub: userId, email } satisfies JwtPayload,
      { expiresIn: ACCESS_TOKEN_TTL },
    );
    return { accessToken, refreshToken: uuidv4() };
  }

  private generateOtp(): string {
    // Cryptographically secure 6-digit OTP.
    return randomInt(100_000, 1_000_000).toString().padStart(6, '0');
  }

  /**
   * HMAC-SHA256 hash of an OTP code using OTP_SALT from the environment.
   * Returns a 64-character hex string for constant-time comparison.
   */
  private hashOtp(code: string): string {
    const salt = process.env.OTP_SALT;
    if (!salt) {
      throw new Error(
        'OTP_SALT must be set to a secure random value — ' +
          'generate one with: openssl rand -hex 32',
      );
    }
    return createHmac('sha256', salt).update(code).digest('hex');
  }

  /**
   * SHA-256 hash of a refresh token UUID for secure database storage.
   * Returns a 64-character hex string.
   */
  private hashRefreshToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private async checkOtpRateLimit(email: string): Promise<void> {
    const result = await this.rateLimit.consume(
      'otp',
      email,
      OTP_RATE_LIMIT,
      OTP_RATE_WINDOW_SEC,
    );

    if (!result.allowed) {
      this.logger.warn(`OTP rate limit hit for ${email}`);
      throw new HttpException(
        `Too many OTP requests. Try again in ${result.retryAfterSec} seconds.`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }
}
