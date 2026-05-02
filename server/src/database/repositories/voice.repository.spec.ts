import { Test, TestingModule } from '@nestjs/testing';
import { VoiceRepository } from './voice.repository';
import { DatabaseService } from '../database.service';
import { voices, type Voice } from '../schema';
import { and, eq } from 'drizzle-orm';

describe('VoiceRepository', () => {
  let repository: VoiceRepository;
  let mockDb: Partial<DatabaseService>;
  let mockDrizzle: any;

  beforeEach(async () => {
    mockDrizzle = {
      select: jest.fn(),
      insert: jest.fn(),
      update: jest.fn(),
    };

    mockDb = {
      noop: false,
      getDb: jest.fn().mockReturnValue(mockDrizzle),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        VoiceRepository,
        { provide: DatabaseService, useValue: mockDb },
      ],
    }).compile();

    repository = module.get<VoiceRepository>(VoiceRepository);
  });

  describe('noop mode', () => {
    it('returns empty array for listPublished in noop mode', async () => {
      (mockDb as any).noop = true;
      const result = await repository.listPublished();
      expect(result).toEqual([]);
    });

    it('returns empty response for listAll in noop mode', async () => {
      (mockDb as any).noop = true;
      const result = await repository.listAll(1, 10);
      expect(result).toEqual({ rows: [], total: 0 });
    });

    it('returns null for findById in noop mode', async () => {
      (mockDb as any).noop = true;
      const result = await repository.findById('voice-1');
      expect(result).toBeNull();
    });

    it('throws error for create in noop mode', async () => {
      (mockDb as any).noop = true;
      await expect(
        repository.create({
          id: 'voice-1',
          slug: 'google-en-us-studio',
          displayName: 'Google US English Studio',
          locale: 'en-US',
          provider: 'google',
          sampleUrl: 'https://example.com/sample.mp3',
          isPublished: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        }),
      ).rejects.toThrow('Database not configured');
    });

    it('returns null for update in noop mode', async () => {
      (mockDb as any).noop = true;
      const result = await repository.update('voice-1', { displayName: 'Updated' });
      expect(result).toBeNull();
    });
  });

  describe('listPublished', () => {
    const mockVoices: Voice[] = [
      {
        id: 'voice-1',
        slug: 'google-en-us-studio',
        displayName: 'Google US English Studio',
        locale: 'en-US',
        provider: 'google',
        sampleUrl: 'https://example.com/sample.mp3',
        isPublished: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: 'voice-2',
        slug: 'google-en-in-standard',
        displayName: 'Google Indian English',
        locale: 'en-IN',
        provider: 'google',
        sampleUrl: null,
        isPublished: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ];

    it('returns all published voices without locale filter', async () => {
      const mockQuery = {
        where: jest.fn().mockReturnThis(),
        orderBy: jest.fn().mockResolvedValue(mockVoices),
      };
      (mockDrizzle.select as jest.Mock).mockReturnValue(mockQuery);

      const result = await repository.listPublished();

      expect(result).toEqual(mockVoices);
      expect(mockDrizzle.select).toHaveBeenCalledWith();
      expect(mockQuery.where).toHaveBeenCalled();
      expect(mockQuery.orderBy).toHaveBeenCalled();
    });

    it('filters published voices by locale', async () => {
      const filteredVoices = [mockVoices[0]];
      const mockQuery = {
        where: jest.fn().mockReturnThis(),
        orderBy: jest.fn().mockResolvedValue(filteredVoices),
      };
      (mockDrizzle.select as jest.Mock).mockReturnValue(mockQuery);

      const result = await repository.listPublished('en-US');

      expect(result).toEqual(filteredVoices);
      expect(mockDrizzle.select).toHaveBeenCalledWith();
      expect(mockQuery.where).toHaveBeenCalled();
      expect(mockQuery.orderBy).toHaveBeenCalled();
    });

    it('returns empty array when no published voices exist', async () => {
      const mockQuery = {
        where: jest.fn().mockReturnThis(),
        orderBy: jest.fn().mockResolvedValue([]),
      };
      (mockDrizzle.select as jest.Mock).mockReturnValue(mockQuery);

      const result = await repository.listPublished('non-existent');

      expect(result).toEqual([]);
    });
  });

  describe('listAll', () => {
    const mockVoices: Voice[] = [
      {
        id: 'voice-1',
        slug: 'google-en-us',
        displayName: 'Google US English',
        locale: 'en-US',
        provider: 'google',
        sampleUrl: null,
        isPublished: true,
        createdAt: new Date('2026-01-01'),
        updatedAt: new Date('2026-01-01'),
      },
      {
        id: 'voice-2',
        slug: 'apple-en-us',
        displayName: 'Apple US English',
        locale: 'en-US',
        provider: 'apple',
        sampleUrl: null,
        isPublished: false,
        createdAt: new Date('2026-01-02'),
        updatedAt: new Date('2026-01-02'),
      },
    ];

    it('returns paginated voices with total count', async () => {
      const mockQuery = {
        orderBy: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        offset: jest.fn().mockResolvedValue(mockVoices),
      };
      const mockCountQuery = {
        from: jest.fn().mockResolvedValue([{ value: 2 }]),
      };
      (mockDrizzle.select as jest.Mock)
        .mockReturnValueOnce(mockCountQuery)
        .mockReturnValueOnce(mockQuery);

      const result = await repository.listAll(1, 10);

      expect(result).toEqual({
        rows: mockVoices,
        total: 2,
      });
      expect(mockQuery.limit).toHaveBeenCalledWith(10);
      expect(mockQuery.offset).toHaveBeenCalledWith(0);
    });

    it('applies correct offset for different pages', async () => {
      const mockQuery = {
        orderBy: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        offset: jest.fn().mockResolvedValue([mockVoices[1]]),
      };
      const mockCountQuery = {
        from: jest.fn().mockResolvedValue([{ value: 2 }]),
      };
      (mockDrizzle.select as jest.Mock)
        .mockReturnValueOnce(mockCountQuery)
        .mockReturnValueOnce(mockQuery);

      const result = await repository.listAll(2, 1);

      expect(result.rows).toEqual([mockVoices[1]]);
      expect(mockQuery.offset).toHaveBeenCalledWith(1); // (2-1) * 1 = 1
    });

    it('handles zero results gracefully', async () => {
      const mockQuery = {
        orderBy: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        offset: jest.fn().mockResolvedValue([]),
      };
      const mockCountQuery = {
        from: jest.fn().mockResolvedValue([{ value: 0 }]),
      };
      (mockDrizzle.select as jest.Mock)
        .mockReturnValueOnce(mockCountQuery)
        .mockReturnValueOnce(mockQuery);

      const result = await repository.listAll(1, 10);

      expect(result).toEqual({ rows: [], total: 0 });
    });

    it('handles null total count gracefully', async () => {
      const mockQuery = {
        orderBy: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        offset: jest.fn().mockResolvedValue([]),
      };
      const mockCountQuery = {
        from: jest.fn().mockResolvedValue([]),
      };
      (mockDrizzle.select as jest.Mock)
        .mockReturnValueOnce(mockCountQuery)
        .mockReturnValueOnce(mockQuery);

      const result = await repository.listAll(1, 10);

      expect(result).toEqual({ rows: [], total: 0 });
    });
  });

  describe('findById', () => {
    const mockVoice: Voice = {
      id: 'voice-1',
      slug: 'google-en-us',
      displayName: 'Google US English',
      locale: 'en-US',
      provider: 'google',
      sampleUrl: 'https://example.com/sample.mp3',
      isPublished: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    it('returns voice by id', async () => {
      const mockQuery = {
        where: jest.fn().mockResolvedValue([mockVoice]),
      };
      (mockDrizzle.select as jest.Mock).mockReturnValue(mockQuery);

      const result = await repository.findById('voice-1');

      expect(result).toEqual(mockVoice);
      expect(mockDrizzle.select).toHaveBeenCalledWith();
      expect(mockQuery.where).toHaveBeenCalled();
    });

    it('returns null when voice not found', async () => {
      const mockQuery = {
        where: jest.fn().mockResolvedValue([]),
      };
      (mockDrizzle.select as jest.Mock).mockReturnValue(mockQuery);

      const result = await repository.findById('non-existent');

      expect(result).toBeNull();
    });
  });

  describe('create', () => {
    const voiceData = {
      id: 'voice-1',
      slug: 'google-en-us',
      displayName: 'Google US English',
      locale: 'en-US',
      provider: 'google',
      sampleUrl: null,
      isPublished: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    it('creates and returns new voice', async () => {
      const mockQuery = {
        values: jest.fn().mockReturnThis(),
        returning: jest.fn().mockResolvedValue([voiceData]),
      };
      (mockDrizzle.insert as jest.Mock).mockReturnValue(mockQuery);

      const result = await repository.create(voiceData);

      expect(result).toEqual(voiceData);
      expect(mockDrizzle.insert).toHaveBeenCalledWith(voices);
      expect(mockQuery.values).toHaveBeenCalledWith(voiceData);
      expect(mockQuery.returning).toHaveBeenCalled();
    });

    it('throws error when insert fails', async () => {
      const mockQuery = {
        values: jest.fn().mockReturnThis(),
        returning: jest.fn().mockResolvedValue([]),
      };
      (mockDrizzle.insert as jest.Mock).mockReturnValue(mockQuery);

      await expect(repository.create(voiceData)).rejects.toThrow(
        'Failed to create voice',
      );
    });

    it('accepts partial voice data for creation', async () => {
      const partialData = {
        slug: 'google-en-us',
        displayName: 'Google US English',
        locale: 'en-US',
        provider: 'google',
      };
      const mockQuery = {
        values: jest.fn().mockReturnThis(),
        returning: jest.fn().mockResolvedValue([{ ...voiceData, ...partialData }]),
      };
      (mockDrizzle.insert as jest.Mock).mockReturnValue(mockQuery);

      const result = await repository.create(partialData as any);

      expect(result).toBeDefined();
      expect(mockQuery.values).toHaveBeenCalledWith(partialData);
    });
  });

  describe('update', () => {
    const voiceId = 'voice-1';
    const updatedVoice: Voice = {
      id: voiceId,
      slug: 'google-en-us',
      displayName: 'Updated Name',
      locale: 'en-US',
      provider: 'google',
      sampleUrl: 'https://example.com/new-sample.mp3',
      isPublished: false,
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-15'),
    };

    it('updates and returns modified voice', async () => {
      const mockQuery = {
        set: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        returning: jest.fn().mockResolvedValue([updatedVoice]),
      };
      (mockDrizzle.update as jest.Mock).mockReturnValue(mockQuery);

      const result = await repository.update(voiceId, {
        displayName: 'Updated Name',
        sampleUrl: 'https://example.com/new-sample.mp3',
        isPublished: false,
      });

      expect(result).toEqual(updatedVoice);
      expect(mockDrizzle.update).toHaveBeenCalledWith(voices);
      expect(mockQuery.set).toHaveBeenCalled();
      expect(mockQuery.where).toHaveBeenCalled();
      expect(mockQuery.returning).toHaveBeenCalled();
    });

    it('returns null when voice not found', async () => {
      const mockQuery = {
        set: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        returning: jest.fn().mockResolvedValue([]),
      };
      (mockDrizzle.update as jest.Mock).mockReturnValue(mockQuery);

      const result = await repository.update('non-existent', { displayName: 'Test' });

      expect(result).toBeNull();
    });

    it('always updates the updatedAt timestamp', async () => {
      const mockQuery = {
        set: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        returning: jest.fn().mockResolvedValue([updatedVoice]),
      };
      (mockDrizzle.update as jest.Mock).mockReturnValue(mockQuery);

      await repository.update(voiceId, { displayName: 'New Name' });

      const setCall = (mockQuery.set as jest.Mock).mock.calls[0][0];
      expect(setCall).toHaveProperty('updatedAt');
      expect(setCall.updatedAt).toBeInstanceOf(Date);
    });

    it('handles partial updates', async () => {
      const mockQuery = {
        set: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        returning: jest.fn().mockResolvedValue([updatedVoice]),
      };
      (mockDrizzle.update as jest.Mock).mockReturnValue(mockQuery);

      const result = await repository.update(voiceId, { isPublished: true });

      expect(result).toEqual(updatedVoice);
      const setCall = (mockQuery.set as jest.Mock).mock.calls[0][0];
      expect(setCall).toEqual({ isPublished: true, updatedAt: expect.any(Date) });
    });
  });

  describe('noop property', () => {
    it('returns the noop state from DatabaseService', () => {
      (mockDb as any).noop = false;
      expect(repository.noop).toBe(false);

      (mockDb as any).noop = true;
      expect(repository.noop).toBe(true);
    });
  });
});
