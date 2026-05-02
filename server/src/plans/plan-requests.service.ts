/**
 * PlanRequestsService — handles "Request a Plan" submissions from the in-app
 * Discover surface. A user-submitted request is:
 *   1. Persisted to plan_requests for the admin dashboard
 *   2. Notified to ADMIN_EMAIL so the team can act on it
 *
 * Email failures are non-fatal: the request is already persisted, so the
 * dashboard remains the source of truth even if SES is briefly unavailable.
 */

import { Injectable, Logger } from '@nestjs/common';
import { v4 as uuidv4 } from 'uuid';
import { AdminRepository } from '../database/repositories/admin.repository';
import { SESEmailService } from '../email/ses-email.service';
import type { PlanRequestDto } from '../admin/dto/plan-request.dto';

export interface PlanRequestResult {
  id: string;
  message: string;
}

@Injectable()
export class PlanRequestsService {
  private readonly logger = new Logger(PlanRequestsService.name);

  constructor(
    private readonly repo: AdminRepository,
    private readonly ses: SESEmailService,
  ) {}

  async submit(
    dto: PlanRequestDto,
    userId: string | null,
  ): Promise<PlanRequestResult> {
    const id = uuidv4();
    const email = dto.email.toLowerCase().trim();

    await this.repo.insertPlanRequest({
      id,
      userId,
      email,
      title: dto.title.trim(),
      description: dto.description.trim(),
      category: dto.category ?? null,
      createdAt: new Date(),
    });

    this.logger.log(`Plan request received: id=${id} email=${email}`);

    await this.notifyAdmin(id, email, dto, userId);

    return {
      id,
      message:
        'Thanks! Your plan request has been received. We’ll review it and email you when it’s ready.',
    };
  }

  private async notifyAdmin(
    id: string,
    email: string,
    dto: PlanRequestDto,
    userId: string | null,
  ): Promise<void> {
    const adminEmail = process.env.ADMIN_EMAIL;
    if (!adminEmail) {
      this.logger.warn(
        'ADMIN_EMAIL not set — plan-request notification suppressed',
      );
      return;
    }

    const subject = `[Instructor] Plan request — ${dto.title.slice(0, 80)}`;
    const body = [
      'A new plan request was submitted from the app.',
      '',
      `Request ID  : ${id}`,
      `User ID     : ${userId ?? '(anonymous)'}`,
      `Email       : ${email}`,
      `Category    : ${dto.category ?? '(not specified)'}`,
      `Title       : ${dto.title}`,
      '',
      'Description',
      '-----------',
      dto.description,
      '',
      `Received    : ${new Date().toISOString()}`,
    ].join('\n');

    try {
      await this.ses.sendAdminEmail(adminEmail, subject, body);
      this.logger.log(`Admin notification sent for plan request ${id}`);
    } catch (err) {
      this.logger.error(
        `Failed to send admin notification for plan request ${id}: ${(err as Error).message}`,
      );
    }
  }
}
