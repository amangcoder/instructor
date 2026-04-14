import React from 'react';
import { USE_CASES } from '@/content/use-cases';

/**
 * Emoji map for use-case icon names.
 */
const ICON_MAP: Record<string, string> = {
  Dumbbell: '🏋️',
  Lotus: '🧘',
  BookOpen: '📖',
  UtensilsCrossed: '🍳',
  Clock: '⏱️',
};

const FALLBACK_ICON = '✨';

/**
 * UseCasesSection Component
 *
 * Showcases the four primary use cases for Instructor:
 * Workout · Meditation · Study · Cooking
 *
 * Accessible:
 * - <section> with aria-labelledby
 * - h2 section title, h3 card titles
 * - Decorative emoji aria-hidden
 *
 * Dark mode:
 * - Cards use surface-container instead of bg-white
 * - Borders use outline-variant
 */
export default function UseCasesSection() {
  return (
    <section
      aria-labelledby="use-cases-heading"
      className="
        w-full py-16 md:py-24 lg:py-32
        px-4 sm:px-6 lg:px-8
        bg-primary/5
      "
    >
      <div className="mx-auto max-w-6xl">
        {/* Heading */}
        <div className="mb-12 md:mb-16 text-center">
          <h2
            id="use-cases-heading"
            className="text-3xl sm:text-4xl md:text-5xl font-black text-on-surface mb-4"
          >
            Built for every routine
          </h2>
          <p className="text-base sm:text-lg text-on-surface-variant max-w-2xl mx-auto leading-relaxed">
            Whether you&apos;re breaking a sweat, finding inner calm, cramming
            for an exam, or following a recipe — Instructor adapts to your
            rhythm.
          </p>
        </div>

        {/* Use-case cards grid */}
        <ul
          role="list"
          className="
            grid gap-6
            grid-cols-1
            sm:grid-cols-2
            lg:grid-cols-4
          "
          aria-label="App use cases"
        >
          {USE_CASES.map((useCase) => {
            const emoji = ICON_MAP[useCase.icon] ?? FALLBACK_ICON;
            return (
              <li key={useCase.title}>
                <article
                  className="
                    flex flex-col gap-4 h-full
                    rounded-2xl border border-outline-variant bg-surface-container
                    p-6
                    shadow-sm
                    transition-all duration-200
                    hover:shadow-md hover:border-primary/30 hover:-translate-y-0.5
                  "
                >
                  {/* Icon */}
                  <div
                    aria-hidden="true"
                    className="
                      flex h-14 w-14 items-center justify-center
                      rounded-2xl bg-primary/10
                      text-3xl
                      select-none
                    "
                  >
                    {emoji}
                  </div>

                  {/* Title */}
                  <h3 className="text-lg font-bold text-on-surface">
                    {useCase.title}
                  </h3>

                  {/* Description */}
                  <p className="text-sm leading-relaxed text-on-surface-variant flex-1">
                    {useCase.description}
                  </p>
                </article>
              </li>
            );
          })}
        </ul>
      </div>
    </section>
  );
}
