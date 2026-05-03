'use client';

import React, { Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface TabItem {
  id: string;
  label: string;
  badge?: number;
  badgeColor?: 'amber' | 'indigo';
}

export interface ContentTabBarProps {
  tabs: TabItem[];
  paramName?: string;
  defaultTab?: string;
  children: (activeTab: string) => React.ReactNode;
}

// ────────────────────────────────────────────────────────────────────────────
// Inner component (uses useSearchParams — must be inside Suspense)
// ────────────────────────────────────────────────────────────────────────────

function ContentTabBarInner({
  tabs,
  paramName = 'tab',
  defaultTab,
  children,
}: ContentTabBarProps) {
  const router = useRouter();
  const searchParams = useSearchParams();

  const activeTab = searchParams.get(paramName) ?? defaultTab ?? tabs[0]?.id ?? '';

  const handleTabClick = (tabId: string) => {
    const params = new URLSearchParams(searchParams.toString());
    params.set(paramName, tabId);
    router.replace(`?${params.toString()}`);
  };

  return (
    <div>
      {/* ── Tab bar ─────────────────────────────────────────────────────── */}
      <div
        className="border-b border-white/8 bg-slate-900 px-6"
        role="tablist"
        aria-label="Content tabs"
      >
        <div className="flex gap-0 -mb-px overflow-x-auto">
          {tabs.map((tab) => {
            const isActive = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                type="button"
                role="tab"
                aria-selected={isActive}
                aria-controls={`tabpanel-${tab.id}`}
                id={`tab-${tab.id}`}
                onClick={() => handleTabClick(tab.id)}
                className={[
                  'inline-flex items-center gap-1.5 px-4 py-3 text-sm font-medium whitespace-nowrap',
                  'border-b-2 transition-colors',
                  'focus-visible:outline-none focus-visible:outline-2 focus-visible:outline-indigo-400',
                  'min-h-[44px]',
                  isActive
                    ? 'border-indigo-400 text-white bg-transparent'
                    : 'border-transparent text-slate-400 hover:text-slate-200 hover:border-white/20',
                ].join(' ')}
              >
                {tab.label}
                {tab.badge !== undefined && tab.badge > 0 && (
                  <span
                    className={[
                      'inline-flex items-center justify-center rounded-full text-xs px-1.5 font-medium',
                      tab.badgeColor === 'indigo'
                        ? 'bg-indigo-500/20 text-indigo-400'
                        : 'bg-amber-500/20 text-amber-400',
                    ].join(' ')}
                    aria-label={`${tab.badge} items`}
                  >
                    {tab.badge}
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* ── Tab panel ───────────────────────────────────────────────────── */}
      <div
        role="tabpanel"
        id={`tabpanel-${activeTab}`}
        aria-labelledby={`tab-${activeTab}`}
      >
        {children(activeTab)}
      </div>
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Exported component with built-in Suspense boundary
// ────────────────────────────────────────────────────────────────────────────

/**
 * ContentTabBar — client component with built-in Suspense boundary
 *
 * URL search param (?tab=) driven horizontal tab bar.
 * Renders children as a render prop: children(activeTab: string)
 *
 * Accessibility:
 *  - role="tablist" on container
 *  - role="tab" + aria-selected on each tab button
 *  - role="tabpanel" + aria-labelledby on content area
 *  - Keyboard navigable (Tab to focus, Enter/Space to activate)
 */
export default function ContentTabBar(props: ContentTabBarProps) {
  return (
    <Suspense fallback={
      <div className="border-b border-white/8 bg-slate-900 px-6">
        <div className="flex gap-0 -mb-px">
          {props.tabs.map((tab) => (
            <div key={tab.id} className="px-4 py-3 text-sm text-slate-600 border-b-2 border-transparent">
              {tab.label}
            </div>
          ))}
        </div>
      </div>
    }>
      <ContentTabBarInner {...props} />
    </Suspense>
  );
}

/** Named export for pages that want the Suspense wrapper explicitly */
export const ContentTabBarSuspense = ContentTabBar;
