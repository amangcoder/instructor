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
 * - Desktop (1024px+): horizontal stepper with connecting lines
 * - Mobile: vertical single-column list
 *
 * Accessible:
 * - <section> with aria-labelledby pointing to h2
 * - Ordered list with h3 step titles
 * - Step numbers visible as text (not colour-only)
 */
export default function HowItWorksSection() {
  return (
    <section
      aria-labelledby="how-it-works-heading"
      className="w-full py-16 md:py-24 lg:py-32 px-4 sm:px-6 lg:px-8 bg-slate-900"
    >
      <div className="mx-auto max-w-6xl">
        {/* Section heading */}
        <div className="mb-12 md:mb-16 text-center">
          <h2
            id="how-it-works-heading"
            className="text-3xl sm:text-4xl md:text-5xl font-black text-white mb-4"
          >
            4 Steps to Better Habits
          </h2>
          <p className="text-base sm:text-lg text-slate-400 max-w-2xl mx-auto leading-relaxed">
            Get up and running in under a minute. No complex setup required.
          </p>
        </div>

        {/* Steps — horizontal on lg+, vertical on mobile */}
        <div className="relative">
          {/* Connecting line on desktop only */}
          <div
            aria-hidden="true"
            className="hidden lg:block absolute left-6 right-6 h-px bg-gradient-to-r from-transparent via-indigo-500/30 to-transparent"
            style={{ top: '24px' }}
          />

          <ol
            className="grid gap-8 grid-cols-1 sm:grid-cols-2 lg:grid-cols-4"
            aria-label="Steps to get started with Instructor"
          >
            {HOW_IT_WORKS_STEPS.map((step, index) => (
              <li key={step.title} className="flex flex-col gap-4">
                {/* Step number circle */}
                <div
                  aria-hidden="true"
                  className="
                    flex h-12 w-12 items-center justify-center
                    rounded-full
                    bg-indigo-600 text-white
                    text-xl font-black
                    select-none flex-shrink-0
                    ring-4 ring-slate-900
                    relative z-10
                  "
                >
                  {index + 1}
                </div>
                <span className="sr-only">Step {index + 1}:</span>

                {/* Step content */}
                <div className="flex flex-col gap-2">
                  <h3 className="text-lg font-bold text-white leading-snug">
                    {step.title}
                  </h3>
                  <p className="text-sm leading-relaxed text-slate-400">
                    {step.description}
                  </p>
                </div>
              </li>
            ))}
          </ol>
        </div>
      </div>
    </section>
  );
}
