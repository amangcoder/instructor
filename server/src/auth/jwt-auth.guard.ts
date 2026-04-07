import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { Request } from 'express';
import { JwtPayload } from './auth.service';

/**
 * Requires a valid JWT Bearer token in the Authorization header.
 * Injects decoded payload into req.user on success.
 * Returns 401 for missing, invalid, or expired tokens.
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest<Request>();
    const token = extractBearer(req);

    if (!token) {
      throw new UnauthorizedException('Missing Bearer token');
    }

    try {
      // Use the secret configured in JwtModule.registerAsync — no fallback here.
      const payload = this.jwt.verify<JwtPayload>(token);
      (req as any).user = payload;
      return true;
    } catch {
      throw new UnauthorizedException('Invalid or expired token');
    }
  }
}

/** Extract the Bearer token from the Authorization header. */
export function extractBearer(req: Request): string | null {
  const auth = req.headers.authorization;
  if (!auth?.startsWith('Bearer ')) return null;
  return auth.slice(7);
}
