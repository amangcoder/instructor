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

import { Injectable, Logger, Optional, Inject } from '@nestjs/common';
import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses';
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import type { SendOtpEmailTask } from '../common/email-task.types';
import type { AppConfig } from '../config/app-config.interface';

const DEFAULT_FROM_EMAIL = '"Instructor App" <instructor.app@layersiq.com>';

@Injectable()
export class SESEmailService {
  private readonly logger = new Logger(SESEmailService.name);
  private readonly ses: SESClient;
  private readonly lambda: LambdaClient;
  private readonly fromEmail: string;
  private readonly lambdaFunctionName: string | null;

  constructor(@Optional() @Inject('APP_CONFIG') config?: AppConfig) {
    const region = config?.awsRegion ?? process.env.AWS_REGION ?? 'ap-south-1';
    this.ses = new SESClient({ region });
    this.lambda = new LambdaClient({ region });
    this.fromEmail = config?.sesFromEmail || process.env.SES_FROM_EMAIL || DEFAULT_FROM_EMAIL;
    this.lambdaFunctionName = (config?.lambdaFunctionName || process.env.AWS_LAMBDA_FUNCTION_NAME) ?? null;

    this.logger.log(`SESEmailService initialised — from=${this.fromEmail}, region=${region}`);
  }

  /**
   * Dispatch OTP email asynchronously by invoking this same Lambda function
   * with InvocationType='Event'. Returns immediately — the email is sent in
   * a separate Lambda invocation that runs independently of the HTTP response.
   *
   * Falls back to direct SES send if not running in Lambda (local dev).
   */
  async dispatchOtpEmail(recipientEmail: string, code: string): Promise<void> {
    const functionName = this.lambdaFunctionName;

    if (!functionName) {
      // Local dev: send directly (no async Lambda available).
      await this.sendOtpEmail(recipientEmail, code);
      return;
    }

    const payload: SendOtpEmailTask = { task: 'sendOtpEmail', to: recipientEmail, code };

    await this.lambda.send(
      new InvokeCommand({
        FunctionName: functionName,
        InvocationType: 'Event', // async — returns 202, doesn't wait for execution
        Payload: Buffer.from(JSON.stringify(payload)),
      }),
    );

    this.logger.log(`OTP email dispatched async for ${recipientEmail}`);
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

  /**
   * Send a plain-text admin notification email (e.g. deletion-request alerts).
   *
   * @param toEmail   Recipient address (typically ADMIN_EMAIL)
   * @param subject   Email subject line
   * @param body      Plain-text body
   */
  async sendAdminEmail(toEmail: string, subject: string, body: string): Promise<void> {
    const command = new SendEmailCommand({
      Source: this.fromEmail,
      Destination: {
        ToAddresses: [toEmail],
      },
      Message: {
        Subject: {
          Data: subject,
          Charset: 'UTF-8',
        },
        Body: {
          Text: {
            Data: body,
            Charset: 'UTF-8',
          },
        },
      },
    });

    const result = await this.ses.send(command);
    this.logger.log(
      `Admin email sent to ${toEmail} — MessageId=${result.MessageId}`,
    );
  }
}
