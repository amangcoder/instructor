import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';
import type { JwtPayload } from './auth.service';

/**
 * AdminRoleGuard — enforces that the authenticated user has role='admin'.
 *
 * MUST be applied after JwtAuthGuard (which populates req.user).
 * Written defensively to handle guard-ordering mistakes gracefully:
 *
 *   - No req.user or missing sub  → 401 UnauthorizedException
 *     (caller is not authenticated — distinguish from "not admin")
 *   - req.user.role !== 'admin'   → 403 ForbiddenException
 *     (caller is authenticated but lacks admin privilege)
 *
 * The typeof check on role is intentional: TypeScript types don't enforce
 * the JWT payload shape at runtime, so a pre-migration token might be missing
 * the 'role' field entirely. typeof guards handle undefined/null safely.
 */
@Injectable()
export class AdminRoleGuard implements CanActivate {
  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest<Request & { user?: JwtPayload }>();

    // Guard-ordering defence: JwtAuthGuard should have populated req.user,
    // but if it wasn't applied we get undefined — return 401, not 403.
    if (!req.user || typeof req.user.sub !== 'string') {
      throw new UnauthorizedException('Authentication required');
    }

    // Runtime-safe role check: use typeof to guard against missing role field
    // (e.g. tokens issued before the role field was added to the JWT payload).
    if (typeof req.user.role !== 'string' || req.user.role !== 'admin') {
      throw new ForbiddenException('Admin access required');
    }

    return true;
  }
}
