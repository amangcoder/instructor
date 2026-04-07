import { Test, TestingModule } from '@nestjs/testing';
import { UnauthorizedException, BadRequestException, BadGatewayException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { TtsController } from './tts.controller';
import { TtsService } from './tts.service';
import { ProviderRegistryService } from './providers/provider-registry.service';
import { SynthesizeDto } from './dto/synthesize.dto';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Build a minimal WAV-like buffer (44-byte header + 20 bytes silent PCM). */
function makeWavBuffer(): Buffer {
  return Buffer.alloc(64, 0);
}

/** Build a mock Express Response object that records calls. */
function makeMockRes() {
  const res = {
    _statusCode: 200,
    _headers: {} as Record<string, string>,
    _body: undefined as unknown,
    status: jest.fn().mockReturnThis(),
    json: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    send: jest.fn().mockReturnThis(),
  } as unknown as import('express').Response & { _statusCode: number; _headers: Record<string, string>; _body: unknown };

  (res.status as jest.Mock).mockImplementation((code: number) => {
    (res as { _statusCode: number })._statusCode = code;
    return res;
  });

  return res;
}

// ---------------------------------------------------------------------------
// Mock JWT service
// ---------------------------------------------------------------------------

/**
 * Build a mock JWT service that accepts any token starting with 'valid-'.
 */
function createMockJwtService() {
  return {
    verify: jest.fn((token: string) => {
      if (!token.startsWith('valid-')) {
        throw Object.assign(new Error('invalid token'), { name: 'JsonWebTokenError' });
      }
      return { sub: 'user-123', email: 'user@example.com' };
    }),
    sign: jest.fn().mockReturnValue('signed-token'),
  };
}

const VALID_JWT = 'valid-test-jwt-token';
const BEARER = (tok: string) => `Bearer ${tok}`;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('TtsController', () => {
  let controller: TtsController;
  let ttsService: jest.Mocked<TtsService>;
  let mockJwtService: ReturnType<typeof createMockJwtService>;

  beforeEach(async () => {
    mockJwtService = createMockJwtService();

    const mockTtsService: Partial<jest.Mocked<TtsService>> = {
      synthesize: jest.fn(),
    };

    const mockProviderRegistry: Partial<ProviderRegistryService> = {
      getProviders: jest.fn().mockResolvedValue([]),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [TtsController],
      providers: [
        { provide: TtsService, useValue: mockTtsService },
        { provide: ProviderRegistryService, useValue: mockProviderRegistry },
        { provide: JwtService, useValue: mockJwtService },
      ],
    }).compile();

    controller = module.get<TtsController>(TtsController);
    ttsService = module.get<jest.Mocked<TtsService>>(TtsService);
  });

  afterEach(() => {
    jest.restoreAllMocks();
    delete process.env.API_KEY;
    jest.useRealTimers();
  });

  // -------------------------------------------------------------------------
  // Happy path
  // Controller method signature: synthesize(dto, apiKey, authHeader, res)
  // -------------------------------------------------------------------------

  /** Call synthesize with a valid JWT Bearer token so auth passes. */
  async function synthesizeWithJwt(
    dto: SynthesizeDto,
    res: ReturnType<typeof makeMockRes>,
  ) {
    return controller.synthesize(
      dto,
      undefined,              // x-api-key (not set)
      BEARER(VALID_JWT),      // Authorization header (valid JWT)
      res as unknown as import('express').Response,
    );
  }

  describe('successful synthesis', () => {
    it('returns 200 with audio/wav Content-Type for a valid request', async () => {
      const wav = makeWavBuffer();
      ttsService.synthesize.mockResolvedValueOnce(wav);

      const dto: SynthesizeDto = { text: 'Hello world' };
      const res = makeMockRes();

      await synthesizeWithJwt(dto, res);

      // Controller calls service with (text, voice, locale, provider, speechRate)
      expect(ttsService.synthesize).toHaveBeenCalledWith(
        'Hello world', undefined, undefined, 'gemini', '1.0',
      );
      expect(res.set).toHaveBeenCalledWith(
        expect.objectContaining({ 'Content-Type': 'audio/wav' }),
      );
      expect(res.send).toHaveBeenCalledWith(wav);
    });

    it('passes voice and locale to TtsService', async () => {
      const wav = makeWavBuffer();
      ttsService.synthesize.mockResolvedValueOnce(wav);

      const dto: SynthesizeDto = { text: 'Hello', voice: 'aoede', locale: 'enIN' };
      const res = makeMockRes();

      await synthesizeWithJwt(dto, res);

      expect(ttsService.synthesize).toHaveBeenCalledWith(
        'Hello', 'aoede', 'enIN', 'gemini', '1.0',
      );
    });

    it('sets Content-Length equal to the buffer size', async () => {
      const wav = makeWavBuffer();
      ttsService.synthesize.mockResolvedValueOnce(wav);

      const dto: SynthesizeDto = { text: 'Test' };
      const res = makeMockRes();

      await synthesizeWithJwt(dto, res);

      expect(res.set).toHaveBeenCalledWith(
        expect.objectContaining({ 'Content-Length': String(wav.length) }),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Provider routing via controller (TASK-005)
  // -------------------------------------------------------------------------

  describe('provider parameter (TASK-005)', () => {
    it('passes provider="kokoro" to TtsService when specified in DTO', async () => {
      const wav = makeWavBuffer();
      ttsService.synthesize.mockResolvedValueOnce(wav);

      const dto: SynthesizeDto = { text: 'Hello', provider: 'kokoro' };
      const res = makeMockRes();

      await controller.synthesize(
        dto,
        undefined,
        BEARER(VALID_JWT),
        res as unknown as import('express').Response,
      );

      expect(ttsService.synthesize).toHaveBeenCalledWith('Hello', undefined, undefined, 'kokoro', '1.0');
    });

    it('passes provider="gemini" to TtsService when specified in DTO', async () => {
      const wav = makeWavBuffer();
      ttsService.synthesize.mockResolvedValueOnce(wav);

      const dto: SynthesizeDto = { text: 'Hello', voice: 'aoede', provider: 'gemini' };
      const res = makeMockRes();

      await controller.synthesize(
        dto,
        undefined,
        BEARER(VALID_JWT),
        res as unknown as import('express').Response,
      );

      expect(ttsService.synthesize).toHaveBeenCalledWith('Hello', 'aoede', undefined, 'gemini', '1.0');
    });

    it('returns 400 when provider is unknown (BadRequestException from TtsService)', async () => {
      ttsService.synthesize.mockRejectedValueOnce(
        new BadRequestException('Unknown provider: invalid-provider'),
      );

      const dto: SynthesizeDto = { text: 'Hello', provider: 'invalid-provider' };
      const res = makeMockRes();

      await controller.synthesize(
        dto,
        undefined,
        BEARER(VALID_JWT),
        res as unknown as import('express').Response,
      );

      expect(res.status).toHaveBeenCalledWith(400);
    });

    it('returns 502 when Kokoro server is unavailable', async () => {
      ttsService.synthesize.mockRejectedValueOnce(
        new BadGatewayException('Kokoro server unavailable'),
      );

      const dto: SynthesizeDto = { text: 'Hello', provider: 'kokoro' };
      const res = makeMockRes();

      await controller.synthesize(
        dto,
        undefined,
        BEARER(VALID_JWT),
        res as unknown as import('express').Response,
      );

      expect(res.status).toHaveBeenCalledWith(502);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ error: 'upstream_failure' }),
      );
    });
  });

  // -------------------------------------------------------------------------
  // AC-007: authentication checks (fail-open vulnerability fixed in TASK-003)
  // -------------------------------------------------------------------------

  describe('API key and JWT authentication (AC-007)', () => {
    it('throws UnauthorizedException when API_KEY is set and x-api-key header is wrong', async () => {
      process.env.API_KEY = 'secret-key';

      const dto: SynthesizeDto = { text: 'Hello' };
      const res = makeMockRes();

      await expect(
        controller.synthesize(
          dto,
          'wrong-key',    // x-api-key: wrong
          undefined,      // Authorization: absent
          res as unknown as import('express').Response,
        ),
      ).rejects.toThrow(UnauthorizedException);

      expect(ttsService.synthesize).not.toHaveBeenCalled();
    });

    it('throws UnauthorizedException when API_KEY is set but no credentials provided', async () => {
      process.env.API_KEY = 'secret-key';

      const dto: SynthesizeDto = { text: 'Hello' };
      const res = makeMockRes();

      await expect(
        controller.synthesize(
          dto,
          undefined,  // x-api-key: absent
          undefined,  // Authorization: absent
          res as unknown as import('express').Response,
        ),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('throws UnauthorizedException when no credentials are provided (fail-open fixed)', async () => {
      // TASK-003: fail-open vulnerability — must reject when no credentials
      delete process.env.API_KEY;

      const dto: SynthesizeDto = { text: 'Hello' };
      const res = makeMockRes();

      await expect(
        controller.synthesize(
          dto,
          undefined,  // x-api-key: absent
          undefined,  // Authorization: absent
          res as unknown as import('express').Response,
        ),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('allows request when valid JWT Bearer token is present', async () => {
      delete process.env.API_KEY;
      const wav = makeWavBuffer();
      ttsService.synthesize.mockResolvedValueOnce(wav);

      const dto: SynthesizeDto = { text: 'Hello' };
      const res = makeMockRes();

      await expect(
        controller.synthesize(
          dto,
          undefined,
          BEARER(VALID_JWT),
          res as unknown as import('express').Response,
        ),
      ).resolves.toBeUndefined();

      expect(res.send).toHaveBeenCalledWith(wav);
    });

    it('allows request when correct x-api-key is provided', async () => {
      process.env.API_KEY = 'secret-key';
      const wav = makeWavBuffer();
      ttsService.synthesize.mockResolvedValueOnce(wav);

      const dto: SynthesizeDto = { text: 'Hello' };
      const res = makeMockRes();

      await expect(
        controller.synthesize(
          dto,
          'secret-key',   // x-api-key: correct
          undefined,       // Authorization: absent
          res as unknown as import('express').Response,
        ),
      ).resolves.toBeUndefined();

      expect(res.send).toHaveBeenCalledWith(wav);
    });
  });

  // -------------------------------------------------------------------------
  // 502 on upstream TTS failure
  // -------------------------------------------------------------------------

  describe('502 upstream failure handling', () => {
    it('returns 502 with {error: upstream_failure} when TtsService throws', async () => {
      ttsService.synthesize.mockRejectedValueOnce(
        new BadGatewayException('Gemini did not respond'),
      );

      const dto: SynthesizeDto = { text: 'Hello' };
      const res = makeMockRes();

      await controller.synthesize(dto, undefined, BEARER(VALID_JWT), res as unknown as import('express').Response);

      expect(res.status).toHaveBeenCalledWith(502);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ error: 'upstream_failure' }),
      );
    });

    it('includes the error message in the 502 body', async () => {
      ttsService.synthesize.mockRejectedValueOnce(
        new Error('Gemini API error 503: upstream unavailable'),
      );

      const dto: SynthesizeDto = { text: 'Hello' };
      const res = makeMockRes();

      await controller.synthesize(dto, undefined, BEARER(VALID_JWT), res as unknown as import('express').Response);

      expect(res.status).toHaveBeenCalledWith(502);
      const jsonCall = (res.json as jest.Mock).mock.calls[0][0] as { error: string; message: string };
      expect(jsonCall.message).toContain('Gemini API error 503');
    });

    it('does not send a WAV body on failure', async () => {
      ttsService.synthesize.mockRejectedValueOnce(new Error('upstream error'));

      const dto: SynthesizeDto = { text: 'Hello' };
      const res = makeMockRes();

      await controller.synthesize(dto, undefined, BEARER(VALID_JWT), res as unknown as import('express').Response);

      expect(res.send).not.toHaveBeenCalled();
    });
  });

  // -------------------------------------------------------------------------
  // 408 on 90-second timeout
  // -------------------------------------------------------------------------

  describe('408 timeout handling', () => {
    beforeEach(() => {
      jest.useFakeTimers();
    });

    it('returns 408 with {error: timeout} when synthesis exceeds 90 seconds', async () => {
      // Service never resolves
      ttsService.synthesize.mockReturnValue(new Promise(() => { /* never resolves */ }));

      const dto: SynthesizeDto = { text: 'Hello' };
      const res = makeMockRes();

      const synthPromise = controller.synthesize(
        dto,
        undefined,
        BEARER(VALID_JWT),
        res as unknown as import('express').Response,
      );

      // Advance fake clock past the 90-second threshold
      jest.advanceTimersByTime(91_000);
      await synthPromise;

      expect(res.status).toHaveBeenCalledWith(408);
      expect(res.json).toHaveBeenCalledWith({ error: 'timeout' });
    });

    it('does NOT trigger timeout if synthesis completes within 90 seconds', async () => {
      const wav = makeWavBuffer();
      ttsService.synthesize.mockResolvedValueOnce(wav);

      const dto: SynthesizeDto = { text: 'Hello' };
      const res = makeMockRes();

      await controller.synthesize(dto, undefined, BEARER(VALID_JWT), res as unknown as import('express').Response);

      // Timeout should not fire
      expect(res.status).not.toHaveBeenCalledWith(408);
      expect(res.json).not.toHaveBeenCalled();
      expect(res.send).toHaveBeenCalledWith(wav);
    });
  });
});
