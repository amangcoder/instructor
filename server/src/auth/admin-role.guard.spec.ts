/**
 * Unit tests for AdminRoleGuard.
 *
 * Test matrix:
 *   ✅ admin role → passes (returns true)
 *   ❌ 'user' role → 403 ForbiddenException
 *   ❌ missing role field (pre-migration token) → 403 ForbiddenException
 *   ❌ no req.user at all → 401 UnauthorizedException (not 500, not 403)
 *   ❌ guard applied WITHOUT JwtAuthGuard → 401 UnauthorizedException (not crash)
 */

import { ExecutionContext, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { AdminRoleGuard } from './admin-role.guard';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Creates a minimal NestJS ExecutionContext mock for HTTP requests.
 * Pass a partial user object (or undefined) to simulate different auth states.
 */
function createMockContext(user: unknown): ExecutionContext {
  const request = { user };
  return {
    switchToHttp: () => ({
      getRequest: () => request,
      getResponse: () => ({}),
    }),
    getClass: () => null,
    getHandler: () => null,
    getArgs: () => [],
    getArgByIndex: () => null,
    switchToRpc: () => null,
    switchToWs: () => null,
    getType: () => 'http',
  } as unknown as ExecutionContext;
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

describe('AdminRoleGuard', () => {
  let guard: AdminRoleGuard;

  beforeEach(() => {
    guard = new AdminRoleGuard();
  });

  // ── Happy path: admin role ─────────────────────────────────────────────────

  describe('admin role', () => {
    it('returns true when req.user.role is "admin"', () => {
      const ctx = createMockContext({ sub: 'user-123', email: 'admin@example.com', role: 'admin' });
      expect(guard.canActivate(ctx)).toBe(true);
    });

    it('does not throw for a valid admin JWT payload', () => {
      const ctx = createMockContext({ sub: 'admin-abc', email: 'boss@example.com', role: 'admin' });
      expect(() => guard.canActivate(ctx)).not.toThrow();
    });
  });

  // ── 403: authenticated but not admin ──────────────────────────────────────

  describe('"user" role → 403', () => {
    it('throws ForbiddenException when role is "user"', () => {
      const ctx = createMockContext({ sub: 'user-456', email: 'user@example.com', role: 'user' });
      expect(() => guard.canActivate(ctx)).toThrow(ForbiddenException);
    });

    it('throws ForbiddenException with message "Admin access required"', () => {
      const ctx = createMockContext({ sub: 'user-456', email: 'user@example.com', role: 'user' });
      let error: ForbiddenException | undefined;
      try {
        guard.canActivate(ctx);
      } catch (e) {
        error = e as ForbiddenException;
      }
      expect(error).toBeInstanceOf(ForbiddenException);
      expect(error?.message).toBe('Admin access required');
    });

    it('returns HTTP 403 status for "user" role', () => {
      const ctx = createMockContext({ sub: 'user-456', email: 'user@example.com', role: 'user' });
      let error: ForbiddenException | undefined;
      try {
        guard.canActivate(ctx);
      } catch (e) {
        error = e as ForbiddenException;
      }
      expect(error?.getStatus()).toBe(403);
    });
  });

  // ── 403: pre-migration token — role field missing ──────────────────────────

  describe('missing role field (pre-migration token) → 403', () => {
    it('throws ForbiddenException when role field is undefined', () => {
      // Simulates a token issued before the role field was added to the JWT
      const ctx = createMockContext({ sub: 'user-789', email: 'old@example.com' });
      expect(() => guard.canActivate(ctx)).toThrow(ForbiddenException);
    });

    it('throws ForbiddenException when role is null', () => {
      const ctx = createMockContext({ sub: 'user-789', email: 'old@example.com', role: null });
      expect(() => guard.canActivate(ctx)).toThrow(ForbiddenException);
    });

    it('throws ForbiddenException when role is an empty string', () => {
      const ctx = createMockContext({ sub: 'user-789', email: 'old@example.com', role: '' });
      expect(() => guard.canActivate(ctx)).toThrow(ForbiddenException);
    });

    it('returns HTTP 403 for a pre-migration token (missing role)', () => {
      const ctx = createMockContext({ sub: 'user-789', email: 'old@example.com' });
      let error: ForbiddenException | undefined;
      try {
        guard.canActivate(ctx);
      } catch (e) {
        error = e as ForbiddenException;
      }
      expect(error?.getStatus()).toBe(403);
    });
  });

  // ── 401: no req.user at all ───────────────────────────────────────────────

  describe('no req.user → 401', () => {
    it('throws UnauthorizedException (not ForbiddenException) when req.user is undefined', () => {
      const ctx = createMockContext(undefined);
      expect(() => guard.canActivate(ctx)).toThrow(UnauthorizedException);
    });

    it('does NOT throw ForbiddenException when req.user is missing', () => {
      const ctx = createMockContext(undefined);
      let error: Error | undefined;
      try {
        guard.canActivate(ctx);
      } catch (e) {
        error = e as Error;
      }
      expect(error).not.toBeInstanceOf(ForbiddenException);
    });

    it('returns HTTP 401 status when req.user is undefined', () => {
      const ctx = createMockContext(undefined);
      let error: UnauthorizedException | undefined;
      try {
        guard.canActivate(ctx);
      } catch (e) {
        error = e as UnauthorizedException;
      }
      expect(error?.getStatus()).toBe(401);
    });

    it('throws UnauthorizedException when req.user is null', () => {
      const ctx = createMockContext(null);
      expect(() => guard.canActivate(ctx)).toThrow(UnauthorizedException);
    });
  });

  // ── 401: guard applied without JwtAuthGuard (no sub field) ────────────────

  describe('guard applied without JwtAuthGuard → 401 (not crash)', () => {
    it('throws UnauthorizedException when req.user exists but has no sub field', () => {
      // req.user was set by some other mechanism without sub — treat as unauthenticated
      const ctx = createMockContext({ email: 'attacker@example.com', role: 'admin' });
      expect(() => guard.canActivate(ctx)).toThrow(UnauthorizedException);
    });

    it('returns HTTP 401 when sub is missing from req.user', () => {
      const ctx = createMockContext({ email: 'attacker@example.com', role: 'admin' });
      let error: UnauthorizedException | undefined;
      try {
        guard.canActivate(ctx);
      } catch (e) {
        error = e as UnauthorizedException;
      }
      expect(error?.getStatus()).toBe(401);
    });

    it('throws UnauthorizedException with message "Authentication required"', () => {
      const ctx = createMockContext(undefined);
      let error: UnauthorizedException | undefined;
      try {
        guard.canActivate(ctx);
      } catch (e) {
        error = e as UnauthorizedException;
      }
      expect(error?.message).toBe('Authentication required');
    });

    it('does NOT crash (throw unhandled error) when applied without JwtAuthGuard', () => {
      // Verify the guard handles the edge case gracefully — no unhandled exceptions
      const ctx = createMockContext(undefined);
      expect(() => guard.canActivate(ctx)).toThrow(UnauthorizedException);
      // The test itself passing proves no unhandled crash occurred
    });
  });
});
