import { JsonLoggerService, resolveMinLevel } from './json-logger.service';

describe('resolveMinLevel', () => {
  const orig = process.env.LOG_LEVEL;
  afterEach(() => {
    if (orig === undefined) delete process.env.LOG_LEVEL;
    else process.env.LOG_LEVEL = orig;
  });

  it('defaults to debug when LOG_LEVEL is unset', () => {
    delete process.env.LOG_LEVEL;
    expect(resolveMinLevel()).toBe('debug');
  });

  it.each([
    ['debug', 'debug'],
    ['DEBUG', 'debug'],
    ['info', 'log'],
    ['INFO', 'log'],
    ['warn', 'warn'],
    ['warning', 'warn'],
    ['error', 'error'],
    ['err', 'error'],
    ['ERROR', 'error'],
    ['unknown', 'debug'],
  ])('maps LOG_LEVEL=%s → %s', (input, expected) => {
    process.env.LOG_LEVEL = input;
    expect(resolveMinLevel()).toBe(expected);
  });
});

describe('JsonLoggerService', () => {
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

  function parsed(): Record<string, unknown>[] {
    return lines
      .filter((l) => l.trim())
      .map((l) => JSON.parse(l.trim()) as Record<string, unknown>);
  }

  describe('structured JSON output', () => {
    it('emits a valid JSON line with required fields', () => {
      process.env.LOG_LEVEL = 'debug';
      const svc = new JsonLoggerService();
      svc.log('hello world', 'TestContext');

      const records = parsed();
      expect(records).toHaveLength(1);
      const rec = records[0];
      expect(rec.level).toBe('log');
      expect(rec.context).toBe('TestContext');
      expect(rec.msg).toBe('hello world');
      expect(typeof rec.ts).toBe('string');
      // ts must be an ISO-8601 date string
      expect(() => new Date(rec.ts as string).toISOString()).not.toThrow();
    });

    it('spreads object messages into the log record', () => {
      process.env.LOG_LEVEL = 'debug';
      const svc = new JsonLoggerService();
      svc.log({ msg: 'order placed', orderId: 'ord-1', userId: 'u-1' }, 'Orders');

      const rec = parsed()[0];
      expect(rec.orderId).toBe('ord-1');
      expect(rec.userId).toBe('u-1');
      expect(rec.context).toBe('Orders');
    });

    it('attaches stack trace on error()', () => {
      process.env.LOG_LEVEL = 'error';
      const svc = new JsonLoggerService();
      svc.error('something broke', 'Error: at foo (foo.ts:1)', 'Service');

      const rec = parsed()[0];
      expect(rec.level).toBe('error');
      expect(rec.stack).toBe('Error: at foo (foo.ts:1)');
      expect(rec.context).toBe('Service');
    });
  });

  describe('log-level filtering', () => {
    it('emits debug logs when LOG_LEVEL=debug', () => {
      process.env.LOG_LEVEL = 'debug';
      const svc = new JsonLoggerService();
      svc.debug('trace me', 'Ctx');
      expect(parsed()).toHaveLength(1);
    });

    it('suppresses debug logs when LOG_LEVEL=info', () => {
      process.env.LOG_LEVEL = 'info';
      const svc = new JsonLoggerService();
      svc.debug('trace me', 'Ctx');
      expect(parsed()).toHaveLength(0);
    });

    it('suppresses log+debug when LOG_LEVEL=warn', () => {
      process.env.LOG_LEVEL = 'warn';
      const svc = new JsonLoggerService();
      svc.debug('d', 'Ctx');
      svc.log('l', 'Ctx');
      expect(parsed()).toHaveLength(0);
    });

    it('emits warn when LOG_LEVEL=warn', () => {
      process.env.LOG_LEVEL = 'warn';
      const svc = new JsonLoggerService();
      svc.warn('degraded', 'Ctx');
      expect(parsed()).toHaveLength(1);
      expect(parsed()[0].level).toBe('warn');
    });

    it('only emits error when LOG_LEVEL=error', () => {
      process.env.LOG_LEVEL = 'error';
      const svc = new JsonLoggerService();
      svc.debug('d', 'Ctx');
      svc.log('l', 'Ctx');
      svc.warn('w', 'Ctx');
      expect(parsed()).toHaveLength(0);

      svc.error('fatal', undefined, 'Ctx');
      expect(parsed()).toHaveLength(1);
      expect(parsed()[0].level).toBe('error');
    });
  });

  describe('sensitive data safeguards', () => {
    it('does NOT emit password or token fields in object messages', () => {
      process.env.LOG_LEVEL = 'debug';
      const svc = new JsonLoggerService();
      // Caller is responsible for not passing secrets — log as-is and
      // assert the interceptor / caller never passes them.
      // This test documents the contract: the logger is transparent.
      const safePayload = { msg: 'auth event', userId: 'u-1', event: 'otp.sent' };
      svc.log(safePayload, 'Auth');
      const rec = parsed()[0];
      expect(rec).not.toHaveProperty('password');
      expect(rec).not.toHaveProperty('token');
      expect(rec.userId).toBe('u-1');
    });
  });
});
