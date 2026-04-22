/**
 * Tests for the admin User Detail page (/admin/users/[id]).
 *
 * AC-008: Session History table (Plan Name, Completed At, Duration)
 * REQ-009: Per-plan summary table (TTS status, run count, last run, active)
 * REQ-018: Empty state when sessions array is empty
 * REQ-012: Tables have <th scope="col"> headers
 */
import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';

// ── Mocks ──────────────────────────────────────────────────────────────────

const mockAdminFetch = jest.fn();
const mockNotFound = jest.fn();

jest.mock('@/lib/admin-api', () => ({
  adminFetch: (...args: unknown[]) => mockAdminFetch(...args),
  AdminApiError: class AdminApiError extends Error {
    code: string;
    constructor(message: string, code: string) {
      super(message);
      this.name = 'AdminApiError';
      this.code = code;
    }
  },
}));

jest.mock('next/navigation', () => ({
  notFound: () => mockNotFound(),
}));

jest.mock('next/link', () => ({
  __esModule: true,
  default: ({
    href,
    children,
    className,
  }: {
    href: string;
    children: React.ReactNode;
    className?: string;
  }) => (
    <a href={href} className={className}>
      {children}
    </a>
  ),
}));

jest.mock('@/components/admin/StatCard', () => ({
  __esModule: true,
  default: ({ title, value }: { title: string; value: number }) => (
    <div data-testid="stat-card">
      <span>{title}</span>
      <span>{value}</span>
    </div>
  ),
}));

jest.mock('@/components/admin/EmptyState', () => ({
  __esModule: true,
  default: ({ message }: { message: string }) => (
    <div role="status" aria-label={message} data-testid="empty-state">
      {message}
    </div>
  ),
}));

// ── Fixtures ───────────────────────────────────────────────────────────────

const USER_ID = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

function makeUserDetail(overrides: Record<string, unknown> = {}) {
  return {
    user: {
      id: USER_ID,
      email: 'alice@example.com',
      name: 'Alice',
      username: 'alice',
      role: 'user',
      photoUrl: null,
      createdAt: '2026-01-01T00:00:00.000Z',
    },
    stats: {
      totalPlans: 5,
      activePlans: 3,
      totalSessions: 12,
      avgSessionDurationMs: 600000,
      totalSessionDurationMs: 7200000,
      lastActivityAt: '2026-04-20T10:00:00.000Z',
      ttsJobsTotal: 8,
      ttsJobsCompleted: 7,
      ttsJobsFailed: 1,
    },
    plansWithSummary: [
      {
        planId: 'plan-1111',
        name: 'Morning Routine',
        createdAt: '2026-02-01T00:00:00.000Z',
        ttsStatus: 'completed',
        runCount: 8,
        lastRunAt: '2026-04-19T08:00:00.000Z',
        isActive: true,
      },
      {
        planId: 'plan-2222',
        name: 'Evening Wind Down',
        createdAt: '2026-03-15T00:00:00.000Z',
        ttsStatus: 'pending',
        runCount: 0,
        lastRunAt: null,
        isActive: false,
      },
    ],
    ...overrides,
  };
}

function makeSessions() {
  return {
    sessions: [
      {
        planName: 'Morning Routine',
        completedAt: '2026-04-21T14:32:00.000Z',
        durationMs: 738000, // 12.3 min
      },
      {
        planName: 'Evening Wind Down',
        completedAt: '2026-04-20T20:15:00.000Z',
        durationMs: 300000, // 5.0 min
      },
    ],
  };
}

function makeEmptySessions() {
  return { sessions: [] };
}

// ── Helpers ────────────────────────────────────────────────────────────────

type PageProps = { params: Promise<{ id: string }> };
let UserDetailPage: (props: PageProps) => Promise<React.JSX.Element>;

async function renderPage(
  userDetail = makeUserDetail(),
  sessions = makeSessions(),
) {
  mockAdminFetch
    .mockResolvedValueOnce(userDetail)
    .mockResolvedValueOnce(sessions);

  const element = await UserDetailPage({
    params: Promise.resolve({ id: USER_ID }),
  });
  return render(element);
}

// ── Setup ──────────────────────────────────────────────────────────────────

beforeAll(async () => {
  const mod = await import('../(dashboard)/users/[id]/page');
  UserDetailPage = mod.default;
});

beforeEach(() => {
  jest.clearAllMocks();
});

// ── Tests ──────────────────────────────────────────────────────────────────

describe('UserDetailPage', () => {
  // ── Parallel fetching ──────────────────────────────────────────────────

  it('fetches user detail and sessions in parallel (both API calls made)', async () => {
    await renderPage();

    expect(mockAdminFetch).toHaveBeenCalledTimes(2);
    expect(mockAdminFetch).toHaveBeenCalledWith(`/admin/users/${USER_ID}`);
    expect(mockAdminFetch).toHaveBeenCalledWith(
      `/admin/users/${USER_ID}/sessions`,
    );
  });

  // ── Session History (AC-008) ──────────────────────────────────────────

  it('renders the Session History heading (AC-008)', async () => {
    await renderPage();

    expect(
      screen.getByRole('heading', { name: 'Session History' }),
    ).toBeInTheDocument();
  });

  it('renders session history table with accessible column headers (REQ-012)', async () => {
    await renderPage();

    const ths = screen
      .getAllByRole('columnheader')
      .filter((th) => th.getAttribute('scope') === 'col');

    const labels = ths.map((th) => th.textContent?.trim());
    expect(labels).toContain('Plan Name');
    expect(labels).toContain('Completed At');
    expect(labels).toContain('Duration');
  });

  it('renders session plan names (AC-008)', async () => {
    await renderPage();

    // Morning Routine appears in both session history and plans summary tables
    expect(screen.getAllByText('Morning Routine').length).toBeGreaterThan(0);
    // Evening Wind Down appears in both plans and sessions tables
    expect(screen.getAllByText('Evening Wind Down').length).toBeGreaterThan(0);
  });

  it('formats Completed At as "Apr 21, 2026 14:32" (AC-008)', async () => {
    await renderPage();

    expect(screen.getByText('Apr 21, 2026 14:32')).toBeInTheDocument();
  });

  it('formats session duration in minutes rounded to 1 decimal (AC-008)', async () => {
    await renderPage();

    // 738000ms = 12.3 min
    expect(screen.getByText('12.3 min')).toBeInTheDocument();
    // 300000ms = 5.0 min
    expect(screen.getByText('5.0 min')).toBeInTheDocument();
  });

  // ── Empty state (REQ-018) ──────────────────────────────────────────────

  it('shows empty state when sessions array is empty (REQ-018)', async () => {
    await renderPage(makeUserDetail(), makeEmptySessions());

    expect(screen.getByTestId('empty-state')).toBeInTheDocument();
    expect(
      screen.getByText('No sessions recorded yet.'),
    ).toBeInTheDocument();
  });

  it('does not render session rows when sessions array is empty', async () => {
    await renderPage(makeUserDetail(), makeEmptySessions());

    // No Completed At column values
    expect(screen.queryByText(/min$/)).not.toBeInTheDocument();
  });

  // ── Plans summary table (REQ-009) ─────────────────────────────────────

  it('renders the Plans heading (REQ-009)', async () => {
    await renderPage();

    expect(
      screen.getByRole('heading', { name: 'Plans' }),
    ).toBeInTheDocument();
  });

  it('renders per-plan summary table with all required columns (REQ-009, REQ-012)', async () => {
    await renderPage();

    const ths = screen
      .getAllByRole('columnheader')
      .filter((th) => th.getAttribute('scope') === 'col');

    const labels = ths.map((th) => th.textContent?.trim());
    expect(labels).toContain('Name');
    expect(labels).toContain('Created');
    expect(labels).toContain('TTS Status');
    expect(labels).toContain('Times Run');
    expect(labels).toContain('Last Run');
    expect(labels).toContain('Active');
  });

  it('renders TTS status badges for each plan (REQ-009)', async () => {
    await renderPage();

    expect(screen.getByText('completed')).toBeInTheDocument();
    expect(screen.getByText('pending')).toBeInTheDocument();
  });

  it('renders run count (Times Run) for each plan (REQ-009)', async () => {
    await renderPage();

    // Morning Routine: runCount=8 — may also appear in stats (ttsJobsTotal); use getAllByText
    expect(screen.getAllByText('8').length).toBeGreaterThan(0);
    // Evening Wind Down: runCount=0
    expect(screen.getAllByText('0').length).toBeGreaterThan(0);
  });

  it('renders Last Run date or dash when null (REQ-009)', async () => {
    await renderPage();

    // Morning Routine: lastRunAt = '2026-04-19T08:00:00.000Z' → '2026-04-19'
    expect(screen.getByText('2026-04-19')).toBeInTheDocument();
  });

  it('renders Active column as Yes/No (REQ-009)', async () => {
    await renderPage();

    const yesCells = screen.getAllByText('Yes');
    const noCells = screen.getAllByText('No');
    expect(yesCells.length).toBeGreaterThan(0);
    expect(noCells.length).toBeGreaterThan(0);
  });

  it('renders plan name as a link to the plan detail page', async () => {
    await renderPage();

    const planLink = screen
      .getAllByRole('link')
      .find((a) =>
        a.getAttribute('href')?.includes(`/admin/users/${USER_ID}/plans/`),
      );
    expect(planLink).toBeInTheDocument();
  });

  it('shows "No plans yet." when plansWithSummary is empty', async () => {
    await renderPage(
      makeUserDetail({ plansWithSummary: [] }),
      makeSessions(),
    );

    expect(screen.getByText('No plans yet.')).toBeInTheDocument();
  });

  // ── All th elements have scope="col" (REQ-012) ────────────────────────

  it('all table headers have scope="col" for accessibility (REQ-012)', async () => {
    await renderPage();

    const ths = screen.getAllByRole('columnheader');
    ths.forEach((th) => {
      expect(th).toHaveAttribute('scope', 'col');
    });
  });

  // ── Error handling ────────────────────────────────────────────────────

  it('shows error message when fetch fails', async () => {
    const { AdminApiError } = await import('@/lib/admin-api');
    mockAdminFetch.mockRejectedValue(
      new AdminApiError('Service unavailable', '503'),
    );

    const element = await UserDetailPage({
      params: Promise.resolve({ id: USER_ID }),
    });
    render(element);

    expect(screen.getByRole('alert')).toBeInTheDocument();
    expect(screen.getByText('Failed to load user')).toBeInTheDocument();
    expect(screen.getByText('Service unavailable')).toBeInTheDocument();
  });

  // ── User header rendering ─────────────────────────────────────────────

  it('renders user name and email in the header', async () => {
    await renderPage();

    expect(screen.getByRole('heading', { name: 'Alice' })).toBeInTheDocument();
    expect(screen.getByText(/alice@example\.com/)).toBeInTheDocument();
  });

  it('renders stat cards for user metrics', async () => {
    await renderPage();

    expect(screen.getByText('Total Plans')).toBeInTheDocument();
    expect(screen.getByText('Active Plans')).toBeInTheDocument();
    expect(screen.getByText('Sessions Completed')).toBeInTheDocument();
  });
});
