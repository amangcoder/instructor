/**
 * AdminService — processes data-deletion requests.
 *
 * Security design:
 *   - Does NOT query the users table (email enumeration prevention).
 *     The presence or absence of an email in users must never be exposed to
 *     the submitter, even indirectly via timing differences.
 *   - Logs the request to deletion_requests unconditionally.
 *   - Sends a notification email to ADMIN_EMAIL for manual review.
 *
 * Environment variables:
 *   ADMIN_EMAIL — destination address for deletion-request notifications
 */

import { Injectable, Logger } from '@nestjs/common';
import { v4 as uuidv4 } from 'uuid';
import { DatabaseService } from '../database/database.service';
import { SESEmailService } from '../email/ses-email.service';
import type { DeletionRequestDto } from './dto/deletion-request.dto';

export interface DeletionRequestResult {
  id: string;
  message: string;
}

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);

  constructor(
    private readonly db: DatabaseService,
    private readonly ses: SESEmailService,
  ) {}

  /**
   * Process an inbound deletion request:
   *   1. Insert a row into deletion_requests (no users-table query).
   *   2. Send a notification email to ADMIN_EMAIL for manual review.
   *
   * @param dto  Validated deletion-request payload
   * @returns    { id, message } — id is the new row UUID
   */
  async processDeletionRequest(dto: DeletionRequestDto): Promise<DeletionRequestResult> {
    const id = uuidv4();

    // ── 1. Persist the request ─────────────────────────────────────────────
    if (!this.db.noop) {
      await this.db.insertDeletionRequest({
        id,
        email: dto.email.toLowerCase().trim(),
        scope: dto.scope.join(','),
        reason: dto.reason ?? null,
        requestedAt: new Date(dto.requestedAt),
        createdAt: new Date(),
      });
    } else {
      this.logger.warn(`[noop] Deletion request NOT persisted: id=${id}`);
    }

    // ── 2. Notify admin ────────────────────────────────────────────────────
    await this.sendAdminNotification(id, dto);

    return {
      id,
      message:
        'Your deletion request has been received. ' +
        'We will process it within 30 days and confirm via email.',
    };
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  private async sendAdminNotification(
    id: string,
    dto: DeletionRequestDto,
  ): Promise<void> {
    const adminEmail = process.env.ADMIN_EMAIL;

    if (!adminEmail) {
      this.logger.warn(
        'ADMIN_EMAIL not set — deletion-request notification suppressed',
      );
      return;
    }

    const subject = `[Instructor] Data Deletion Request — ${dto.scope} (${id})`;
    const body = [
      `A new data-deletion request was received.`,
      ``,
      `Request ID : ${id}`,
      `Email      : ${dto.email}`,
      `Scope      : ${dto.scope}`,
      `Reason     : ${dto.reason ?? '(none provided)'}`,
      `Requested  : ${dto.requestedAt}`,
      `Received   : ${new Date().toISOString()}`,
      ``,
      `Please review and process this request within 30 days.`,
    ].join('\n');

    try {
      await this.ses.sendAdminEmail(adminEmail, subject, body);
      this.logger.log(`Admin notification sent for deletion request ${id}`);
    } catch (err) {
      // Non-fatal: the request is already persisted; log and continue.
      this.logger.error(
        `Failed to send admin notification for deletion request ${id}: ${(err as Error).message}`,
      );
    }
  }
}
