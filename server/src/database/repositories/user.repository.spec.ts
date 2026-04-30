import { Test, TestingModule } from '@nestjs/testing';
import { UserRepository } from './user.repository';
import { DatabaseService, UserRecord } from '../database.service';
import { createMockDatabaseService } from '../testing';

const MOCK_USER: UserRecord = {
  id: 'user-1',
  email: 'test@example.com',
  name: null,
  username: null,
  photoUrl: null,
  role: 'user',
  createdAt: new Date(),
};

describe('UserRepository', () => {
  let repository: UserRepository;
  let mockDb: Partial<DatabaseService>;

  beforeEach(async () => {
    mockDb = createMockDatabaseService();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UserRepository,
        { provide: DatabaseService, useValue: mockDb },
      ],
    }).compile();

    repository = module.get<UserRepository>(UserRepository);
  });

  it('getUserById delegates to DatabaseService', async () => {
    (mockDb.getUserById as jest.Mock).mockResolvedValue(MOCK_USER);
    const result = await repository.getUserById('user-1');
    expect(result).toBe(MOCK_USER);
    expect(mockDb.getUserById).toHaveBeenCalledWith('user-1');
  });

  it('getUserByEmail delegates to DatabaseService', async () => {
    (mockDb.getUserByEmail as jest.Mock).mockResolvedValue(MOCK_USER);
    const result = await repository.getUserByEmail('test@example.com');
    expect(result).toBe(MOCK_USER);
    expect(mockDb.getUserByEmail).toHaveBeenCalledWith('test@example.com');
  });

  it('createUser delegates to DatabaseService', async () => {
    const user = { id: 'user-1', email: 'test@example.com', createdAt: new Date() };
    await repository.createUser(user);
    expect(mockDb.createUser).toHaveBeenCalledWith(user);
  });

  it('updateUserProfile delegates to DatabaseService', async () => {
    const data = { name: 'Alice' };
    await repository.updateUserProfile('user-1', data);
    expect(mockDb.updateUserProfile).toHaveBeenCalledWith('user-1', data);
  });

  it('deleteUser delegates to DatabaseService', async () => {
    await repository.deleteUser('user-1', 'test@example.com');
    expect(mockDb.deleteUser).toHaveBeenCalledWith('user-1', 'test@example.com');
  });
});
