'use client';

import Link from 'next/link';

/**
 * Footer Component
 * Displays the footer with legal links and contact information.
 * This component is part of the SharedLayout.
 *
 * Accessibility:
 * - Semantic <footer> element
 * - Proper heading hierarchy (h3 for brand, h4 for sections)
 * - All links have minimum 44px touch target
 *
 * Dark mode:
 * - Uses semantic color tokens (surface, on-surface, outline-variant)
 */

export default function Footer() {
  return (
    <footer className="bg-slate-950 border-t border-white/8">
      <div className="mx-auto max-w-6xl px-4 py-12 w-full">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-8">
          {/* Brand section */}
          <div>
            <h3 className="text-lg font-bold text-indigo-400 mb-2">Instructor</h3>
            <p className="text-slate-400">
              Interactive learning content creation platform.
            </p>
          </div>

          {/* Legal links */}
          <div>
            <h4 className="font-semibold text-white mb-4">Legal</h4>
            <ul className="space-y-2">
              <li>
                <Link
                  href="/privacy-policy"
                  className="text-slate-400 hover:text-white transition min-h-[44px] flex items-center"
                >
                  Privacy Policy
                </Link>
              </li>
              <li>
                <Link
                  href="/data-deletion"
                  className="text-slate-400 hover:text-white transition min-h-[44px] flex items-center"
                >
                  Data Deletion
                </Link>
              </li>
            </ul>
          </div>

          {/* Contact section */}
          <div>
            <h4 className="font-semibold text-white mb-4">Contact</h4>
            <a
              href="mailto:admin@layersiq.com"
              className="text-slate-400 hover:text-white transition min-h-[44px] flex items-center"
            >
              admin@layersiq.com
            </a>
          </div>
        </div>

        {/* Copyright */}
        <div className="border-t border-white/8 pt-8">
          <p className="text-slate-600 text-center text-sm">
            &copy; 2026 LayersIQ Private Limited
          </p>
        </div>
      </div>
    </footer>
  );
}
