import {
  Controller,
  Post,
  Patch,
  Get,
  Body,
  BadRequestException,
  HttpCode,
  HttpException,
  HttpStatus,
  Logger,
  Req,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  Headers,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { AuthService } from './auth.service';
import { RequestOtpDto } from './dto/request-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { LogoutDto } from './dto/logout.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { OptionalAuthGuard } from './optional-auth.guard';
import { JwtAuthGuard } from './jwt-auth.guard';
import { JwtPayload } from './auth.service';
import type { Request } from 'express';

@Controller('auth')
export class AuthController {
  private readonly logger = new Logger(AuthController.name);

  constructor(private readonly authService: AuthService) {}

  /**
   * GET /api/auth/me
   * Returns the authenticated user's profile.
   */
  @Get('me')
  @UseGuards(JwtAuthGuard)
  async getMe(@Req() req: Request) {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`GET /auth/me — userId=${user.sub}`);
    return this.authService.getProfile(user.sub);
  }

  /**
   * POST /api/auth/profile/photo
   * Accepts a multipart/form-data upload (field: 'photo').
   * Uploads the image to S3 and returns a presigned URL (7-day TTL).
   * Max file size: 5 MB. Allowed types: JPEG, PNG, WebP.
   */
  @Post('profile/photo')
  @UseGuards(JwtAuthGuard)
  @UseInterceptors(
    FileInterceptor('photo', {
      storage: memoryStorage(),
      limits: { fileSize: 5 * 1024 * 1024 },
      fileFilter: (_req, file, cb) => {
        if (/^image\/(jpeg|png|webp)$/.test(file.mimetype)) {
          cb(null, true);
        } else {
          cb(new BadRequestException('Only JPEG, PNG, and WebP images are allowed'), false);
        }
      },
    }),
  )
  @HttpCode(200)
  async uploadProfilePhoto(
    @UploadedFile() file: Express.Multer.File,
    @Req() req: Request,
  ): Promise<{ photoUrl: string }> {
    if (!file) throw new BadRequestException('No photo file provided (field name: photo)');
    const user = (req as any).user as JwtPayload;
    this.logger.log(`POST /auth/profile/photo — userId=${user.sub}, size=${file.size}B`);
    return this.authService.uploadProfilePhoto(user.sub, file.buffer, file.mimetype);
  }

  /**
   * PATCH /api/auth/profile
   * Updates the authenticated user's profile (name, username, photoUrl).
   * All fields are optional — only provided fields are updated.
   */
  @Patch('profile')
  @UseGuards(JwtAuthGuard)
  @HttpCode(200)
  async updateProfile(
    @Body() dto: UpdateProfileDto,
    @Req() req: Request,
  ) {
    const user = (req as any).user as JwtPayload;
    this.logger.log(`PATCH /auth/profile — userId=${user.sub}`);
    return this.authService.updateProfile(user.sub, dto);
  }

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
