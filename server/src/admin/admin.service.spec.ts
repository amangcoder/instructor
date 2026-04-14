/**
 * Unit tests for AdminService.
 *
 * AdminService never queries users — it only inserts into deletion_requests.
 * We mock the DB layer by spying on the neon / drizzle internals and mock
 * SESEmailService.sendAdminEmail.
 */

import { Test, TestingModule } from '@nestjs/testing';
import { AdminService } from './admin.service';
import { SESEmailService } from '../email/ses-email.service';
import type { DeletionRequestDto } from './dto/deletion-request.dto';

// ---------------------------------------------------------------------------
// Mock SESEmailService
// ---------------------------------------------------------------------------

function createMockSESEmailService() {
  return {
    sendAdminEmail: jest.fn().mockResolvedValue(undefined),
    dispatchOtpEmail: jest.fn().mockResolvedValue(undefined),
    sendOtpEmail: jest.fn().mockResolvedValue(undefined),
  };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeDto(overrides: Partial<DeletionRequestDto> = {}): DeletionRequestDto {
  return {
    email: 'user@example.com',
    scope: 'full_account',
    reason: 'No longer using the app',
    requestedAt: new Date().toISOString(),
    ...overrides,
  } as DeletionRequestDto;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('AdminService', () => {
  let service: AdminService;
  let ses: ReturnType<typeof createMockSESEmailService>;

  beforeEach(async () => {
    ses = createMockSESEmailService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AdminService,
        { provide: SESEmailService, useValue: ses },
      ],
    }).compile();

    service = module.get<AdminService>(AdminService);

    // Force noop mode so no DB calls are made in unit tests.
    (service as any).noop = true;
    (service as any).db = null;
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('processDeletionRequest', () => {
    it('returns an id and a message on success', async () => {
      const dto = makeDto();
      process.env.ADMIN_EMAIL = 'admin@example.com';

      const result = await service.processDeletionRequest(dto);

      expect(result.id).toMatch(
        /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
      );
      expect(result.message).toBeTruthy();
    });

    it('calls sendAdminEmail when ADMIN_EMAIL is set', async () => {
      process.env.ADMIN_EMAIL = 'admin@example.com';
      const dto = makeDto({ scope: 'plans' });

      await service.processDeletionRequest(dto);

      expect(ses.sendAdminEmail).toHaveBeenCalledTimes(1);
      const [to, subject, body] = ses.sendAdminEmail.mock.calls[0] as [string, string, string];
      expect(to).toBe('admin@example.com');
      expect(subject).toContain('plans');
      expect(body).toContain('user@example.com');
    });

    it('does NOT call sendAdminEmail when ADMIN_EMAIL is unset', async () => {
      delete process.env.ADMIN_EMAIL;
      const dto = makeDto();

      await service.processDeletionRequest(dto);

      expect(ses.sendAdminEmail).not.toHaveBeenCalled();
    });

    it('does NOT crash when sendAdminEmail throws', async () => {
      process.env.ADMIN_EMAIL = 'admin@example.com';
      ses.sendAdminEmail.mockRejectedValueOnce(new Error('SES error'));

      const dto = makeDto();
      await expect(service.processDeletionRequest(dto)).resolves.not.toThrow();
    });

    it('uses the reason value when provided', async () => {
      process.env.ADMIN_EMAIL = 'admin@example.com';
      const dto = makeDto({ reason: 'Privacy concerns' });

      await service.processDeletionRequest(dto);

      const [, , body] = ses.sendAdminEmail.mock.calls[0] as [string, string, string];
      expect(body).toContain('Privacy concerns');
    });

    it('shows "(none provided)" in body when reason is omitted', async () => {
      process.env.ADMIN_EMAIL = 'admin@example.com';
      const dto = makeDto({ reason: undefined });

      await service.processDeletionRequest(dto);

      const [, , body] = ses.sendAdminEmail.mock.calls[0] as [string, string, string];
      expect(body).toContain('(none provided)');
    });
  });
});
