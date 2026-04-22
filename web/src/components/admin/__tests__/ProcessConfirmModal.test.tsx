/**
 * Tests for ProcessConfirmModal client component.
 *
 * AC-004: Confirmation dialog shown before marking as processed.
 */
import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';

import ProcessConfirmModal from '../ProcessConfirmModal';

// ── Mock HTMLDialogElement methods ─────────────────────────────────────────
// jsdom does not implement <dialog>.showModal() / .close()

beforeAll(() => {
  HTMLDialogElement.prototype.showModal = jest.fn(function (this: HTMLDialogElement) {
    this.setAttribute('open', '');
  });
  HTMLDialogElement.prototype.close = jest.fn(function (this: HTMLDialogElement) {
    this.removeAttribute('open');
  });
});

// ── Tests ──────────────────────────────────────────────────────────────────

describe('ProcessConfirmModal', () => {
  const defaultProps = {
    open: true,
    email: 'j***@example.com',
    onConfirm: jest.fn().mockResolvedValue(undefined),
    onClose: jest.fn(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders the dialog when open', () => {
    render(<ProcessConfirmModal {...defaultProps} />);

    expect(screen.getByText('Confirm Processing')).toBeInTheDocument();
  });

  it('displays the masked email in the description', () => {
    render(<ProcessConfirmModal {...defaultProps} />);

    expect(screen.getByText('j***@example.com')).toBeInTheDocument();
  });

  it('renders Cancel and Confirm buttons', () => {
    render(<ProcessConfirmModal {...defaultProps} />);

    expect(
      screen.getByRole('button', { name: /cancel/i }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole('button', { name: /confirm mark as processed/i }),
    ).toBeInTheDocument();
  });

  it('calls onClose when Cancel is clicked', () => {
    render(<ProcessConfirmModal {...defaultProps} />);

    fireEvent.click(screen.getByRole('button', { name: /cancel/i }));
    expect(defaultProps.onClose).toHaveBeenCalledTimes(1);
  });

  it('calls onConfirm and then onClose on success (AC-004)', async () => {
    const onConfirm = jest.fn().mockResolvedValue(undefined);
    const onClose = jest.fn();

    render(
      <ProcessConfirmModal
        open={true}
        email="j***@example.com"
        onConfirm={onConfirm}
        onClose={onClose}
      />,
    );

    fireEvent.click(
      screen.getByRole('button', { name: /confirm mark as processed/i }),
    );

    await waitFor(() => {
      expect(onConfirm).toHaveBeenCalledTimes(1);
    });

    await waitFor(() => {
      expect(onClose).toHaveBeenCalledTimes(1);
    });
  });

  it('shows error message when onConfirm throws', async () => {
    const onConfirm = jest.fn().mockRejectedValue(new Error('Server error'));
    const onClose = jest.fn();

    render(
      <ProcessConfirmModal
        open={true}
        email="j***@example.com"
        onConfirm={onConfirm}
        onClose={onClose}
      />,
    );

    fireEvent.click(
      screen.getByRole('button', { name: /confirm mark as processed/i }),
    );

    await waitFor(() => {
      expect(screen.getByRole('alert')).toBeInTheDocument();
      expect(screen.getByText('Server error')).toBeInTheDocument();
    });

    // Should NOT close on error
    expect(onClose).not.toHaveBeenCalled();
  });

  it('shows "Processing…" text while confirming', async () => {
    // Create a promise that we control
    let resolveConfirm: () => void;
    const confirmPromise = new Promise<void>((resolve) => {
      resolveConfirm = resolve;
    });
    const onConfirm = jest.fn().mockReturnValue(confirmPromise);

    render(
      <ProcessConfirmModal
        open={true}
        email="j***@example.com"
        onConfirm={onConfirm}
        onClose={jest.fn()}
      />,
    );

    fireEvent.click(
      screen.getByRole('button', { name: /confirm mark as processed/i }),
    );

    await waitFor(() => {
      expect(screen.getByText('Processing…')).toBeInTheDocument();
    });

    // Resolve the promise to clean up
    resolveConfirm!();
  });

  it('has correct ARIA attributes for accessibility', () => {
    render(<ProcessConfirmModal {...defaultProps} />);

    const dialog = document.querySelector('dialog');
    expect(dialog).toHaveAttribute('aria-labelledby', 'process-confirm-title');
    expect(dialog).toHaveAttribute(
      'aria-describedby',
      'process-confirm-description',
    );
  });
});
