import { cookies } from 'next/headers';
import Link from 'next/link';
import { Suspense } from 'react';
import { adminFetch, AdminApiError } from '@/lib/admin-api';
import UserSearchInput from '@/components/admin/UserSearchInput';
import RoleToggleButton from '@/components/admin/RoleToggleButton';
import CsvExportButton from '@/components/admin/CsvExportButton';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

interface AdminUserRow {
  id: string;
  email: string;
  name: string | null;
  username: string | null;
  role: 'user' | 'admin';
  createdAt: string;
  planCount: number;
  lastActivityAt: string | null;
}

interface AdminUsersListResponse {
  users: AdminUserRow[];
  total: number;
  page: number;
  pageSize: number;
}

const DEFAULT_PAGE_SIZE = 25;

interface Props {
  role: 'user' | 'admin';
  heading: string;
  /** Route this page lives at, e.g. "/admin/users-list" or "/admin/admins". */
  basePath: string;
  searchParams: {
    search?: string;
    page?: string;
    pageSize?: string;
  };
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

function getErrorMessage(reason: unknown): string {
  if (reason instanceof AdminApiError) return reason.message;
  if (reason instanceof Error) return reason.message;
  return 'An unexpected error occurred while loading users.';
}

function parsePositiveInt(raw: string | undefined, fallback: number): number {
  const n = Number.parseInt(raw ?? '', 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

function formatDateTime(iso: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toISOString().slice(0, 10);
}

/** Decode JWT without verification — used only to read the current admin's sub claim. */
function decodeSelfId(token: string | undefined): string | null {
  if (!token) return null;
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const payload = JSON.parse(
      Buffer.from(parts[1], 'base64url').toString('utf-8'),
    );
    return typeof payload.sub === 'string' ? payload.sub : null;
  } catch {
    return null;
  }
}

function buildPageHref(
  basePath: string,
  base: Record<string, string | undefined>,
  page: number,
): string {
  const params = new URLSearchParams();
  for (const [k, v] of Object.entries(base)) {
    if (v !== undefined && v !== '') params.set(k, v);
  }
  params.set('page', String(page));
  return `${basePath}?${params.toString()}`;
}

/**
 * Build the CSV export URL with current search and role filters.
 * The route handler will forward these params to the backend.
 */
function buildExportUrl(
  search: string,
  role: 'user' | 'admin',
): string {
  const params = new URLSearchParams();
  if (search) params.set('search', search);
  params.set('role', role);
  return `/api/admin/users/export?${params.toString()}`;
}

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * Shared users table used by both the Consumers page (/admin/users-list)
 * and the Admins page (/admin/admins). The backend filters by `role`.
 */
export default async function UsersListSection({
  role,
  heading,
  basePath,
  searchParams,
}: Props) {
  const search = searchParams.search ?? '';
  const page = parsePositiveInt(searchParams.page, 1);
  const pageSize = parsePositiveInt(searchParams.pageSize, DEFAULT_PAGE_SIZE);

  const cookieStore = await cookies();
  const selfId = decodeSelfId(cookieStore.get('access_token')?.value);

  let data: AdminUsersListResponse | null = null;
  let error: string | null = null;

  try {
    data = await adminFetch<AdminUsersListResponse>('/admin/users', {
      query: { page, pageSize, search: search || undefined, role },
    });
  } catch (reason) {
    error = getErrorMessage(reason);
  }

  const totalPages = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;
  const currentPage = data?.page ?? page;
  const rows = data?.users ?? [];
  const noun = role === 'admin' ? 'admin' : 'user';
  const nounPlural = role === 'admin' ? 'admins' : 'users';

  const baseQuery: Record<string, string | undefined> = {
    search: search || undefined,
    pageSize: pageSize !== DEFAULT_PAGE_SIZE ? String(pageSize) : undefined,
  };

  const exportUrl = buildExportUrl(search, role);

  return (
    <div>
      {/* ── Header ─────────────────────────────────────────────────────── */}
      <div className="flex flex-col gap-4 mb-8">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <h1 className="text-2xl font-bold text-on-surface">{heading}</h1>
          <Suspense fallback={null}>
            <UserSearchInput initialValue={search} />
          </Suspense>
        </div>
        <CsvExportButton exportUrl={exportUrl} filename={`${role}s_export`} />
      </div>

      {/* ── Error banner ──────────────────────────────────────────────── */}
      {error && (
        <div
          className="rounded-lg bg-error-container p-4 text-sm text-on-error-container mb-6"
          role="alert"
        >
          <p className="font-medium">Failed to load {nounPlural}</p>
          <p className="mt-1">{error}</p>
        </div>
      )}

      {/* ── Summary ───────────────────────────────────────────────────── */}
      {data && (
        <p className="text-sm text-on-surface-variant mb-4">
          {data.total.toLocaleString()} {data.total === 1 ? noun : nounPlural}
          {search ? ` matching "${search}"` : ''} — page {currentPage} of{' '}
          {totalPages}
        </p>
      )}

      {/* ── Table ─────────────────────────────────────────────────────── */}
      <div className="rounded-xl bg-surface-container shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-outline-variant">
            <thead className="bg-surface-variant/30">
              <tr>
                <Th>Email</Th>
                <Th>Name</Th>
                <Th>Username</Th>
                <Th>Role</Th>
                <Th className="text-right">Plans</Th>
                <Th>Joined</Th>
                <Th>Last session</Th>
                <Th className="text-right">Actions</Th>
              </tr>
            </thead>
            <tbody className="divide-y divide-outline-variant">
              {rows.length === 0 && !error ? (
                <tr>
                  <td
                    colSpan={8}
                    className="px-4 py-10 text-center text-sm text-on-surface-variant"
                  >
                    No {nounPlural} found.
                  </td>
                </tr>
              ) : (
                rows.map((u) => (
                  <tr key={u.id} className="hover:bg-surface-variant/20">
                    <Td>
                      <Link
                        href={`/admin/users/${u.id}`}
                        className="font-medium text-primary hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary rounded-sm"
                      >
                        {u.email}
                      </Link>
                    </Td>
                    <Td>{u.name ?? '—'}</Td>
                    <Td>{u.username ?? '—'}</Td>
                    <Td>
                      <RoleBadge role={u.role} />
                    </Td>
                    <Td className="text-right tabular-nums">
                      {u.planCount.toLocaleString()}
                    </Td>
                    <Td className="tabular-nums">{formatDateTime(u.createdAt)}</Td>
                    <Td className="tabular-nums">
                      {formatDateTime(u.lastActivityAt)}
                    </Td>
                    <Td className="text-right">
                      <RoleToggleButton
                        userId={u.id}
                        currentRole={u.role}
                        selfId={selfId}
                      />
                    </Td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── Pagination ────────────────────────────────────────────────── */}
      {data && totalPages > 1 && (
        <nav
          aria-label={`${heading} pagination`}
          className="mt-4 flex items-center justify-between"
        >
          <PageLink
            disabled={currentPage <= 1}
            href={buildPageHref(basePath, baseQuery, currentPage - 1)}
            label="Previous"
          />
          <PageLink
            disabled={currentPage >= totalPages}
            href={buildPageHref(basePath, baseQuery, currentPage + 1)}
            label="Next"
          />
        </nav>
      )}
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Presentational helpers
// ────────────────────────────────────────────────────────────────────────────

function Th({
  children,
  className = '',
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <th
      scope="col"
      className={`px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-on-surface-variant ${className}`}
    >
      {children}
    </th>
  );
}

function Td({
  children,
  className = '',
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <td
      className={`px-4 py-3 text-sm text-on-surface-variant ${className}`}
    >
      {children}
    </td>
  );
}

function RoleBadge({ role }: { role: 'user' | 'admin' }) {
  return (
    <span
      className={[
        'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium',
        role === 'admin'
          ? 'bg-primary/15 text-primary'
          : 'bg-surface-variant text-on-surface-variant',
      ].join(' ')}
    >
      {role}
    </span>
  );
}

function PageLink({
  disabled,
  href,
  label,
}: {
  disabled: boolean;
  href: string;
  label: string;
}) {
  if (disabled) {
    return (
      <span className="rounded-lg border border-outline-variant px-4 py-2 text-sm text-on-surface-variant opacity-50 cursor-not-allowed">
        {label}
      </span>
    );
  }
  return (
    <Link
      href={href}
      className="rounded-lg border border-outline-variant px-4 py-2 text-sm text-on-surface hover:bg-surface-variant/30 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
    >
      {label}
    </Link>
  );
}
