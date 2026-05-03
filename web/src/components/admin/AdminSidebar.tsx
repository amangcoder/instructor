'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useState } from 'react';

// ────────────────────────────────────────────────────────────────────────────
// Navigation items
// ────────────────────────────────────────────────────────────────────────────

interface NavItem {
  label: string;
  href: string;
  icon: React.ReactNode;
}

const NAV_ITEMS: ReadonlyArray<NavItem> = [
  {
    label: 'Dashboard',
    href: '/admin/overview',
    icon: (
      <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <rect x="3" y="3" width="7" height="7" rx="1" />
        <rect x="14" y="3" width="7" height="7" rx="1" />
        <rect x="14" y="14" width="7" height="7" rx="1" />
        <rect x="3" y="14" width="7" height="7" rx="1" />
      </svg>
    ),
  },
  {
    label: 'Users',
    href: '/admin/users',
    icon: (
      <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
        <circle cx="9" cy="7" r="4" />
        <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
        <path d="M16 3.13a4 4 0 0 1 0 7.75" />
      </svg>
    ),
  },
  {
    label: 'Content',
    href: '/admin/content',
    icon: (
      <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
        <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
      </svg>
    ),
  },
  {
    label: 'TTS',
    href: '/admin/tts',
    icon: (
      <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <path d="M12 1v22M4.22 4.22l15.56 15.56M1 12h22M4.22 19.78L19.78 4.22" />
      </svg>
    ),
  },
  {
    label: 'Settings',
    href: '/admin/settings',
    icon: (
      <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <circle cx="12" cy="12" r="3" />
        <path d="M12 1v6m0 6v6M4.22 4.22l4.24 4.24m0 5.08l-4.24 4.24M1 12h6m6 0h6M4.22 19.78l4.24-4.24m5.08 0l4.24 4.24M19.78 4.22l-4.24 4.24m0 5.08l4.24 4.24" />
      </svg>
    ),
  },
];

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * AdminSidebar — client component
 *
 * Fixed-position vertical navigation sidebar with consolidated 6 items.
 * Features responsive collapse: icon-only rail on <1024px, slide-in overlay on mobile.
 *
 * Structure:
 *  - Brand area: BrandMark + "Instructor" + "Admin" pill badge
 *  - Nav: 6 items with icons (Dashboard, Users, Content, TTS, Settings)
 *  - Footer: adminEmail + Sign Out button
 *
 * Props:
 *  - pendingDeletionCount (optional): Pending deletion count for badge on Users tab
 *  - adminEmail (optional): Admin email displayed in footer
 *
 * Responsive behavior:
 *  - ≥ 1024px: Full w-64 sidebar with labels visible
 *  - < 1024px: Icon-only rail w-[60px], hamburger button opens overlay
 *
 * Accessibility:
 *  - aria-current="page" on active link
 *  - min-h-[44px] touch targets (WCAG)
 *  - focus-visible outlines on all interactive elements
 *  - Overlay closes on Escape key or outside click
 */
export interface AdminSidebarProps {
  pendingDeletionCount?: number;
  adminEmail?: string;
}

export default function AdminSidebar({
  pendingDeletionCount,
  adminEmail,
}: AdminSidebarProps = {}) {
  const pathname = usePathname();
  const router = useRouter();
  const [isOverlayOpen, setIsOverlayOpen] = useState(false);

  const handleSignOut = async () => {
    try {
      await fetch('/api/auth/logout', { method: 'POST' });
      router.push('/admin/login');
    } catch (error) {
      console.error('Sign out failed:', error);
    }
  };

  const handleNavClick = () => {
    setIsOverlayOpen(false);
  };

  const handleEscape = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      setIsOverlayOpen(false);
    }
  };

  return (
    <>
      {/* ── Desktop Sidebar (≥ 1024px) ──────────────────────────────────────── */}
      <aside
        className="hidden lg:flex fixed inset-y-0 left-0 w-64 bg-slate-900 border-r border-white/8 flex-col z-40"
        aria-label="Admin navigation"
      >
        <NavContent
          navItems={NAV_ITEMS}
          pathname={pathname}
          pendingDeletionCount={pendingDeletionCount}
          adminEmail={adminEmail}
          onNavClick={handleNavClick}
          onSignOut={handleSignOut}
          isRailMode={false}
        />
      </aside>

      {/* ── Mobile Icon Rail (< 1024px) ─────────────────────────────────────── */}
      <aside
        className="lg:hidden fixed inset-y-0 left-0 w-[60px] bg-slate-900 border-r border-white/8 flex flex-col z-40"
        aria-label="Admin navigation rail"
      >
        <NavContent
          navItems={NAV_ITEMS}
          pathname={pathname}
          pendingDeletionCount={pendingDeletionCount}
          adminEmail={adminEmail}
          onNavClick={handleNavClick}
          onSignOut={handleSignOut}
          isRailMode={true}
        />
        {/* Hamburger Button */}
        <div className="p-2 border-t border-white/8 flex items-center justify-center">
          <button
            onClick={() => setIsOverlayOpen(true)}
            className="p-2 rounded-lg hover:bg-white/5 transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-indigo-400 focus-visible:outline-offset-2"
            aria-label="Open navigation menu"
            aria-expanded={isOverlayOpen}
          >
            <svg className="w-5 h-5 text-slate-300" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <line x1="3" y1="6" x2="21" y2="6" />
              <line x1="3" y1="12" x2="21" y2="12" />
              <line x1="3" y1="18" x2="21" y2="18" />
            </svg>
          </button>
        </div>
      </aside>

      {/* ── Mobile Overlay (< 1024px) ────────────────────────────────────────── */}
      {isOverlayOpen && (
        <>
          {/* Scrim */}
          <div
            className="fixed inset-0 bg-black/50 backdrop-blur-sm z-30 lg:hidden"
            onClick={() => setIsOverlayOpen(false)}
            onKeyDown={handleEscape}
            role="presentation"
          />
          {/* Overlay Sidebar */}
          <aside
            className="fixed inset-y-0 left-0 w-64 bg-slate-900 border-r border-white/8 flex flex-col z-40 lg:hidden animate-in slide-in-from-left duration-200"
            aria-label="Admin navigation overlay"
            onKeyDown={handleEscape}
          >
            <div className="absolute top-4 right-4">
              <button
                onClick={() => setIsOverlayOpen(false)}
                className="p-2 rounded-lg hover:bg-white/5 transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-indigo-400 focus-visible:outline-offset-2"
                aria-label="Close navigation menu"
              >
                <svg className="w-5 h-5 text-slate-300" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <line x1="18" y1="6" x2="6" y2="18" />
                  <line x1="6" y1="6" x2="18" y2="18" />
                </svg>
              </button>
            </div>
            <NavContent
              navItems={NAV_ITEMS}
              pathname={pathname}
              pendingDeletionCount={pendingDeletionCount}
              adminEmail={adminEmail}
              onNavClick={handleNavClick}
              onSignOut={handleSignOut}
              isRailMode={false}
              isOverlay={true}
            />
          </aside>
        </>
      )}
    </>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// NavContent subcomponent
// ────────────────────────────────────────────────────────────────────────────

interface NavContentProps {
  navItems: ReadonlyArray<NavItem>;
  pathname: string;
  pendingDeletionCount?: number;
  adminEmail?: string;
  onNavClick: () => void;
  onSignOut: () => void;
  isRailMode: boolean;
  isOverlay?: boolean;
}

function NavContent({
  navItems,
  pathname,
  pendingDeletionCount,
  adminEmail,
  onNavClick,
  onSignOut,
  isRailMode,
  isOverlay = false,
}: NavContentProps) {
  return (
    <>
      {/* ── Brand area ──────────────────────────────────────────────────────── */}
      {!isRailMode && (
        <div className="p-6 border-b border-white/8 flex-shrink-0">
          <div className="flex items-center gap-3 mb-3">
            <div
              className="w-8 h-8 rounded-lg bg-gradient-to-br from-indigo-500 to-violet-600 flex items-center justify-center flex-shrink-0"
              aria-hidden="true"
            >
              <span className="text-white font-bold text-sm">I</span>
            </div>
            <span className="font-bold text-white">Instructor</span>
          </div>
          <div className="inline-block bg-indigo-600/20 text-indigo-400 text-xs rounded-full px-2 py-0.5 font-medium">
            Admin
          </div>
        </div>
      )}

      {/* ── Navigation ──────────────────────────────────────────────────────── */}
      <nav className={`flex-1 overflow-y-auto ${isRailMode ? 'py-4 px-2' : 'py-4 px-3'}`} aria-label="Admin sections">
        <ul className={`${isRailMode ? 'space-y-2' : 'space-y-1'}`} role="list">
          {navItems.map(({ label, href, icon }) => {
            const isActive = pathname === href || pathname.startsWith(href + '/');

            return (
              <li key={href}>
                <Link
                  href={href}
                  onClick={onNavClick}
                  aria-current={isActive ? 'page' : undefined}
                  className={[
                    'flex items-center gap-3 rounded-xl px-3 py-2.5 transition-colors min-h-[44px]',
                    'focus-visible:outline focus-visible:outline-2 focus-visible:outline-indigo-400 focus-visible:outline-offset-2',
                    isActive
                      ? 'bg-indigo-600/15 text-indigo-300 border-l-2 border-indigo-400'
                      : 'text-slate-400 hover:text-slate-100 hover:bg-white/5',
                    isRailMode ? 'justify-center' : '',
                  ]
                    .filter(Boolean)
                    .join(' ')}
                >
                  {icon}
                  {!isRailMode && <span className="flex-1">{label}</span>}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      {/* ── Footer ──────────────────────────────────────────────────────────── */}
      {!isRailMode && (
        <div className="p-4 border-t border-white/8 flex-shrink-0 space-y-3">
          {adminEmail && (
            <p className="text-slate-500 text-xs truncate" title={adminEmail}>
              {adminEmail}
            </p>
          )}
          <button
            onClick={onSignOut}
            className="w-full px-3 py-2 rounded-lg text-slate-400 hover:text-red-400 transition-colors text-sm font-medium focus-visible:outline focus-visible:outline-2 focus-visible:outline-indigo-400 focus-visible:outline-offset-2"
          >
            Sign Out
          </button>
        </div>
      )}
    </>
  );
}
