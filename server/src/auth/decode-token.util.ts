import { ExecutionContext } from '@nestjs/common';
import type { Request } from 'express';
import { JwtPayload } from './auth.service';

/**
 * Extracts the decoded JWT payload from the request context.
 * Returns null if no user is attached (anonymous request).
 *
 * Usage in a controller:
 *   const user = decodeToken(context);
 */
export function decodeToken(ctx: ExecutionContext): JwtPayload | null {
  const req = ctx.switchToHttp().getRequest<Request>();
  return (req as any).user ?? null;
}

/**
 * Typed accessor for when JwtAuthGuard is applied (user is guaranteed).
 */
export function requireUser(ctx: ExecutionContext): JwtPayload {
  const user = decodeToken(ctx);
  if (!user) throw new Error('No user in request context — JwtAuthGuard not applied?');
  return user;
}
