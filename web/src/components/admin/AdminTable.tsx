import React from 'react';

// ────────────────────────────────────────────────────────────────────────────
// AdminTable — standardised table wrapper
// ────────────────────────────────────────────────────────────────────────────

/**
 * AdminTable — server component
 *
 * Provides standardized dark-slate table styling:
 *  - Container: bg-slate-900 rounded-xl border border-white/8 overflow-hidden
 *  - Header rows: bg-slate-800/50 with text-slate-400 uppercase tracking
 *  - Body rows: border-b border-white/5 hover:bg-white/5 transitions
 *  - Data cells: text-sm text-slate-300 px-4 py-3
 *
 * Usage:
 *   <AdminTable>
 *     <AdminTableHead>
 *       <tr>
 *         <AdminTableTh>Column</AdminTableTh>
 *       </tr>
 *     </AdminTableHead>
 *     <AdminTableBody>
 *       <tr><AdminTableTd>Cell</AdminTableTd></tr>
 *     </AdminTableBody>
 *   </AdminTable>
 */

export interface AdminTableProps {
  children: React.ReactNode;
  'aria-label'?: string;
  className?: string;
}

export default function AdminTable({
  children,
  'aria-label': ariaLabel,
  className = '',
}: AdminTableProps) {
  return (
    <div className={`rounded-xl bg-slate-900 border border-white/8 overflow-hidden ${className}`}>
      <div className="overflow-x-auto">
        <table
          className="min-w-full"
          aria-label={ariaLabel}
        >
          {children}
        </table>
      </div>
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// AdminTableHead
// ────────────────────────────────────────────────────────────────────────────

export function AdminTableHead({ children }: { children: React.ReactNode }) {
  return (
    <thead className="bg-slate-800/50">
      {children}
    </thead>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// AdminTableBody
// ────────────────────────────────────────────────────────────────────────────

export function AdminTableBody({ children }: { children: React.ReactNode }) {
  return (
    <tbody className="divide-y divide-white/5">
      {children}
    </tbody>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// AdminTableTh — header cell
// ────────────────────────────────────────────────────────────────────────────

export interface AdminTableThProps {
  children: React.ReactNode;
  className?: string;
  align?: 'left' | 'right' | 'center';
}

export function AdminTableTh({
  children,
  className = '',
  align = 'left',
}: AdminTableThProps) {
  const alignClass = align === 'right' ? 'text-right' : align === 'center' ? 'text-center' : 'text-left';
  return (
    <th
      scope="col"
      className={`px-4 py-3 text-xs font-semibold uppercase tracking-wide text-slate-400 ${alignClass} ${className}`}
    >
      {children}
    </th>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// AdminTableTd — data cell
// ────────────────────────────────────────────────────────────────────────────

export interface AdminTableTdProps {
  children: React.ReactNode;
  className?: string;
}

export function AdminTableTd({ children, className = '' }: AdminTableTdProps) {
  return (
    <td className={`px-4 py-3 text-sm text-slate-300 ${className}`}>
      {children}
    </td>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// AdminTableRow — table row with standard hover styling
// ────────────────────────────────────────────────────────────────────────────

export interface AdminTableRowProps {
  children: React.ReactNode;
  className?: string;
}

export function AdminTableRow({ children, className = '' }: AdminTableRowProps) {
  return (
    <tr className={`border-b border-white/5 hover:bg-white/5 transition-colors duration-150 last:border-b-0 ${className}`}>
      {children}
    </tr>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// StatusBadge — colour-coded pill for status/role values
// ────────────────────────────────────────────────────────────────────────────

export type StatusBadgeVariant = 'admin' | 'user' | 'pending' | 'completed' | 'failed' | 'default';

export interface StatusBadgeProps {
  variant?: StatusBadgeVariant;
  children: React.ReactNode;
}

const STATUS_BADGE_CLASSES: Record<StatusBadgeVariant, string> = {
  admin: 'bg-indigo-500/20 text-indigo-400',
  user: 'bg-slate-700 text-slate-300',
  pending: 'bg-amber-500/20 text-amber-400',
  completed: 'bg-emerald-500/20 text-emerald-400',
  failed: 'bg-red-500/20 text-red-400',
  default: 'bg-slate-700 text-slate-300',
};

export function StatusBadge({ variant = 'default', children }: StatusBadgeProps) {
  return (
    <span
      className={[
        'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium',
        STATUS_BADGE_CLASSES[variant],
      ].join(' ')}
    >
      {children}
    </span>
  );
}
