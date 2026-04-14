'use client';

import Link from 'next/link';
import Image from 'next/image';
import { PLAY_STORE_URL } from '@/content/constants';

/**
 * StoreBadges Component
 * Renders official App Store and Google Play Store badge links.
 * Responsive: stacks vertically on mobile (<640px), side-by-side on tablet+.
 * Badge images are SVG assets stored in public/badges/.
 * Touch targets are >= 44px on mobile for accessibility.
 */

export default function StoreBadges() {
  return (
    <div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
      {/* Google Play Store Badge */}
      <Link
        href={PLAY_STORE_URL}
        className="inline-flex items-center justify-center transition-transform hover:scale-105 active:scale-95 min-h-[60px]"
        aria-label="Get it on Google Play"
        title="Download Instructor on Google Play Store"
      >
        <Image
          src="/badges/google-play-badge.png"
          alt="Get it on Google Play"
          width={240}
          height={92}
          className="h-auto w-auto"
          priority
        />
      </Link>
    </div>
  );
}
