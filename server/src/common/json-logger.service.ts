/**
 * JsonLoggerService — NestJS LoggerService that emits structured JSON to stdout.
 *
 * Every log line is a single JSON object on stdout:
 *   {"ts":"2026-04-09T…","level":"log","context":"Bootstrap","msg":"Server running","port":3071}
 *
 * Log-level filtering is controlled by the LOG_LEVEL environment variable:
 *   debug   → all levels (verbose, debug, log, warn, error)
 *   info    → log, warn, error
 *   warn    → warn, error
 *   error   → error only
 *
 * Defaults to "debug" when LOG_LEVEL is not set.
 *
 * NEVER log passwords, tokens, API keys, session IDs, or PII here.
 */

import { Injectable, LoggerService } from '@nestjs/common';

type Level = 'verbose' | 'debug' | 'log' | 'warn' | 'error';

const PRIORITY: Record<Level, number> = {
  verbose: 0,
  debug: 1,
  log: 2,
  warn: 3,
  error: 4,
};

/** Map the LOG_LEVEL env string to an internal NestJS log level. */
export function resolveMinLevel(): Level {
  const raw = (process.env.LOG_LEVEL ?? 'debug').toLowerCase();
  const map: Record<string, Level> = {
    verbose: 'verbose',
    debug: 'debug',
    info: 'log',
    log: 'log',
    warn: 'warn',
    warning: 'warn',
    error: 'error',
    err: 'error',
  };
  return map[raw] ?? 'debug';
}

@Injectable()
export class JsonLoggerService implements LoggerService {
  private readonly min: Level;

  constructor() {
    this.min = resolveMinLevel();
  }

  /** Returns the resolved minimum log level (useful for tests). */
  getMinLevel(): Level {
    return this.min;
  }

  private allowed(level: Level): boolean {
    return PRIORITY[level] >= PRIORITY[this.min];
  }

  private write(
    level: Level,
    message: unknown,
    contextOrTrace?: string,
    context?: string,
  ): void {
    if (!this.allowed(level)) return;

    // Resolve context: for error() the second arg is stack, third is context.
    const resolvedContext =
      level === 'error'
        ? (context ?? 'App')
        : (contextOrTrace ?? 'App');

    let body: Record<string, unknown>;
    if (message !== null && typeof message === 'object') {
      body = { ...(message as Record<string, unknown>) };
    } else {
      body = { msg: String(message ?? '') };
    }

    const record: Record<string, unknown> = {
      ts: new Date().toISOString(),
      level,
      context: resolvedContext,
      ...body,
    };

    // Attach stack trace for errors when available.
    if (level === 'error' && contextOrTrace && contextOrTrace !== context) {
      record.stack = contextOrTrace;
    }

    process.stdout.write(JSON.stringify(record) + '\n');
  }

  log(message: unknown, context?: string): void {
    this.write('log', message, context);
  }

  warn(message: unknown, context?: string): void {
    this.write('warn', message, context);
  }

  /** NestJS calls error(msg, stack?, context?). */
  error(message: unknown, stack?: string, context?: string): void {
    this.write('error', message, stack, context);
  }

  debug(message: unknown, context?: string): void {
    this.write('debug', message, context);
  }

  verbose(message: unknown, context?: string): void {
    this.write('verbose', message, context);
  }
}
