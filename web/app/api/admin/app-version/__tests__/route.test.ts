import { NextRequest } from 'next/server';
import { GET, PATCH } from '../route';

// Mock fetch globally
global.fetch = jest.fn();

const BACKEND_URL = 'http://localhost:3071/api';

const mockRequest = (options: { cookies?: Record<string, string>; method: string } = { method: 'GET' }) => {
  const req = {
    cookies: {
      get: (name: string) => {
        if (options.cookies?.[name]) {
          return { value: options.cookies[name] };
        }
        return undefined;
      },
    },
    json: async () => ({}),
  } as unknown as NextRequest;

  return req;
};

describe('/api/admin/app-version', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    (global.fetch as jest.Mock).mockClear();
  });

  describe('GET', () => {
    it('returns 401 when no access token is provided', async () => {
      const req = mockRequest({ method: 'GET' });
      const res = await GET(req);
      const data = await res.json();

      expect(res.status).toBe(401);
      expect(data.message).toBe('Unauthorized');
    });

    it('forwards request to backend with bearer token', async () => {
      const token = 'test-token-12345';
      const mockConfig = {
        ios: { minVersion: '1.0.0', forceUpdateVersion: '1.0.0' },
        android: { minVersion: '1.0.0', forceUpdateVersion: '1.0.0' },
        enabled: true,
      };

      (global.fetch as jest.Mock).mockResolvedValue({
        ok: true,
        json: async () => mockConfig,
      });

      const req = mockRequest({ method: 'GET', cookies: { access_token: token } });
      const res = await GET(req);
      const data = await res.json();

      expect(global.fetch).toHaveBeenCalledWith(`${BACKEND_URL}/admin/app-version`, {
        method: 'GET',
        headers: { Authorization: `Bearer ${token}` },
        cache: 'no-store',
      });

      expect(res.status).toBe(200);
      expect(data).toEqual(mockConfig);
    });

    it('returns 503 when backend is unavailable', async () => {
      const token = 'test-token-12345';
      (global.fetch as jest.Mock).mockRejectedValue(new Error('Network error'));

      const req = mockRequest({ method: 'GET', cookies: { access_token: token } });
      const res = await GET(req);
      const data = await res.json();

      expect(res.status).toBe(503);
      expect(data.message).toBe('Backend unavailable');
    });

    it('returns non-200 status from backend', async () => {
      const token = 'test-token-12345';
      (global.fetch as jest.Mock).mockResolvedValue({
        ok: false,
        status: 403,
      });

      const req = mockRequest({ method: 'GET', cookies: { access_token: token } });
      const res = await GET(req);
      const data = await res.json();

      expect(res.status).toBe(403);
      expect(data.message).toBe('Failed to fetch app version config');
    });
  });

  describe('PATCH', () => {
    it('returns 401 when no access token is provided', async () => {
      const req = mockRequest({ method: 'PATCH' });
      const res = await PATCH(req);
      const data = await res.json();

      expect(res.status).toBe(401);
      expect(data.message).toBe('Unauthorized');
    });

    it('returns 400 when body is not valid JSON', async () => {
      const token = 'test-token-12345';
      const req = {
        cookies: {
          get: (name: string) => (name === 'access_token' ? { value: token } : undefined),
        },
        json: async () => {
          throw new Error('Invalid JSON');
        },
      } as unknown as NextRequest;

      const res = await PATCH(req);
      const data = await res.json();

      expect(res.status).toBe(400);
      expect(data.message).toBe('Invalid request body');
    });

    it('forwards PATCH request to backend with config data', async () => {
      const token = 'test-token-12345';
      const configData = {
        ios: { minVersion: '1.0.0', forceUpdateVersion: '1.1.0' },
        android: { minVersion: '1.0.0', forceUpdateVersion: '1.1.0' },
        enabled: true,
      };

      (global.fetch as jest.Mock).mockResolvedValue({
        ok: true,
        json: async () => configData,
      });

      const req = {
        cookies: {
          get: (name: string) => (name === 'access_token' ? { value: token } : undefined),
        },
        json: async () => configData,
      } as unknown as NextRequest;

      const res = await PATCH(req);
      const data = await res.json();

      expect(global.fetch).toHaveBeenCalledWith(`${BACKEND_URL}/admin/app-version`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(configData),
        cache: 'no-store',
      });

      expect(res.status).toBe(200);
      expect(data).toEqual(configData);
    });

    it('returns 503 when backend is unavailable', async () => {
      const token = 'test-token-12345';
      const configData = {
        ios: { minVersion: '1.0.0', forceUpdateVersion: '1.1.0' },
        android: { minVersion: '1.0.0', forceUpdateVersion: '1.1.0' },
        enabled: true,
      };

      (global.fetch as jest.Mock).mockRejectedValue(new Error('Network error'));

      const req = {
        cookies: {
          get: (name: string) => (name === 'access_token' ? { value: token } : undefined),
        },
        json: async () => configData,
      } as unknown as NextRequest;

      const res = await PATCH(req);
      const data = await res.json();

      expect(res.status).toBe(503);
      expect(data.message).toBe('Backend unavailable');
    });

    it('returns backend error response with validation errors', async () => {
      const token = 'test-token-12345';
      const configData = {
        ios: { minVersion: '1.0.0', forceUpdateVersion: '0.9.0' },
        android: { minVersion: '1.0.0', forceUpdateVersion: '1.1.0' },
        enabled: true,
      };
      const errorResponse = {
        statusCode: 400,
        message: 'Validation failed',
        error: 'Bad Request',
      };

      (global.fetch as jest.Mock).mockResolvedValue({
        ok: false,
        status: 400,
        json: async () => errorResponse,
      });

      const req = {
        cookies: {
          get: (name: string) => (name === 'access_token' ? { value: token } : undefined),
        },
        json: async () => configData,
      } as unknown as NextRequest;

      const res = await PATCH(req);
      const data = await res.json();

      expect(res.status).toBe(400);
      expect(data).toEqual(errorResponse);
    });

    it('handles backend response that fails to parse JSON', async () => {
      const token = 'test-token-12345';
      const configData = {
        ios: { minVersion: '1.0.0', forceUpdateVersion: '1.1.0' },
        android: { minVersion: '1.0.0', forceUpdateVersion: '1.1.0' },
        enabled: true,
      };

      (global.fetch as jest.Mock).mockResolvedValue({
        ok: true,
        status: 200,
        json: async () => {
          throw new Error('Invalid JSON from backend');
        },
      });

      const req = {
        cookies: {
          get: (name: string) => (name === 'access_token' ? { value: token } : undefined),
        },
        json: async () => configData,
      } as unknown as NextRequest;

      const res = await PATCH(req);
      const data = await res.json();

      expect(res.status).toBe(200);
      expect(data).toEqual({});
    });
  });
});
