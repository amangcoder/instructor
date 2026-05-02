'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

// ────────────────────────────────────────────────────────────────────────────
// Navigation items
// ────────────────────────────────────────────────────────────────────────────

interface NavItem {
  label: string;
  href: string;
}

const NAV_ITEMS: ReadonlyArray<NavItem> = [
  { label: 'Overview', href: '/admin/overview' },
  { label: 'Users', href: '/admin/users' },
  { label: 'Consumers', href: '/admin/users-list' },
  { label: 'Admins', href: '/admin/admins' },
  { label: 'Plans', href: '/admin/plans' },
  { label: 'Categories', href: '/admin/categories' },
  { label: 'Series', href: '/admin/series' },
  { label: 'Plan Requests', href: '/admin/plan-requests' },
  { label: 'TTS', href: '/admin/tts' },
  { label: 'Engagement', href: '/admin/engagement' },
  { label: 'Library', href: '/admin/library' },
  { label: 'Deletion Requests', href: '/admin/deletion-requests' },
  { label: 'App Version', href: '/admin/app-version' },
];

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * AdminSidebar — client component
 *
 * Fixed-position vertical navigation sidebar for the /admin/* route group.
 * Uses usePathname() to highlight the active link.
 *
 * Structure:
 *  - Header: "Admin" brand text
 *  - Nav: link list for Overview, Users, Plans, TTS, Engagement, Library, Deletion Requests, App Version
 *
 * Props:
 *  - pendingDeletionCount (optional): Number of pending deletion requests — displays as amber badge next to Deletion Requests nav item when > 0
 *
 * Active link detection:
 *  pathname.startsWith(href) so nested routes (e.g. /admin/users/123)
 *  also highlight the correct nav item.
 *
 * Accessibility:
 *  - <aside> with aria-label for landmark navigation
 *  - <nav> inside for the link list
 *  - aria-current="page" on the active link
 *  - Links have min-h-[44px] for WCAG touch target compliance
 *  - Keyboard navigable via Tab
 */
export interface AdminSidebarProps {
  pendingDeletionCount?: number;
}

export default function AdminSidebar({
  pendingDeletionCount,
}: AdminSidebarProps = {}) {
  const pathname = usePathname();

  return (
    <aside
      className="fixed inset-y-0 left-0 w-64 bg-surface-container border-r border-outline-variant flex flex-col z-40"
      aria-label="Admin navigation"
    >
      {/* ── Brand header ───────────────────────────────────────────────── */}
      <div className="flex items-center h-16 px-6 border-b border-outline-variant flex-shrink-0">
        <span className="text-base font-bold text-on-surface tracking-wide">
          Admin
        </span>
      </div>

      {/* ── Navigation ─────────────────────────────────────────────────── */}
      <nav className="flex-1 overflow-y-auto py-4 px-3" aria-label="Admin sections">
        <ul className="space-y-1" role="list">
          {NAV_ITEMS.map(({ label, href }) => {
            // Exact match or descendant path (followed by "/") — prevents
            // "/admin/users" from incorrectly matching "/admin/users-list".
            const isActive =
              pathname === href || pathname.startsWith(href + '/');

            // Check if this is the Deletion Requests item and show badge if count > 0
            const showBadge =
              label === 'Deletion Requests' &&
              pendingDeletionCount !== undefined &&
              pendingDeletionCount > 0;

            return (
              <li key={href}>
                <Link
                  href={href}
                  aria-current={isActive ? 'page' : undefined}
                  className={[
                    'flex items-center gap-3 rounded-lg px-3 py-2.5',
                    'text-sm font-medium transition-colors min-h-[44px]',
                    'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-1',
                    isActive
                      ? 'bg-primary/10 text-primary font-semibold'
                      : 'text-on-surface-variant hover:bg-primary/5 hover:text-on-surface',
                  ]
                    .filter(Boolean)
                    .join(' ')}
                >
                  <span className="flex-1">{label}</span>
                  {showBadge && (
                    <span
                      className="inline-flex items-center justify-center px-2 py-1 text-xs font-semibold text-amber-900 bg-amber-200 rounded-full"
                      aria-label={`${pendingDeletionCount} pending deletion requests`}
                    >
                      {pendingDeletionCount}
                    </span>
                  )}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>
    </aside>
  );
}
