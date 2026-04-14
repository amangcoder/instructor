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
 * - Uses surface-container instead of hardcoded bg-white
 * - Borders use theme-aware outline-variant
 */
export default function FeatureCard({ feature }: FeatureCardProps) {
  const emoji = ICON_MAP[feature.icon] ?? FALLBACK_ICON;

  return (
    <article
      className="
        flex flex-col gap-4
        rounded-2xl border border-outline-variant bg-surface-container
        p-6
        shadow-sm
        transition-all duration-200
        hover:shadow-md hover:border-primary/30 hover:-translate-y-0.5
        focus-within:ring-2 focus-within:ring-primary focus-within:ring-offset-2
      "
    >
      {/* Icon */}
      <div
        aria-hidden="true"
        className="
          flex h-12 w-12 items-center justify-center
          rounded-xl bg-primary/10
          text-2xl
          select-none
        "
      >
        {emoji}
      </div>

      {/* Title */}
      <h3 className="text-lg font-bold leading-snug text-on-surface">
        {feature.title}
      </h3>

      {/* Description */}
      <p className="text-sm leading-relaxed text-on-surface-variant">
        {feature.description}
      </p>
    </article>
  );
}
