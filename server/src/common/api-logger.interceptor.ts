/**
 * ApiLoggerInterceptor — Global HTTP request/response logger.
 *
 * Emits one structured JSON log entry per request to stdout (CloudWatch-ready).
 * Each entry contains:
 *   - requestId   : correlation ID (from x-request-id header or generated UUID)
 *   - method      : HTTP verb
 *   - endpoint    : path without query string
 *   - statusCode  : HTTP response status
 *   - duration    : elapsed milliseconds
 *   - userId      : authenticated user ID (omitted for anonymous requests)
 *   - errors      : error details array (only on failures)
 *
 * Log-level filtering (LOG_LEVEL env var):
 *   debug  → all request events (inbound trace + completion)
 *   info   → completions only (2xx/3xx/4xx/5xx)
 *   warn   → 4xx + 5xx + slow requests
 *   error  → 5xx errors only
 *
 * Overrides (always logged regardless of LOG_LEVEL):
 *   - Auth endpoints   (/api/auth/*)  — security audit trail
 *   - Slow requests    (> SLOW_MS)    — performance budget alerts
 *
 * NEVER logged:
 *   - Passwords, tokens, API keys, session IDs
 *   - Request/response bodies
 *   - PII beyond the userId claim already carried in the JWT
 */

import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable, tap } from 'rxjs';
import { Request, Response } from 'express';
import { randomUUID } from 'crypto';
import { resolveMinLevel } from './json-logger.service';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/** Path prefixes that are ALWAYS logged (security audit trail). */
const AUTH_PREFIXES = ['/api/auth/'];

/** Requests exceeding this threshold are ALWAYS logged as perf alerts. */
const SLOW_MS = 3_000;

// ---------------------------------------------------------------------------
// Level helpers
// ---------------------------------------------------------------------------

type Level = 'debug' | 'log' | 'warn' | 'error';

const PRIORITY: Record<Level, number> = {
  debug: 0,
  log: 1,
  warn: 2,
  error: 3,
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function isAuthEndpoint(url: string): boolean {
  return AUTH_PREFIXES.some((prefix) => url.startsWith(prefix));
}

function statusToLevel(code: number): Level {
  if (code >= 500) return 'error';
  if (code >= 400) return 'warn';
  return 'log';
}

function emitJson(level: Level, fields: Record<string, unknown>): void {
  process.stdout.write(
    JSON.stringify({ ts: new Date().toISOString(), level, ...fields }) + '\n',
  );
}

// ---------------------------------------------------------------------------
// Interceptor
// ---------------------------------------------------------------------------

@Injectable()
export class ApiLoggerInterceptor implements NestInterceptor {
  /**
   * The minimum level is resolved once at startup from LOG_LEVEL.
   * Mapping from LOG_LEVEL string to internal level:
   *   "debug"  → debug (everything)
   *   "info"   → log   (completions)
   *   "warn"   → warn  (4xx/5xx/slow)
   *   "error"  → error (5xx only; auth + perf overrides still apply)
   */
  private readonly min: Level;

  constructor() {
    const resolved = resolveMinLevel();
    // verbose maps to debug for this interceptor's 4-level scale
    this.min = resolved === 'verbose' ? 'debug' : (resolved as Level);
  }

  private allowed(level: Level): boolean {
    return PRIORITY[level] >= PRIORITY[this.min];
  }

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest<Request>();
    const { method, originalUrl } = req;

    // Propagate or generate a correlation ID so downstream services can use it.
    const requestId =
      (req.headers['x-request-id'] as string | undefined) ?? randomUUID();
    (req as Request & { requestId: string }).requestId = requestId;

    // userId is only available after auth guards have run.
    // We read it lazily in tap() so guards executing after this interceptor
    // starts are still captured.
    const endpoint = originalUrl.split('?')[0]; // drop query string
    const start = Date.now();

    // ── DEBUG: inbound trace (dev environments only) ──────────────────────
    if (this.allowed('debug')) {
      emitJson('debug', {
        event: 'request.start',
        requestId,
        method,
        endpoint,
      });
    }

    return next.handle().pipe(
      tap({
        // ── SUCCESS path ────────────────────────────────────────────────
        next: () => {
          const res = context.switchToHttp().getResponse<Response>();
          const duration = Date.now() - start;
          const statusCode = res.statusCode;
          const userId: string | undefined =
            (req as any).user?.sub ?? undefined;

          const level = statusToLevel(statusCode);
          const slow = duration >= SLOW_MS;
          const auth = isAuthEndpoint(endpoint);

          // Emit when: level passes filter, OR it's an auth/perf override.
          if (!this.allowed(level) && !auth && !slow) return;

          const entry: Record<string, unknown> = {
            event: 'request.complete',
            requestId,
            method,
            endpoint,
            statusCode,
            duration,
            ...(userId !== undefined ? { userId } : {}),
            ...(slow ? { slowRequest: true } : {}),
            ...(auth ? { authEvent: true } : {}),
          };

          emitJson(level, entry);
        },

        // ── ERROR path ──────────────────────────────────────────────────
        error: (err: any) => {
          const duration = Date.now() - start;
          const statusCode: number = err.status ?? err.statusCode ?? 500;
          const userId: string | undefined =
            (req as any).user?.sub ?? undefined;

          const level = statusToLevel(statusCode);
          const slow = duration >= SLOW_MS;
          const auth = isAuthEndpoint(endpoint);

          // Errors at or above 500 are ALWAYS emitted.
          // 4xx errors respect the filter unless auth/perf override.
          if (statusCode < 500 && !this.allowed(level) && !auth && !slow) {
            return;
          }

          const entry: Record<string, unknown> = {
            event: 'request.error',
            requestId,
            method,
            endpoint,
            statusCode,
            duration,
            ...(userId !== undefined ? { userId } : {}),
            ...(slow ? { slowRequest: true } : {}),
            ...(auth ? { authEvent: true } : {}),
            errors: [
              {
                type: err.name ?? 'Error',
                message: err.message,
                // Stack traces only in debug mode to keep CloudWatch lean.
                ...(this.min === 'debug' && err.stack
                  ? { stack: err.stack }
                  : {}),
              },
            ],
          };

          emitJson(level, entry);
        },
      }),
    );
  }
}
