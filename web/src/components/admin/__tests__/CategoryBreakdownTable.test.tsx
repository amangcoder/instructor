/**
 * Tests for CategoryBreakdownTable component.
 *
 * Covers:
 *  - Rendering columns and rows (AC-009)
 *  - Sort by column header click (asc → desc toggle) (AC-009, REQ-010)
 *  - Conversion rate percentage formatting
 *  - Empty state (REQ-018)
 *  - Accessibility attributes
 */
import React from 'react';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import '@testing-library/jest-dom';
import CategoryBreakdownTable from '../CategoryBreakdownTable';
import type { CategoryRow } from '@/types/library-categories';

// ── Fixtures ──────────────────────────────────────────────────────────────────

const ROWS: CategoryRow[] = [
  {
    category: 'yoga',
    publishedPlans: 5,
    totalAdoptions: 200,
    rangeAdoptions: 50,
    totalSessions: 150,
    conversionRate: 0.75,
  },
  {
    category: 'meditation',
    publishedPlans: 8,
    totalAdoptions: 350,
    rangeAdoptions: 90,
    totalSessions: 280,
    conversionRate: 0.8,
  },
  {
    category: 'workout',
    publishedPlans: 12,
    totalAdoptions: 180,
    rangeAdoptions: 40,
    totalSessions: 60,
    conversionRate: 0.333,
  },
  {
    category: 'cooking',
    publishedPlans: 3,
    totalAdoptions: 90,
    rangeAdoptions: 20,
    totalSessions: 0,
    conversionRate: null,
  },
];

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Returns data rows (excludes header row). */
function getDataRows() {
  const rows = screen.getAllByRole('row');
  return rows.slice(1); // first row is <thead>
}

function getCategoryNames(rows: HTMLElement[]): string[] {
  return rows.map((r) => within(r).getAllByRole('cell')[0].textContent ?? '');
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('CategoryBreakdownTable', () => {
  // ── Rendering ──────────────────────────────────────────────────────────────

  it('renders all column headers', () => {
    render(<CategoryBreakdownTable rows={ROWS} />);

    expect(screen.getByRole('button', { name: /category/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /published plans/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /total adoptions/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /total sessions/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /conversion rate/i })).toBeInTheDocument();
  });

  it('renders a row for each category (AC-009)', () => {
    render(<CategoryBreakdownTable rows={ROWS} />);

    const dataRows = getDataRows();
    expect(dataRows).toHaveLength(4);
  });

  it('renders category names in each row', () => {
    render(<CategoryBreakdownTable rows={ROWS} />);

    expect(screen.getByText('yoga')).toBeInTheDocument();
    expect(screen.getByText('meditation')).toBeInTheDocument();
    expect(screen.getByText('workout')).toBeInTheDocument();
    expect(screen.getByText('cooking')).toBeInTheDocument();
  });

  it('renders published plans count', () => {
    render(<CategoryBreakdownTable rows={ROWS} />);
    expect(screen.getByText('5')).toBeInTheDocument();
    expect(screen.getByText('8')).toBeInTheDocument();
    expect(screen.getByText('12')).toBeInTheDocument();
    expect(screen.getByText('3')).toBeInTheDocument();
  });

  it('renders total adoptions count', () => {
    render(<CategoryBreakdownTable rows={ROWS} />);
    expect(screen.getByText('200')).toBeInTheDocument();
    expect(screen.getByText('350')).toBeInTheDocument();
    expect(screen.getByText('180')).toBeInTheDocument();
    expect(screen.getByText('90')).toBeInTheDocument();
  });

  // ── Conversion rate formatting ─────────────────────────────────────────────

  it('formats conversionRate as percentage with 1 decimal (e.g. 34.2%)', () => {
    render(<CategoryBreakdownTable rows={ROWS} />);

    expect(screen.getByText('75.0%')).toBeInTheDocument();
    expect(screen.getByText('80.0%')).toBeInTheDocument();
    expect(screen.getByText('33.3%')).toBeInTheDocument();
  });

  it('renders em-dash for null conversionRate', () => {
    render(<CategoryBreakdownTable rows={ROWS} />);
    // cooking has null conversionRate
    expect(screen.getByText('—')).toBeInTheDocument();
  });

  // ── Sorting — initial state ────────────────────────────────────────────────

  it('sorts alphabetically by category ascending by default', () => {
    render(<CategoryBreakdownTable rows={ROWS} />);

    const names = getCategoryNames(getDataRows());
    expect(names).toEqual(['cooking', 'meditation', 'workout', 'yoga']);
  });

  // ── Sorting — clicking headers ─────────────────────────────────────────────

  it('toggles from asc to desc when the same column header is clicked again (AC-009)', async () => {
    const user = userEvent.setup();
    render(<CategoryBreakdownTable rows={ROWS} />);

    // Category is already sorted asc — click to go desc
    await user.click(screen.getByRole('button', { name: /sort by category/i }));
    const names = getCategoryNames(getDataRows());
    expect(names).toEqual(['yoga', 'workout', 'meditation', 'cooking']);
  });

  it('sorts by Total Adoptions descending on click', async () => {
    const user = userEvent.setup();
    render(<CategoryBreakdownTable rows={ROWS} />);

    // Click once → asc
    await user.click(screen.getByRole('button', { name: /sort by total adoptions/i }));
    let names = getCategoryNames(getDataRows());
    expect(names).toEqual(['cooking', 'workout', 'yoga', 'meditation']);

    // Click again → desc
    await user.click(screen.getByRole('button', { name: /sort by total adoptions/i }));
    names = getCategoryNames(getDataRows());
    expect(names).toEqual(['meditation', 'yoga', 'workout', 'cooking']);
  });

  it('sorts by Published Plans ascending on first click', async () => {
    const user = userEvent.setup();
    render(<CategoryBreakdownTable rows={ROWS} />);

    await user.click(screen.getByRole('button', { name: /sort by published plans/i }));
    const names = getCategoryNames(getDataRows());
    expect(names).toEqual(['cooking', 'yoga', 'meditation', 'workout']);
  });

  it('sorts by Conversion Rate and pushes nulls to bottom', async () => {
    const user = userEvent.setup();
    render(<CategoryBreakdownTable rows={ROWS} />);

    // Sort conversion rate asc
    await user.click(screen.getByRole('button', { name: /sort by conversion rate/i }));
    const names = getCategoryNames(getDataRows());
    // workout (33.3%) < yoga (75%) < meditation (80%) < cooking (null → bottom)
    expect(names).toEqual(['workout', 'yoga', 'meditation', 'cooking']);
  });

  // ── Sort indicator arrow ───────────────────────────────────────────────────

  it('shows ▲ on active column when sorted asc', () => {
    render(<CategoryBreakdownTable rows={ROWS} />);

    // Default is category asc — the button contains ▲
    const categoryBtn = screen.getByRole('button', { name: /sort by category/i });
    expect(categoryBtn.textContent).toContain('▲');
  });

  it('shows ▼ on active column when sorted desc', async () => {
    const user = userEvent.setup();
    render(<CategoryBreakdownTable rows={ROWS} />);

    // Click category to toggle to desc
    await user.click(screen.getByRole('button', { name: /sort by category/i }));
    const categoryBtn = screen.getByRole('button', { name: /sort by category/i });
    expect(categoryBtn.textContent).toContain('▼');
  });

  it('does not show an arrow on inactive column headers', () => {
    render(<CategoryBreakdownTable rows={ROWS} />);

    const adoptionsBtn = screen.getByRole('button', { name: /sort by total adoptions/i });
    expect(adoptionsBtn.textContent).not.toMatch(/[▲▼]/);
  });

  // ── Empty state (REQ-018) ──────────────────────────────────────────────────

  it('renders EmptyState when rows is empty', () => {
    render(<CategoryBreakdownTable rows={[]} />);

    expect(screen.getByRole('status')).toBeInTheDocument();
    expect(screen.getByText('No category data available.')).toBeInTheDocument();
  });

  it('does not render a table when rows is empty', () => {
    render(<CategoryBreakdownTable rows={[]} />);

    expect(screen.queryByRole('table')).not.toBeInTheDocument();
  });

  // ── Accessibility ──────────────────────────────────────────────────────────

  it('table has an accessible label', () => {
    render(<CategoryBreakdownTable rows={ROWS} />);

    expect(
      screen.getByRole('table', { name: 'Library category breakdown' }),
    ).toBeInTheDocument();
  });

  it('column header buttons are keyboard-accessible', () => {
    render(<CategoryBreakdownTable rows={ROWS} />);

    const buttons = screen.getAllByRole('button');
    buttons.forEach((btn) => {
      expect(btn).toHaveAttribute('type', 'button');
    });
  });

  it('active column header button includes direction in aria-label', () => {
    render(<CategoryBreakdownTable rows={ROWS} />);

    // Category is the default active column sorted asc
    const categoryBtn = screen.getByRole('button', { name: /currently ascending/i });
    expect(categoryBtn).toBeInTheDocument();
  });
});
