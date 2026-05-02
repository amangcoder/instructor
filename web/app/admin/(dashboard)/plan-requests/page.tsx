'use client';

/**
 * Admin Plan Requests Page — client component (REQ-017)
 *
 * Lists pending plan requests (plans submitted by users for admin review).
 * Each row has a "Promote to Plan" button that opens a pre-filled form derived
 * from the request data and submits to POST /api/admin/plan-requests/:id/promote.
 *
 * Route: /admin/plan-requests
 * Layout: AdminDashboardLayout (auth-gated, sidebar)
 */

import { useState, useEffect, useCallback } from 'react';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

interface PlanRequest {
  id: string;
  title: string;
  description?: string;
  ownerUserId: string;
  ownerEmail?: string;
  visibility: string;
  createdAt: string;
  updatedAt: string;
}

interface PromoteFormData {
  voiceIds: string[];
  seriesId?: string;
  categoryId?: string;
  position?: number;
}

// ────────────────────────────────────────────────────────────────────────────
// Promote Modal
// ────────────────────────────────────────────────────────────────────────────

interface PromoteModalProps {
  planRequest: PlanRequest;
  onClose: () => void;
  onSuccess: (planId: string) => void;
}

function PromoteModal({ planRequest, onClose, onSuccess }: PromoteModalProps) {
  const [voiceIds, setVoiceIds] = useState('');
  const [seriesId, setSeriesId] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [position, setPosition] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSubmitting(true);

    const payload: PromoteFormData = {
      voiceIds: voiceIds
        .split(',')
        .map((v) => v.trim())
        .filter(Boolean),
      ...(seriesId.trim() ? { seriesId: seriesId.trim() } : {}),
      ...(categoryId.trim() ? { categoryId: categoryId.trim() } : {}),
      ...(position.trim() ? { position: Number(position.trim()) } : {}),
    };

    try {
      const res = await fetch(`/api/admin/plan-requests/${planRequest.id}/promote`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error(
          (body as { error?: string }).error ?? `Failed with HTTP ${res.status}`,
        );
      }

      const data = (await res.json()) as { planId: string };
      onSuccess(data.planId);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Promotion failed. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
      role="dialog"
      aria-modal="true"
      aria-labelledby="promote-modal-title"
    >
      <div className="bg-surface rounded-xl shadow-xl p-6 w-full max-w-md mx-4">
        <div className="flex items-center justify-between mb-4">
          <h2 id="promote-modal-title" className="text-lg font-semibold text-on-surface">
            Promote to Plan
          </h2>
          <button
            onClick={onClose}
            aria-label="Close modal"
            className="text-on-surface-variant hover:text-on-surface transition-colors"
          >
            ✕
          </button>
        </div>

        {/* Pre-filled context from request */}
        <div className="mb-4 p-3 rounded-lg bg-surface-container text-sm">
          <p className="font-medium text-on-surface">{planRequest.title}</p>
          {planRequest.description && (
            <p className="text-on-surface-variant mt-1 text-xs">{planRequest.description}</p>
          )}
          <p className="text-on-surface-variant mt-1 text-xs">
            Submitted by: {planRequest.ownerEmail ?? planRequest.ownerUserId}
          </p>
        </div>

        {error && (
          <div
            className="mb-4 rounded-lg bg-error-container p-3 text-sm text-on-error-container"
            role="alert"
          >
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label
              htmlFor="voice-ids"
              className="block text-sm font-medium text-on-surface mb-1"
            >
              Voice IDs{' '}
              <span className="text-on-surface-variant font-normal">(comma-separated)</span>
            </label>
            <input
              id="voice-ids"
              type="text"
              value={voiceIds}
              onChange={(e) => setVoiceIds(e.target.value)}
              placeholder="voice-uuid-1, voice-uuid-2"
              className="w-full rounded-lg border border-outline px-3 py-2 text-sm bg-surface text-on-surface focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>

          <div>
            <label
              htmlFor="series-id"
              className="block text-sm font-medium text-on-surface mb-1"
            >
              Series ID{' '}
              <span className="text-on-surface-variant font-normal">(optional)</span>
            </label>
            <input
              id="series-id"
              type="text"
              value={seriesId}
              onChange={(e) => setSeriesId(e.target.value)}
              placeholder="series-uuid"
              className="w-full rounded-lg border border-outline px-3 py-2 text-sm bg-surface text-on-surface focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>

          <div>
            <label
              htmlFor="category-id"
              className="block text-sm font-medium text-on-surface mb-1"
            >
              Category ID{' '}
              <span className="text-on-surface-variant font-normal">(optional)</span>
            </label>
            <input
              id="category-id"
              type="text"
              value={categoryId}
              onChange={(e) => setCategoryId(e.target.value)}
              placeholder="category-uuid"
              className="w-full rounded-lg border border-outline px-3 py-2 text-sm bg-surface text-on-surface focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>

          <div>
            <label
              htmlFor="position"
              className="block text-sm font-medium text-on-surface mb-1"
            >
              Position{' '}
              <span className="text-on-surface-variant font-normal">(optional)</span>
            </label>
            <input
              id="position"
              type="number"
              min="0"
              value={position}
              onChange={(e) => setPosition(e.target.value)}
              placeholder="0"
              className="w-full rounded-lg border border-outline px-3 py-2 text-sm bg-surface text-on-surface focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>

          <div className="flex gap-3 justify-end pt-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={submitting}
              className="px-4 py-2 text-sm font-medium rounded-lg bg-primary text-on-primary hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {submitting ? 'Promoting…' : 'Promote to Plan'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Page
// ────────────────────────────────────────────────────────────────────────────

export default function AdminPlanRequestsPage() {
  const [requests, setRequests] = useState<PlanRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeRequest, setActiveRequest] = useState<PlanRequest | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // ── Fetch pending plan requests ───────────────────────────────────────────

  const fetchRequests = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/admin/plan-requests');
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error((body as { error?: string }).error ?? `HTTP ${res.status}`);
      }
      const data = (await res.json()) as PlanRequest[] | { data: PlanRequest[] };
      const list = Array.isArray(data) ? data : (data as { data: PlanRequest[] }).data ?? [];
      setRequests(list);
    } catch (err) {
      setError(
        err instanceof Error ? err.message : 'Failed to load plan requests.',
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void fetchRequests();
  }, [fetchRequests]);

  // ── Promote success ───────────────────────────────────────────────────────

  const handlePromoteSuccess = (planId: string) => {
    setActiveRequest(null);
    setSuccessMsg(`Plan created successfully (ID: ${planId}). The request has been promoted.`);
    void fetchRequests();
    setTimeout(() => setSuccessMsg(null), 6000);
  };

  // ── Render ───────────────────────────────────────────────────────────────

  return (
    <div>
      {/* ── Page header ──────────────────────────────────────────────────── */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-on-surface">Plan Requests</h1>
        <p className="mt-1 text-sm text-on-surface-variant">
          Review user-submitted plan requests. Promote a request to create a published
          plan with TTS voices assigned.
        </p>
      </div>

      {/* ── Success banner ────────────────────────────────────────────────── */}
      {successMsg && (
        <div
          className="rounded-lg bg-green-100 p-4 text-sm text-green-800 mb-6"
          role="status"
        >
          {successMsg}
        </div>
      )}

      {/* ── Error banner ──────────────────────────────────────────────────── */}
      {error && (
        <div
          className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-6"
          role="alert"
        >
          <p className="font-medium">Failed to load plan requests</p>
          <p className="mt-1">{error}</p>
        </div>
      )}

      {/* ── Loading ───────────────────────────────────────────────────────── */}
      {loading && (
        <div
          className="flex items-center justify-center py-20 text-on-surface-variant text-sm"
          role="status"
          aria-label="Loading plan requests"
        >
          Loading plan requests…
        </div>
      )}

      {/* ── Empty state ───────────────────────────────────────────────────── */}
      {!loading && !error && requests.length === 0 && (
        <div className="rounded-lg bg-surface-container p-8 text-center text-sm text-on-surface-variant">
          No pending plan requests.
        </div>
      )}

      {/* ── Requests table ────────────────────────────────────────────────── */}
      {!loading && requests.length > 0 && (
        <div className="overflow-x-auto rounded-lg border border-outline-variant">
          <table
            className="min-w-full divide-y divide-outline-variant text-sm"
            aria-label="Pending plan requests"
          >
            <thead className="bg-surface-container">
              <tr>
                <th className="px-4 py-3 text-left font-semibold text-on-surface-variant">
                  Title
                </th>
                <th className="px-4 py-3 text-left font-semibold text-on-surface-variant">
                  Submitted by
                </th>
                <th className="px-4 py-3 text-left font-semibold text-on-surface-variant">
                  Date
                </th>
                <th className="px-4 py-3 text-left font-semibold text-on-surface-variant">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-outline-variant bg-surface">
              {requests.map((req) => (
                <tr
                  key={req.id}
                  className="hover:bg-surface-container-low transition-colors"
                >
                  <td className="px-4 py-3 font-medium text-on-surface">
                    {req.title}
                    {req.description && (
                      <p className="text-xs text-on-surface-variant font-normal mt-0.5 line-clamp-2">
                        {req.description}
                      </p>
                    )}
                  </td>
                  <td className="px-4 py-3 text-on-surface-variant">
                    {req.ownerEmail ?? req.ownerUserId}
                  </td>
                  <td className="px-4 py-3 text-on-surface-variant">
                    {new Date(req.createdAt).toLocaleDateString()}
                  </td>
                  <td className="px-4 py-3">
                    <button
                      onClick={() => setActiveRequest(req)}
                      aria-label={`Promote ${req.title} to plan`}
                      className="rounded px-3 py-1.5 text-xs font-medium bg-primary/10 text-primary hover:bg-primary/20 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
                    >
                      Promote to Plan
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* ── Promote modal ─────────────────────────────────────────────────── */}
      {activeRequest && (
        <PromoteModal
          planRequest={activeRequest}
          onClose={() => setActiveRequest(null)}
          onSuccess={handlePromoteSuccess}
        />
      )}
    </div>
  );
}
