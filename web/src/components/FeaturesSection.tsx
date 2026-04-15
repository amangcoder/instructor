import React from 'react';
import { FEATURES } from '@/content/features';
import FeatureCard from './FeatureCard';

/**
 * FeaturesSection Component
 *
 * Renders the full features grid on the landing page.
 * - Mobile  (<640px): 1-column grid
 * - Tablet  (640px–1023px): 2-column grid
 * - Desktop (1024px+): 3-column grid
 *
 * Layout Balance:
 * - With 7 feature cards, the grid displays 2 full rows (6 cards) + 1 orphan card on row 3
 * - The orphan card is centered on desktop (col-start-2) via `last:lg:col-start-2` class
 * - On tablet and mobile, the orphan card flows naturally in the grid
 *
 * Accessible:
 * - <section> landmark with aria-labelledby pointing to the section heading
 * - Proper heading hierarchy (h2 for section title)
 * - Feature cards use <article> + h3 (see FeatureCard)
 */
export default function FeaturesSection() {
  return (
    <section
      aria-labelledby="features-heading"
      className="w-full py-16 md:py-24 lg:py-32 px-4 sm:px-6 lg:px-8 bg-surface"
    >
      <div className="mx-auto max-w-6xl">
        {/* Section heading */}
        <div className="mb-12 md:mb-16 text-center">
          <h2
            id="features-heading"
            className="text-3xl sm:text-4xl md:text-5xl font-black text-on-surface mb-4"
          >
            Everything you need to stay on track
          </h2>
          <p className="text-base sm:text-lg text-on-surface-variant max-w-2xl mx-auto leading-relaxed">
            Instructor packs powerful features into a simple, distraction-free
            experience designed to keep you moving through every step of your
            routine.
          </p>
        </div>

        {/* Responsive feature grid */}
        <ul
          role="list"
          className="
            grid gap-6
            grid-cols-1
            sm:grid-cols-2
            lg:grid-cols-3
          "
          aria-label="App features"
        >
          {FEATURES.map((feature) => (
            <li key={feature.title} className="last:lg:col-start-2">
              <FeatureCard feature={feature} />
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
