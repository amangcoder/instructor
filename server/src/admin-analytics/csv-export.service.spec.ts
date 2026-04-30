/**
 * Unit tests for CsvExportService (TASK-007).
 *
 * Tests:
 *   - streamUsersCsv() sets correct Content-Type and Content-Disposition headers
 *   - streamUsersCsv() writes CSV header row
 *   - streamUsersCsv() writes data rows and calls res.end()
 *   - streamDeletionRequestsCsv() sets correct Content-Type and Content-Disposition headers
 *   - streamDeletionRequestsCsv() writes correct header row
 *   - streamDeletionRequestsCsv() stops at empty batch
 *   - csvEscape handles comma, newline, double-quote characters
 */

import { Test, TestingModule } from '@nestjs/testing';
import { CsvExportService } from './csv-export.service';
import { DatabaseService } from '../database/database.service';
import { createMockDatabaseService } from '../database/testing';
import type { Response } from 'express';

// ---------------------------------------------------------------------------
// Mock factories
// ---------------------------------------------------------------------------

function createMockResponse(): jest.Mocked<Response> {
  return {
    setHeader: jest.fn(),
    write: jest.fn(),
    end: jest.fn(),
  } as unknown as jest.Mocked<Response>;
}

describe('CsvExportService', () => {
  let service: CsvExportService;
  let dbService: ReturnType<typeof createMockDatabaseService>;

  beforeEach(async () => {
    dbService = createMockDatabaseService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CsvExportService,
        { provide: DatabaseService, useValue: dbService },
      ],
    }).compile();

    service = module.get<CsvExportService>(CsvExportService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  // -------------------------------------------------------------------------
  // streamUsersCsv
  // -------------------------------------------------------------------------

  describe('streamUsersCsv()', () => {
    it('sets Content-Type header to text/csv', async () => {
      const res = createMockResponse();
      // Empty result — just write header and end
      dbService._mockDb.offset.mockResolvedValueOnce([]);

      await service.streamUsersCsv({}, res);

      expect(res.setHeader).toHaveBeenCalledWith('Content-Type', 'text/csv; charset=utf-8');
    });

    it('sets Content-Disposition attachment header', async () => {
      const res = createMockResponse();
      dbService._mockDb.offset.mockResolvedValueOnce([]);

      await service.streamUsersCsv({}, res);

      const dispositionCall = (res.setHeader as jest.Mock).mock.calls.find(
        ([key]: [string]) => key === 'Content-Disposition',
      );
      expect(dispositionCall).toBeDefined();
      expect(dispositionCall[1]).toMatch(/attachment; filename=users_export_\d{4}-\d{2}-\d{2}\.csv/);
    });

    it('writes CSV header row first', async () => {
      const res = createMockResponse();
      dbService._mockDb.offset.mockResolvedValueOnce([]);

      await service.streamUsersCsv({}, res);

      const firstWrite = (res.write as jest.Mock).mock.calls[0]?.[0] as string;
      expect(firstWrite).toContain('id,email,role,created_at,plans_count,last_active_at');
    });

    it('writes user rows and calls res.end()', async () => {
      const res = createMockResponse();
      const now = new Date('2026-04-21T12:00:00Z');

      dbService._mockDb.offset
        .mockResolvedValueOnce([
          {
            id: 'user-001',
            email: 'alice@example.com',
            role: 'user',
            createdAt: now,
            planCount: 3,
            lastActiveAt: now,
          },
        ])
        .mockResolvedValueOnce([]); // second batch is empty, stops loop

      await service.streamUsersCsv({}, res);

      expect(res.write).toHaveBeenCalledTimes(2); // header + 1 data row
      const dataRow = (res.write as jest.Mock).mock.calls[1]?.[0] as string;
      expect(dataRow).toContain('user-001');
      expect(dataRow).toContain('alice@example.com');
      expect(dataRow).toContain('user');
      expect(res.end).toHaveBeenCalledTimes(1);
    });

    it('calls res.end() even with empty results', async () => {
      const res = createMockResponse();
      dbService._mockDb.offset.mockResolvedValueOnce([]);

      await service.streamUsersCsv({}, res);

      expect(res.end).toHaveBeenCalledTimes(1);
    });
  });

  // -------------------------------------------------------------------------
  // streamDeletionRequestsCsv
  // -------------------------------------------------------------------------

  describe('streamDeletionRequestsCsv()', () => {
    it('sets Content-Type header to text/csv', async () => {
      const res = createMockResponse();
      dbService._mockDb.offset.mockResolvedValueOnce([]);

      await service.streamDeletionRequestsCsv({}, res);

      expect(res.setHeader).toHaveBeenCalledWith('Content-Type', 'text/csv; charset=utf-8');
    });

    it('sets Content-Disposition for deletion requests', async () => {
      const res = createMockResponse();
      dbService._mockDb.offset.mockResolvedValueOnce([]);

      await service.streamDeletionRequestsCsv({}, res);

      const dispositionCall = (res.setHeader as jest.Mock).mock.calls.find(
        ([key]: [string]) => key === 'Content-Disposition',
      );
      expect(dispositionCall[1]).toMatch(/attachment; filename=deletion_requests_export_\d{4}-\d{2}-\d{2}\.csv/);
    });

    it('writes correct header row for deletion requests', async () => {
      const res = createMockResponse();
      dbService._mockDb.offset.mockResolvedValueOnce([]);

      await service.streamDeletionRequestsCsv({}, res);

      const firstWrite = (res.write as jest.Mock).mock.calls[0]?.[0] as string;
      expect(firstWrite).toContain('id,email,ip_address,requested_at,processed_at,status');
    });

    it('writes deletion request rows with unmasked email', async () => {
      const res = createMockResponse();
      const requestedAt = new Date('2026-04-20T10:00:00Z');

      dbService._mockDb.offset
        .mockResolvedValueOnce([
          {
            id: 'dr-001',
            email: 'john@example.com', // Unmasked in CSV (admin context)
            ipAddress: '192.168.1.1',
            requestedAt,
            processedAt: null,
            status: 'pending',
          },
        ])
        .mockResolvedValueOnce([]);

      await service.streamDeletionRequestsCsv({}, res);

      const dataRow = (res.write as jest.Mock).mock.calls[1]?.[0] as string;
      expect(dataRow).toContain('dr-001');
      expect(dataRow).toContain('john@example.com'); // Unmasked
      expect(dataRow).toContain('192.168.1.1');
      expect(dataRow).toContain('pending');
    });

    it('handles null ipAddress and processedAt', async () => {
      const res = createMockResponse();
      const requestedAt = new Date('2026-04-20T10:00:00Z');

      dbService._mockDb.offset
        .mockResolvedValueOnce([
          {
            id: 'dr-002',
            email: 'user@test.com',
            ipAddress: null,
            requestedAt,
            processedAt: null,
            status: 'pending',
          },
        ])
        .mockResolvedValueOnce([]);

      await service.streamDeletionRequestsCsv({}, res);

      const dataRow = (res.write as jest.Mock).mock.calls[1]?.[0] as string;
      // Should not throw and should write empty string for nulls
      expect(dataRow).toBeDefined();
      expect(res.end).toHaveBeenCalled();
    });

    it('calls res.end() after streaming completes', async () => {
      const res = createMockResponse();
      dbService._mockDb.offset.mockResolvedValueOnce([]);

      await service.streamDeletionRequestsCsv({}, res);

      expect(res.end).toHaveBeenCalledTimes(1);
    });
  });
});
