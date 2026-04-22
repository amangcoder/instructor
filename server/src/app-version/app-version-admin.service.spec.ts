/**
 * Unit tests for AppVersionAdminService (TASK-009).
 *
 * Tests:
 *   - getVersionConfig() returns config from DB
 *   - getVersionConfig() throws NotFoundException when no config row exists
 *   - updateVersionConfig() updates provided fields only
 *   - updateVersionConfig() throws UnprocessableEntityException when force < min
 *   - updateVersionConfig() throws NotFoundException when no config row exists
 *   - updateVersionConfig() enables/disables force update flag
 */

import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException, UnprocessableEntityException } from '@nestjs/common';
import { AppVersionAdminService } from './app-version-admin.service';
import { DatabaseService } from '../database/database.service';

// ---------------------------------------------------------------------------
// Mock factory
// ---------------------------------------------------------------------------

function createMockDatabaseService() {
  const mockDb = {
    select: jest.fn().mockReturnThis(),
    from: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    update: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    returning: jest.fn().mockResolvedValue([]),
  };

  return {
    getDb: jest.fn().mockReturnValue(mockDb),
    withRetry: jest.fn().mockImplementation(async (fn: () => Promise<any>) => fn()),
    _mockDb: mockDb,
  };
}

const DEFAULT_CONFIG = {
  id: 'config-uuid-001',
  iosMinVersion: '1.0.0',
  androidMinVersion: '1.0.0',
  iosForceVersion: '1.0.5',
  androidForceVersion: '1.0.5',
  forceUpdateEnabled: false,
  updatedAt: new Date('2026-04-21T12:00:00Z'),
};

describe('AppVersionAdminService', () => {
  let service: AppVersionAdminService;
  let dbService: ReturnType<typeof createMockDatabaseService>;

  beforeEach(async () => {
    dbService = createMockDatabaseService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AppVersionAdminService,
        { provide: DatabaseService, useValue: dbService },
      ],
    }).compile();

    service = module.get<AppVersionAdminService>(AppVersionAdminService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  // -------------------------------------------------------------------------
  // getVersionConfig
  // -------------------------------------------------------------------------

  describe('getVersionConfig()', () => {
    it('returns version config when row exists', async () => {
      dbService._mockDb.limit.mockResolvedValueOnce([DEFAULT_CONFIG]);

      const result = await service.getVersionConfig();

      expect(result.ios.minVersion).toBe('1.0.0');
      expect(result.ios.forceUpdateVersion).toBe('1.0.5');
      expect(result.android.minVersion).toBe('1.0.0');
      expect(result.android.forceUpdateVersion).toBe('1.0.5');
      expect(result.enabled).toBe(false);
    });

    it('returns null versions when columns are null', async () => {
      dbService._mockDb.limit.mockResolvedValueOnce([
        {
          ...DEFAULT_CONFIG,
          iosMinVersion: null,
          androidMinVersion: null,
          iosForceVersion: null,
          androidForceVersion: null,
        },
      ]);

      const result = await service.getVersionConfig();

      expect(result.ios.minVersion).toBeNull();
      expect(result.ios.forceUpdateVersion).toBeNull();
      expect(result.android.minVersion).toBeNull();
      expect(result.android.forceUpdateVersion).toBeNull();
    });

    it('throws NotFoundException when no config row exists', async () => {
      dbService._mockDb.limit.mockResolvedValueOnce([]);

      await expect(service.getVersionConfig()).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  // -------------------------------------------------------------------------
  // updateVersionConfig
  // -------------------------------------------------------------------------

  describe('updateVersionConfig()', () => {
    it('updates iosMinVersion and returns updated config', async () => {
      // Read current config
      dbService._mockDb.limit.mockResolvedValueOnce([DEFAULT_CONFIG]);

      const updatedConfig = {
        ...DEFAULT_CONFIG,
        iosMinVersion: '1.1.0',
      };
      // Update returning
      dbService._mockDb.returning.mockResolvedValueOnce([updatedConfig]);

      const result = await service.updateVersionConfig({ iosMinVersion: '1.1.0' });

      expect(result.ios.minVersion).toBe('1.1.0');
    });

    it('enables force update flag', async () => {
      dbService._mockDb.limit.mockResolvedValueOnce([DEFAULT_CONFIG]);

      const updatedConfig = { ...DEFAULT_CONFIG, forceUpdateEnabled: true };
      dbService._mockDb.returning.mockResolvedValueOnce([updatedConfig]);

      const result = await service.updateVersionConfig({ forceUpdateEnabled: true });

      expect(result.enabled).toBe(true);
    });

    it('throws UnprocessableEntityException when iOS force < min', async () => {
      dbService._mockDb.limit.mockResolvedValueOnce([DEFAULT_CONFIG]);

      await expect(
        service.updateVersionConfig({
          iosMinVersion: '2.0.0',
          iosForceVersion: '1.5.0', // force < min
        }),
      ).rejects.toBeInstanceOf(UnprocessableEntityException);
    });

    it('throws UnprocessableEntityException when Android force < min', async () => {
      dbService._mockDb.limit.mockResolvedValueOnce([DEFAULT_CONFIG]);

      await expect(
        service.updateVersionConfig({
          androidMinVersion: '2.0.0',
          androidForceVersion: '1.0.0', // force < min
        }),
      ).rejects.toBeInstanceOf(UnprocessableEntityException);
    });

    it('allows force version equal to min version', async () => {
      dbService._mockDb.limit.mockResolvedValueOnce([DEFAULT_CONFIG]);

      const updatedConfig = {
        ...DEFAULT_CONFIG,
        iosMinVersion: '1.2.0',
        iosForceVersion: '1.2.0', // force === min is OK
      };
      dbService._mockDb.returning.mockResolvedValueOnce([updatedConfig]);

      const result = await service.updateVersionConfig({
        iosMinVersion: '1.2.0',
        iosForceVersion: '1.2.0',
      });

      expect(result.ios.minVersion).toBe('1.2.0');
      expect(result.ios.forceUpdateVersion).toBe('1.2.0');
    });

    it('throws NotFoundException when config row does not exist', async () => {
      dbService._mockDb.limit.mockResolvedValueOnce([]);

      await expect(service.updateVersionConfig({})).rejects.toBeInstanceOf(NotFoundException);
    });

    it('merges DTO with existing values (partial update)', async () => {
      // Only iosMinVersion is provided, other fields stay from DEFAULT_CONFIG
      dbService._mockDb.limit.mockResolvedValueOnce([DEFAULT_CONFIG]);

      const updatedConfig = {
        ...DEFAULT_CONFIG,
        iosMinVersion: '1.2.0',
      };
      dbService._mockDb.returning.mockResolvedValueOnce([updatedConfig]);

      const result = await service.updateVersionConfig({ iosMinVersion: '1.2.0' });

      // ios force version should remain unchanged (1.0.5 from DEFAULT_CONFIG)
      expect(result.ios.forceUpdateVersion).toBe('1.0.5');
      expect(result.android.minVersion).toBe('1.0.0');
    });
  });
});
