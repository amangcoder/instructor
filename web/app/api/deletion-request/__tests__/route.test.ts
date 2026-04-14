/**
 * @jest-environment node
 *
 * Tests for the POST /api/deletion-request route handler.
 *
 * The handler:
 *  - Validates Content-Type (415 if not application/json)
 *  - Rate-limits by IP (429 after 20 req/hour)
 *  - Validates request body structure and email format (400)
 *  - Constructs a sanitized body and proxies to NestJS backend
 *  - Returns a generic 201 success regardless of whether the email exists
 *  - Returns 503 with a mailto: fallback on network/timeout errors
 *  - Never forwards Authorization, Cookie, or other sensitive headers
 */

// ── Mock global fetch before importing the module ─────────────────────────
const mockFetch = jest.fn();
global.fetch = mockFetch;

// ── Helpers ───────────────────────────────────────────────────────────────

/**
 * Builds a minimal NextRequest-compatible object.
 * We construct from the real NextRequest so it honours the Node.js
 * runtime requirements of the App Router.
 */
import { NextRequest } from 'next/server';

function makeRequest({
  contentType = 'application/json',
  body = {},
  ip = '127.0.0.1',
  method = 'POST',
}: {
  contentType?: string;
  body?: unknown;
  ip?: string;
  method?: string;
} = {}): NextRequest {
  const rawBody =
    typeof body === 'string' ? body : JSON.stringify(body);

  const req = new NextRequest('http://localhost:3000/api/deletion-request', {
    method,
    headers: {
      'content-type': contentType,
      'x-forwarded-for': ip,
    },
    body: rawBody,
  });

  return req;
}

/** Returns a successful backend fetch mock */
function mockBackendSuccess(status = 201) {
  mockFetch.mockResolvedValueOnce({
    status,
    ok: status >= 200 && status < 300,
    json: async () => ({ success: true }),
  });
}

/** Returns a backend 404 mock (user not found — still treated as success) */
function mockBackendNotFound() {
  mockFetch.mockResolvedValueOnce({
    status: 404,
    ok: false,
    json: async () => ({ message: 'User not found' }),
  });
}

/** Returns a backend 500 mock */
function mockBackendError() {
  mockFetch.mockResolvedValueOnce({
    status: 500,
    ok: false,
    json: async () => ({ message: 'Internal server error' }),
  });
}

/** Makes the backend fetch throw a network error */
function mockNetworkError() {
  mockFetch.mockRejectedValueOnce(new Error('Network failure'));
}

/** Makes the backend fetch simulate an AbortError (timeout) */
function mockTimeoutError() {
  const err = new Error('The operation was aborted');
  err.name = 'AbortError';
  mockFetch.mockRejectedValueOnce(err);
}

// ── Import the handler (after mocks are set up) ────────────────────────────
import { POST } from '../route';

// ── Tests ─────────────────────────────────────────────────────────────────

beforeEach(() => {
  mockFetch.mockReset();
  jest.clearAllMocks();
});

// ─────────────────────────────────────────────────────────────────────────────
describe('POST /api/deletion-request', () => {
  // ── Content-Type validation ───────────────────────────────────────────────

  describe('Content-Type enforcement (CSRF protection)', () => {
    it('returns 415 when Content-Type is not application/json', async () => {
      const req = makeRequest({ contentType: 'text/plain' });
      const res = await POST(req);

      expect(res.status).toBe(415);
      const body = await res.json() as { success: boolean };
      expect(body.success).toBe(false);
    });

    it('returns 415 when Content-Type is missing', async () => {
      const req = new NextRequest('http://localhost:3000/api/deletion-request', {
        method: 'POST',
        body: JSON.stringify({ email: 'test@example.com', scope: 'full' }),
      });
      // No content-type header set → will be absent
      const res = await POST(req);
      expect(res.status).toBe(415);
    });

    it('accepts application/json; charset=utf-8 as a valid content-type', async () => {
      mockBackendSuccess();
      const req = makeRequest({
        contentType: 'application/json; charset=utf-8',
        body: { email: 'user@example.com', scope: 'full' },
      });
      const res = await POST(req);
      expect(res.status).toBe(201);
    });
  });

  // ── Body size enforcement ────────────────────────────────────────────────

  describe('Request body size limit (1 KB)', () => {
    it('returns 413 when body exceeds 1 KB', async () => {
      const oversizedBody = { email: 'a@b.com', scope: 'full', junk: 'x'.repeat(2_000) };
      const req = makeRequest({ body: oversizedBody });
      const res = await POST(req);
      expect(res.status).toBe(413);
    });
  });

  // ── JSON parsing ──────────────────────────────────────────────────────────

  describe('JSON parsing', () => {
    it('returns 400 when body is not valid JSON', async () => {
      const req = makeRequest({ body: 'NOT{JSON}' });
      const res = await POST(req);
      expect(res.status).toBe(400);
    });

    it('returns 400 when body is a JSON array', async () => {
      const req = makeRequest({ body: [{ email: 'a@b.com' }] });
      const res = await POST(req);
      expect(res.status).toBe(400);
    });

    it('returns 400 when body is a JSON primitive', async () => {
      const req = makeRequest({ body: '"just-a-string"' });
      const res = await POST(req);
      expect(res.status).toBe(400);
    });
  });

  // ── Body structure validation ─────────────────────────────────────────────

  describe('Body structure validation', () => {
    it('returns 400 when email is missing', async () => {
      const req = makeRequest({ body: { scope: 'full' } });
      const res = await POST(req);
      expect(res.status).toBe(400);
    });

    it('returns 400 when email is an empty string', async () => {
      const req = makeRequest({ body: { email: '', scope: 'full' } });
      const res = await POST(req);
      expect(res.status).toBe(400);
    });

    it('returns 400 when email is a non-string type', async () => {
      const req = makeRequest({ body: { email: 42, scope: 'full' } });
      const res = await POST(req);
      expect(res.status).toBe(400);
    });

    it('returns 400 when scope is missing', async () => {
      const req = makeRequest({ body: { email: 'user@example.com' } });
      const res = await POST(req);
      expect(res.status).toBe(400);
    });

    it('returns 400 when scope is null', async () => {
      const req = makeRequest({ body: { email: 'user@example.com', scope: null } });
      const res = await POST(req);
      expect(res.status).toBe(400);
    });

    it('returns 400 when scope is an empty string', async () => {
      const req = makeRequest({ body: { email: 'user@example.com', scope: '' } });
      const res = await POST(req);
      expect(res.status).toBe(400);
    });

    it('returns 400 when scope is an empty array', async () => {
      const req = makeRequest({ body: { email: 'user@example.com', scope: [] } });
      const res = await POST(req);
      expect(res.status).toBe(400);
    });

    it('accepts scope as a string', async () => {
      mockBackendSuccess();
      const req = makeRequest({ body: { email: 'user@example.com', scope: 'full' } });
      const res = await POST(req);
      expect(res.status).toBe(201);
    });

    it('accepts scope as a non-empty array', async () => {
      mockBackendSuccess();
      const req = makeRequest({ body: { email: 'user@example.com', scope: ['plans', 'profile'] } });
      const res = await POST(req);
      expect(res.status).toBe(201);
    });
  });

  // ── Email format validation ───────────────────────────────────────────────

  describe('Email format validation', () => {
    const invalidEmails = [
      'plainaddress',
      '@missinglocal.com',
      'user@',
      'user @example.com',
      'user@ example.com',
      'user@.com',
    ];

    invalidEmails.forEach((email) => {
      it(`returns 400 for invalid email: "${email}"`, async () => {
        const req = makeRequest({ body: { email, scope: 'full' } });
        const res = await POST(req);
        expect(res.status).toBe(400);
        const body = await res.json() as { success: boolean; message: string };
        // Generic message — does NOT reveal it's specifically an email error
        expect(body.message).toBe('Invalid request body.');
      });
    });

    it('accepts a valid email and proceeds to backend', async () => {
      mockBackendSuccess();
      const req = makeRequest({ body: { email: 'valid@example.com', scope: 'full' } });
      const res = await POST(req);
      expect(res.status).toBe(201);
    });
  });

  // ── Sanitized request body forwarding ────────────────────────────────────

  describe('Sanitized body construction', () => {
    it('forwards only email, scope, and requestedAt to the backend', async () => {
      mockBackendSuccess();

      const req = makeRequest({
        body: {
          email: 'USER@Example.COM',
          scope: 'full',
          // Extra fields that should be stripped
          reason: 'I want to leave',
          __proto__: { attack: true },
          internalField: 'secret',
        },
      });

      await POST(req);

      expect(mockFetch).toHaveBeenCalledTimes(1);
      const [, fetchOptions] = mockFetch.mock.calls[0] as [string, RequestInit];
      const forwarded = JSON.parse(fetchOptions.body as string) as {
        email: string;
        scope: string;
        requestedAt: string;
        reason?: string;
        internalField?: string;
      };

      expect(forwarded.email).toBe('user@example.com'); // lowercased + trimmed
      expect(forwarded.scope).toBe('full');
      expect(forwarded.requestedAt).toBeDefined();
      expect(forwarded.reason).toBeUndefined();
      expect(forwarded.internalField).toBeUndefined();
    });

    it('lowercases and trims the email before forwarding', async () => {
      mockBackendSuccess();
      const req = makeRequest({ body: { email: '  User@EXAMPLE.com  ', scope: 'full' } });
      await POST(req);

      const [, fetchOptions] = mockFetch.mock.calls[0] as [string, RequestInit];
      const body = JSON.parse(fetchOptions.body as string) as { email: string };
      expect(body.email).toBe('user@example.com');
    });

    it('requestedAt is an ISO 8601 timestamp', async () => {
      mockBackendSuccess();
      const before = Date.now();
      const req = makeRequest({ body: { email: 'a@b.com', scope: 'full' } });
      await POST(req);
      const after = Date.now();

      const [, fetchOptions] = mockFetch.mock.calls[0] as [string, RequestInit];
      const body = JSON.parse(fetchOptions.body as string) as { requestedAt: string };
      const ts = new Date(body.requestedAt).getTime();
      expect(ts).toBeGreaterThanOrEqual(before);
      expect(ts).toBeLessThanOrEqual(after);
    });
  });

  // ── Header forwarding policy ──────────────────────────────────────────────

  describe('Header forwarding policy', () => {
    it('sends Content-Type, x-api-key, and X-Forwarded-For to backend', async () => {
      mockBackendSuccess();
      const req = makeRequest({
        body: { email: 'a@b.com', scope: 'full' },
        ip: '10.0.0.1',
      });
      await POST(req);

      const [, fetchOptions] = mockFetch.mock.calls[0] as [string, RequestInit];
      const headers = fetchOptions.headers as Record<string, string>;

      expect(headers['Content-Type']).toBe('application/json');
      expect(headers['x-api-key']).toBeDefined();
      expect(headers['X-Forwarded-For']).toBe('10.0.0.1');
    });

    it('does NOT forward Authorization header', async () => {
      mockBackendSuccess();
      // The client request carries Authorization but the handler must not forward it.
      const req = new NextRequest('http://localhost:3000/api/deletion-request', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: 'Bearer secret-token',
          cookie: 'session=abc123',
          host: 'attacker.example.com',
        },
        body: JSON.stringify({ email: 'a@b.com', scope: 'full' }),
      });

      await POST(req);

      const [, fetchOptions] = mockFetch.mock.calls[0] as [string, RequestInit];
      const headers = fetchOptions.headers as Record<string, string>;

      expect(headers['authorization']).toBeUndefined();
      expect(headers['Authorization']).toBeUndefined();
      expect(headers['cookie']).toBeUndefined();
      expect(headers['Cookie']).toBeUndefined();
      expect(headers['host']).toBeUndefined();
    });

    it('sends to the correct NestJS endpoint', async () => {
      mockBackendSuccess();
      const req = makeRequest({ body: { email: 'a@b.com', scope: 'full' } });
      await POST(req);

      const [url] = mockFetch.mock.calls[0] as [string, RequestInit];
      expect(url).toMatch(/\/api\/admin\/deletion-requests$/);
    });
  });

  // ── Success response ──────────────────────────────────────────────────────

  describe('Success response', () => {
    it('returns 201 with success: true on backend 201', async () => {
      mockBackendSuccess(201);
      const req = makeRequest({ body: { email: 'a@b.com', scope: 'full' } });
      const res = await POST(req);

      expect(res.status).toBe(201);
      const body = await res.json() as { success: boolean; message: string };
      expect(body.success).toBe(true);
      expect(body.message).toBeTruthy();
    });

    it('returns 201 with success: true on backend 200', async () => {
      mockBackendSuccess(200);
      const req = makeRequest({ body: { email: 'a@b.com', scope: 'full' } });
      const res = await POST(req);

      expect(res.status).toBe(201);
      const body = await res.json() as { success: boolean };
      expect(body.success).toBe(true);
    });

    it('returns 201 even when backend returns 404 (email enumeration prevention)', async () => {
      mockBackendNotFound();
      const req = makeRequest({ body: { email: 'nonexistent@example.com', scope: 'full' } });
      const res = await POST(req);

      // Must return the same response as when the email exists
      expect(res.status).toBe(201);
      const body = await res.json() as { success: boolean };
      expect(body.success).toBe(true);
    });

    it('success messages are identical for registered and unregistered emails', async () => {
      mockBackendSuccess(201);
      const req1 = makeRequest({ body: { email: 'registered@example.com', scope: 'full' }, ip: '1.2.3.4' });
      const res1 = await POST(req1);
      const body1 = await res1.json() as { message: string };

      mockBackendNotFound();
      const req2 = makeRequest({ body: { email: 'unknown@example.com', scope: 'full' }, ip: '1.2.3.5' });
      const res2 = await POST(req2);
      const body2 = await res2.json() as { message: string };

      expect(res1.status).toBe(res2.status);
      expect(body1.message).toBe(body2.message);
    });
  });

  // ── Error handling ────────────────────────────────────────────────────────

  describe('Error handling', () => {
    it('returns 503 with fallback mailto: link on network error', async () => {
      mockNetworkError();
      const req = makeRequest({ body: { email: 'a@b.com', scope: 'full' } });
      const res = await POST(req);

      expect(res.status).toBe(503);
      const body = await res.json() as { success: boolean; message: string; fallback: string };
      expect(body.success).toBe(false);
      expect(body.fallback).toMatch(/^mailto:/);
    });

    it('returns 503 with fallback mailto: link on timeout', async () => {
      mockTimeoutError();
      const req = makeRequest({ body: { email: 'a@b.com', scope: 'full' } });
      const res = await POST(req);

      expect(res.status).toBe(503);
      const body = await res.json() as { success: boolean; fallback: string };
      expect(body.success).toBe(false);
      expect(body.fallback).toMatch(/^mailto:/);
    });

    it('returns 503 when backend returns 5xx', async () => {
      mockBackendError();
      const req = makeRequest({ body: { email: 'a@b.com', scope: 'full' } });
      const res = await POST(req);

      expect(res.status).toBe(503);
    });

    it('503 response includes a Retry-After header', async () => {
      mockNetworkError();
      const req = makeRequest({ body: { email: 'a@b.com', scope: 'full' } });
      const res = await POST(req);

      expect(res.headers.get('retry-after')).toBeTruthy();
    });

    it('503 message includes a support email address', async () => {
      mockNetworkError();
      const req = makeRequest({ body: { email: 'a@b.com', scope: 'full' } });
      const res = await POST(req);

      const body = await res.json() as { message: string };
      expect(body.message).toMatch(/@/); // contains an email address
    });
  });

  // ── Rate limiting ─────────────────────────────────────────────────────────

  describe('Rate limiting (20 req/hour per IP)', () => {
    it('allows up to 20 requests from the same IP', async () => {
      // Use a unique IP to avoid interference from other tests
      const ip = `192.168.100.${Math.floor(Math.random() * 200) + 1}`;

      for (let i = 0; i < 20; i++) {
        mockBackendSuccess();
        const req = makeRequest({ body: { email: 'a@b.com', scope: 'full' }, ip });
        const res = await POST(req);
        expect(res.status).not.toBe(429);
      }
    });

    it('returns 429 on the 21st request from the same IP', async () => {
      const ip = `192.168.200.${Math.floor(Math.random() * 200) + 1}`;

      for (let i = 0; i < 20; i++) {
        mockBackendSuccess();
        const req = makeRequest({ body: { email: 'a@b.com', scope: 'full' }, ip });
        await POST(req);
      }

      // 21st request — should be rate-limited without hitting the backend
      const req = makeRequest({ body: { email: 'a@b.com', scope: 'full' }, ip });
      const res = await POST(req);

      expect(res.status).toBe(429);
      const body = await res.json() as { success: boolean; message: string };
      expect(body.success).toBe(false);
    });

    it('returns 429 response with Retry-After header', async () => {
      const ip = `10.10.${Math.floor(Math.random() * 200) + 1}.1`;

      for (let i = 0; i < 20; i++) {
        mockBackendSuccess();
        const req = makeRequest({ body: { email: 'a@b.com', scope: 'full' }, ip });
        await POST(req);
      }

      const req = makeRequest({ body: { email: 'a@b.com', scope: 'full' }, ip });
      const res = await POST(req);

      expect(res.status).toBe(429);
      expect(res.headers.get('retry-after')).toBeTruthy();
    });

    it('different IPs get independent rate limit buckets', async () => {
      const ip1 = `172.16.${Math.floor(Math.random() * 100)}.1`;
      const ip2 = `172.16.${Math.floor(Math.random() * 100) + 101}.1`;

      // Exhaust ip1's limit
      for (let i = 0; i < 20; i++) {
        mockBackendSuccess();
        const req = makeRequest({ body: { email: 'a@b.com', scope: 'full' }, ip: ip1 });
        await POST(req);
      }

      // ip2 should still be allowed
      mockBackendSuccess();
      const req = makeRequest({ body: { email: 'a@b.com', scope: 'full' }, ip: ip2 });
      const res = await POST(req);
      expect(res.status).toBe(201);
    });
  });

  // ── Backend URL construction ──────────────────────────────────────────────

  describe('Backend endpoint', () => {
    it('calls the NestJS deletion-requests endpoint', async () => {
      mockBackendSuccess();
      const req = makeRequest({ body: { email: 'a@b.com', scope: 'full' } });
      await POST(req);

      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/deletion-requests'),
        expect.any(Object),
      );
    });
  });
});
