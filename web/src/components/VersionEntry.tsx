import React from 'react';
import { ChangeLogEntry } from '@/content/changelog';

interface VersionEntryProps {
  entry: ChangeLogEntry;
  isLast?: boolean;
}

/**
 * Type-to-icon mapping for changelog entry types
 */
const CHANGE_TYPE_ICONS: Record<string, string> = {
  Added: '✨',
  Changed: '🔄',
  Fixed: '🐛',
  Removed: '🗑️',
};

/**
 * VersionEntry Component
 *
 * Renders a single version entry in the timeline with:
 * - Version number and release date
 * - Timeline dot and connector line
 * - Categorized changes (Added, Changed, Fixed, Removed)
 * - Each change type has a visual icon
 *
 * Accessible:
 * - Semantic <article> element
 * - Heading hierarchy: h3 for version
 * - aria-label on timeline dot
 * - Descriptive text for change types and items
 * - aria-hidden on decorative dots
 */
export default function VersionEntry({
  entry,
  isLast = false,
}: VersionEntryProps) {
  const releaseDate = new Date(entry.date);
  const formattedDate = releaseDate.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });

  return (
    <article className="relative">
      {/* Timeline container */}
      <div className="flex gap-6 pb-8 md:pb-12">
        {/* Timeline dot and connector */}
        <div className="flex flex-col items-center">
          {/* Version dot */}
          <div
            aria-hidden="true"
            className="
              h-4 w-4 md:h-5 md:w-5
              rounded-full
              bg-primary
              ring-4 ring-surface
              flex-shrink-0
              relative z-10
            "
          />

          {/* Connector line (only if not last) */}
          {!isLast && (
            <div
              aria-hidden="true"
              className="
                w-1
                flex-grow
                bg-gradient-to-b from-primary/40 to-primary/10
                min-h-[4rem] md:min-h-[6rem]
              "
            />
          )}
        </div>

        {/* Content */}
        <div className="flex-1 pt-1">
          {/* Header: Version and Date */}
          <div className="mb-4">
            <h3 className="text-xl md:text-2xl font-bold text-on-surface">
              v{entry.version}
            </h3>
            <time
              dateTime={entry.date}
              className="text-sm md:text-base text-on-surface/60"
            >
              {formattedDate}
            </time>
          </div>

          {/* Changes grouped by type */}
          <div className="flex flex-col gap-4">
            {entry.sections.map((section) => (
              <div key={section.type}>
                {/* Change type header */}
                <h4 className="flex items-center gap-2 text-sm md:text-base font-semibold text-on-surface mb-2">
                  <span aria-hidden="true" className="text-lg">
                    {CHANGE_TYPE_ICONS[section.type] || '•'}
                  </span>
                  {section.type}
                </h4>

                {/* Change items as unordered list */}
                <ul
                  className="ml-6 space-y-1"
                  aria-label={`${section.type} changes in version ${entry.version}`}
                >
                  {section.items.map((item, index) => (
                    <li
                      key={index}
                      className="text-sm md:text-base text-on-surface/80 leading-relaxed"
                    >
                      <span aria-hidden="true" className="text-primary mr-2">
                        •
                      </span>
                      {item}
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        </div>
      </div>
    </article>
  );
}
