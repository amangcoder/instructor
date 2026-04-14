'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import BrandMark from './BrandMark';

/**
 * Header Component
 * Sticky navigation header with brand mark and page links.
 * Uses usePathname() to highlight the active page link.
 *
 * Accessibility:
 * - Semantic <header> and <nav> elements
 * - aria-label on navigation
 * - aria-current="page" on active link
 * - All touch targets >= 44px
 * - Focus indicators via global :focus-visible styles
 *
 * Dark mode:
 * - Uses theme-aware CSS custom properties (bg-surface, border-outline-variant)
 */

export default function Header() {
  const pathname = usePathname();

  const isActive = (path: string) => {
    if (path === '/') {
      return pathname === '/';
    }
    return pathname.startsWith(path);
  };

  const getLinkClasses = (path: string) => {
    const baseClasses =
      'text-sm font-medium transition-colors min-h-[44px] flex items-center px-3 sm:px-4 py-2 rounded-md';
    const activeClasses = isActive(path)
      ? 'text-primary font-bold border-b-2 border-primary'
      : 'text-on-surface opacity-70 hover:opacity-100 hover:bg-primary/5';
    return `${baseClasses} ${activeClasses}`;
  };

  return (
    <header className="sticky top-0 z-50 bg-surface border-b border-outline-variant">
      <nav
        className="mx-auto max-w-6xl px-4 py-3 flex items-center justify-between w-full"
        role="navigation"
        aria-label="Main navigation"
      >
        <div className="flex items-center gap-8">
          <BrandMark />
        </div>

        {/* Navigation links — wraps gracefully on narrow screens */}
        <div className="flex gap-1 sm:gap-4 items-center flex-wrap">
          <Link
            href="/"
            className={getLinkClasses('/')}
            aria-current={isActive('/') ? 'page' : undefined}
          >
            Home
          </Link>
          <Link
            href="/privacy-policy"
            className={getLinkClasses('/privacy-policy')}
            aria-current={isActive('/privacy-policy') ? 'page' : undefined}
          >
            <span className="hidden sm:inline">Privacy Policy</span>
            <span className="sm:hidden">Privacy</span>
          </Link>
          <Link
            href="/data-deletion"
            className={getLinkClasses('/data-deletion')}
            aria-current={isActive('/data-deletion') ? 'page' : undefined}
          >
            <span className="hidden sm:inline">Data Deletion</span>
            <span className="sm:hidden">Deletion</span>
          </Link>
        </div>
      </nav>
    </header>
  );
}
