'use client';

import React, { useState, useEffect, useCallback } from 'react';
import type { ActivityFeedResponse, ActivityEvent, ActivityEventType } from '@/types/activity-feed';
import EmptyState from '@/components/admin/EmptyState';

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

/** Auto-refresh interval: 2 minutes (120 000 ms) */
const REFRESH_INTERVAL_MS = 2 * 60 * 1000;

/** Route handler URL — same-origin proxy to the NestJS backend */
const ACTIVITY_FEED_URL = '/api/admin/activity-feed';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface ActivityFeedWidgetProps {
  /**
   * Server-side pre-fetched activity data passed as initial state.
   * The component will auto-refresh independently every 2 minutes.
   * Pass null if the initial server-side fetch failed (widget shows empty state).
   */
  initialData: ActivityFeedResponse | null;
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/** Unicode icons for each event type */
const EVENT_ICONS: Record<ActivityEventType, string> = {
  signup: '👤',
  tts_failure: '⚠️',
  deletion_request: '🗑️',
};

/** Fallback icon for unknown event types */
const FALLBACK_ICON = '📋';

/**
 * Format an ISO 8601 timestamp as a human-readable locale string.
 * Renders short date + time, matching the user's system locale.
 */
function formatOccurredAt(isoString: string): string {
  try {
    return new Date(isoString).toLocaleString(undefined, {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return isoString;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Sub-components
// ────────────────────────────────────────────────────────────────────────────

function ActivityEventRow({ event }: { event: ActivityEvent }) {
  const icon = EVENT_ICONS[event.type] ?? FALLBACK_ICON;
  const formattedTime = formatOccurredAt(event.occurredAt);

  return (
    <li className="flex items-start gap-3 py-2.5 border-b border-outline-variant/30 last:border-b-0">
      {/* Event type icon */}
      <span
        aria-hidden="true"
        className="mt-0.5 text-base leading-5 shrink-0 select-none"
      >
        {icon}
      </span>

      {/* Event details */}
      <div className="flex-1 min-w-0">
        <p className="text-sm text-on-surface leading-snug">{event.description}</p>
        <time
          dateTime={event.occurredAt}
          className="text-xs text-on-surface-variant mt-0.5 block"
          aria-label={`Occurred at ${formattedTime}`}
        >
          {formattedTime}
        </time>
      </div>
    </li>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Main component
// ────────────────────────────────────────────────────────────────────────────

/**
 * ActivityFeedWidget — client component
 *
 * Displays the last 10 platform events (new signups, TTS failures, deletion
 * requests) in reverse-chronological order.
 *
 * Features:
 *  - Server-side initial data via the `initialData` prop (no loading flash)
 *  - Auto-refreshes every 2 minutes via GET /api/admin/activity-feed
 *  - Refresh indicator during background polling
 *  - Error banner shown only for refresh failures (initial data still visible)
 *  - EmptyState shown when no events exist and no error
 *
 * Accessibility:
 *  - Section has aria-label="Recent Activity"
 *  - Event list has role="list" with aria-label
 *  - Refresh status uses aria-live="polite" so screen readers are notified
 *  - Each event's timestamp has an aria-label with readable time
 */
export default function ActivityFeedWidget({ initialData }: ActivityFeedWidgetProps) {
  const [data, setData] = useState<ActivityFeedResponse | null>(initialData);
  const [refreshError, setRefreshError] = useState<string | null>(null);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const fetchActivity = useCallback(async () => {
    setIsRefreshing(true);
    try {
      const response = await fetch(ACTIVITY_FEED_URL, {
        cache: 'no-store',
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const json = (await response.json()) as ActivityFeedResponse;
      setData(json);
      setRefreshError(null);
    } catch (err) {
      setRefreshError(
        err instanceof Error && err.message
          ? `Refresh failed: ${err.message}`
          : 'Failed to refresh activity feed. Will retry shortly.',
      );
    } finally {
      setIsRefreshing(false);
    }
  }, []);

  // Set up the 2-minute auto-refresh interval
  useEffect(() => {
    const interval = setInterval(fetchActivity, REFRESH_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [fetchActivity]);

  const events = data?.events ?? [];

  return (
    <section
      aria-label="Recent Activity"
      className="rounded-xl bg-surface-container shadow-sm p-6"
    >
      {/* Widget header */}
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-base font-semibold text-on-surface">Recent Activity</h2>

        {/* Refresh status indicator — aria-live so screen readers are notified */}
        <span
          aria-live="polite"
          aria-atomic="true"
          className={`text-xs text-on-surface-variant transition-opacity ${
            isRefreshing ? 'opacity-100 animate-pulse' : 'opacity-0'
          }`}
        >
          {isRefreshing ? 'Refreshing…' : ''}
        </span>
      </div>

      {/* Refresh error banner (initial data still visible below) */}
      {refreshError && (
        <div
          className="rounded-lg bg-error-container px-3 py-2 mb-4 text-xs text-on-error-container"
          role="alert"
          aria-label="Activity feed refresh error"
        >
          {refreshError}
        </div>
      )}

      {/* Event list or empty state */}
      {events.length === 0 ? (
        <EmptyState message="No recent platform activity to display." />
      ) : (
        <ol
          aria-label="Platform events, most recent first"
          className="divide-y-0"
        >
          {events.map((event, index) => (
            <ActivityEventRow
              key={`${event.type}-${event.occurredAt}-${index}`}
              event={event}
            />
          ))}
        </ol>
      )}

      {/* Auto-refresh note (visually subtle, informational) */}
      <p className="mt-4 text-xs text-on-surface-variant/60 text-right" aria-hidden="true">
        Auto-refreshes every 2 minutes
      </p>
    </section>
  );
}
