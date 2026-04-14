import React from 'react';

interface Step {
  title: string;
  description: string;
}

/**
 * Four numbered steps explaining how Instructor works.
 */
const HOW_IT_WORKS_STEPS: Step[] = [
  {
    title: 'Pick or create a plan',
    description:
      'Browse starter plans in the library, or generate a custom one in seconds using AI. Workouts, meditations, study sessions, recipes — all in one place.',
  },
  {
    title: 'Customise your routine',
    description:
      'Adjust step durations, rearrange the order, and choose your voice guidance style. Your plan, your rules.',
  },
  {
    title: 'Run with voice guidance',
    description:
      'Press play and let Instructor guide you through every step with spoken cues. Keep your screen off — audio keeps you in the zone.',
  },
  {
    title: 'Review and improve',
    description:
      'Refine plans based on how they felt, adjust step durations, and keep improving your routines over time.',
  },
];

/**
 * HowItWorksSection Component
 *
 * Renders four numbered steps explaining the core Instructor workflow.
 *
 * Accessible:
 * - <section> with aria-labelledby pointing to h2
 * - Ordered visual numbering (decorative) with h3 step titles
 * - No reliance on colour alone to convey information
 *   (step numbers are both colored AND numbered text)
 */
export default function HowItWorksSection() {
  return (
    <section
      aria-labelledby="how-it-works-heading"
      className="w-full py-16 md:py-24 lg:py-32 px-4 sm:px-6 lg:px-8 bg-surface"
    >
      <div className="mx-auto max-w-6xl">
        {/* Section heading */}
        <div className="mb-12 md:mb-16 text-center">
          <h2
            id="how-it-works-heading"
            className="text-3xl sm:text-4xl md:text-5xl font-black text-on-surface mb-4"
          >
            How it works
          </h2>
          <p className="text-base sm:text-lg text-on-surface-variant max-w-2xl mx-auto leading-relaxed">
            Get up and running in under a minute. No complex setup required.
          </p>
        </div>

        {/* Steps */}
        <ol
          className="
            grid gap-8
            grid-cols-1
            sm:grid-cols-2
            lg:grid-cols-4
          "
          aria-label="Steps to get started with Instructor"
        >
          {HOW_IT_WORKS_STEPS.map((step, index) => (
            <li
              key={step.title}
              className="flex flex-col gap-4"
            >
              {/* Step number badge — text "Step N" for screen readers, visible number for sighted users */}
              <div
                aria-hidden="true"
                className="
                  flex h-12 w-12 items-center justify-center
                  rounded-full
                  bg-primary text-white
                  text-xl font-black
                  select-none flex-shrink-0
                "
              >
                {index + 1}
              </div>

              {/* Step content */}
              <div className="flex flex-col gap-2">
                <h3 className="text-lg font-bold text-on-surface leading-snug">
                  {step.title}
                </h3>
                <p className="text-sm leading-relaxed text-on-surface-variant">
                  {step.description}
                </p>
              </div>

            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
