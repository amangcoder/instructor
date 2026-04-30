import { Test, TestingModule } from '@nestjs/testing';
import { AuthRepository } from './auth.repository';
import { DatabaseService, OtpRecord, RefreshTokenRecord } from '../database.service';
import { createMockDatabaseService } from '../testing';

describe('AuthRepository', () => {
  let repository: AuthRepository;
  let mockDb: Partial<DatabaseService>;

  beforeEach(async () => {
    mockDb = createMockDatabaseService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthRepository,
        { provide: DatabaseService, useValue: mockDb },
      ],
    }).compile();

    repository = module.get<AuthRepository>(AuthRepository);
  });

  it('createOtp delegates to DatabaseService', async () => {
    const expiresAt = new Date();
    await repository.createOtp('a@b.com', 'hash', expiresAt);
    expect(mockDb.createOtp).toHaveBeenCalledWith('a@b.com', 'hash', expiresAt);
  });

  it('getActiveOtps delegates to DatabaseService', async () => {
    const records: OtpRecord[] = [
      { id: 'id1', email: 'a@b.com', code: 'hash', expiresAt: new Date(), attempts: 0, used: false },
    ];
    (mockDb.getActiveOtps as jest.Mock).mockResolvedValue(records);
    const result = await repository.getActiveOtps('a@b.com');
    expect(result).toBe(records);
    expect(mockDb.getActiveOtps).toHaveBeenCalledWith('a@b.com');
  });

  it('markOtpUsed delegates to DatabaseService', async () => {
    await repository.markOtpUsed('a@b.com', 'otp-id');
    expect(mockDb.markOtpUsed).toHaveBeenCalledWith('a@b.com', 'otp-id');
  });

  it('incrementOtpAttempts delegates to DatabaseService', async () => {
    await repository.incrementOtpAttempts('a@b.com', 'otp-id');
    expect(mockDb.incrementOtpAttempts).toHaveBeenCalledWith('a@b.com', 'otp-id');
  });

  it('invalidateOtpsForEmail delegates to DatabaseService', async () => {
    await repository.invalidateOtpsForEmail('a@b.com');
    expect(mockDb.invalidateOtpsForEmail).toHaveBeenCalledWith('a@b.com');
  });

  it('createRefreshToken delegates to DatabaseService', async () => {
    const expiresAt = new Date();
    await repository.createRefreshToken('user-1', 'token-hash', expiresAt);
    expect(mockDb.createRefreshToken).toHaveBeenCalledWith('user-1', 'token-hash', expiresAt);
  });

  it('getRefreshToken delegates to DatabaseService', async () => {
    const record: RefreshTokenRecord = {
      id: 'id1',
      userId: 'user-1',
      tokenHash: 'hash',
      revoked: false,
      expiresAt: new Date(),
    };
    (mockDb.getRefreshToken as jest.Mock).mockResolvedValue(record);
    const result = await repository.getRefreshToken('hash');
    expect(result).toBe(record);
    expect(mockDb.getRefreshToken).toHaveBeenCalledWith('hash');
  });

  it('revokeRefreshToken delegates to DatabaseService', async () => {
    await repository.revokeRefreshToken('user-1', 'token-hash');
    expect(mockDb.revokeRefreshToken).toHaveBeenCalledWith('user-1', 'token-hash');
  });

  it('revokeAllRefreshTokens delegates to DatabaseService', async () => {
    await repository.revokeAllRefreshTokens('user-1');
    expect(mockDb.revokeAllRefreshTokens).toHaveBeenCalledWith('user-1');
  });
});
