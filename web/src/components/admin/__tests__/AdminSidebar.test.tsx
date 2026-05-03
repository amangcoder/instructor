import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';

// ── Mocks ─────────────────────────────────────────────────────────────────────

let mockPathname = '/admin/overview';
const mockRouterPush = jest.fn();

jest.mock('next/navigation', () => ({
  usePathname: () => mockPathname,
  useRouter: () => ({ push: mockRouterPush }),
}));

// next/link renders a standard <a> in the test environment via next/jest setup
// No additional mock needed.

import AdminSidebar from '../AdminSidebar';

// ── Helpers ───────────────────────────────────────────────────────────────────

function setPathname(path: string) {
  mockPathname = path;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('AdminSidebar', () => {
  beforeEach(() => {
    setPathname('/admin/overview');
    mockRouterPush.mockClear();
  });

  // ── AC-002: Exactly 6 navigable items ────────────────────────────────────

  it('renders exactly 5 main navigation items (Dashboard, Users, Content, TTS, Settings)', () => {
    render(<AdminSidebar />);
    // Desktop sidebar (lg:flex) renders labels; rail mode hides them
    expect(screen.getByRole('link', { name: 'Dashboard' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Users' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Content' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'TTS' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Settings' })).toBeInTheDocument();
  });

  it('does not render standalone Deletion Requests, Library, App Version, or Engagement nav items', () => {
    render(<AdminSidebar />);
    expect(screen.queryByRole('link', { name: /Deletion Requests/ })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /Library/ })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /App Version/ })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /Engagement/ })).not.toBeInTheDocument();
  });

  // ── Landmark ─────────────────────────────────────────────────────────────

  it('renders an <aside> landmark with aria-label "Admin navigation"', () => {
    render(<AdminSidebar />);
    expect(
      screen.getByRole('complementary', { name: 'Admin navigation' }),
    ).toBeInTheDocument();
  });

  it('renders a mobile rail aside with aria-label "Admin navigation rail"', () => {
    render(<AdminSidebar />);
    expect(
      screen.getByRole('complementary', { name: 'Admin navigation rail' }),
    ).toBeInTheDocument();
  });

  // ── Brand area (REQ-009) ──────────────────────────────────────────────────

  it('renders the "Instructor" brand name', () => {
    render(<AdminSidebar />);
    expect(screen.getByText('Instructor')).toBeInTheDocument();
  });

  it('renders the "Admin" pill badge', () => {
    render(<AdminSidebar />);
    expect(screen.getByText('Admin')).toBeInTheDocument();
  });

  // ── Link hrefs ────────────────────────────────────────────────────────────

  it('Dashboard link points to /admin/overview', () => {
    render(<AdminSidebar />);
    expect(screen.getByRole('link', { name: 'Dashboard' })).toHaveAttribute(
      'href',
      '/admin/overview',
    );
  });

  it('Users link points to /admin/users', () => {
    render(<AdminSidebar />);
    expect(screen.getByRole('link', { name: 'Users' })).toHaveAttribute(
      'href',
      '/admin/users',
    );
  });

  it('Content link points to /admin/content', () => {
    render(<AdminSidebar />);
    expect(screen.getByRole('link', { name: 'Content' })).toHaveAttribute(
      'href',
      '/admin/content',
    );
  });

  it('TTS link points to /admin/tts', () => {
    render(<AdminSidebar />);
    expect(screen.getByRole('link', { name: 'TTS' })).toHaveAttribute(
      'href',
      '/admin/tts',
    );
  });

  it('Settings link points to /admin/settings', () => {
    render(<AdminSidebar />);
    expect(screen.getByRole('link', { name: 'Settings' })).toHaveAttribute(
      'href',
      '/admin/settings',
    );
  });

  // ── Active link detection ─────────────────────────────────────────────────

  it('marks the Dashboard link with aria-current="page" on /admin/overview', () => {
    setPathname('/admin/overview');
    render(<AdminSidebar />);
    expect(screen.getByRole('link', { name: 'Dashboard' })).toHaveAttribute(
      'aria-current',
      'page',
    );
  });

  it('does not set aria-current on inactive links', () => {
    setPathname('/admin/overview');
    render(<AdminSidebar />);
    expect(screen.getByRole('link', { name: 'Users' })).not.toHaveAttribute(
      'aria-current',
    );
  });

  it('marks /admin/users as active when pathname starts with /admin/users', () => {
    setPathname('/admin/users');
    render(<AdminSidebar />);
    expect(screen.getByRole('link', { name: 'Users' })).toHaveAttribute(
      'aria-current',
      'page',
    );
    expect(screen.getByRole('link', { name: 'Dashboard' })).not.toHaveAttribute(
      'aria-current',
    );
  });

  it('marks /admin/tts as active on the TTS page', () => {
    setPathname('/admin/tts');
    render(<AdminSidebar />);
    expect(screen.getByRole('link', { name: 'TTS' })).toHaveAttribute(
      'aria-current',
      'page',
    );
  });

  it('marks /admin/content as active on the Content page', () => {
    setPathname('/admin/content');
    render(<AdminSidebar />);
    expect(screen.getByRole('link', { name: 'Content' })).toHaveAttribute(
      'aria-current',
      'page',
    );
  });

  it('marks /admin/settings as active on the Settings page', () => {
    setPathname('/admin/settings');
    render(<AdminSidebar />);
    expect(screen.getByRole('link', { name: 'Settings' })).toHaveAttribute(
      'aria-current',
      'page',
    );
  });

  // ── Active link styling (REQ-009) ─────────────────────────────────────────

  it('active link has bg-indigo-600/15 class', () => {
    setPathname('/admin/overview');
    render(<AdminSidebar />);
    const activeLink = screen.getByRole('link', { name: 'Dashboard' });
    expect(activeLink.className).toMatch(/bg-indigo-600\/15/);
  });

  it('active link has border-l-2 border-indigo-400', () => {
    setPathname('/admin/overview');
    render(<AdminSidebar />);
    const activeLink = screen.getByRole('link', { name: 'Dashboard' });
    expect(activeLink.className).toMatch(/border-l-2/);
    expect(activeLink.className).toMatch(/border-indigo-400/);
  });

  it('inactive link does not have active bg-indigo-600/15 class', () => {
    setPathname('/admin/overview');
    render(<AdminSidebar />);
    const inactiveLink = screen.getByRole('link', { name: 'Users' });
    expect(inactiveLink.className).not.toMatch(/bg-indigo-600\/15/);
  });

  // ── Sidebar structure ─────────────────────────────────────────────────────

  it('sidebar is fixed-position', () => {
    const { container } = render(<AdminSidebar />);
    const aside = container.querySelector('aside');
    expect(aside?.className).toMatch(/fixed/);
  });

  it('desktop sidebar has w-64 class', () => {
    const { container } = render(<AdminSidebar />);
    const allAsides = container.querySelectorAll('aside');
    const desktopSidebar = Array.from(allAsides).find((a) =>
      a.className.includes('w-64'),
    );
    expect(desktopSidebar).toBeTruthy();
  });

  // ── WCAG 2.1 AA: min-h-[44px] touch targets (REQ-018) ────────────────────

  it('all nav links have min-h-[44px] touch targets', () => {
    render(<AdminSidebar />);
    const dashboardLink = screen.getByRole('link', { name: 'Dashboard' });
    expect(dashboardLink.className).toMatch(/min-h-\[44px\]/);
  });

  // ── Footer: adminEmail and Sign Out (REQ-009) ─────────────────────────────

  it('renders adminEmail in footer when provided', () => {
    render(<AdminSidebar adminEmail="admin@example.com" />);
    expect(screen.getByText('admin@example.com')).toBeInTheDocument();
  });

  it('does not crash when adminEmail is undefined', () => {
    expect(() => render(<AdminSidebar />)).not.toThrow();
  });

  it('renders Sign Out button', () => {
    render(<AdminSidebar />);
    expect(screen.getByRole('button', { name: /sign out/i })).toBeInTheDocument();
  });

  // ── pendingDeletionCount prop ─────────────────────────────────────────────

  it('accepts pendingDeletionCount prop without error', () => {
    expect(() => render(<AdminSidebar pendingDeletionCount={5} />)).not.toThrow();
  });

  it('accepts zero pendingDeletionCount without error', () => {
    expect(() => render(<AdminSidebar pendingDeletionCount={0} />)).not.toThrow();
  });

  it('does not render a deletion-count badge in the sidebar nav items', () => {
    render(<AdminSidebar pendingDeletionCount={5} />);
    // The badge is in the ContentTabBar (users page), not the sidebar
    expect(
      screen.queryByLabelText(/pending deletion requests/i),
    ).not.toBeInTheDocument();
  });

  // ── Mobile hamburger button ──────────────────────────────────────────────

  it('renders a hamburger button with aria-label "Open navigation menu"', () => {
    render(<AdminSidebar />);
    expect(
      screen.getByRole('button', { name: 'Open navigation menu' }),
    ).toBeInTheDocument();
  });
});
