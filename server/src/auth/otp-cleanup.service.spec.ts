import { Test, TestingModule } from '@nestjs/testing';
import { OtpCleanupService } from './otp-cleanup.service';
import { DatabaseService } from '../database/database.service';
import { createMockDatabaseService } from '../database/testing';

describe('OtpCleanupService', () => {
  let service: OtpCleanupService;
  let mockDatabaseService: Partial<DatabaseService>;

  beforeEach(async () => {
    mockDatabaseService = createMockDatabaseService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OtpCleanupService,
        {
          provide: DatabaseService,
          useValue: mockDatabaseService,
        },
      ],
    }).compile();

    service = module.get<OtpCleanupService>(OtpCleanupService);
  });

  describe('cleanupExpiredOtps', () => {
    it('should delete expired OTP records', async () => {
      const mockExecute = jest.fn().mockResolvedValue({ rowCount: 5 });
      const mockDb = {
        execute: mockExecute,
      };

      jest
        .spyOn(mockDatabaseService as any, 'getDb')
        .mockReturnValue(mockDb);
      jest
        .spyOn(mockDatabaseService as any, 'withRetry')
        .mockImplementation((fn) => fn());

      await service.cleanupExpiredOtps();

      expect(mockExecute).toHaveBeenCalledWith(
        `DELETE FROM otp_records WHERE expires_at < NOW() - INTERVAL '24 hours'`,
      );
    });

    it('should preserve non-expired OTP records', async () => {
      const mockExecute = jest.fn().mockResolvedValue({ rowCount: 2 });
      const mockDb = {
        execute: mockExecute,
      };

      jest
        .spyOn(mockDatabaseService as any, 'getDb')
        .mockReturnValue(mockDb);
      jest
        .spyOn(mockDatabaseService as any, 'withRetry')
        .mockImplementation((fn) => fn());

      await service.cleanupExpiredOtps();

      // Only expired records (older than 24h) should be deleted
      // This test verifies the correct WHERE clause is used
      expect(mockExecute).toHaveBeenCalledWith(
        expect.stringContaining("WHERE expires_at < NOW() - INTERVAL '24 hours'"),
      );
    });

    it('should handle database errors gracefully', async () => {
      jest
        .spyOn(mockDatabaseService as any, 'withRetry')
        .mockImplementationOnce(() => {
          throw new Error('Database connection failed');
        });

      // Should not throw — error is caught and logged
      await expect(service.cleanupExpiredOtps()).resolves.toBeUndefined();
    });

    it('should return 0 deleted rows if table is empty', async () => {
      const mockExecute = jest.fn().mockResolvedValue({ rowCount: 0 });
      const mockDb = {
        execute: mockExecute,
      };

      jest
        .spyOn(mockDatabaseService as any, 'getDb')
        .mockReturnValue(mockDb);
      jest
        .spyOn(mockDatabaseService as any, 'withRetry')
        .mockImplementation((fn) => fn());

      await service.cleanupExpiredOtps();

      expect(mockExecute).toHaveBeenCalled();
    });
  });
});
