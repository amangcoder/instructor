'use client';

import StoreBadges from './StoreBadges';
import { BRAND } from '@/content/brand';

/**
 * HeroSection Component
 * Landing page hero section displaying:
 * - App name with gradient via BrandMark component
 * - Marketing tagline from BRAND.tagline
 * - Download badge buttons (StoreBadges component)
 *
 * Responsive design:
 * - Typography scales from 320px to 1920px without horizontal scroll
 * - Centered layout with responsive padding
 * - Touch targets >= 44px on mobile
 *
 * Accessibility:
 * - Gradient text has aria-label fallback ("Instructor" text is visually
 *   present and accessible to screen readers)
 */

export default function HeroSection() {
  return (
    <section
      aria-labelledby="hero-heading"
      className="w-full py-10 md:py-14 px-4 sm:px-6 lg:px-8"
    >
      {/* Container with max-width constraint */}
      <div className="mx-auto max-w-3xl">
        {/* Hero content wrapper - centered alignment */}
        <div className="flex flex-col items-center justify-center gap-6 md:gap-8 lg:gap-10 text-center">
          {/* App Name with Gradient - BrandMark Component */}
          <div className="flex justify-center">
            <h1
              id="hero-heading"
              className="text-4xl sm:text-5xl md:text-6xl lg:text-7xl font-black"
              style={{
                backgroundImage: `linear-gradient(${BRAND.gradientAngle}, ${BRAND.gradientFrom} 0%, ${BRAND.gradientTo} 100%)`,
                backgroundClip: 'text',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
              }}
            >
              {BRAND.name}
            </h1>
          </div>

          {/* Tagline */}
          <p className="text-lg sm:text-xl md:text-2xl lg:text-3xl text-on-surface leading-relaxed max-w-2xl font-normal">
            {BRAND.tagline}
          </p>

          {/* Download CTA - Store Badges */}
          <div className="w-full">
            <StoreBadges />
          </div>
        </div>
      </div>
    </section>
  );
}
