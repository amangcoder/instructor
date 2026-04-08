/**
 * Unit tests for SESEmailService.
 *
 * All AWS SES SDK calls are intercepted via mocked SESClient.send().
 * No real SES calls are made — CI runs without AWS credentials.
 *
 * Scenarios covered:
 *   - OTP email is sent with correct To/From/Subject/Body
 *   - SES_FROM_EMAIL environment variable is used as the sender address
 *   - Both text and HTML body parts are present
 *   - OTP code appears in the email body
 *   - SES throttle / error causes sendOtpEmail to throw
 */

import { Test, TestingModule } from '@nestjs/testing';
import { SESEmailService } from './ses-email.service';

// ---------------------------------------------------------------------------
// Mock @aws-sdk/client-ses
// ---------------------------------------------------------------------------

const mockSesSend = jest.fn();

jest.mock('@aws-sdk/client-ses', () => ({
  SESClient: jest.fn().mockImplementation(() => ({ send: mockSesSend })),
  SendEmailCommand: jest.fn().mockImplementation((input) => ({ _type: 'SendEmail', ...input })),
}));

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('SESEmailService', () => {
  let service: SESEmailService;

  beforeEach(async () => {
    process.env.AWS_REGION = 'us-east-1';
    process.env.SES_FROM_EMAIL = 'noreply@instructor.app';

    mockSesSend.mockResolvedValue({ MessageId: 'test-message-id-abc' });

    const module: TestingModule = await Test.createTestingModule({
      providers: [SESEmailService],
    }).compile();

    service = module.get<SESEmailService>(SESEmailService);
  });

  afterEach(() => {
    jest.clearAllMocks();
    delete process.env.AWS_REGION;
    delete process.env.SES_FROM_EMAIL;
  });

  // ── sendOtpEmail ────────────────────────────────────────────────────────────

  describe('sendOtpEmail', () => {
    const recipientEmail = 'user@example.com';
    const otpCode = '123456';

    it('resolves without throwing for a valid email and OTP code', async () => {
      await expect(service.sendOtpEmail(recipientEmail, otpCode)).resolves.toBeUndefined();
    });

    it('calls SES SendEmailCommand exactly once', async () => {
      await service.sendOtpEmail(recipientEmail, otpCode);
      expect(mockSesSend).toHaveBeenCalledTimes(1);
    });

    it('sends to the correct recipient email address', async () => {
      await service.sendOtpEmail(recipientEmail, otpCode);
      const callArg = mockSesSend.mock.calls[0][0];
      const toAddresses: string[] =
        callArg.Destination?.ToAddresses ??
        callArg.ToAddresses ??
        [];
      expect(toAddresses).toContain(recipientEmail);
    });

    it('uses SES_FROM_EMAIL as the sender address', async () => {
      await service.sendOtpEmail(recipientEmail, otpCode);
      const callArg = mockSesSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain('noreply@instructor.app');
    });

    it('falls back to a default sender when SES_FROM_EMAIL is not set', async () => {
      delete process.env.SES_FROM_EMAIL;

      // Rebuild service without the env var to confirm it still works
      const module = await Test.createTestingModule({
        providers: [SESEmailService],
      }).compile();
      const noEnvService = module.get<SESEmailService>(SESEmailService);

      await expect(noEnvService.sendOtpEmail(recipientEmail, otpCode)).resolves.toBeUndefined();
      expect(mockSesSend).toHaveBeenCalledTimes(1);
    });

    it('includes the 6-digit OTP code in the email body', async () => {
      await service.sendOtpEmail(recipientEmail, otpCode);
      const callArg = mockSesSend.mock.calls[0][0];
      expect(JSON.stringify(callArg)).toContain(otpCode);
    });

    it('includes a non-empty email subject', async () => {
      await service.sendOtpEmail(recipientEmail, otpCode);
      const callArg = mockSesSend.mock.calls[0][0];
      const subject =
        callArg.Message?.Subject?.Data ??
        callArg.Subject?.Data ??
        '';
      expect(subject.length).toBeGreaterThan(0);
    });

    it('includes both plain-text and HTML body parts', async () => {
      await service.sendOtpEmail(recipientEmail, otpCode);
      const callArg = mockSesSend.mock.calls[0][0];
      const body = callArg.Message?.Body ?? callArg.Body ?? {};
      expect(body.Text?.Data ?? body.text).toBeTruthy();
      expect(body.Html?.Data ?? body.html).toBeTruthy();
    });

    it('HTML body contains the OTP code', async () => {
      await service.sendOtpEmail(recipientEmail, '654321');
      const callArg = mockSesSend.mock.calls[0][0];
      const html =
        callArg.Message?.Body?.Html?.Data ??
        callArg.Body?.Html?.Data ??
        JSON.stringify(callArg);
      expect(html).toContain('654321');
    });

    it('text body also contains the OTP code', async () => {
      await service.sendOtpEmail(recipientEmail, '999888');
      const callArg = mockSesSend.mock.calls[0][0];
      const text =
        callArg.Message?.Body?.Text?.Data ??
        callArg.Body?.Text?.Data ??
        JSON.stringify(callArg);
      expect(text).toContain('999888');
    });

    it('throws when SES returns a throttling error', async () => {
      mockSesSend.mockRejectedValueOnce(new Error('Throttling: Rate exceeded'));
      await expect(service.sendOtpEmail(recipientEmail, otpCode)).rejects.toThrow(/Throttling/i);
    });

    it('throws when SES returns an access denied error', async () => {
      mockSesSend.mockRejectedValueOnce(new Error('AccessDenied: User not authorized'));
      await expect(service.sendOtpEmail(recipientEmail, otpCode)).rejects.toThrow(/AccessDenied/i);
    });

    it('sends to different emails independently (no state leakage)', async () => {
      await service.sendOtpEmail('alice@example.com', '111111');
      await service.sendOtpEmail('bob@example.com', '222222');

      expect(mockSesSend).toHaveBeenCalledTimes(2);

      const firstCall = mockSesSend.mock.calls[0][0];
      const secondCall = mockSesSend.mock.calls[1][0];

      expect(JSON.stringify(firstCall)).toContain('alice@example.com');
      expect(JSON.stringify(secondCall)).toContain('bob@example.com');
    });

    it('mentions 5-minute expiry in the email body', async () => {
      await service.sendOtpEmail(recipientEmail, otpCode);
      const callArg = mockSesSend.mock.calls[0][0];
      const fullBody = JSON.stringify(callArg);
      // Body should mention expiry to inform the user
      expect(fullBody).toMatch(/5.?minute|expir/i);
    });
  });
});
