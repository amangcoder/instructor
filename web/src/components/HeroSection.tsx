'use client';

import StoreBadges from './StoreBadges';
import { BRAND } from '@/content/brand';

/**
 * HeroSection — full-viewport dark-gradient hero with animated sound-wave background.
 *
 * Accessibility:
 * - <section> with aria-labelledby
 * - Gradient text is visually readable; H1 text content is accessible to screen readers
 */

export default function HeroSection() {
  return (
    <section
      aria-labelledby="hero-heading"
      className="relative w-full min-h-screen flex flex-col items-center justify-center overflow-hidden bg-gradient-to-b from-slate-950 to-slate-900 px-4 sm:px-6 lg:px-8"
    >
      {/* ── Animated sound-wave background ─────────────────────────────────── */}
      <div
        aria-hidden="true"
        className="absolute inset-0 flex items-center justify-center gap-1.5 opacity-10 pointer-events-none"
      >
        {[0.4, 0.7, 1, 0.7, 0.5, 0.8, 1, 0.6, 0.4, 0.9, 1, 0.5, 0.7, 0.4, 0.8].map((height, i) => (
          <div
            key={i}
            className="w-1.5 rounded-full bg-indigo-400 animate-wave"
            style={{
              height: `${height * 80}px`,
              animationDelay: `${(i * 0.08) % 1.2}s`,
            }}
          />
        ))}
      </div>

      {/* ── Hero content ────────────────────────────────────────────────────── */}
      <div className="relative z-10 mx-auto max-w-3xl text-center">
        <div className="flex flex-col items-center gap-6 md:gap-8">
          {/* H1 */}
          <h1
            id="hero-heading"
            className="text-6xl sm:text-7xl lg:text-8xl font-black tracking-tight bg-gradient-to-r from-indigo-400 to-violet-400 bg-clip-text text-transparent"
          >
            {BRAND.name}
          </h1>

          {/* Tagline */}
          <p className="text-xl text-slate-300 max-w-2xl leading-relaxed font-normal">
            {BRAND.tagline}
          </p>

          {/* Store badges */}
          <div className="w-full">
            <StoreBadges />
          </div>
        </div>
      </div>
    </section>
  );
}
