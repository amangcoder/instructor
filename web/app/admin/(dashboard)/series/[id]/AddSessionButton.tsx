'use client';

import { useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';

interface AddSessionButtonProps {
  seriesId: string;
}

const INPUT_CLASS =
  'w-full rounded-lg border border-outline-variant bg-surface px-3 py-2 text-sm text-on-surface placeholder:text-outline focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent disabled:opacity-50';

function extractMessage(data: unknown): string {
  if (typeof data === 'object' && data !== null) {
    const obj = data as Record<string, unknown>;
    const msg = obj.message ?? obj.error;
    if (Array.isArray(msg)) return msg.join(', ');
    if (typeof msg === 'string') return msg;
  }
  return 'Request failed.';
}

export default function AddSessionButton({ seriesId }: AddSessionButtonProps) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [planJson, setPlanJson] = useState('');

  const reset = () => {
    setName('');
    setDescription('');
    setPlanJson('');
    setError(null);
  };

  const close = () => {
    if (submitting) return;
    setOpen(false);
    reset();
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);

    // Validate JSON parses before sending.
    try {
      JSON.parse(planJson);
    } catch {
      setError('Plan JSON is not valid JSON. Paste a parseable JSON document.');
      return;
    }

    setSubmitting(true);
    try {
      const res = await fetch(`/api/admin/series/${seriesId}/plans`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: name.trim(),
          description: description.trim() || undefined,
          planJson,
        }),
      });

      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        setError(extractMessage(body) || `HTTP ${res.status}`);
        return;
      }

      setOpen(false);
      reset();
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Network error.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white hover:bg-primary/90 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 flex-shrink-0"
      >
        + Add Session
      </button>

      {open && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50"
          role="dialog"
          aria-modal="true"
          aria-labelledby="add-session-modal-title"
        >
          <div className="w-full max-w-2xl max-h-[90vh] overflow-y-auto rounded-2xl bg-surface p-6 shadow-xl">
            <div className="flex items-center justify-between mb-5">
              <h3
                id="add-session-modal-title"
                className="text-lg font-semibold text-on-surface"
              >
                New Session
              </h3>
              <button
                type="button"
                onClick={close}
                aria-label="Close modal"
                disabled={submitting}
                className="rounded-lg p-1 text-on-surface-variant hover:bg-surface-container transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary disabled:opacity-50"
              >
                ✕
              </button>
            </div>

            {error && (
              <div
                role="alert"
                className="mb-4 rounded-lg bg-error-container p-3 text-sm text-on-error-container"
              >
                {error}
              </div>
            )}

            <form
              onSubmit={(e) => {
                void handleSubmit(e);
              }}
              className="space-y-4"
              noValidate
            >
              <div>
                <label
                  htmlFor="session-name"
                  className="block text-sm font-medium text-on-surface mb-1"
                >
                  Name *
                </label>
                <input
                  id="session-name"
                  type="text"
                  required
                  maxLength={200}
                  disabled={submitting}
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className={INPUT_CLASS}
                  placeholder="e.g. Day 1 — Foundations"
                />
              </div>

              <div>
                <label
                  htmlFor="session-description"
                  className="block text-sm font-medium text-on-surface mb-1"
                >
                  Description
                </label>
                <textarea
                  id="session-description"
                  rows={2}
                  maxLength={2000}
                  disabled={submitting}
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  className={INPUT_CLASS}
                  placeholder="Optional summary."
                />
              </div>

              <div>
                <label
                  htmlFor="session-plan-json"
                  className="block text-sm font-medium text-on-surface mb-1"
                >
                  Plan JSON *
                </label>
                <textarea
                  id="session-plan-json"
                  required
                  rows={14}
                  maxLength={524288}
                  disabled={submitting}
                  value={planJson}
                  onChange={(e) => setPlanJson(e.target.value)}
                  className={`${INPUT_CLASS} font-mono text-xs`}
                  placeholder='{"name":"...","steps":[ ... ]}'
                  spellCheck={false}
                />
                <p className="mt-1 text-xs text-on-surface-variant">
                  Paste the full plan JSON. Validated on the client; voices/TTS are queued separately.
                </p>
              </div>

              <div className="flex justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={close}
                  disabled={submitting}
                  className="rounded-lg px-4 py-2 text-sm font-medium text-on-surface-variant hover:text-on-surface hover:bg-surface-container transition-colors disabled:opacity-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
                >
                  {submitting ? 'Creating…' : 'Create Session'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
}
