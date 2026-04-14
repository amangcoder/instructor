/**
 * AdminController — internal admin endpoints.
 *
 * Authentication:
 *   All routes require the x-api-key request header to match ADMIN_API_KEY
 *   (constant-time comparison via timingSafeEqual to prevent timing attacks).
 *   Returns 403 Forbidden if the header is missing or incorrect.
 *
 * Rate limiting:
 *   POST /api/admin/deletion-requests is rate-limited to 10 requests per hour
 *   per IP address using Upstash Redis.
 *
 * Routes:
 *   POST /api/admin/deletion-requests — submit a data-deletion request
 */

import {
  Body,
  Controller,
  ForbiddenException,
  Headers,
  HttpCode,
  HttpException,
  HttpStatus,
  Logger,
  Post,
  Req,
} from '@nestjs/common';
import type { Request } from 'express';
import { timingSafeEqual } from 'crypto';
import { AdminService } from './admin.service';
import { DeletionRequestDto } from './dto/deletion-request.dto';
import { UpstashRateLimitService } from '../ratelimit/upstash-ratelimit.service';

/** 10 deletion-request submissions per hour per IP */
const DELETION_RATE_LIMIT = 10;
const DELETION_RATE_WINDOW_SEC = 3600; // 1 hour

@Controller('admin')
export class AdminController {
  private readonly logger = new Logger(AdminController.name);

  constructor(
    private readonly adminService: AdminService,
    private readonly rateLimit: UpstashRateLimitService,
  ) {}

  /**
   * POST /api/admin/deletion-requests
   *
   * Accepts a data-deletion request from the marketing website form.
   *
   * @param apiKey  x-api-key header — must match ADMIN_API_KEY env var
   * @param dto     Validated deletion-request body
   * @returns       { id, message } on success (201 Created)
   */
  @Post('deletion-requests')
  @HttpCode(HttpStatus.CREATED)
  async createDeletionRequest(
    @Headers('x-api-key') apiKey: string | undefined,
    @Body() dto: DeletionRequestDto,
    @Req() req: Request,
  ): Promise<{ id: string; message: string }> {
    // ── 1. API key authentication ──────────────────────────────────────────
    this.verifyApiKey(apiKey);

    // ── 2. Per-IP rate limiting ────────────────────────────────────────────
    const ip = this.extractIp(req);
    await this.enforceRateLimit(ip);

    // ── 3. Process the request ─────────────────────────────────────────────
    this.logger.log(`POST /admin/deletion-requests — scope=${dto.scope}`);
    this.logger.debug(`POST /admin/deletion-requests — ip=${ip}`);

    return this.adminService.processDeletionRequest(dto);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /**
   * Verify the x-api-key header using a constant-time comparison.
   * Returns silently on success; throws ForbiddenException on failure.
   *
   * Constant-time comparison prevents timing side-channel attacks where an
   * attacker could infer the correct key byte-by-byte from response latency.
   */
  private verifyApiKey(apiKey: string | undefined): void {
    const expected = process.env.ADMIN_API_KEY ?? '';

    if (!apiKey || expected === '') {
      // No header provided, or ADMIN_API_KEY not configured.
      throw new ForbiddenException('Missing or invalid API key');
    }

    try {
      const expectedBuf = Buffer.from(expected, 'utf8');
      const actualBuf = Buffer.from(apiKey, 'utf8');

      // timingSafeEqual requires buffers of equal length.
      // Use a length check first (also constant-time for rejection).
      if (expectedBuf.length !== actualBuf.length) {
        throw new ForbiddenException('Missing or invalid API key');
      }

      const match = timingSafeEqual(expectedBuf, actualBuf);
      if (!match) {
        throw new ForbiddenException('Missing or invalid API key');
      }
    } catch (err) {
      if (err instanceof ForbiddenException) throw err;
      // Unexpected error during comparison — deny.
      throw new ForbiddenException('Missing or invalid API key');
    }
  }

  /**
   * Enforce the per-IP rate limit for deletion requests.
   * Throws an HttpException (429) if the limit is exceeded.
   */
  private async enforceRateLimit(ip: string): Promise<void> {
    const result = await this.rateLimit.consume(
      'deletion_request',
      ip,
      DELETION_RATE_LIMIT,
      DELETION_RATE_WINDOW_SEC,
    );

    if (!result.allowed) {
      this.logger.warn(`Deletion-request rate limit exceeded for IP ${ip}`);
      throw new HttpException(
        `Too many requests. Try again in ${result.retryAfterSec} seconds.`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  /** Extract the originating IP address, respecting X-Forwarded-For. */
  private extractIp(req: Request): string {
    const forwarded = req.headers['x-forwarded-for'];
    if (forwarded) {
      const first = Array.isArray(forwarded) ? forwarded[0] : forwarded.split(',')[0];
      return first.trim();
    }
    return req.socket?.remoteAddress ?? req.ip ?? 'unknown';
  }
}
