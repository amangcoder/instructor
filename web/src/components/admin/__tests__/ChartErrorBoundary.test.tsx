import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import ChartErrorBoundary from '../ChartErrorBoundary';

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Component that immediately throws during render */
function Bomb({ message }: { message: string }) {
  throw new Error(message);
}

// Suppress expected console.error output from React's error boundary machinery
const originalConsoleError = console.error;
beforeEach(() => {
  console.error = jest.fn();
});
afterEach(() => {
  console.error = originalConsoleError;
});

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('ChartErrorBoundary', () => {
  it('renders children when there is no error', () => {
    render(
      <ChartErrorBoundary>
        <p>Chart content</p>
      </ChartErrorBoundary>,
    );
    expect(screen.getByText('Chart content')).toBeInTheDocument();
  });

  it('renders error fallback when child throws', () => {
    render(
      <ChartErrorBoundary>
        <Bomb message="Recharts exploded" />
      </ChartErrorBoundary>,
    );

    expect(screen.getByRole('alert')).toBeInTheDocument();
    expect(screen.getByText('Chart failed to load')).toBeInTheDocument();
  });

  it('displays the error message in the fallback', () => {
    render(
      <ChartErrorBoundary>
        <Bomb message="Data shape mismatch" />
      </ChartErrorBoundary>,
    );

    expect(screen.getByText('Data shape mismatch')).toBeInTheDocument();
  });

  it('renders custom fallback when provided and child throws', () => {
    render(
      <ChartErrorBoundary fallback={<p>Custom error UI</p>}>
        <Bomb message="boom" />
      </ChartErrorBoundary>,
    );

    expect(screen.getByText('Custom error UI')).toBeInTheDocument();
    expect(screen.queryByText('Chart failed to load')).not.toBeInTheDocument();
  });

  it('error card uses role="alert" for screen reader announcement', () => {
    render(
      <ChartErrorBoundary>
        <Bomb message="error" />
      </ChartErrorBoundary>,
    );
    expect(screen.getByRole('alert')).toBeInTheDocument();
  });

  it('error card has red-tinted styling classes', () => {
    const { container } = render(
      <ChartErrorBoundary>
        <Bomb message="styled error" />
      </ChartErrorBoundary>,
    );
    const alertEl = container.querySelector('[role="alert"]');
    expect(alertEl?.className).toMatch(/border-error/);
    expect(alertEl?.className).toMatch(/bg-error-container/);
  });
});
