import {
  Controller,
  Post,
  Body,
  HttpCode,
  HttpException,
  HttpStatus,
  Logger,
  Req,
  UseGuards,
  Headers,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { RequestOtpDto } from './dto/request-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { LogoutDto } from './dto/logout.dto';
import { OptionalAuthGuard } from './optional-auth.guard';
import { JwtPayload } from './auth.service';
import type { Request } from 'express';

@Controller('auth')
export class AuthController {
  private readonly logger = new Logger(AuthController.name);

  constructor(private readonly authService: AuthService) {}

  /**
   * POST /api/auth/invite
   * Pre-creates a user account so they can authenticate.
   * Requires the x-admin-key header matching ADMIN_API_KEY env var.
   */
  @Post('invite')
  @HttpCode(200)
  async invite(
    @Body() body: { email: string },
    @Headers('x-admin-key') adminKey: string,
  ): Promise<{ message: string; email: string }> {
    const expectedKey = process.env.ADMIN_API_KEY;
    if (!expectedKey || adminKey !== expectedKey) {
      throw new HttpException('Unauthorized', HttpStatus.UNAUTHORIZED);
    }
    this.logger.log(`POST /auth/invite — email=${body.email}`);
    return this.authService.inviteUser(body.email);
  }

  /**
   * POST /api/auth/request-otp
   * Sends a 6-digit OTP to the given email.
   * Rate-limited: 3 requests per email per 5 minutes AND 10 per IP per hour.
   */
  @Post('request-otp')
  @HttpCode(200)
  async requestOtp(
    @Body() dto: RequestOtpDto,
    @Req() req: Request,
  ): Promise<{ message: string }> {
    // Extract client IP from x-forwarded-for (populated by API Gateway/CloudFront).
    // Fall back to socket remoteAddress for local development.
    const ip =
      ((req as any).headers['x-forwarded-for'] as string | undefined)
        ?.split(',')[0]
        ?.trim() ??
      (req as any).socket?.remoteAddress ??
      'unknown';
    this.logger.log(`POST /auth/request-otp — email=${dto.email}`);
    return this.authService.requestOtp(dto.email, ip);
  }

  /**
   * POST /api/auth/verify-otp
   * Validates the OTP and returns JWT access + refresh tokens.
   */
  @Post('verify-otp')
  @HttpCode(200)
  async verifyOtp(@Body() dto: VerifyOtpDto) {
    this.logger.log(`POST /auth/verify-otp — email=${dto.email}`);
    return this.authService.verifyOtp(dto.email, dto.otp);
  }

  /**
   * POST /api/auth/refresh
   * Exchanges a valid refresh token for a new access token.
   */
  @Post('refresh')
  @HttpCode(200)
  async refresh(@Body() dto: RefreshTokenDto) {
    this.logger.log(`POST /auth/refresh`);
    return this.authService.refreshAccessToken(dto.refreshToken);
  }

  /**
   * POST /api/auth/logout
   * Revokes the provided refresh token. If a valid JWT is attached,
   * revokes ALL refresh tokens for that user (logout-all).
   * Always returns 200 to avoid leaking token validity.
   */
  @Post('logout')
  @UseGuards(OptionalAuthGuard)
  @HttpCode(200)
  async logout(
    @Body() dto: LogoutDto,
    @Req() req: Request,
  ): Promise<{ message: string }> {
    const user = (req as any).user as JwtPayload | undefined;

    if (user) {
      // JWT present — revoke all tokens for this user.
      await this.authService.revokeAllRefreshTokens(user.sub);
      this.logger.log(`POST /auth/logout — revoked all tokens for user ${user.sub}`);
    } else if (dto.refreshToken) {
      // No JWT but refresh token provided — revoke just that token.
      await this.authService.revokeRefreshToken(dto.refreshToken);
      this.logger.log(`POST /auth/logout — revoked single refresh token`);
    }

    return { message: 'Logged out' };
  }
}
