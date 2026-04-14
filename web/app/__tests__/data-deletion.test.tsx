import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import DataDeletionPage from '../data-deletion/page';

// Mock the DeletionForm client component to isolate page-level tests
jest.mock('@/components/DeletionForm', () => ({
  __esModule: true,
  default: function DeletionForm() {
    return <div data-testid="deletion-form">DeletionForm mock</div>;
  },
}));

/**
 * DataDeletionPage (/data-deletion) Tests
 * Verifies page structure, informational content, and form integration.
 */

describe('DataDeletionPage', () => {
  // ── Page header ────────────────────────────────────────────────────────────

  describe('Page header', () => {
    it('renders the page heading "Data Deletion Request"', () => {
      render(<DataDeletionPage />);
      expect(
        screen.getByRole('heading', { name: /data deletion request/i, level: 1 }),
      ).toBeInTheDocument();
    });

    it('mentions GDPR Article 17', () => {
      render(<DataDeletionPage />);
      expect(screen.getByText(/GDPR Article 17/i)).toBeInTheDocument();
    });

    it('displays the 30-day processing timeline', () => {
      render(<DataDeletionPage />);
      expect(screen.getByText(/30 days/i)).toBeInTheDocument();
    });
  });

  // ── Deletion consequences ──────────────────────────────────────────────────

  describe('Deletion consequences section', () => {
    it('renders the "What gets deleted" heading', () => {
      render(<DataDeletionPage />);
      expect(
        screen.getByRole('heading', { name: /what gets deleted/i }),
      ).toBeInTheDocument();
    });

    it('lists account removal consequence', () => {
      render(<DataDeletionPage />);
      expect(screen.getByText(/account removed/i)).toBeInTheDocument();
    });

    it('lists plans deletion consequence', () => {
      render(<DataDeletionPage />);
      expect(screen.getByText(/plans deleted/i)).toBeInTheDocument();
    });

    it('lists TTS cache purge consequence', () => {
      render(<DataDeletionPage />);
      expect(screen.getByText(/tts cache purged/i)).toBeInTheDocument();
    });

    it('lists access tokens revocation consequence', () => {
      render(<DataDeletionPage />);
      expect(screen.getByText(/access tokens revoked/i)).toBeInTheDocument();
    });

    it('lists OTP data clearance consequence', () => {
      render(<DataDeletionPage />);
      expect(screen.getByText(/otp data cleared/i)).toBeInTheDocument();
    });
  });

  // ── Process steps ──────────────────────────────────────────────────────────

  describe('How the process works section', () => {
    it('renders process steps heading', () => {
      render(<DataDeletionPage />);
      expect(
        screen.getByRole('heading', { name: /how the process works/i }),
      ).toBeInTheDocument();
    });

    it('mentions email verification step', () => {
      render(<DataDeletionPage />);
      expect(screen.getByText(/verifies the request/i)).toBeInTheDocument();
    });
  });

  // ── Warning notice ─────────────────────────────────────────────────────────

  describe('Warning notice', () => {
    it('shows irreversible action warning', () => {
      render(<DataDeletionPage />);
      expect(screen.getByText(/this action cannot be undone/i)).toBeInTheDocument();
    });
  });

  // ── Form integration ───────────────────────────────────────────────────────

  describe('DeletionForm integration', () => {
    it('renders the DeletionForm component', () => {
      render(<DataDeletionPage />);
      expect(screen.getByTestId('deletion-form')).toBeInTheDocument();
    });

    it('renders "Submit your request" section heading', () => {
      render(<DataDeletionPage />);
      expect(
        screen.getByRole('heading', { name: /submit your request/i }),
      ).toBeInTheDocument();
    });
  });

  // ── Accessibility ──────────────────────────────────────────────────────────

  describe('Accessibility', () => {
    it('uses landmark sections with aria-labelledby attributes', () => {
      const { container } = render(<DataDeletionPage />);
      const sections = container.querySelectorAll('section[aria-labelledby]');
      expect(sections.length).toBeGreaterThanOrEqual(2);
    });

    it('uses <aside> element for informational content', () => {
      const { container } = render(<DataDeletionPage />);
      expect(container.querySelector('aside')).toBeInTheDocument();
    });

    it('uses <ul> with aria-label for consequences list', () => {
      const { container } = render(<DataDeletionPage />);
      const list = container.querySelector('ul[aria-label]');
      expect(list).toBeInTheDocument();
    });
  });

  // ── Component export ───────────────────────────────────────────────────────

  it('exports a valid default component', () => {
    expect(DataDeletionPage).toBeDefined();
    expect(typeof DataDeletionPage).toBe('function');
  });
});
