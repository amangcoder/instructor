import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { Observable, tap } from 'rxjs';
import { Request, Response } from 'express';

@Injectable()
export class ApiLoggerInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const req = context.switchToHttp().getRequest<Request>();
    const { method, originalUrl, ip } = req;
    const userAgent = req.get('user-agent') ?? '-';
    const userId = (req as any).user?.sub ?? 'anon';
    const start = Date.now();

    return next.handle().pipe(
      tap({
        next: () => {
          const res = context.switchToHttp().getResponse<Response>();
          const ms = Date.now() - start;
          this.logger.log(
            `${method} ${originalUrl} ${res.statusCode} ${ms}ms — user=${userId} ip=${ip} ua=${userAgent}`,
          );
        },
        error: (err) => {
          const ms = Date.now() - start;
          const status = err.status ?? err.statusCode ?? 500;
          this.logger.warn(
            `${method} ${originalUrl} ${status} ${ms}ms — user=${userId} ip=${ip} err=${err.message}`,
          );
        },
      }),
    );
  }
}
