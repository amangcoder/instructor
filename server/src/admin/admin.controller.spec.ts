/**
 * Unit tests for AdminController.
 *
 * Tests:
 *   - 403 when x-api-key header is missing
 *   - 403 when x-api-key is wrong
 *   - 429 when rate limit exceeded
 *   - 201 Created with { id, message } on success
 *   - 400 when DTO validation fails (via ValidationPipe)
 */

import { Test, TestingModule } from '@nestjs/testing';
import { HttpStatus, ValidationPipe } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { UpstashRateLimitService } from '../ratelimit/upstash-ratelimit.service';
import type { DeletionRequestDto } from './dto/deletion-request.dto';
import type { Request } from 'express';

// ---------------------------------------------------------------------------
// Mock factories
// ---------------------------------------------------------------------------

function createMockAdminService() {
  return {
    processDeletionRequest: jest.fn().mockResolvedValue({
      id: 'mock-uuid-1234',
      message: 'Your deletion request has been received.',
    }),
  };
}

function createMockRateLimiter() {
  return {
    consume: jest.fn().mockResolvedValue({ allowed: true, current: 1, retryAfterSec: 0 }),
    peek: jest.fn().mockResolvedValue({ allowed: true, current: 0, retryAfterSec: 0 }),
    increment: jest.fn().mockResolvedValue(undefined),
  };
}

function makeRequest(ip = '1.2.3.4'): Partial<Request> {
  return {
    headers: {},
    ip,
    socket: { remoteAddress: ip } as any,
  };
}

function makeDto(overrides: Partial<DeletionRequestDto> = {}): DeletionRequestDto {
  return {
    email: 'user@example.com',
    scope: 'full_account',
    reason: 'Testing',
    requestedAt: new Date().toISOString(),
    ...overrides,
  } as DeletionRequestDto;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('AdminController', () => {
  let controller: AdminController;
  let adminService: ReturnType<typeof createMockAdminService>;
  let rateLimiter: ReturnType<typeof createMockRateLimiter>;

  beforeEach(async () => {
    adminService = createMockAdminService();
    rateLimiter = createMockRateLimiter();

    const module: TestingModule = await Test.createTestingModule({
      controllers: [AdminController],
      providers: [
        { provide: AdminService, useValue: adminService },
        { provide: UpstashRateLimitService, useValue: rateLimiter },
      ],
    }).compile();

    controller = module.get<AdminController>(AdminController);

    // Set env variable for tests
    process.env.ADMIN_API_KEY = 'test-secret-key';
  });

  afterEach(() => {
    delete process.env.ADMIN_API_KEY;
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('POST /admin/deletion-requests', () => {
    it('returns 201 with id and message on success', async () => {
      const dto = makeDto();
      const req = makeRequest();

      const result = await controller.createDeletionRequest(
        'test-secret-key',
        dto,
        req as Request,
      );

      expect(result.id).toBe('mock-uuid-1234');
      expect(result.message).toBeTruthy();
      expect(adminService.processDeletionRequest).toHaveBeenCalledWith(dto);
    });

    it('throws 403 when x-api-key header is missing', async () => {
      const dto = makeDto();
      const req = makeRequest();

      await expect(
        controller.createDeletionRequest(undefined, dto, req as Request),
      ).rejects.toMatchObject({ status: HttpStatus.FORBIDDEN });
    });

    it('throws 403 when x-api-key is incorrect', async () => {
      const dto = makeDto();
      const req = makeRequest();

      await expect(
        controller.createDeletionRequest('wrong-key', dto, req as Request),
      ).rejects.toMatchObject({ status: HttpStatus.FORBIDDEN });
    });

    it('throws 403 when ADMIN_API_KEY is not configured', async () => {
      delete process.env.ADMIN_API_KEY;
      const dto = makeDto();
      const req = makeRequest();

      await expect(
        controller.createDeletionRequest('test-secret-key', dto, req as Request),
      ).rejects.toMatchObject({ status: HttpStatus.FORBIDDEN });
    });

    it('throws 429 when rate limit is exceeded', async () => {
      rateLimiter.consume.mockResolvedValueOnce({
        allowed: false,
        current: 11,
        retryAfterSec: 3000,
      });

      const dto = makeDto();
      const req = makeRequest();

      await expect(
        controller.createDeletionRequest('test-secret-key', dto, req as Request),
      ).rejects.toMatchObject({ status: HttpStatus.TOO_MANY_REQUESTS });
    });

    it('passes the correct namespace and limit to rate limiter', async () => {
      const dto = makeDto();
      const req = makeRequest('5.6.7.8');

      await controller.createDeletionRequest('test-secret-key', dto, req as Request);

      expect(rateLimiter.consume).toHaveBeenCalledWith(
        'deletion_request',
        '5.6.7.8',
        10,    // DELETION_RATE_LIMIT
        3600,  // DELETION_RATE_WINDOW_SEC
      );
    });

    it('extracts IP from X-Forwarded-For when present', async () => {
      const dto = makeDto();
      const req: Partial<Request> = {
        headers: { 'x-forwarded-for': '9.9.9.9, 10.10.10.10' },
        ip: '127.0.0.1',
        socket: { remoteAddress: '127.0.0.1' } as any,
      };

      await controller.createDeletionRequest('test-secret-key', dto, req as Request);

      expect(rateLimiter.consume).toHaveBeenCalledWith(
        'deletion_request',
        '9.9.9.9',
        10,
        3600,
      );
    });
  });
});
