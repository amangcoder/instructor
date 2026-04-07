import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { Request } from 'express';
import { JwtPayload } from './auth.service';
import { extractBearer } from './jwt-auth.guard';

/**
 * Allows all requests (anonymous access is fine).
 * If a valid Bearer token is present, populates req.user.
 * Does NOT reject requests with missing or invalid tokens.
 */
@Injectable()
export class OptionalAuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest<Request>();
    const token = extractBearer(req);

    if (token) {
      try {
        // Use the secret already validated and configured in JwtModule.registerAsync.
        const payload = this.jwt.verify<JwtPayload>(token);
        (req as any).user = payload;
      } catch {
        // Invalid token — silently ignore, leave req.user undefined.
      }
    }

    return true;
  }
}
