'use client';

import { useCallback, useState } from 'react';
import { useRouter } from 'next/navigation';
import type { PlanVoice } from '@/types/plan-detail';

export interface RegenerateMissingButtonProps {
  planId: string;
  voices: PlanVoice[] | null;
}

export default function RegenerateMissingButton({
  planId,
  voices,
}: RegenerateMissingButtonProps) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const targets = (voices ?? []).filter((v) => v.status !== 'ready');

  const handleClick = useCallback(async () => {
    if (targets.length === 0) return;
    setBusy(true);
    setError(null);

    const results = await Promise.allSettled(
      targets.map((v) =>
        fetch(`/api/admin/plans/${planId}/voices/${v.voiceId}/regenerate`, {
          method: 'POST',
        }).then(async (res) => {
          if (!res.ok) {
            const body = (await res.json().catch(() => ({}))) as { error?: unknown };
            throw new Error(
              typeof body.error === 'string' ? body.error : 'Regenerate failed',
            );
          }
        }),
      ),
    );

    const failed = results.filter((r) => r.status === 'rejected').length;
    if (failed > 0) {
      setError(`${failed} of ${targets.length} regenerate request${failed === 1 ? '' : 's'} failed`);
    }
    setBusy(false);
    router.refresh();
  }, [planId, targets, router]);

  if (voices === null) return null;
  if (targets.length === 0) return null;

  const label = `Regenerate missing (${targets.length} voice${targets.length === 1 ? '' : 's'})`;

  return (
    <div className="flex flex-col gap-1">
      <button
        type="button"
        onClick={() => { void handleClick(); }}
        disabled={busy}
        aria-label={label}
        className="self-start rounded-lg bg-primary px-3 py-1.5 text-xs font-semibold text-white hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
      >
        {busy ? 'Queuing…' : label}
      </button>
      {error && (
        <p role="alert" className="text-xs text-error">
          {error}
        </p>
      )}
    </div>
  );
}
