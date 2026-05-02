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
  Optional,
  Inject,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { randomInt, createHmac, createHash, timingSafeEqual } from 'crypto';
import { v4 as uuidv4 } from 'uuid';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { DatabaseService } from '../database/database.service';
import { AuthRepository } from '../database/repositories/auth.repository';
import { UserRepository } from '../database/repositories/user.repository';
import { SESEmailService } from '../email/ses-email.service';
import { UpstashRateLimitService } from '../ratelimit/upstash-ratelimit.service';
import type { AppConfig } from '../config/app-config.interface';

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
  role: string;
}

export interface UserProfile {
  id: string;
  email: string;
  name: string | null;
  username: string | null;
  photoUrl: string | null;
}

export interface AuthResult {
  accessToken: string;
  refreshToken: string;
  user: UserProfile;
}

// ── Service ──────────────────────────────────────────────────────────────────

/** S3 key prefix for profile photos. */
const AVATAR_PREFIX = 'avatars';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly s3: S3Client | null;
  private readonly bucket: string | null;
  private readonly auth: AuthRepository | DatabaseService;
  private readonly userRepo: UserRepository | DatabaseService;

  constructor(
    private readonly db: DatabaseService,
    private readonly ses: SESEmailService,
    private readonly rateLimit: UpstashRateLimitService,
    private readonly jwt: JwtService,
    @Optional() @Inject('APP_CONFIG') private readonly config?: AppConfig,
    @Optional() @Inject(AuthRepository) authRepo?: AuthRepository,
    @Optional() @Inject(UserRepository) userRepo?: UserRepository,
  ) {
    // Prefer repositories when available; fall back to DatabaseService for
    // backward compatibility with tests that only provide DatabaseService.
    this.auth = authRepo ?? db;
    this.userRepo = userRepo ?? db;
    this.bucket = (config?.awsS3Bucket || process.env.AWS_S3_BUCKET) ?? null;
    this.s3 = this.bucket
      ? new S3Client({ region: config?.awsRegion ?? process.env.AWS_REGION ?? 'ap-south-1' })
      : null;
  }

  // ── OTP request ───────────────────────────────────────────────────────────

  async requestOtp(email: string, ip?: string): Promise<{ message: string }> {
    const normalizedEmail = email.toLowerCase().trim();

    // Per-IP rate limit: 10 OTP requests per IP per hour.
    // This prevents spray attacks across many email addresses that bypass the
    // per-email limit. Applied first so IP-banned callers don't hit the DB.
    if (ip) {
      await this.checkOtpRateLimitByIp(ip);
    }

    // Per-email rate limit: 3 per 5 minutes per email (Upstash Redis-backed, atomic).
    await this.checkOtpRateLimit(normalizedEmail);

    const code = this.generateOtp();
    const hashedCode = this.hashOtp(code);
    const expiresAt = new Date(Date.now() + OTP_TTL_MS);

    // Invalidate all previous unused OTPs for this email (single-active-OTP invariant).
    await this.auth.invalidateOtpsForEmail(normalizedEmail);

    // Store new OTP record — the hash, never plaintext.
    await this.auth.createOtp(normalizedEmail, hashedCode, expiresAt);

    // Dispatch email via async Lambda self-invocation (returns 202 immediately).
    // The email Lambda runs independently — no risk of dying with this request.
    await this.ses.dispatchOtpEmail(normalizedEmail, code);

    if ((this.config?.nodeEnv ?? process.env.NODE_ENV) !== 'production') {
      this.logger.log(`[DEV] OTP for ${normalizedEmail}: ${code}`);
    }
    this.logger.log(`OTP requested for ${normalizedEmail}`);
    return { message: 'OTP sent' };
  }

  // ── OTP verification ──────────────────────────────────────────────────────

  async verifyOtp(email: string, otp: string): Promise<AuthResult> {
    const normalizedEmail = email.toLowerCase().trim();

    // Retrieve all active (unused, non-expired) OTP records for this email.
    const records = await this.auth.getActiveOtps(normalizedEmail);

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
      await this.auth.incrementOtpAttempts(normalizedEmail, record.id);

      const remaining = OTP_MAX_ATTEMPTS - (record.attempts + 1);
      throw new UnauthorizedException(
        `Invalid OTP. ${remaining} attempt(s) remaining.`,
      );
    }

    // Mark OTP as used (single-use enforcement).
    await this.auth.markOtpUsed(normalizedEmail, record.id);

    // Upsert user record (create on first successful login).
    let user = await this.userRepo.getUserByEmail(normalizedEmail);

    if (!user) {
      const newUserId = uuidv4();
      await this.userRepo.createUser({ id: newUserId, email: normalizedEmail, createdAt: new Date() });
      // Re-fetch so we have the full UserRecord shape (including nullable profile fields).
      user = await this.userRepo.getUserById(newUserId);
      this.logger.log(`New user created: ${normalizedEmail} (id=${newUserId})`);
    }

    if (!user) {
      throw new UnauthorizedException('Failed to create or retrieve user');
    }

    // Issue access token + refresh token.
    const tokens = await this.issueTokens(user.id, user.email, user.role ?? 'user');
    this.logger.log(`OTP verified for ${normalizedEmail}`);
    return {
      ...tokens,
      user: {
        id: user.id,
        email: user.email,
        name: user.name ?? null,
        username: user.username ?? null,
        photoUrl: this.resolvePhotoUrl(user.photoUrl ?? null),
      },
    };
  }

  // ── Invite user ───────────────────────────────────────────────────────────

  async inviteUser(email: string): Promise<{ message: string; email: string }> {
    const normalizedEmail = email.toLowerCase().trim();

    const existing = await this.userRepo.getUserByEmail(normalizedEmail);
    if (existing) {
      return { message: 'User already exists', email: normalizedEmail };
    }

    await this.userRepo.createUser({
      id: uuidv4(),
      email: normalizedEmail,
      createdAt: new Date(),
    });

    this.logger.log(`User invited: ${normalizedEmail}`);
    return { message: 'User invited', email: normalizedEmail };
  }

  // ── Refresh token ─────────────────────────────────────────────────────────

  async refreshAccessToken(
    token: string,
  ): Promise<AuthResult> {
    const hashedToken = this.hashRefreshToken(token);

    // Look up the refresh token by its hash.
    const record = await this.auth.getRefreshToken(hashedToken);

    if (!record || record.revoked || record.expiresAt <= new Date()) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const user = await this.userRepo.getUserById(record.userId);
    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    // Revoke the current token (token rotation — limits blast radius of theft).
    await this.auth.revokeRefreshToken(record.userId, hashedToken);

    // Issue a fresh access token AND a new refresh token.
    const tokens = await this.issueTokens(user.id, user.email, user.role ?? 'user');

    this.logger.log(`Tokens rotated for user ${user.id}`);
    return {
      ...tokens,
      user: {
        id: user.id,
        email: user.email,
        name: user.name ?? null,
        username: user.username ?? null,
        photoUrl: this.resolvePhotoUrl(user.photoUrl ?? null),
      },
    };
  }

  // ── Logout / token revocation ─────────────────────────────────────────────

  /**
   * Revoke a single refresh token (e.g. logout from one device).
   * Silently succeeds if the token is already revoked or doesn't exist.
   */
  async revokeRefreshToken(token: string): Promise<void> {
    const hashedToken = this.hashRefreshToken(token);
    // The database update is a no-op if the item doesn't exist or is already revoked.
    await this.auth.revokeRefreshToken('', hashedToken);
  }

  /**
   * Revoke all refresh tokens for a user (logout-all / security reset).
   */
  async revokeAllRefreshTokens(userId: string): Promise<void> {
    await this.auth.revokeAllRefreshTokens(userId);
    this.logger.log(`All refresh tokens revoked for user ${userId}`);
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  async getProfile(userId: string): Promise<UserProfile> {
    const user = await this.userRepo.getUserById(userId);
    if (!user) throw new UnauthorizedException('User not found');
    return {
      id: user.id,
      email: user.email,
      name: user.name ?? null,
      username: user.username ?? null,
      photoUrl: this.resolvePhotoUrl(user.photoUrl ?? null),
    };
  }

  async uploadProfilePhoto(
    userId: string,
    buffer: Buffer,
    mimeType: string,
  ): Promise<{ photoUrl: string }> {
    if (!this.s3 || !this.bucket) {
      throw new HttpException(
        'Photo upload is not available — S3 is not configured',
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }

    const ext = mimeType === 'image/png' ? 'png' : mimeType === 'image/webp' ? 'webp' : 'jpg';
    const s3Key = `${AVATAR_PREFIX}/${userId}.${ext}`;

    await this.s3.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: s3Key,
        Body: buffer,
        ContentType: mimeType,
      }),
    );

    await this.userRepo.updateUserProfile(userId, { photoUrl: s3Key });

    const photoUrl = this.buildPublicPhotoUrl(s3Key)!;

    this.logger.log(`Profile photo uploaded: userId=${userId}, key=${s3Key}`);
    return { photoUrl };
  }

  async deleteAccount(userId: string): Promise<void> {
    const user = await this.userRepo.getUserById(userId);
    if (!user) throw new UnauthorizedException('User not found');
    await this.userRepo.deleteUser(userId, user.email);
    this.logger.log(`Account deleted: userId=${userId}`);
  }

  async updateProfile(
    userId: string,
    data: { name?: string; username?: string; photoUrl?: string },
  ): Promise<UserProfile> {
    try {
      await this.userRepo.updateUserProfile(userId, data);
    } catch (err) {
      if ((err as { code?: string })?.code === 'USERNAME_TAKEN') {
        throw new HttpException('Username already taken', HttpStatus.CONFLICT);
      }
      throw err;
    }
    return this.getProfile(userId);
  }

  // ── Private: photo URL resolution ────────────────────────────────────────

  /**
   * If the stored value is an S3 key (starts with 'avatars/'), return the
   * public virtual-hosted S3 URL. Otherwise returns the value unchanged.
   * Public read access is granted via bucket policy (ACLs disabled on bucket).
   */
  private resolvePhotoUrl(raw: string | null): string | null {
    if (!raw || !raw.startsWith(`${AVATAR_PREFIX}/`)) return raw;
    return this.buildPublicPhotoUrl(raw);
  }

  private buildPublicPhotoUrl(s3Key: string): string | null {
    if (!this.bucket) return null;
    const region = this.config?.awsRegion ?? process.env.AWS_REGION ?? 'ap-south-1';
    return `https://${this.bucket}.s3.${region}.amazonaws.com/${s3Key}`;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  private async issueTokens(
    userId: string,
    email: string,
    role: string,
  ): Promise<{ accessToken: string; refreshToken: string }> {
    const accessToken = this.jwt.sign(
      { sub: userId, email, role } satisfies JwtPayload,
      { expiresIn: ACCESS_TOKEN_TTL },
    );

    const refreshToken = uuidv4();
    const hashedRefreshToken = this.hashRefreshToken(refreshToken);
    const expiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_MS);

    await this.auth.createRefreshToken(userId, hashedRefreshToken, expiresAt);

    return { accessToken, refreshToken };
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
    const salt = this.config?.otpSalt || process.env.OTP_SALT;
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

  private async checkOtpRateLimitByIp(ip: string): Promise<void> {
    const result = await this.rateLimit.consume(
      'otp_ip',
      ip,
      10,   // 10 OTP requests per IP per hour
      3600, // 1 hour window
    );

    if (!result.allowed) {
      this.logger.warn(`OTP IP rate limit hit for ${ip}`);
      throw new HttpException(
        `Too many OTP requests from this IP. Try again in ${result.retryAfterSec} seconds.`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }
}
