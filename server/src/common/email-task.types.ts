/**
 * Shared types for email task dispatch and Lambda event handling.
 *
 * This file breaks the circular dependency between server/src/lambda.ts and
 * server/src/email/ses-email.service.ts. By placing the type in CommonModule
 * (which neither email nor server root imports), both modules can reference it
 * without creating a cycle.
 */

export interface SendOtpEmailTask {
  task: 'sendOtpEmail';
  to: string;
  code: string;
}
