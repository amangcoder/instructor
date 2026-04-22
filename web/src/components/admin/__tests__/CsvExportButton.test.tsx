import React from 'react';
import { render, screen, act } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import '@testing-library/jest-dom';
import CsvExportButton from '../CsvExportButton';

// ── Timer setup ────────────────────────────────────────────────────────────────

// Fake timers let us control the 1500ms reset without real-time waits
jest.useFakeTimers();

afterEach(() => {
  jest.clearAllTimers();
  jest.restoreAllMocks();
});

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Spy on HTMLAnchorElement.prototype.click to intercept programmatic download
 * triggers without disrupting React's own DOM operations (document.createElement,
 * document.body.appendChild etc. are left intact so rendering works normally).
 */
function mockAnchorClick() {
  return jest
    .spyOn(HTMLAnchorElement.prototype, 'click')
    .mockImplementation(() => {});
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('CsvExportButton', () => {
  // ── Initial render ─────────────────────────────────────────────────────────

  describe('initial render', () => {
    it('renders a button', () => {
      render(<CsvExportButton exportUrl="/api/export" filename="users.csv" />);
      expect(screen.getByRole('button')).toBeInTheDocument();
    });

    it('shows "Export CSV" label when idle', () => {
      render(<CsvExportButton exportUrl="/api/export" filename="users.csv" />);
      expect(screen.getByText('Export CSV')).toBeInTheDocument();
    });

    it('button is not disabled initially', () => {
      render(<CsvExportButton exportUrl="/api/export" filename="users.csv" />);
      expect(screen.getByRole('button')).not.toBeDisabled();
    });

    it('aria-label mentions the filename when idle', () => {
      render(<CsvExportButton exportUrl="/api/export" filename="report.csv" />);
      expect(screen.getByRole('button')).toHaveAttribute(
        'aria-label',
        expect.stringContaining('report.csv'),
      );
    });
  });

  // ── Download trigger ───────────────────────────────────────────────────────

  describe('download trigger', () => {
    it('calls anchor.click() when button is pressed', async () => {
      const clickSpy = mockAnchorClick();
      const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime });

      render(<CsvExportButton exportUrl="/api/export" filename="users.csv" />);
      await user.click(screen.getByRole('button'));

      expect(clickSpy).toHaveBeenCalledTimes(1);
    });

    it('sets the anchor href to the exportUrl', async () => {
      let capturedHref = '';
      jest.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (
        this: HTMLAnchorElement,
      ) {
        capturedHref = this.href;
      });

      const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime });
      render(
        <CsvExportButton exportUrl="/api/admin/export?format=csv" filename="report.csv" />,
      );
      await user.click(screen.getByRole('button'));

      expect(capturedHref).toContain('/api/admin/export');
    });

    it('sets the anchor download attribute to filename', async () => {
      let capturedDownload = '';
      jest.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (
        this: HTMLAnchorElement,
      ) {
        capturedDownload = this.download;
      });

      const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime });
      render(<CsvExportButton exportUrl="/api/export" filename="my-report.csv" />);
      await user.click(screen.getByRole('button'));

      expect(capturedDownload).toBe('my-report.csv');
    });
  });

  // ── Loading state ──────────────────────────────────────────────────────────

  describe('loading state during download', () => {
    it('shows "Downloading…" immediately after click', async () => {
      mockAnchorClick();
      const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime });
      render(<CsvExportButton exportUrl="/api/export" filename="users.csv" />);

      await user.click(screen.getByRole('button'));

      expect(screen.getByText('Downloading…')).toBeInTheDocument();
    });

    it('disables the button during download', async () => {
      mockAnchorClick();
      const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime });
      render(<CsvExportButton exportUrl="/api/export" filename="users.csv" />);

      await user.click(screen.getByRole('button'));

      expect(screen.getByRole('button')).toBeDisabled();
    });

    it('sets aria-disabled="true" during download', async () => {
      mockAnchorClick();
      const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime });
      render(<CsvExportButton exportUrl="/api/export" filename="users.csv" />);

      await user.click(screen.getByRole('button'));

      expect(screen.getByRole('button')).toHaveAttribute('aria-disabled', 'true');
    });

    it('aria-label mentions "Downloading" while loading', async () => {
      mockAnchorClick();
      const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime });
      render(<CsvExportButton exportUrl="/api/export" filename="report.csv" />);

      await user.click(screen.getByRole('button'));

      expect(screen.getByRole('button')).toHaveAttribute(
        'aria-label',
        expect.stringContaining('Downloading'),
      );
    });

    it('resets to idle state after the 1500ms timeout', async () => {
      mockAnchorClick();
      const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime });
      render(<CsvExportButton exportUrl="/api/export" filename="users.csv" />);

      await user.click(screen.getByRole('button'));
      act(() => {
        jest.advanceTimersByTime(2000);
      });

      expect(screen.getByText('Export CSV')).toBeInTheDocument();
      expect(screen.getByRole('button')).not.toBeDisabled();
    });

    it('does not trigger a second download while already downloading', async () => {
      const clickSpy = mockAnchorClick();
      const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime });
      render(<CsvExportButton exportUrl="/api/export" filename="users.csv" />);

      await user.click(screen.getByRole('button')); // triggers download → disabled
      // Button is disabled so userEvent skips the second click
      expect(clickSpy).toHaveBeenCalledTimes(1);
    });
  });

  // ── Accessibility ──────────────────────────────────────────────────────────

  describe('accessibility', () => {
    it('meets minimum 44px height via min-h-[44px] class', () => {
      render(<CsvExportButton exportUrl="/api/export" filename="users.csv" />);
      expect(screen.getByRole('button').className).toMatch(/min-h-\[44px\]/);
    });

    it('has focus-visible ring class for keyboard navigation', () => {
      render(<CsvExportButton exportUrl="/api/export" filename="users.csv" />);
      expect(screen.getByRole('button').className).toMatch(/focus-visible/);
    });
  });
});
