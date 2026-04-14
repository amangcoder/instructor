import React from 'react';
import { CHANGELOG } from '@/content/changelog';
import VersionEntry from './VersionEntry';
import AppScreenshot from './AppScreenshot';

/**
 * VersionsSection Component
 *
 * Renders the versions/changelog section on the landing page with:
 * - A vertical timeline of version entries
 * - Each version displays release date and categorized changes
 * - App screenshot placeholders positioned alongside the timeline
 *
 * Responsive layout:
 * - Mobile: Timeline spans full width
 * - Desktop: Timeline on left, screenshot on right
 *
 * Accessible:
 * - <section> with aria-labelledby pointing to heading
 * - Semantic timeline using <ol> with proper nesting
 * - Proper heading hierarchy
 * - Time elements with datetime attributes
 */
export default function VersionsSection() {
  return (
    <section
      aria-labelledby="versions-heading"
      className="w-full py-16 md:py-24 lg:py-32 px-4 sm:px-6 lg:px-8 bg-surface"
    >
      <div className="mx-auto max-w-6xl">
        {/* Section heading */}
        <div className="mb-12 md:mb-16 text-center">
          <h2
            id="versions-heading"
            className="text-3xl sm:text-4xl md:text-5xl font-black text-on-surface mb-4"
          >
            What&apos;s New
          </h2>
          <p className="text-base sm:text-lg text-on-surface/70 max-w-2xl mx-auto leading-relaxed">
            Follow along with our development journey. See what we&apos;ve added,
            changed, and fixed with each release.
          </p>
        </div>

        {/* Timeline and screenshots container */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-12 items-start">
          {/* Timeline */}
          <div>
            <ol
              role="list"
              className="space-y-1"
              aria-label="Application version changelog"
            >
              {CHANGELOG.map((entry, index) => (
                <li key={entry.version}>
                  <VersionEntry
                    entry={entry}
                    isLast={index === CHANGELOG.length - 1}
                  />
                </li>
              ))}
            </ol>
          </div>

          {/* Screenshots section - visible on desktop, hidden on mobile */}
          <div className="hidden lg:flex flex-col gap-8 sticky top-20">
            <div className="flex justify-center">
              <AppScreenshot />
            </div>
            <div className="text-center">
              <p className="text-sm text-on-surface/60">
                App screenshots will appear here
              </p>
            </div>
          </div>
        </div>

        {/* Mobile screenshot placeholder - visible only on mobile */}
        <div className="lg:hidden mt-12 flex justify-center">
          <div className="max-w-xs w-full">
            <AppScreenshot />
          </div>
        </div>
      </div>
    </section>
  );
}
