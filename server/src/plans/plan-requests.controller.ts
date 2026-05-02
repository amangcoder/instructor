import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Logger,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { PlanRequestsService } from './plan-requests.service';
import { PlanRequestDto } from '../admin/dto/plan-request.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { JwtPayload } from '../auth/auth.service';

/**
 * PlanRequestsController — user-facing endpoint for the in-app
 * "Request a Plan" form. JWT-protected: the requester must be authenticated
 * so we can attribute the request and follow up by email.
 */
@Controller('plans/requests')
@UseGuards(JwtAuthGuard)
export class PlanRequestsController {
  private readonly logger = new Logger(PlanRequestsController.name);

  constructor(private readonly service: PlanRequestsService) {}

  /**
   * POST /api/plans/requests
   *
   * Accepts a request for a plan/schedule that isn't currently in Discover.
   * Persists the row and dispatches an admin email notification.
   */
  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(
    @Req() req: Request,
    @Body() dto: PlanRequestDto,
  ): Promise<{ id: string; message: string }> {
    const user = (req as any).user as JwtPayload;
    this.logger.log(
      `POST /plans/requests — userId=${user.sub}, title="${dto.title.slice(0, 80)}"`,
    );

    // Trust the JWT email over whatever the client supplies in the body.
    const email = (user.email ?? dto.email).toLowerCase().trim();

    return this.service.submit({ ...dto, email }, user.sub);
  }
}
