'use client';

import React from 'react';

interface PolicySectionProps {
  id: string;
  title: string;
  children: React.ReactNode;
}

/**
 * PolicySection Component
 * Reusable wrapper for privacy policy sections.
 * Renders section title as h2 and content with proper typography.
 * Ensures WCAG 2.1 AA compliance with proper heading hierarchy, line-height, and contrast.
 */
export default function PolicySection({
  id,
  title,
  children,
}: PolicySectionProps) {
  return (
    <section id={id} className="mb-12">
      <h2 className="text-2xl font-bold text-on-surface mb-4 pt-2">
        {title}
      </h2>
      <div className="prose prose-sm max-w-none text-on-surface prose-headings:text-on-surface prose-strong:text-on-surface prose-li:text-on-surface space-y-4 leading-relaxed">
        {children}
      </div>
    </section>
  );
}
