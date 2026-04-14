'use client';

import Link from 'next/link';

/**
 * BrandMark Component
 * Renders the 'Instructor' app name with CSS gradient matching Flutter branding.
 * Colors: #565C8C to #C0C6FD (primary to primaryContainer)
 */

export default function BrandMark() {
  return (
    <Link
      href="/"
      className="flex items-center gap-2 text-2xl font-bold hover:opacity-80 transition min-h-[44px] py-2"
      aria-label="Instructor home"
    >
      <span
        className="font-black"
        style={{
          backgroundImage: 'linear-gradient(135deg, #565C8C 0%, #C0C6FD 100%)',
          backgroundClip: 'text',
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'transparent',
        }}
      >
        Instructor
      </span>
    </Link>
  );
}
