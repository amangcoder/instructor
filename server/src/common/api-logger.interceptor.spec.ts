import { of, throwError } from 'rxjs';
import { ApiLoggerInterceptor } from './api-logger.interceptor';
import { ExecutionContext, CallHandler } from '@nestjs/common';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeContext(
  method = 'GET',
  url = '/api/plans',
  headers: Record<string, string> = {},
  user?: { sub: string },
): ExecutionContext {
  const req: any = { method, originalUrl: url, headers, user };
  const res: any = { statusCode: 200 };
  return {
    switchToHttp: () => ({
      getRequest: () => req,
      getResponse: () => res,
    }),
  } as unknown as ExecutionContext;
}

function makeHandler(value: unknown = { ok: true }): CallHandler {
  return { handle: () => of(value) };
}

function makeErrorHandler(err: any): CallHandler {
  return { handle: () => throwError(() => err) };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('ApiLoggerInterceptor', () => {
  let writeSpy: jest.SpyInstance;
  let lines: string[];

  beforeEach(() => {
    lines = [];
    writeSpy = jest
      .spyOn(process.stdout, 'write')
      .mockImplementation((chunk: any) => {
        lines.push(typeof chunk === 'string' ? chunk : chunk.toString());
        return true;
      });
  });

  afterEach(() => {
    writeSpy.mockRestore();
    delete process.env.LOG_LEVEL;
  });

  function records(): Record<string, unknown>[] {
    return lines
      .filter((l) => l.trim())
      .map((l) => JSON.parse(l.trim()) as Record<string, unknown>);
  }

  describe('structured log fields', () => {
    it('emits requestId, method, endpoint, statusCode, duration on success', (done) => {
      process.env.LOG_LEVEL = 'debug';
      const interceptor = new ApiLoggerInterceptor();
      const ctx = makeContext('GET', '/api/plans');

      interceptor.intercept(ctx, makeHandler()).subscribe({
        complete: () => {
          const recs = records();
          // At debug level: request.start + request.complete
          const complete = recs.find((r) => r.event === 'request.complete');
          expect(complete).toBeDefined();
          expect(complete!.method).toBe('GET');
          expect(complete!.endpoint).toBe('/api/plans');
          expect(complete!.statusCode).toBe(200);
          expect(typeof complete!.duration).toBe('number');
          expect(typeof complete!.requestId).toBe('string');
          expect(complete!.ts).toBeTruthy();
          done();
        },
      });
    });

    it('omits userId when request is anonymous', (done) => {
      process.env.LOG_LEVEL = 'debug';
      const interceptor = new ApiLoggerInterceptor();
      const ctx = makeContext('GET', '/api/plans', {}, undefined);

      interceptor.intercept(ctx, makeHandler()).subscribe({
        complete: () => {
          const complete = records().find((r) => r.event === 'request.complete');
          expect(complete).toBeDefined();
          expect(complete).not.toHaveProperty('userId');
          done();
        },
      });
    });

    it('includes userId when authenticated', (done) => {
      process.env.LOG_LEVEL = 'debug';
      const interceptor = new ApiLoggerInterceptor();
      const ctx = makeContext('GET', '/api/plans', {}, { sub: 'user-123' });

      interceptor.intercept(ctx, makeHandler()).subscribe({
        complete: () => {
          const complete = records().find((r) => r.event === 'request.complete');
          expect(complete!.userId).toBe('user-123');
          done();
        },
      });
    });

    it('propagates x-request-id header as requestId', (done) => {
      process.env.LOG_LEVEL = 'debug';
      const interceptor = new ApiLoggerInterceptor();
      const ctx = makeContext('GET', '/api/plans', { 'x-request-id': 'req-abc' });

      interceptor.intercept(ctx, makeHandler()).subscribe({
        complete: () => {
          const start = records().find((r) => r.event === 'request.start');
          expect(start!.requestId).toBe('req-abc');
          done();
        },
      });
    });

    it('strips query string from endpoint', (done) => {
      process.env.LOG_LEVEL = 'debug';
      const interceptor = new ApiLoggerInterceptor();
      const ctx = makeContext('GET', '/api/plans?page=2&limit=10');

      interceptor.intercept(ctx, makeHandler()).subscribe({
        complete: () => {
          const complete = records().find((r) => r.event === 'request.complete');
          expect(complete!.endpoint).toBe('/api/plans');
          done();
        },
      });
    });

    it('emits errors array on failure', (done) => {
      process.env.LOG_LEVEL = 'debug';
      const interceptor = new ApiLoggerInterceptor();
      const ctx = makeContext('POST', '/api/plans');
      const err = Object.assign(new Error('DB timeout'), { status: 500 });

      interceptor.intercept(ctx, makeErrorHandler(err)).subscribe({
        error: () => {
          const errorRec = records().find((r) => r.event === 'request.error');
          expect(errorRec).toBeDefined();
          expect(Array.isArray(errorRec!.errors)).toBe(true);
          const errors = errorRec!.errors as any[];
          expect(errors[0].message).toBe('DB timeout');
          expect(errors[0].type).toBe('Error');
          done();
        },
      });
    });
  });

  describe('log-level filtering', () => {
    it('suppresses request.start and request.complete when LOG_LEVEL=error for 2xx', (done) => {
      process.env.LOG_LEVEL = 'error';
      const interceptor = new ApiLoggerInterceptor();
      const ctx = makeContext('GET', '/api/plans');

      interceptor.intercept(ctx, makeHandler()).subscribe({
        complete: () => {
          const recs = records();
          expect(recs.find((r) => r.event === 'request.start')).toBeUndefined();
          expect(recs.find((r) => r.event === 'request.complete')).toBeUndefined();
          done();
        },
      });
    });

    it('always emits 5xx errors regardless of LOG_LEVEL', (done) => {
      process.env.LOG_LEVEL = 'error';
      const interceptor = new ApiLoggerInterceptor();
      const ctx = makeContext('POST', '/api/plans');
      const err = Object.assign(new Error('crash'), { status: 500 });

      interceptor.intercept(ctx, makeErrorHandler(err)).subscribe({
        error: () => {
          const errorRec = records().find((r) => r.event === 'request.error');
          expect(errorRec).toBeDefined();
          expect(errorRec!.level).toBe('error');
          done();
        },
      });
    });

    it('always emits auth endpoint events regardless of LOG_LEVEL', (done) => {
      process.env.LOG_LEVEL = 'error';
      const interceptor = new ApiLoggerInterceptor();
      const ctx = makeContext('POST', '/api/auth/request-otp');

      interceptor.intercept(ctx, makeHandler()).subscribe({
        complete: () => {
          const complete = records().find((r) => r.event === 'request.complete');
          expect(complete).toBeDefined();
          expect(complete!.authEvent).toBe(true);
          done();
        },
      });
    });

    it('does NOT emit debug request.start when LOG_LEVEL=info', (done) => {
      process.env.LOG_LEVEL = 'info';
      const interceptor = new ApiLoggerInterceptor();
      const ctx = makeContext('GET', '/api/plans');

      interceptor.intercept(ctx, makeHandler()).subscribe({
        complete: () => {
          const start = records().find((r) => r.event === 'request.start');
          expect(start).toBeUndefined();
          done();
        },
      });
    });

    it('emits 4xx as warn and respects LOG_LEVEL=warn', (done) => {
      process.env.LOG_LEVEL = 'warn';
      const interceptor = new ApiLoggerInterceptor();
      const ctx = makeContext('GET', '/api/plans');
      // Simulate a 404 by using an error
      const err = Object.assign(new Error('Not Found'), { status: 404 });

      interceptor.intercept(ctx, makeErrorHandler(err)).subscribe({
        error: () => {
          const errorRec = records().find((r) => r.event === 'request.error');
          expect(errorRec).toBeDefined();
          expect(errorRec!.level).toBe('warn');
          done();
        },
      });
    });

    it('suppresses 4xx when LOG_LEVEL=error (non-auth endpoint)', (done) => {
      process.env.LOG_LEVEL = 'error';
      const interceptor = new ApiLoggerInterceptor();
      const ctx = makeContext('GET', '/api/plans');
      const err = Object.assign(new Error('Not Found'), { status: 404 });

      interceptor.intercept(ctx, makeErrorHandler(err)).subscribe({
        error: () => {
          const errorRec = records().find((r) => r.event === 'request.error');
          expect(errorRec).toBeUndefined();
          done();
        },
      });
    });
  });

  describe('slow request detection', () => {
    it('marks slowRequest=true and forces emission when duration >= 3000ms', (done) => {
      process.env.LOG_LEVEL = 'error'; // strict level
      const interceptor = new ApiLoggerInterceptor();
      const ctx = makeContext('GET', '/api/plans');

      // Manually override Date.now to simulate elapsed time
      const realNow = Date.now;
      let call = 0;
      jest.spyOn(Date, 'now').mockImplementation(() => {
        call++;
        return call === 1 ? 1000 : 4001; // 3001ms elapsed
      });

      interceptor.intercept(ctx, makeHandler()).subscribe({
        complete: () => {
          Date.now = realNow;
          const complete = records().find((r) => r.event === 'request.complete');
          expect(complete).toBeDefined();
          expect(complete!.slowRequest).toBe(true);
          done();
        },
      });
    });
  });

  describe('sensitive data safeguards', () => {
    it('never includes password or authorization header in log output', (done) => {
      process.env.LOG_LEVEL = 'debug';
      const interceptor = new ApiLoggerInterceptor();
      const ctx = makeContext(
        'POST',
        '/api/auth/verify-otp',
        { authorization: 'Bearer secret-token-123' },
        { sub: 'u-1' },
      );

      interceptor.intercept(ctx, makeHandler()).subscribe({
        complete: () => {
          const output = lines.join('');
          expect(output).not.toContain('secret-token-123');
          expect(output).not.toContain('Bearer');
          done();
        },
      });
    });
  });
});
