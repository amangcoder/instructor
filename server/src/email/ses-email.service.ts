/**
 * SESEmailService — replaces Nodemailer/SMTP email sending with AWS SES SDK v3.
 *
 * Eliminates SMTP port restrictions on Lambda (outbound port 25 is blocked;
 * SMTP requires 465/587 which must be explicitly enabled and adds cold-start overhead).
 *
 * Environment variables:
 *   SES_FROM_EMAIL   — verified SES sender address (required in production)
 *   AWS_REGION       — AWS region for SES endpoint (default: ap-south-1)
 */

import { Injectable, Logger } from '@nestjs/common';
import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses';

const DEFAULT_FROM_EMAIL = '"Instructor App" <noreply@instructor.app>';

@Injectable()
export class SESEmailService {
  private readonly logger = new Logger(SESEmailService.name);
  private readonly ses: SESClient;
  private readonly fromEmail: string;

  constructor() {
    const region = process.env.AWS_REGION ?? 'ap-south-1';
    this.ses = new SESClient({ region });
    this.fromEmail = process.env.SES_FROM_EMAIL ?? DEFAULT_FROM_EMAIL;

    this.logger.log(`SESEmailService initialised — from=${this.fromEmail}, region=${region}`);
  }

  /**
   * Send a one-time password verification email via AWS SES.
   *
   * @param recipientEmail  Destination email address
   * @param code            Plaintext 6-digit OTP code
   * @throws Error if SES rejects the request (throttling, access denied, etc.)
   */
  async sendOtpEmail(recipientEmail: string, code: string): Promise<void> {
    const command = new SendEmailCommand({
      Source: this.fromEmail,
      Destination: {
        ToAddresses: [recipientEmail],
      },
      Message: {
        Subject: {
          Data: 'Your Instructor App verification code',
          Charset: 'UTF-8',
        },
        Body: {
          Text: {
            Data: `Your Instructor App verification code is: ${code}\n\nThis code expires in 5 minutes.\n\nIf you did not request this, please ignore this email.`,
            Charset: 'UTF-8',
          },
          Html: {
            Data: `
              <p>Your Instructor App verification code is:</p>
              <h2 style="letter-spacing:0.3em;font-family:monospace">${code}</h2>
              <p>This code expires in 5 minutes.</p>
              <p>If you did not request this, please ignore this email.</p>
            `,
            Charset: 'UTF-8',
          },
        },
      },
    });

    const result = await this.ses.send(command);
    this.logger.log(
      `OTP email sent to ${recipientEmail} — MessageId=${result.MessageId}`,
    );
  }
}
