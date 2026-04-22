/**
 * Tests for the admin (dashboard) layout auth gate.
 *
 * Since the layout is a React Server Component that uses `cookies()` and
 * `redirect()` from next/headers and next/navigation, we test the auth
 * logic by calling the layout function directly and asserting on
 * redirect behavior.
 */

// ── Mocks ─────────────────────────────────────────────────────────────────────

let mockCookies: Map<string, { value: string }>;

jest.mock('next/headers', () => ({
  cookies: jest.fn(async () => ({
    get: (name: string) => mockCookies.get(name),
  })),
}));

// Capture redirect calls
const mockRedirect = jest.fn();
jest.mock('next/navigation', () => ({
  redirect: (url: string) => {
    mockRedirect(url);
    throw new Error(`NEXT_REDIRECT: ${url}`);
  },
}));

// Mock AdminSidebar to track props
let mockAdminSidebarProps: { pendingDeletionCount?: number } | undefined;
jest.mock('@/components/admin/AdminSidebar', () => ({
  __esModule: true,
  default: (props: { pendingDeletionCount?: number }) => {
    mockAdminSidebarProps = props;
    return <aside data-testid="admin-sidebar">Sidebar</aside>;
  },
}));

// Mock adminFetch
let mockAdminFetchResult: unknown = null;
let mockAdminFetchError: Error | null = null;
jest.mock('@/lib/admin-api', () => ({
  adminFetch: jest.fn(async () => {
    if (mockAdminFetchError) throw mockAdminFetchError;
    return mockAdminFetchResult;
  }),
  AdminApiError: class AdminApiError extends Error {
    constructor(message: string, public readonly code: string) {
      super(message);
    }
  },
}));

import React from 'react';
import { render } from '@testing-library/react';

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Create a fake JWT with the given payload (no signature verification needed).
 */
function makeJwt(payload: Record<string, unknown>): string {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256' })).toString(
    'base64url',
  );
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${header}.${body}.fake-signature`;
}

function setCookie(name: string, value: string) {
  mockCookies.set(name, { value });
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('AdminDashboardLayout', () => {
  // Dynamic import to ensure mocks are set up before module loads
  let AdminDashboardLayout: (props: {
    children: React.ReactNode;
  }) => Promise<React.JSX.Element>;

  beforeAll(async () => {
    const mod = await import('../(dashboard)/layout');
    AdminDashboardLayout = mod.default;
  });

  beforeEach(() => {
    jest.clearAllMocks();
    mockCookies = new Map();
    mockAdminSidebarProps = undefined;
    mockAdminFetchResult = null;
    mockAdminFetchError = null;
  });

  // ── AC-014: Unauthenticated → /admin/login ───────────────────────────

  it('redirects to /admin/login when no access_token cookie is present', async () => {
    await expect(
      AdminDashboardLayout({ children: <div>test</div> }),
    ).rejects.toThrow('NEXT_REDIRECT: /admin/login');

    expect(mockRedirect).toHaveBeenCalledWith('/admin/login');
  });

  // ── AC-015: Non-admin → / ────────────────────────────────────────────

  it('redirects to / when user role is not admin', async () => {
    setCookie(
      'access_token',
      makeJwt({ sub: '1', email: 'user@test.com', role: 'user' }),
    );

    await expect(
      AdminDashboardLayout({ children: <div>test</div> }),
    ).rejects.toThrow('NEXT_REDIRECT: /');

    expect(mockRedirect).toHaveBeenCalledWith('/');
  });

  it('redirects to / when role is missing from JWT payload', async () => {
    setCookie(
      'access_token',
      makeJwt({ sub: '1', email: 'user@test.com' }),
    );

    await expect(
      AdminDashboardLayout({ children: <div>test</div> }),
    ).rejects.toThrow('NEXT_REDIRECT: /');

    expect(mockRedirect).toHaveBeenCalledWith('/');
  });

  // ── Malformed JWT → /admin/login ──────────────────────────────────────

  it('redirects to /admin/login when JWT is malformed', async () => {
    setCookie('access_token', 'not-a-valid-jwt');

    await expect(
      AdminDashboardLayout({ children: <div>test</div> }),
    ).rejects.toThrow('NEXT_REDIRECT: /admin/login');

    expect(mockRedirect).toHaveBeenCalledWith('/admin/login');
  });

  // ── AC-016: Admin renders children with sidebar ───────────────────────

  it('renders children and sidebar for admin users', async () => {
    setCookie(
      'access_token',
      makeJwt({ sub: '1', email: 'admin@test.com', role: 'admin', exp: Math.floor(Date.now() / 1000) + 3600 }),
    );

    const result = await AdminDashboardLayout({
      children: <div data-testid="child-content">Dashboard content</div>,
    });

    // The result should be a React element tree containing both sidebar and children
    expect(result).toBeTruthy();
    // No redirect should have been called
    expect(mockRedirect).not.toHaveBeenCalled();
  });

  // ── Pending deletion count fetch ────────────────────────────────────────

  it('fetches pending deletion count from backend and passes to AdminSidebar', async () => {
    setCookie(
      'access_token',
      makeJwt({ sub: '1', email: 'admin@test.com', role: 'admin', exp: Math.floor(Date.now() / 1000) + 3600 }),
    );
    mockAdminFetchResult = { count: 5 };

    const { adminFetch } = await import('@/lib/admin-api');

    render(await AdminDashboardLayout({
      children: <div>Dashboard content</div>,
    }));

    expect(adminFetch).toHaveBeenCalledWith(
      '/admin/analytics/deletion-requests/pending-count',
    );
    expect(mockAdminSidebarProps?.pendingDeletionCount).toBe(5);
  });

  it('passes undefined pendingDeletionCount to AdminSidebar when fetch fails', async () => {
    setCookie(
      'access_token',
      makeJwt({ sub: '1', email: 'admin@test.com', role: 'admin', exp: Math.floor(Date.now() / 1000) + 3600 }),
    );
    mockAdminFetchError = new Error('Network error');

    await AdminDashboardLayout({
      children: <div>Dashboard content</div>,
    });

    // Should not redirect and should pass undefined count
    expect(mockRedirect).not.toHaveBeenCalled();
    expect(mockAdminSidebarProps?.pendingDeletionCount).toBeUndefined();
  });

  it('passes zero count to AdminSidebar when there are no pending requests', async () => {
    setCookie(
      'access_token',
      makeJwt({ sub: '1', email: 'admin@test.com', role: 'admin', exp: Math.floor(Date.now() / 1000) + 3600 }),
    );
    mockAdminFetchResult = { count: 0 };

    const { adminFetch } = await import('@/lib/admin-api');

    render(await AdminDashboardLayout({
      children: <div>Dashboard content</div>,
    }));

    expect(adminFetch).toHaveBeenCalledWith(
      '/admin/analytics/deletion-requests/pending-count',
    );
    expect(mockAdminSidebarProps?.pendingDeletionCount).toBe(0);
  });
});
