/**
 * AllExceptionsFilter — global exception filter that standardises every error
 * response from the NestJS API into a single JSON envelope:
 *
 *   { statusCode, error, message, requestId }
 *
 * Handling rules:
 *   - HttpException   → use exception.getStatus() and extract message / error
 *   - Drizzle/Neon statement-timeout (message contains 'canceling statement')
 *                     → 504 GATEWAY_TIMEOUT with error='query_timeout'
 *   - Everything else → 500 INTERNAL_SERVER_ERROR (sanitised — no stack traces
 *                       or raw SQL in production responses)
 *
 * The requestId is read from `request.requestId` which is set by
 * ApiLoggerInterceptor. It is also echoed in the X-Request-ID response header
 * so clients can correlate error reports with server logs.
 */

import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

/** Signature of an error response envelope. */
export interface ErrorEnvelope {
  statusCode: number;
  error: string;
  message: string;
  requestId: string;
}

/** Postgres / Neon statement-timeout error fragment. */
const STATEMENT_TIMEOUT_FRAGMENT = 'canceling statement due to statement timeout';

function extractRequestId(req: Request): string {
  return (req as any).requestId ?? (req.headers['x-request-id'] as string | undefined) ?? 'unknown';
}

function isStatementTimeout(err: unknown): boolean {
  const msg = err instanceof Error ? err.message : String(err);
  return msg.includes(STATEMENT_TIMEOUT_FRAGMENT);
}

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const req = ctx.getRequest<Request>();
    const res = ctx.getResponse<Response>();

    const requestId = extractRequestId(req);
    let statusCode: number;
    let error: string;
    let message: string;

    if (exception instanceof HttpException) {
      // ── NestJS HTTP exceptions (including validation errors) ─────────────
      statusCode = exception.getStatus();
      const responseBody = exception.getResponse();

      if (typeof responseBody === 'string') {
        message = responseBody;
        error = exception.message;
      } else if (typeof responseBody === 'object' && responseBody !== null) {
        const body = responseBody as Record<string, unknown>;
        // ValidationPipe produces { message: string[], error: string }
        const rawMessage = body['message'];
        message = Array.isArray(rawMessage)
          ? (rawMessage as string[]).join('; ')
          : String(rawMessage ?? exception.message);
        error = String(body['error'] ?? exception.name);
      } else {
        message = exception.message;
        error = exception.name;
      }
    } else if (isStatementTimeout(exception)) {
      // ── Neon/Postgres statement-timeout ───────────────────────────────────
      statusCode = HttpStatus.GATEWAY_TIMEOUT;
      error = 'query_timeout';
      message = 'Database query timed out';
      this.logger.error(`Statement timeout — requestId=${requestId}`);
    } else {
      // ── Unexpected / unhandled errors ─────────────────────────────────────
      statusCode = HttpStatus.INTERNAL_SERVER_ERROR;
      error = 'internal_server_error';

      if (process.env.NODE_ENV !== 'production' && exception instanceof Error) {
        // In dev/test expose the raw message for faster debugging.
        message = exception.message;
        this.logger.error(`Unhandled exception — requestId=${requestId}`, exception.stack);
      } else {
        // Never leak internal details in production.
        message = 'An unexpected error occurred';
        this.logger.error(
          `Unhandled exception — requestId=${requestId}: ${
            exception instanceof Error ? exception.message : String(exception)
          }`,
        );
      }
    }

    const envelope: ErrorEnvelope = { statusCode, error, message, requestId };

    res
      .status(statusCode)
      .header('X-Request-ID', requestId)
      .json(envelope);
  }
}
