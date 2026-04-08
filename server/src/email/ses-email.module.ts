/**
 * SESEmailModule — global module providing SESEmailService.
 *
 * Import once in AppModule. Replaces the Nodemailer SMTP transporter
 * that was previously configured in AuthService.onModuleInit().
 */

import { Global, Module } from '@nestjs/common';
import { SESEmailService } from './ses-email.service';

@Global()
@Module({
  providers: [SESEmailService],
  exports: [SESEmailService],
})
export class SESEmailModule {}
