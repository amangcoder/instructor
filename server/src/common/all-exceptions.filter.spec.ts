import { HttpException, HttpStatus } from '@nestjs/common';
import { AllExceptionsFilter, ErrorEnvelope } from './all-exceptions.filter';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeHost(requestId?: string) {
  const responseHeaders: Record<string, string> = {};
  const responseBody: { statusCode?: number; payload?: unknown } = {};

  const res: any = {
    status: (code: number) => {
      responseBody.statusCode = code;
      return res;
    },
    header: (name: string, value: string) => {
      responseHeaders[name] = value;
      return res;
    },
    json: (payload: unknown) => {
      responseBody.payload = payload;
    },
  };

  const req: any = {
    requestId,
    headers: {},
  };

  return {
    switchToHttp: () => ({
      getRequest: () => req,
      getResponse: () => res,
    }),
    _responseHeaders: responseHeaders,
    _responseBody: responseBody,
  } as any;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('AllExceptionsFilter', () => {
  let filter: AllExceptionsFilter;
  const originalEnv = process.env.NODE_ENV;

  beforeEach(() => {
    filter = new AllExceptionsFilter();
  });

  afterEach(() => {
    process.env.NODE_ENV = originalEnv;
  });

  describe('HttpException handling', () => {
    it('returns the HttpException status code', () => {
      const host = makeHost('req-1');
      filter.catch(new HttpException('Not found', HttpStatus.NOT_FOUND), host);
      expect((host._responseBody.payload as ErrorEnvelope).statusCode).toBe(404);
    });

    it('includes the message from the HttpException', () => {
      const host = makeHost('req-1');
      filter.catch(new HttpException('Forbidden resource', HttpStatus.FORBIDDEN), host);
      const body = host._responseBody.payload as ErrorEnvelope;
      expect(body.message).toBe('Forbidden resource');
    });

    it('flattens validation-pipe array messages into a semicolon-separated string', () => {
      const host = makeHost('req-2');
      const validationException = new HttpException(
        { statusCode: 400, message: ['email must be valid', 'otp must be 6 digits'], error: 'Bad Request' },
        HttpStatus.BAD_REQUEST,
      );
      filter.catch(validationException, host);
      const body = host._responseBody.payload as ErrorEnvelope;
      expect(body.message).toBe('email must be valid; otp must be 6 digits');
      expect(body.error).toBe('Bad Request');
    });

    it('includes requestId in the response envelope', () => {
      const host = makeHost('my-request-id');
      filter.catch(new HttpException('Oops', HttpStatus.BAD_REQUEST), host);
      const body = host._responseBody.payload as ErrorEnvelope;
      expect(body.requestId).toBe('my-request-id');
    });

    it('sets the X-Request-ID response header', () => {
      const host = makeHost('corr-id-123');
      filter.catch(new HttpException('Oops', HttpStatus.BAD_REQUEST), host);
      expect(host._responseHeaders['X-Request-ID']).toBe('corr-id-123');
    });
  });

  describe('statement_timeout handling', () => {
    it('returns 504 for Neon statement-timeout errors', () => {
      const host = makeHost('req-timeout');
      const err = new Error(
        'ERROR: canceling statement due to statement timeout',
      );
      filter.catch(err, host);
      expect(host._responseBody.statusCode).toBe(504);
    });

    it('uses error code query_timeout for DB timeouts', () => {
      const host = makeHost('req-timeout');
      const err = new Error('canceling statement due to statement timeout');
      filter.catch(err, host);
      const body = host._responseBody.payload as ErrorEnvelope;
      expect(body.error).toBe('query_timeout');
    });

    it('uses human-readable message for DB timeouts', () => {
      const host = makeHost('req-timeout');
      const err = new Error('canceling statement due to statement timeout');
      filter.catch(err, host);
      const body = host._responseBody.payload as ErrorEnvelope;
      expect(body.message).toBe('Database query timed out');
    });
  });

  describe('generic Error handling', () => {
    it('returns 500 for unknown errors', () => {
      process.env.NODE_ENV = 'production';
      const host = makeHost('req-err');
      filter.catch(new Error('Something exploded'), host);
      expect(host._responseBody.statusCode).toBe(500);
    });

    it('does not expose raw error message in production', () => {
      process.env.NODE_ENV = 'production';
      const host = makeHost('req-err');
      filter.catch(new Error('Internal DB credential'), host);
      const body = host._responseBody.payload as ErrorEnvelope;
      expect(body.message).not.toContain('Internal DB credential');
      expect(body.message).toBe('An unexpected error occurred');
    });

    it('exposes raw error message in development for debuggability', () => {
      process.env.NODE_ENV = 'development';
      const host = makeHost('req-err');
      filter.catch(new Error('Some dev-only detail'), host);
      const body = host._responseBody.payload as ErrorEnvelope;
      expect(body.message).toBe('Some dev-only detail');
    });

    it('includes requestId for generic errors', () => {
      process.env.NODE_ENV = 'production';
      const host = makeHost('req-xyz');
      filter.catch(new Error('crash'), host);
      const body = host._responseBody.payload as ErrorEnvelope;
      expect(body.requestId).toBe('req-xyz');
    });
  });

  describe('requestId fallback', () => {
    it('uses unknown when requestId is absent from the request', () => {
      const host = makeHost(); // no requestId
      filter.catch(new HttpException('err', 400), host);
      const body = host._responseBody.payload as ErrorEnvelope;
      expect(body.requestId).toBe('unknown');
    });
  });
});
