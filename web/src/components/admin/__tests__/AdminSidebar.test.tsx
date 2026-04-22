import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';

// ── Mocks ─────────────────────────────────────────────────────────────────────

let mockPathname = '/admin/overview';

jest.mock('next/navigation', () => ({
  usePathname: () => mockPathname,
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
  });

  // ── Rendering ────────────────────────────────────────────────────────────

  it('renders all navigation links including Deletion Requests and App Version', () => {
    render(<AdminSidebar />);
    expect(screen.getByRole('link', { name: /Overview/ })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /Users/ })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /Plans/ })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /TTS/ })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /Engagement/ })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /Library/ })).toBeInTheDocument();
    expect(
      screen.getByRole('link', { name: /Deletion Requests/ }),
    ).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /App Version/ })).toBeInTheDocument();
  });

  it('renders an <aside> landmark with aria-label', () => {
    render(<AdminSidebar />);
    expect(
      screen.getByRole('complementary', { name: 'Admin navigation' }),
    ).toBeInTheDocument();
  });

  it('renders the "Admin" brand header text', () => {
    render(<AdminSidebar />);
    expect(screen.getByText('Admin')).toBeInTheDocument();
  });

  // ── Link hrefs ────────────────────────────────────────────────────────────

  it('each link points to the correct href', () => {
    render(<AdminSidebar />);
    expect(screen.getByRole('link', { name: 'Overview' })).toHaveAttribute(
      'href',
      '/admin/overview',
    );
    expect(screen.getByRole('link', { name: 'Users' })).toHaveAttribute(
      'href',
      '/admin/users',
    );
    expect(screen.getByRole('link', { name: 'Library' })).toHaveAttribute(
      'href',
      '/admin/library',
    );
  });

  // ── Active link detection ─────────────────────────────────────────────────

  it('marks the current page link with aria-current="page"', () => {
    setPathname('/admin/overview');
    render(<AdminSidebar />);
    expect(screen.getByRole('link', { name: 'Overview' })).toHaveAttribute(
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
    expect(screen.getByRole('link', { name: 'Overview' })).not.toHaveAttribute(
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

  // ── Active link styling ───────────────────────────────────────────────────

  it('active link has bg-primary/10 class', () => {
    setPathname('/admin/plans');
    render(<AdminSidebar />);
    const activeLink = screen.getByRole('link', { name: 'Plans' });
    expect(activeLink.className).toMatch(/bg-primary/);
  });

  it('sidebar is fixed-position with w-64', () => {
    const { container } = render(<AdminSidebar />);
    const aside = container.querySelector('aside');
    expect(aside?.className).toMatch(/fixed/);
    expect(aside?.className).toMatch(/w-64/);
  });

  // ── Deletion Requests nav item and badge ─────────────────────────────

  it('renders Deletion Requests nav item with correct href', () => {
    render(<AdminSidebar />);
    expect(screen.getByRole('link', { name: /Deletion Requests/ })).toHaveAttribute(
      'href',
      '/admin/deletion-requests',
    );
  });

  it('renders App Version nav item with correct href', () => {
    render(<AdminSidebar />);
    expect(screen.getByRole('link', { name: /App Version/ })).toHaveAttribute(
      'href',
      '/admin/app-version',
    );
  });

  it('does not render badge when pendingDeletionCount is undefined', () => {
    render(<AdminSidebar pendingDeletionCount={undefined} />);
    // Badge should not be present
    expect(screen.queryByText(/^\d+$/)).not.toBeInTheDocument();
  });

  it('does not render badge when pendingDeletionCount is 0', () => {
    render(<AdminSidebar pendingDeletionCount={0} />);
    // Badge should not be present for count of 0
    expect(screen.queryByText('0')).not.toBeInTheDocument();
  });

  it('renders amber badge with count when pendingDeletionCount > 0', () => {
    render(<AdminSidebar pendingDeletionCount={5} />);
    const badge = screen.getByText('5');
    expect(badge).toBeInTheDocument();
    // Check badge styling
    expect(badge.className).toMatch(/bg-amber-200/);
    expect(badge.className).toMatch(/text-amber-900/);
  });

  it('badge has accessible aria-label', () => {
    render(<AdminSidebar pendingDeletionCount={3} />);
    const badge = screen.getByLabelText('3 pending deletion requests');
    expect(badge).toBeInTheDocument();
    expect(badge).toHaveTextContent('3');
  });

  it('renders Deletion Requests as active link when on that route', () => {
    setPathname('/admin/deletion-requests');
    render(<AdminSidebar pendingDeletionCount={2} />);
    const link = screen.getByRole('link', { name: /Deletion Requests/ });
    expect(link).toHaveAttribute('aria-current', 'page');
  });

  it('renders App Version as active link when on that route', () => {
    setPathname('/admin/app-version');
    render(<AdminSidebar />);
    const link = screen.getByRole('link', { name: /App Version/ });
    expect(link).toHaveAttribute('aria-current', 'page');
  });

  it('does not render badge on inactive Deletion Requests link', () => {
    setPathname('/admin/overview');
    render(<AdminSidebar pendingDeletionCount={5} />);
    const badge = screen.getByText('5');
    expect(badge).toBeInTheDocument();
    // Badge should still be rendered even when link is inactive
    const link = screen.getByRole('link', { name: /Deletion Requests/ });
    expect(link).not.toHaveAttribute('aria-current', 'page');
  });
});
