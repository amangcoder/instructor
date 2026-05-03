'use client';

import { useState, useCallback, useEffect, useRef, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import type { PlanVoice, PlanVoiceStatus } from '@/types/plan-detail';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface VoiceGridProps {
  /** Plan UUID */
  planId: string;
  /** Initial list of plan voices */
  voices: PlanVoice[];
  /**
   * Voice slug from the plan's `defaultVoice` field. When the voices array is
   * empty, the empty-state offers a button to generate a rendition for this
   * voice. Hidden when null/undefined or no slug is set on the plan.
   */
  defaultVoiceSlug?: string | null;
  /** Callback after a regeneration — parent can refresh data */
  onRegenerated?: () => void;
}

// ────────────────────────────────────────────────────────────────────────────
// Status pill styling
// ────────────────────────────────────────────────────────────────────────────

const STATUS_STYLES: Record<PlanVoiceStatus, string> = {
  pending: 'bg-warning-container text-warning',
  processing: 'bg-primary/10 text-primary',
  ready: 'bg-success-container text-success',
  failed: 'bg-error-container text-error',
};

const STATUS_LABELS: Record<PlanVoiceStatus, string> = {
  pending: 'Pending',
  processing: 'Processing',
  ready: 'Ready',
  failed: 'Failed',
};

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * VoiceGrid — client component
 *
 * Displays a grid of plan voices with status pills and Regenerate buttons.
 * Each voice shows its display name, locale, status, and optional error message.
 *
 * Regenerate button calls POST /api/admin/plans/:id/voices/:voiceId/regenerate
 * and optimistically updates the status to 'pending' in the UI.
 *
 * Accessibility:
 *  - Grid rendered as a table with proper th/td semantics
 *  - Status pills use aria-label for screen readers
 *  - Regenerate buttons include voice name context
 *  - Error messages use role="alert"
 */
export default function VoiceGrid({
  planId,
  voices: initialVoices,
  defaultVoiceSlug,
  onRegenerated,
}: VoiceGridProps) {
  const router = useRouter();
  const [, startTransition] = useTransition();
  const [voices, setVoices] = useState<PlanVoice[]>(initialVoices);
  const [regeneratingIds, setRegeneratingIds] = useState<Set<string>>(new Set());
  const [deletingIds, setDeletingIds] = useState<Set<string>>(new Set());
  const [isGenerating, setIsGenerating] = useState(false);
  const [addSlug, setAddSlug] = useState('');
  const [toasts, setToasts] = useState<Array<{ id: string; message: string; type: 'success' | 'error' }>>([]);
  const [playingVoiceId, setPlayingVoiceId] = useState<string | null>(null);
  const [loadingPreviewIds, setLoadingPreviewIds] = useState<Set<string>>(new Set());
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const previewUrlsRef = useRef<Map<string, string>>(new Map());

  useEffect(() => {
    const previewUrls = previewUrlsRef.current;
    return () => {
      audioRef.current?.pause();
      audioRef.current = null;
      previewUrls.forEach((url) => URL.revokeObjectURL(url));
      previewUrls.clear();
    };
  }, []);

  const refresh = useCallback(() => {
    startTransition(() => router.refresh());
  }, [router]);

  const dismissToast = useCallback((toastId: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== toastId));
  }, []);

  const addToast = useCallback(
    (message: string, type: 'success' | 'error') => {
      const id = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
      setToasts((prev) => [...prev, { id, message, type }]);
      // Auto-dismiss after 5 seconds
      setTimeout(() => dismissToast(id), 5000);
    },
    [dismissToast],
  );

  const handleGenerate = useCallback(
    async (voiceSlug: string) => {
      setIsGenerating(true);
      try {
        const res = await fetch(`/api/admin/plans/${planId}/voices`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ voiceSlug }),
        });

        if (!res.ok) {
          const errBody = await res.json().catch(() => ({}));
          const msg =
            typeof errBody?.error === 'string'
              ? errBody.error
              : 'Failed to queue voice generation.';
          addToast(`${voiceSlug}: ${msg}`, 'error');
          return;
        }

        addToast(`${voiceSlug}: Generation queued`, 'success');
        // Parent refresh is required to surface the newly-created plan_voices
        // row — VoiceGrid does not have the row's UUID/displayName/locale
        // until the GET listing returns them.
        onRegenerated?.();
        refresh();
      } catch {
        addToast(`${voiceSlug}: Network error. Please try again.`, 'error');
      } finally {
        setIsGenerating(false);
      }
    },
    [planId, addToast, onRegenerated, refresh],
  );

  const handleDelete = useCallback(
    async (voiceId: string, voiceName: string) => {
      const confirmed =
        typeof window !== 'undefined'
          ? window.confirm(`Remove the "${voiceName}" voice rendition from this plan?`)
          : true;
      if (!confirmed) return;

      setDeletingIds((prev) => new Set(prev).add(voiceId));
      try {
        const res = await fetch(
          `/api/admin/plans/${planId}/voices/${voiceId}`,
          { method: 'DELETE' },
        );
        if (!res.ok) {
          const body = await res.json().catch(() => ({}));
          const msg =
            typeof body?.error === 'string' ? body.error : 'Failed to delete voice.';
          addToast(`${voiceName}: ${msg}`, 'error');
          return;
        }
        setVoices((prev) => prev.filter((v) => v.voiceId !== voiceId));
        addToast(`${voiceName}: Removed`, 'success');
        onRegenerated?.();
        refresh();
      } catch {
        addToast(`${voiceName}: Network error.`, 'error');
      } finally {
        setDeletingIds((prev) => {
          const next = new Set(prev);
          next.delete(voiceId);
          return next;
        });
      }
    },
    [planId, addToast, onRegenerated, refresh],
  );

  const playPreviewUrl = useCallback(
    (voiceId: string, voiceName: string, url: string) => {
      const current = audioRef.current;
      if (current) {
        current.pause();
        audioRef.current = null;
      }

      const audio = new Audio(url);
      audioRef.current = audio;
      setPlayingVoiceId(voiceId);

      let failed = false;
      const handleFailure = () => {
        if (failed) return;
        failed = true;
        if (audioRef.current === audio) audioRef.current = null;
        setPlayingVoiceId((prev) => (prev === voiceId ? null : prev));
        addToast(`${voiceName}: Unable to play audio.`, 'error');
      };

      audio.addEventListener('ended', () => {
        if (audioRef.current === audio) audioRef.current = null;
        setPlayingVoiceId((prev) => (prev === voiceId ? null : prev));
      });
      audio.addEventListener('pause', () => {
        setPlayingVoiceId((prev) => (prev === voiceId ? null : prev));
      });
      audio.addEventListener('error', handleFailure);

      void audio.play().catch(handleFailure);
    },
    [addToast],
  );

  const handleTogglePlay = useCallback(
    async (voiceId: string, voiceName: string) => {
      if (playingVoiceId === voiceId && audioRef.current) {
        audioRef.current.pause();
        return;
      }

      const cached = previewUrlsRef.current.get(voiceId);
      if (cached) {
        playPreviewUrl(voiceId, voiceName, cached);
        return;
      }

      setLoadingPreviewIds((prev) => new Set(prev).add(voiceId));
      try {
        const res = await fetch(
          `/api/admin/plans/${planId}/voices/${voiceId}/preview`,
          { method: 'POST' },
        );
        if (!res.ok) {
          const body = await res.json().catch(() => ({}));
          const msg =
            typeof body?.error === 'string'
              ? body.error
              : 'Unable to render preview.';
          addToast(`${voiceName}: ${msg}`, 'error');
          return;
        }
        const blob = await res.blob();
        const url = URL.createObjectURL(blob);
        previewUrlsRef.current.set(voiceId, url);
        playPreviewUrl(voiceId, voiceName, url);
      } catch {
        addToast(`${voiceName}: Network error. Please try again.`, 'error');
      } finally {
        setLoadingPreviewIds((prev) => {
          const next = new Set(prev);
          next.delete(voiceId);
          return next;
        });
      }
    },
    [planId, playingVoiceId, playPreviewUrl, addToast],
  );

  const handleRegenerate = useCallback(
    async (voiceId: string, voiceName: string) => {
      setRegeneratingIds((prev) => new Set(prev).add(voiceId));

      try {
        const res = await fetch(
          `/api/admin/plans/${planId}/voices/${voiceId}/regenerate`,
          { method: 'POST' },
        );

        if (!res.ok) {
          const body = await res.json().catch(() => ({}));
          const msg =
            typeof body?.error === 'string'
              ? body.error
              : 'Failed to queue regeneration.';
          addToast(`${voiceName}: ${msg}`, 'error');
          return;
        }

        // Optimistically update status to pending
        setVoices((prev) =>
          prev.map((v) =>
            v.voiceId === voiceId
              ? { ...v, status: 'pending' as PlanVoiceStatus, errorMsg: null }
              : v,
          ),
        );
        addToast(`${voiceName}: Regeneration queued`, 'success');
        onRegenerated?.();
      } catch {
        addToast(`${voiceName}: Network error. Please try again.`, 'error');
      } finally {
        setRegeneratingIds((prev) => {
          const next = new Set(prev);
          next.delete(voiceId);
          return next;
        });
      }
    },
    [planId, addToast, onRegenerated],
  );

  if (voices.length === 0) {
    return (
      <div className="space-y-3">
        {toasts.length > 0 && (
          <div className="space-y-2" aria-live="polite" aria-relevant="additions">
            {toasts.map((toast) => (
              <div
                key={toast.id}
                role="alert"
                className={`flex items-center justify-between rounded-lg px-4 py-2 text-sm ${
                  toast.type === 'error'
                    ? 'bg-error-container text-on-error-container'
                    : 'bg-success-container text-success'
                }`}
              >
                <span>{toast.message}</span>
                <button
                  type="button"
                  onClick={() => dismissToast(toast.id)}
                  aria-label="Dismiss notification"
                  className="ml-3 shrink-0 rounded p-1 hover:bg-black/10 transition-colors"
                >
                  ✕
                </button>
              </div>
            ))}
          </div>
        )}
        <div
          className="flex min-h-[80px] flex-col items-center justify-center gap-3 rounded-xl bg-surface-container p-6 text-center"
          role="status"
          aria-label="No voices configured"
        >
          <p className="text-sm text-on-surface-variant">
            No voices configured for this plan.
          </p>
          {defaultVoiceSlug && (
            <button
              type="button"
              onClick={() => {
                void handleGenerate(defaultVoiceSlug);
              }}
              disabled={isGenerating}
              className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
            >
              {isGenerating
                ? 'Queuing...'
                : `Generate voice (${defaultVoiceSlug})`}
            </button>
          )}
        </div>
      </div>
    );
  }

  // Show a top "Generate default voice" action when the plan's defaultVoice
  // slug doesn't have a plan_voices row yet — once a row exists, the per-row
  // Regenerate button covers the same operation.
  const defaultSlugMissing =
    !!defaultVoiceSlug &&
    !voices.some((v) => v.voice?.slug === defaultVoiceSlug);

  return (
    <div className="space-y-3">
      {/* Toast notifications */}
      {toasts.length > 0 && (
        <div className="space-y-2" aria-live="polite" aria-relevant="additions">
          {toasts.map((toast) => (
            <div
              key={toast.id}
              role="alert"
              className={`flex items-center justify-between rounded-lg px-4 py-2 text-sm ${
                toast.type === 'error'
                  ? 'bg-error-container text-on-error-container'
                  : 'bg-success-container text-success'
              }`}
            >
              <span>{toast.message}</span>
              <button
                type="button"
                onClick={() => dismissToast(toast.id)}
                aria-label="Dismiss notification"
                className="ml-3 shrink-0 rounded p-1 hover:bg-black/10 transition-colors"
              >
                ✕
              </button>
            </div>
          ))}
        </div>
      )}

      <div className="flex flex-wrap items-center justify-end gap-2">
        {defaultSlugMissing && defaultVoiceSlug && (
          <button
            type="button"
            onClick={() => { void handleGenerate(defaultVoiceSlug); }}
            disabled={isGenerating}
            className="rounded-lg bg-primary px-3 py-1.5 text-xs font-semibold text-white hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
          >
            {isGenerating ? 'Queuing...' : `+ Generate default voice (${defaultVoiceSlug})`}
          </button>
        )}
        <form
          onSubmit={(e) => {
            e.preventDefault();
            const slug = addSlug.trim();
            if (slug.length === 0) return;
            void handleGenerate(slug).then(() => setAddSlug(''));
          }}
          className="flex items-center gap-2"
        >
          <input
            type="text"
            value={addSlug}
            onChange={(e) => setAddSlug(e.target.value)}
            placeholder="voice slug (e.g. aoede)"
            aria-label="Add voice by slug"
            className="rounded-lg bg-surface-container-high px-2 py-1 text-xs text-on-surface font-mono focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
            maxLength={100}
          />
          <button
            type="submit"
            disabled={isGenerating || addSlug.trim().length === 0}
            className="rounded-lg bg-primary/10 px-3 py-1.5 text-xs font-semibold text-primary hover:bg-primary/20 transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
          >
            + Add voice
          </button>
        </form>
      </div>

      {/* Voice table */}
      <div className="rounded-xl bg-surface-container shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table
            className="w-full text-sm"
            aria-label="Plan voices status grid"
          >
            <thead>
              <tr className="border-b border-outline-variant bg-surface-container-high">
                {['Voice', 'Locale', 'Status', 'Duration', 'Actions'].map(
                  (h, i) => (
                    <th
                      key={h}
                      scope="col"
                      className={`px-4 py-3 text-xs font-semibold text-on-surface-variant uppercase tracking-wider ${
                        i >= 3 ? 'text-right' : 'text-left'
                      }`}
                    >
                      {h}
                    </th>
                  ),
                )}
              </tr>
            </thead>
            <tbody>
              {voices.map((voice) => {
                const voiceName =
                  voice.voice?.displayName ?? voice.voiceId;
                const isRegenerating = regeneratingIds.has(voice.voiceId);

                return (
                  <tr
                    key={voice.id}
                    className="border-b border-outline-variant/50 hover:bg-primary/5 transition-colors last:border-b-0"
                  >
                    <td className="px-4 py-3 font-medium text-on-surface">
                      {voiceName}
                    </td>
                    <td className="px-4 py-3 text-on-surface-variant">
                      {voice.locale}
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
                          STATUS_STYLES[voice.status]
                        }`}
                        aria-label={`Status: ${STATUS_LABELS[voice.status]}`}
                      >
                        {STATUS_LABELS[voice.status]}
                      </span>
                      {voice.status === 'failed' && voice.errorMsg && (
                        <p className="mt-1 text-xs text-error truncate max-w-[200px]" title={voice.errorMsg}>
                          {voice.errorMsg}
                        </p>
                      )}
                    </td>
                    <td className="px-4 py-3 text-right tabular-nums text-on-surface-variant">
                      {voice.durationMs != null
                        ? `${(voice.durationMs / 1000).toFixed(1)}s`
                        : '—'}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <div className="flex justify-end gap-2">
                        {voice.status === 'ready' && (
                          <button
                            type="button"
                            onClick={() => {
                              void handleTogglePlay(voice.voiceId, voiceName);
                            }}
                            disabled={loadingPreviewIds.has(voice.voiceId)}
                            aria-label={
                              playingVoiceId === voice.voiceId
                                ? `Pause preview for ${voiceName}`
                                : `Play preview for ${voiceName}`
                            }
                            className="rounded-lg bg-primary/10 px-3 py-1.5 text-xs font-semibold text-primary hover:bg-primary/20 transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
                          >
                            {loadingPreviewIds.has(voice.voiceId)
                              ? 'Loading…'
                              : playingVoiceId === voice.voiceId
                                ? '❚❚ Pause'
                                : '▶ Play'}
                          </button>
                        )}
                        <button
                          type="button"
                          onClick={() => { void handleRegenerate(voice.voiceId, voiceName); }}
                          disabled={isRegenerating || voice.status === 'processing'}
                          aria-label={`Regenerate voice ${voiceName}`}
                          className="rounded-lg bg-primary px-3 py-1.5 text-xs font-semibold text-white hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
                        >
                          {isRegenerating ? 'Queuing...' : 'Regenerate'}
                        </button>
                        <button
                          type="button"
                          onClick={() => { void handleDelete(voice.voiceId, voiceName); }}
                          disabled={deletingIds.has(voice.voiceId)}
                          aria-label={`Delete voice ${voiceName}`}
                          className="rounded-lg bg-error-container px-3 py-1.5 text-xs font-semibold text-error hover:bg-error/20 transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error"
                        >
                          {deletingIds.has(voice.voiceId) ? 'Removing…' : 'Delete'}
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
