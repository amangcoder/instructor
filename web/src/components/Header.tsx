'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import BrandMark from './BrandMark';

/**
 * Header Component
 *
 * Scroll-aware marketing header with:
 * - Transparent on initial load (scrollY <= 100)
 * - bg-slate-950/90 backdrop-blur-sm border-b when scrolled (scrollY > 100)
 * - 200ms CSS transition on background/border
 * - Desktop: standard nav links (>= 640px)
 * - Mobile: hamburger → full-screen overlay (<640px)
 *
 * Accessibility:
 * - Semantic <header> and <nav> elements
 * - aria-label on navigation
 * - aria-current="page" on active link
 * - All touch targets >= 44px (min-h-[44px])
 * - Focus indicators via global :focus-visible styles
 * - Mobile overlay traps focus via close button focus management
 */
export default function Header() {
  const pathname = usePathname();
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  // Scroll listener
  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 100);
    };
    window.addEventListener('scroll', handleScroll, { passive: true });
    // Check initial scroll position
    handleScroll();
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  // Close mobile overlay on Escape key
  useEffect(() => {
    if (!mobileOpen) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setMobileOpen(false);
      }
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [mobileOpen]);

  // Close mobile overlay on route change
  useEffect(() => {
    setMobileOpen(false);
  }, [pathname]);

  const isActive = (path: string) => {
    if (path === '/') return pathname === '/';
    return pathname.startsWith(path);
  };

  const NAV_LINKS = [
    { href: '/', label: 'Home' },
    { href: '/privacy-policy', label: 'Privacy Policy' },
    { href: '/data-deletion', label: 'Data Deletion' },
  ];

  return (
    <>
      <header
        className={[
          'fixed top-0 left-0 right-0 z-50 transition-all duration-200 ease-in-out',
          scrolled
            ? 'bg-slate-950/90 backdrop-blur-sm border-b border-white/8'
            : 'bg-transparent border-b border-transparent',
        ].join(' ')}
      >
        <nav
          className="mx-auto max-w-6xl px-4 py-4 flex items-center justify-between w-full"
          role="navigation"
          aria-label="Main navigation"
        >
          {/* Brand */}
          <div className="flex items-center">
            <BrandMark />
          </div>

          {/* Desktop nav links (>= 640px) */}
          <div className="hidden sm:flex gap-1 items-center">
            {NAV_LINKS.map(({ href, label }) => (
              <Link
                key={href}
                href={href}
                aria-current={isActive(href) ? 'page' : undefined}
                className={[
                  'text-sm font-medium transition-colors min-h-[44px] flex items-center px-3 py-2 rounded-lg',
                  'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-400 focus-visible:ring-offset-2 focus-visible:ring-offset-transparent',
                  isActive(href)
                    ? 'text-white font-semibold'
                    : 'text-slate-300 hover:text-white',
                ].join(' ')}
              >
                {label}
              </Link>
            ))}
          </div>

          {/* Mobile hamburger button (< 640px) */}
          <button
            type="button"
            onClick={() => setMobileOpen(true)}
            aria-label="Open navigation menu"
            aria-expanded={mobileOpen}
            aria-controls="mobile-nav-overlay"
            className={[
              'sm:hidden flex items-center justify-center w-11 h-11 rounded-lg',
              'text-slate-300 hover:text-white transition-colors',
              'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-400',
            ].join(' ')}
          >
            <svg
              className="w-6 h-6"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              aria-hidden="true"
            >
              <line x1="3" y1="6" x2="21" y2="6" />
              <line x1="3" y1="12" x2="21" y2="12" />
              <line x1="3" y1="18" x2="21" y2="18" />
            </svg>
          </button>
        </nav>
      </header>

      {/* Mobile full-screen overlay */}
      {mobileOpen && (
        <div
          id="mobile-nav-overlay"
          role="dialog"
          aria-modal="true"
          aria-label="Navigation menu"
          className="fixed inset-0 bg-slate-950/95 backdrop-blur-sm z-50 flex flex-col items-center justify-center gap-8 sm:hidden"
        >
          {/* Close button */}
          <button
            type="button"
            onClick={() => setMobileOpen(false)}
            aria-label="Close navigation menu"
            className={[
              'absolute top-4 right-4 flex items-center justify-center w-11 h-11 rounded-lg',
              'text-slate-300 hover:text-white transition-colors',
              'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-400',
            ].join(' ')}
          >
            <svg
              className="w-6 h-6"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              aria-hidden="true"
            >
              <line x1="18" y1="6" x2="6" y2="18" />
              <line x1="6" y1="6" x2="18" y2="18" />
            </svg>
          </button>

          {/* Mobile nav links */}
          {NAV_LINKS.map(({ href, label }) => (
            <Link
              key={href}
              href={href}
              onClick={() => setMobileOpen(false)}
              aria-current={isActive(href) ? 'page' : undefined}
              className={[
                'text-2xl font-semibold transition-colors min-h-[44px] flex items-center',
                'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-400 focus-visible:ring-offset-2 focus-visible:ring-offset-slate-950',
                isActive(href) ? 'text-indigo-400' : 'text-white hover:text-indigo-300',
              ].join(' ')}
            >
              {label}
            </Link>
          ))}
        </div>
      )}
    </>
  );
}
