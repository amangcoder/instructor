/**
 * Tests for DeletionRequestsTable client component.
 *
 * AC-003: Status badges — 'Pending' in amber, 'Processed' in green
 * AC-003: Masked email, IP, submitted-at displayed
 * AC-004: 'Mark as Processed' button for pending rows
 */
import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';

// ── Mock Next.js navigation ────────────────────────────────────────────────

const mockReplace = jest.fn();
const mockRefresh = jest.fn();

jest.mock('next/navigation', () => ({
  useRouter: () => ({
    replace: mockReplace,
    refresh: mockRefresh,
    push: jest.fn(),
    back: jest.fn(),
  }),
  usePathname: () => '/admin/deletion-requests',
  useSearchParams: () => new URLSearchParams(),
}));

// Mock ProcessConfirmModal
jest.mock('@/components/admin/ProcessConfirmModal', () => ({
  __esModule: true,
  default: ({
    open,
    email,
    onConfirm,
    onClose,
  }: {
    open: boolean;
    email: string;
    onConfirm: () => Promise<void>;
    onClose: () => void;
  }) =>
    open ? (
      <div data-testid="process-confirm-modal" data-email={email}>
        <button data-testid="modal-confirm" onClick={onConfirm}>
          Confirm
        </button>
        <button data-testid="modal-cancel" onClick={onClose}>
          Cancel
        </button>
      </div>
    ) : null,
}));

import DeletionRequestsTable from '../DeletionRequestsTable';

// ── Fixtures ───────────────────────────────────────────────────────────────

const pendingRow = {
  id: 'dr-1',
  email: 'john@example.com',
  scope: ['full_account' as const],
  status: 'pending' as const,
  reason: null,
  createdAt: '2026-04-21T14:32:00Z',
  processedAt: null,
  ipAddress: '192.168.1.1',
};

const processedRow = {
  id: 'dr-2',
  email: 'jane@example.com',
  scope: ['audio_cache' as const],
  status: 'processed' as const,
  reason: null,
  createdAt: '2026-04-20T10:00:00Z',
  processedAt: '2026-04-20T12:00:00Z',
  ipAddress: '10.0.0.5',
};

const defaultProps = {
  rows: [pendingRow, processedRow],
  total: 2,
  page: 1,
  pageSize: 25,
  search: '',
};

// ── Tests ──────────────────────────────────────────────────────────────────

describe('DeletionRequestsTable', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders table headers', () => {
    render(<DeletionRequestsTable {...defaultProps} />);

    expect(screen.getByText('Email')).toBeInTheDocument();
    expect(screen.getByText('IP Address')).toBeInTheDocument();
    expect(screen.getByText('Submitted')).toBeInTheDocument();
    expect(screen.getByText('Status')).toBeInTheDocument();
    expect(screen.getByText('Actions')).toBeInTheDocument();
  });

  it('displays masked emails (AC-003)', () => {
    render(<DeletionRequestsTable {...defaultProps} />);

    // Both "john@example.com" and "jane@example.com" mask to "j***@example.com"
    // Use getAllByText since multiple rows share the same masked email
    const maskedEmails = screen.getAllByText('j***@example.com');
    expect(maskedEmails).toHaveLength(2);
  });

  it('displays formatted timestamps (AC-003)', () => {
    render(<DeletionRequestsTable {...defaultProps} />);

    expect(screen.getByText('Apr 21, 2026 14:32')).toBeInTheDocument();
    expect(screen.getByText('Apr 20, 2026 10:00')).toBeInTheDocument();
  });

  it('displays status badges with correct labels (AC-003)', () => {
    render(<DeletionRequestsTable {...defaultProps} />);

    const pendingBadge = screen.getByText('Pending');
    const processedBadge = screen.getByText('Processed');

    expect(pendingBadge).toBeInTheDocument();
    expect(processedBadge).toBeInTheDocument();

    // Amber for pending
    expect(pendingBadge.className).toContain('amber');
    // Green for processed
    expect(processedBadge.className).toContain('green');
  });

  it('shows "Mark as Processed" button only for pending rows (AC-004)', () => {
    render(<DeletionRequestsTable {...defaultProps} />);

    const buttons = screen.getAllByRole('button', { name: /mark.*processed/i });
    expect(buttons).toHaveLength(1);
  });

  it('opens confirmation modal when clicking "Mark as Processed" (AC-004)', () => {
    render(<DeletionRequestsTable {...defaultProps} />);

    // No modal initially
    expect(screen.queryByTestId('process-confirm-modal')).not.toBeInTheDocument();

    // Click the button
    const markButton = screen.getByRole('button', { name: /mark.*processed/i });
    fireEvent.click(markButton);

    // Modal should now be open
    expect(screen.getByTestId('process-confirm-modal')).toBeInTheDocument();
  });

  it('renders search input with correct aria-label', () => {
    render(<DeletionRequestsTable {...defaultProps} />);

    const searchInput = screen.getByRole('searchbox');
    expect(searchInput).toHaveAttribute(
      'aria-label',
      'Search deletion requests by email',
    );
  });

  it('renders summary with total count', () => {
    render(<DeletionRequestsTable {...defaultProps} />);

    expect(screen.getByText(/2 deletion requests/)).toBeInTheDocument();
    expect(screen.getByText(/page 1 of 1/)).toBeInTheDocument();
  });

  it('does not render pagination when only one page', () => {
    render(<DeletionRequestsTable {...defaultProps} />);

    expect(
      screen.queryByRole('navigation', { name: /pagination/i }),
    ).not.toBeInTheDocument();
  });

  it('renders pagination when there are multiple pages', () => {
    render(
      <DeletionRequestsTable {...defaultProps} total={50} pageSize={25} />,
    );

    const nav = screen.getByRole('navigation', { name: /pagination/i });
    expect(nav).toBeInTheDocument();
    expect(screen.getByText('Next')).toBeInTheDocument();
  });

  it('shows "no results" message when rows are empty with search', () => {
    render(
      <DeletionRequestsTable
        rows={[]}
        total={0}
        page={1}
        pageSize={25}
        search="nonexistent"
      />,
    );

    expect(
      screen.getByText('No deletion requests matching "nonexistent"'),
    ).toBeInTheDocument();
  });

  it('shows "no deletion requests yet" when rows are empty without search', () => {
    render(
      <DeletionRequestsTable
        rows={[]}
        total={0}
        page={1}
        pageSize={25}
        search=""
      />,
    );

    expect(
      screen.getByText('No deletion requests yet'),
    ).toBeInTheDocument();
  });
});
