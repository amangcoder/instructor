import {
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { randomInt, createHmac, createHash, timingSafeEqual } from 'crypto';
import * as nodemailer from 'nodemailer';
import { eq, and, gt, lt } from 'drizzle-orm';
import { v4 as uuidv4 } from 'uuid';
import { DatabaseService } from '../database/database.service';
import { RateLimitService } from '../redis/rate-limit.service';
import { users, otpRecords, refreshTokens } from '../database/schema';

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

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  private transporter!: nodemailer.Transporter;

  constructor(
    private readonly db: DatabaseService,
    private readonly jwt: JwtService,
    private readonly rateLimit: RateLimitService,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.initMailTransporter();
  }

  // ── Mail setup ────────────────────────────────────────────────────────────

  private async initMailTransporter(): Promise<void> {
    const host = process.env.SMTP_HOST;
    const user = process.env.SMTP_USER;
    const pass = process.env.SMTP_PASS;

    if (host && user && pass) {
      this.transporter = nodemailer.createTransport({
        host,
        port: parseInt(process.env.SMTP_PORT ?? '587', 10),
        secure: process.env.SMTP_SECURE === 'true',
        auth: { user, pass },
      });
      this.logger.log(`Mail transporter configured via ${host}`);
    } else {
      // Fallback to Ethereal test account for development / CI.
      const testAccount = await nodemailer.createTestAccount();
      this.transporter = nodemailer.createTransport({
        host: 'smtp.ethereal.email',
        port: 587,
        secure: false,
        auth: { user: testAccount.user, pass: testAccount.pass },
      });
      this.logger.warn(
        `SMTP not configured — using Ethereal test account: ${testAccount.user}`,
      );
    }

    // Verify SMTP connection at startup so misconfiguration surfaces early
    // rather than silently failing on the first OTP send.
    try {
      await this.transporter.verify();
      this.logger.log('SMTP connection verified successfully');
    } catch (err: any) {
      this.logger.error(`SMTP verification failed — email delivery will not work: ${err.message}`);
      // Do not throw; allow the server to start (OTP send errors are logged per-request).
    }
  }

  // ── OTP request ───────────────────────────────────────────────────────────

  async requestOtp(email: string): Promise<{ message: string }> {
    const normalizedEmail = email.toLowerCase().trim();

    // Enforce rate limit: 3 per 5 minutes per email (Redis-backed).
    await this.checkOtpRateLimit(normalizedEmail);

    const code = this.generateOtp();
    const hashedCode = this.hashOtp(code);
    const now = new Date();
    const expiresAt = new Date(now.getTime() + OTP_TTL_MS);

    // Invalidate all previous unused OTPs for this email (cleanup).
    await this.db.db
      .update(otpRecords)
      .set({ used: true })
      .where(
        and(
          eq(otpRecords.email, normalizedEmail),
          eq(otpRecords.used, false),
        ),
      );

    // Insert new OTP record — store the hash, never the plaintext.
    await this.db.db.insert(otpRecords).values({
      email: normalizedEmail,
      code: hashedCode,
      expiresAt,
      attempts: 0,
      used: false,
      createdAt: now,
    });

    // Send plaintext code via email (fire-and-forget for latency, but log errors).
    this.sendOtpEmail(normalizedEmail, code).catch((err: Error) =>
      this.logger.error(`Failed to send OTP email to ${normalizedEmail}: ${err.message}`),
    );

    this.logger.log(`OTP requested for ${normalizedEmail}`);
    return { message: 'OTP sent' };
  }

  // ── OTP verification ──────────────────────────────────────────────────────

  async verifyOtp(email: string, otp: string): Promise<AuthResult> {
    const normalizedEmail = email.toLowerCase().trim();
    const now = new Date();

    // Find the most recent valid OTP for this email.
    const records = await this.db.db
      .select()
      .from(otpRecords)
      .where(
        and(
          eq(otpRecords.email, normalizedEmail),
          eq(otpRecords.used, false),
          gt(otpRecords.expiresAt, now),
        ),
      )
      .orderBy(otpRecords.id)
      .all();

    // Use the most recently inserted record.
    const record = records[records.length - 1];

    if (!record) {
      // Either no OTP was sent or it already expired.
      throw new UnauthorizedException('OTP expired or not found. Please request a new one.');
    }

    // Check attempt count BEFORE validating to prevent brute-force.
    if (record.attempts >= OTP_MAX_ATTEMPTS) {
      throw new UnauthorizedException(
        'Too many failed attempts. Please request a new OTP.',
      );
    }

    // Hash the submitted OTP and compare against the stored hash using a
    // timing-safe comparison to prevent timing side-channel attacks.
    const hashedSubmitted = this.hashOtp(otp);
    const storedHash = record.code;
    // Both are hex strings of equal length (64 chars) — safe to compare with timingSafeEqual.
    const otpMatch = timingSafeEqual(
      Buffer.from(storedHash, 'hex'),
      Buffer.from(hashedSubmitted, 'hex'),
    );

    if (!otpMatch) {
      // Increment attempts.
      await this.db.db
        .update(otpRecords)
        .set({ attempts: record.attempts + 1 })
        .where(eq(otpRecords.id, record.id));

      const remaining = OTP_MAX_ATTEMPTS - (record.attempts + 1);
      throw new UnauthorizedException(
        `Invalid OTP. ${remaining} attempt(s) remaining.`,
      );
    }

    // Mark OTP as used (single-use enforcement).
    await this.db.db
      .update(otpRecords)
      .set({ used: true })
      .where(eq(otpRecords.id, record.id));

    // Upsert user record (create on first login).
    let user = await this.db.db
      .select()
      .from(users)
      .where(eq(users.email, normalizedEmail))
      .get();

    if (!user) {
      const newUser = {
        id: uuidv4(),
        email: normalizedEmail,
        createdAt: now,
      };
      await this.db.db.insert(users).values(newUser);
      user = newUser;
      this.logger.log(`New user created: ${normalizedEmail} (id=${newUser.id})`);
    }

    // Issue tokens.
    const tokens = await this.issueTokens(user.id, user.email);
    this.logger.log(`OTP verified for ${normalizedEmail}`);
    return { ...tokens, user: { id: user.id, email: user.email } };
  }

  // ── Refresh token ─────────────────────────────────────────────────────────

  async refreshAccessToken(
    token: string,
  ): Promise<{ accessToken: string; refreshToken: string }> {
    const now = new Date();

    // Look up the refresh token by its SHA-256 hash (tokens are stored hashed).
    const hashedToken = this.hashRefreshToken(token);
    const record = await this.db.db
      .select()
      .from(refreshTokens)
      .where(
        and(
          eq(refreshTokens.token, hashedToken),
          eq(refreshTokens.revoked, false),
          gt(refreshTokens.expiresAt, now),
        ),
      )
      .get();

    if (!record) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const user = await this.db.db
      .select()
      .from(users)
      .where(eq(users.id, record.userId))
      .get();

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    // Revoke the current refresh token (token rotation — limits blast radius of theft).
    await this.db.db
      .update(refreshTokens)
      .set({ revoked: true })
      .where(eq(refreshTokens.id, record.id));

    // Issue a brand-new access token AND a new refresh token.
    const tokens = await this.issueTokens(user.id, user.email);

    this.logger.log(`Tokens rotated for user ${user.id}`);
    return tokens;
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
    // Store a SHA-256 hash of the token — the raw UUID is returned to the client only.
    const hashedRefreshToken = this.hashRefreshToken(refreshToken);
    const expiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_MS);

    await this.db.db.insert(refreshTokens).values({
      id: uuidv4(),
      userId,
      token: hashedRefreshToken,
      expiresAt,
      revoked: false,
    });

    return { accessToken, refreshToken };
  }

  private generateOtp(): string {
    // Use crypto.randomInt for a cryptographically secure 6-digit OTP.
    // randomInt(min, max) returns an integer in [min, max).
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
          'do not leave it unset. Generate one with: openssl rand -hex 32',
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

  private async sendOtpEmail(email: string, code: string): Promise<void> {
    const info = await this.transporter.sendMail({
      from: process.env.SMTP_FROM ?? '"Instructor App" <noreply@instructor.app>',
      to: email,
      subject: 'Your Instructor App verification code',
      text: `Your verification code is: ${code}\n\nThis code expires in 5 minutes.`,
      html: `
        <p>Your Instructor App verification code is:</p>
        <h2 style="letter-spacing:0.3em">${code}</h2>
        <p>This code expires in 5 minutes.</p>
        <p>If you did not request this, please ignore this email.</p>
      `,
    });

    // Log Ethereal preview URL (dev only).
    const previewUrl = nodemailer.getTestMessageUrl(info);
    if (previewUrl) {
      this.logger.log(`OTP email preview: ${previewUrl}`);
    }
  }

  // ── Logout / token revocation ──────────────────────────────────────────────

  /**
   * Revoke a single refresh token (e.g. on logout from one device).
   * Silently succeeds if the token is already revoked or doesn't exist.
   */
  async revokeRefreshToken(token: string): Promise<void> {
    const hashedToken = this.hashRefreshToken(token);
    await this.db.db
      .update(refreshTokens)
      .set({ revoked: true })
      .where(
        and(
          eq(refreshTokens.token, hashedToken),
          eq(refreshTokens.revoked, false),
        ),
      );
  }

  /**
   * Revoke all refresh tokens for a user (e.g. logout-all / password reset).
   */
  async revokeAllRefreshTokens(userId: string): Promise<void> {
    await this.db.db
      .update(refreshTokens)
      .set({ revoked: true })
      .where(
        and(
          eq(refreshTokens.userId, userId),
          eq(refreshTokens.revoked, false),
        ),
      );
    this.logger.log(`All refresh tokens revoked for user ${userId}`);
  }

  /**
   * Cleanup expired OTP records older than 1 hour (call periodically).
   * Not strictly required but keeps the table small.
   */
  async pruneExpiredOtps(): Promise<void> {
    const cutoff = new Date(Date.now() - 60 * 60 * 1000);
    await this.db.db
      .delete(otpRecords)
      .where(lt(otpRecords.expiresAt, cutoff));
  }
}
