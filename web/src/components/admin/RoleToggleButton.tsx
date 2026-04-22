'use client';

import { useState, useTransition } from 'react';
import { updateUserRoleAction } from '../../../app/admin/(dashboard)/users-list/actions';

export default function RoleToggleButton({
  userId,
  currentRole,
  selfId,
}: {
  userId: string;
  currentRole: 'user' | 'admin';
  /** Logged-in admin's id — disables self-demotion */
  selfId: string | null;
}) {
  const [role, setRole] = useState<'user' | 'admin'>(currentRole);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  // Promotion to admin is intentionally not exposed in the UI — grant via DB only.
  // This button only demotes an existing admin back to 'user'.
  if (role !== 'admin') {
    return null;
  }

  const isSelf = selfId === userId;
  const disabled = isPending || isSelf;

  const onClick = () => {
    setError(null);
    if (!window.confirm('Revoke admin privileges from this user?')) return;

    startTransition(async () => {
      const result = await updateUserRoleAction(userId, 'user');
      if (result.ok) {
        setRole(result.role);
      } else {
        setError(result.error);
      }
    });
  };

  return (
    <div className="flex flex-col items-end gap-1">
      <button
        type="button"
        onClick={onClick}
        disabled={disabled}
        className={[
          'rounded-md px-3 py-1.5 text-xs font-medium transition-colors',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary',
          'disabled:cursor-not-allowed disabled:opacity-50',
          'bg-error-container text-on-error-container hover:bg-error/20',
        ].join(' ')}
        title={isSelf ? 'You cannot remove your own admin role' : undefined}
      >
        {isPending ? 'Updating…' : 'Revoke admin'}
      </button>
      {error && (
        <span className="text-xs text-error" role="alert">
          {error}
        </span>
      )}
    </div>
  );
}
