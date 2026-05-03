import React from 'react';
import type { Feature } from '@/content/features';

/**
 * Icon emoji map — translates icon name strings from the FEATURES data array
 * into renderable emoji characters.
 * No external icon library required.
 */
const ICON_MAP: Record<string, string> = {
  Music: '🎵',
  Zap: '⚡',
  Library: '📚',
  Bell: '🔔',
  Phone: '📱',
  Database: '💾',
  Sun: '☀️',
  Share2: '🔗',
  Dumbbell: '🏋️',
  Lotus: '🧘',
  BookOpen: '📖',
  UtensilsCrossed: '🍳',
  Clock: '⏱️',
};

/** Fallback emoji when an icon name is not found in ICON_MAP. */
const FALLBACK_ICON = '✨';

interface FeatureCardProps {
  feature: Feature;
}

/**
 * FeatureCard Component
 *
 * Renders a single feature card with:
 * - A large emoji icon representing the feature
 * - A bold feature title
 * - A short description paragraph
 * - Subtle hover elevation / border highlight effect
 *
 * Accessible:
 * - Semantic <article> element
 * - aria-hidden on decorative icon container
 * - Heading hierarchy: h3 (inside a section > grid)
 *
 * Dark mode:
 * - Uses dark-slate/indigo Tailwind palette
 */
export default function FeatureCard({ feature }: FeatureCardProps) {
  const emoji = ICON_MAP[feature.icon] ?? FALLBACK_ICON;

  return (
    <article
      className="
        flex flex-col gap-4
        rounded-2xl border border-white/8 bg-slate-900/80
        p-6
        shadow-sm
        transition-all duration-200
        hover:shadow-xl hover:border-indigo-400/30 hover:-translate-y-0.5
        focus-within:ring-2 focus-within:ring-indigo-400 focus-within:ring-offset-2 focus-within:ring-offset-slate-950
      "
    >
      {/* Icon */}
      <div
        aria-hidden="true"
        className="
          flex h-12 w-12 items-center justify-center
          rounded-xl bg-indigo-500/15
          text-2xl
          select-none
        "
      >
        {emoji}
      </div>

      {/* Title */}
      <h3 className="text-lg font-bold leading-snug text-white">
        {feature.title}
      </h3>

      {/* Description */}
      <p className="text-sm leading-relaxed text-slate-400">
        {feature.description}
      </p>
    </article>
  );
}
