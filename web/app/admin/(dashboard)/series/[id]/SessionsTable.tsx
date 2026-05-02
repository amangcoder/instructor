'use client';

import Link from 'next/link';
import { useState } from 'react';
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
} from '@dnd-kit/core';
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import type { AdminSeriesPlanRecord } from '@/types/series';

// Allow runtime fields that don't appear on AdminSeriesPlanRecord but are
// returned by the upstream NestJS series detail endpoint.
type SessionRow = AdminSeriesPlanRecord & {
  voiceQuality?: string | null;
  ttsTotal?: number | null;
  ttsCompleted?: number | null;
};

interface SessionsTableProps {
  seriesId: string;
  seriesName: string;
  initialSessions: SessionRow[];
}

const TTS_STATUS_STYLES: Record<string, string> = {
  completed: 'bg-green-100 text-green-800',
  partial: 'bg-amber-100 text-amber-800',
  pending: 'bg-amber-100 text-amber-800',
  processing: 'bg-primary/10 text-primary',
  failed: 'bg-error-container text-on-error-container',
  none: 'bg-outline-variant/40 text-on-surface-variant',
};

const TTS_STATUS_LABELS: Record<string, string> = {
  completed: 'Ready',
  partial: 'Partial',
  pending: 'Pending',
  processing: 'Processing',
  failed: 'Failed',
  none: 'None',
};

function ttsStatusPill(status: string): { className: string; label: string } {
  const key = status.toLowerCase();
  return {
    className:
      TTS_STATUS_STYLES[key] ?? 'bg-outline-variant/40 text-on-surface-variant',
    label: TTS_STATUS_LABELS[key] ?? status,
  };
}

function formatDate(value: string): string {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

// ────────────────────────────────────────────────────────────────────────────
// Sortable row
// ────────────────────────────────────────────────────────────────────────────

function SortableSessionRow({
  session,
  index,
  seriesId,
}: {
  session: SessionRow;
  index: number;
  seriesId: string;
}) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: session.planId });

  const style: React.CSSProperties = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.6 : 1,
  };

  const pill = ttsStatusPill(session.ttsStatus);
  const total = session.ttsTotal ?? 0;
  const done = session.ttsCompleted ?? 0;
  const progress = total > 0 ? `${done} / ${total}` : '—';

  return (
    <tr
      ref={setNodeRef}
      style={style}
      className={[
        'transition-colors',
        isDragging
          ? 'bg-primary/5 ring-2 ring-primary/30'
          : 'hover:bg-surface-container-low',
      ].join(' ')}
    >
      <td className="px-2 py-3 w-10">
        <button
          type="button"
          {...attributes}
          {...listeners}
          aria-label={`Drag to reorder ${session.name}`}
          className="p-1.5 rounded text-on-surface-variant hover:text-on-surface hover:bg-surface-container-high cursor-grab active:cursor-grabbing transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="currentColor"
            aria-hidden="true"
          >
            <path d="M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z" />
          </svg>
        </button>
      </td>
      <td className="px-4 py-3 text-on-surface-variant tabular-nums w-12">
        {index + 1}
      </td>
      <td className="px-4 py-3 font-medium text-on-surface">{session.name}</td>
      <td className="px-4 py-3 text-on-surface-variant capitalize">
        {session.voiceQuality || '—'}
      </td>
      <td className="px-4 py-3">
        <span
          className={[
            'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold',
            pill.className,
          ].join(' ')}
        >
          {pill.label}
        </span>
      </td>
      <td className="px-4 py-3 text-on-surface-variant tabular-nums">{progress}</td>
      <td className="px-4 py-3">
        <span
          className={[
            'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold',
            session.isActive
              ? 'bg-green-100 text-green-800'
              : 'bg-outline-variant/40 text-on-surface-variant',
          ].join(' ')}
        >
          {session.isActive ? 'Active' : 'Inactive'}
        </span>
      </td>
      <td className="px-4 py-3 text-on-surface-variant">
        {formatDate(session.createdAt)}
      </td>
      <td className="px-4 py-3 text-right">
        <Link
          href={`/admin/plans/${session.planId}?from=series&seriesId=${seriesId}`}
          className="rounded px-3 py-1.5 text-xs font-medium text-primary hover:bg-primary/10 transition-colors"
        >
          View plan &rarr;
        </Link>
      </td>
    </tr>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Main component
// ────────────────────────────────────────────────────────────────────────────

export default function SessionsTable({
  seriesId,
  seriesName,
  initialSessions,
}: SessionsTableProps) {
  const [sessions, setSessions] = useState<SessionRow[]>(initialSessions);
  const [reorderError, setReorderError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 4 } }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    }),
  );

  const handleDragEnd = async (event: DragEndEvent) => {
    const { active, over } = event;
    if (!over || active.id === over.id) return;

    const oldIndex = sessions.findIndex((s) => s.planId === active.id);
    const newIndex = sessions.findIndex((s) => s.planId === over.id);
    if (oldIndex === -1 || newIndex === -1) return;

    const previousOrder = sessions;
    const reordered = arrayMove(sessions, oldIndex, newIndex);
    setSessions(reordered);
    setReorderError(null);
    setSaving(true);

    try {
      const res = await fetch(`/api/admin/series/${seriesId}/reorder-plans`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(
          reordered.map((s, idx) => ({ planId: s.planId, position: idx })),
        ),
      });

      if (!res.ok) {
        setSessions(previousOrder);
        const body = await res.json().catch(() => ({}));
        const msg =
          (body as { error?: string; message?: string }).error ??
          (body as { error?: string; message?: string }).message ??
          `HTTP ${res.status}`;
        setReorderError(`Failed to save order: ${msg}`);
      }
    } catch (err) {
      setSessions(previousOrder);
      setReorderError(
        err instanceof Error ? err.message : 'Network error saving order.',
      );
    } finally {
      setSaving(false);
    }
  };

  if (sessions.length === 0) {
    return (
      <div
        className="flex min-h-[80px] items-center justify-center rounded-xl bg-surface-container p-6 text-center"
        role="status"
      >
        <p className="text-sm text-on-surface-variant">
          This series has no sessions yet.
        </p>
      </div>
    );
  }

  return (
    <div>
      {reorderError && (
        <div
          role="alert"
          className="mb-3 rounded-lg bg-error-container p-3 text-sm text-on-error-container"
        >
          {reorderError}
        </div>
      )}
      {saving && !reorderError && (
        <p
          role="status"
          className="mb-3 text-xs text-on-surface-variant"
          aria-live="polite"
        >
          Saving new order…
        </p>
      )}

      <div className="overflow-x-auto rounded-lg border border-outline-variant">
        <table
          className="min-w-full divide-y divide-outline-variant text-sm"
          aria-label={`Sessions in ${seriesName}`}
        >
          <thead className="bg-surface-container">
            <tr>
              <th className="px-2 py-3 w-10" aria-label="Drag handle" />
              <th className="px-4 py-3 text-left font-semibold text-on-surface-variant w-12">
                #
              </th>
              <th className="px-4 py-3 text-left font-semibold text-on-surface-variant">
                Name
              </th>
              <th className="px-4 py-3 text-left font-semibold text-on-surface-variant">
                Voice quality
              </th>
              <th className="px-4 py-3 text-left font-semibold text-on-surface-variant">
                TTS status
              </th>
              <th className="px-4 py-3 text-left font-semibold text-on-surface-variant">
                TTS progress
              </th>
              <th className="px-4 py-3 text-left font-semibold text-on-surface-variant">
                Active
              </th>
              <th className="px-4 py-3 text-left font-semibold text-on-surface-variant">
                Created
              </th>
              <th className="px-4 py-3 text-right font-semibold text-on-surface-variant">
                Actions
              </th>
            </tr>
          </thead>
          <DndContext
            sensors={sensors}
            collisionDetection={closestCenter}
            onDragEnd={(e) => {
              void handleDragEnd(e);
            }}
          >
            <SortableContext
              items={sessions.map((s) => s.planId)}
              strategy={verticalListSortingStrategy}
            >
              <tbody className="divide-y divide-outline-variant bg-surface">
                {sessions.map((session, idx) => (
                  <SortableSessionRow
                    key={session.planId}
                    session={session}
                    index={idx}
                    seriesId={seriesId}
                  />
                ))}
              </tbody>
            </SortableContext>
          </DndContext>
        </table>
      </div>
    </div>
  );
}
