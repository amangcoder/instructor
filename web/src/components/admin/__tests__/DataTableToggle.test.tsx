import React from 'react';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import '@testing-library/jest-dom';
import DataTableToggle, { DataTableColumn } from '../DataTableToggle';

// ── Fixtures ──────────────────────────────────────────────────────────────────

const COLUMNS: DataTableColumn[] = [
  { key: 'name', label: 'Name' },
  { key: 'value', label: 'Value' },
  { key: 'date', label: 'Date' },
];

const DATA: Record<string, unknown>[] = [
  { name: 'Alice', value: 42, date: '2024-01-01' },
  { name: 'Bob', value: 7, date: '2024-01-02' },
];

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('DataTableToggle', () => {
  // ── Initial render ─────────────────────────────────────────────────────────

  describe('initial render (collapsed)', () => {
    it('renders a "Show data table" button', () => {
      render(<DataTableToggle data={DATA} columns={COLUMNS} />);
      expect(screen.getByRole('button', { name: /show data table/i })).toBeInTheDocument();
    });

    it('button has aria-expanded="false" initially', () => {
      render(<DataTableToggle data={DATA} columns={COLUMNS} />);
      expect(screen.getByRole('button')).toHaveAttribute('aria-expanded', 'false');
    });

    it('does not render the table initially', () => {
      render(<DataTableToggle data={DATA} columns={COLUMNS} />);
      expect(screen.queryByRole('table')).not.toBeInTheDocument();
    });
  });

  // ── Toggle open ────────────────────────────────────────────────────────────

  describe('clicking to open', () => {
    it('reveals the table after clicking the button', async () => {
      const user = userEvent.setup();
      render(<DataTableToggle data={DATA} columns={COLUMNS} />);

      await user.click(screen.getByRole('button'));

      expect(screen.getByRole('table')).toBeInTheDocument();
    });

    it('changes button label to "Hide data table" when open', async () => {
      const user = userEvent.setup();
      render(<DataTableToggle data={DATA} columns={COLUMNS} />);

      await user.click(screen.getByRole('button'));

      expect(screen.getByRole('button', { name: /hide data table/i })).toBeInTheDocument();
    });

    it('sets aria-expanded="true" when table is open', async () => {
      const user = userEvent.setup();
      render(<DataTableToggle data={DATA} columns={COLUMNS} />);

      await user.click(screen.getByRole('button'));

      expect(screen.getByRole('button')).toHaveAttribute('aria-expanded', 'true');
    });
  });

  // ── Toggle close ───────────────────────────────────────────────────────────

  describe('clicking again to close', () => {
    it('hides the table after clicking twice', async () => {
      const user = userEvent.setup();
      render(<DataTableToggle data={DATA} columns={COLUMNS} />);

      await user.click(screen.getByRole('button')); // open
      await user.click(screen.getByRole('button')); // close

      expect(screen.queryByRole('table')).not.toBeInTheDocument();
    });

    it('reverts button label to "Show data table" when closed again', async () => {
      const user = userEvent.setup();
      render(<DataTableToggle data={DATA} columns={COLUMNS} />);

      await user.click(screen.getByRole('button')); // open
      await user.click(screen.getByRole('button')); // close

      expect(screen.getByRole('button', { name: /show data table/i })).toBeInTheDocument();
    });

    it('resets aria-expanded to "false" when closed again', async () => {
      const user = userEvent.setup();
      render(<DataTableToggle data={DATA} columns={COLUMNS} />);

      await user.click(screen.getByRole('button')); // open
      await user.click(screen.getByRole('button')); // close

      expect(screen.getByRole('button')).toHaveAttribute('aria-expanded', 'false');
    });
  });

  // ── Table content ──────────────────────────────────────────────────────────

  describe('table content', () => {
    it('renders column headers when open', async () => {
      const user = userEvent.setup();
      render(<DataTableToggle data={DATA} columns={COLUMNS} />);

      await user.click(screen.getByRole('button'));

      expect(screen.getByRole('columnheader', { name: 'Name' })).toBeInTheDocument();
      expect(screen.getByRole('columnheader', { name: 'Value' })).toBeInTheDocument();
      expect(screen.getByRole('columnheader', { name: 'Date' })).toBeInTheDocument();
    });

    it('renders the correct number of data rows', async () => {
      const user = userEvent.setup();
      render(<DataTableToggle data={DATA} columns={COLUMNS} />);

      await user.click(screen.getByRole('button'));

      const rows = screen.getAllByRole('row');
      // 1 header row + 2 data rows
      expect(rows).toHaveLength(3);
    });

    it('renders cell values correctly', async () => {
      const user = userEvent.setup();
      render(<DataTableToggle data={DATA} columns={COLUMNS} />);

      await user.click(screen.getByRole('button'));

      expect(screen.getByRole('cell', { name: 'Alice' })).toBeInTheDocument();
      expect(screen.getByRole('cell', { name: '42' })).toBeInTheDocument();
      expect(screen.getByRole('cell', { name: '2024-01-01' })).toBeInTheDocument();
    });

    it('renders "No data available" when data array is empty', async () => {
      const user = userEvent.setup();
      render(<DataTableToggle data={[]} columns={COLUMNS} />);

      await user.click(screen.getByRole('button'));

      expect(screen.getByText('No data available')).toBeInTheDocument();
    });

    it('renders em dash for undefined/null cell values', async () => {
      const user = userEvent.setup();
      const partialData = [{ name: 'Alice', value: null }];
      render(<DataTableToggle data={partialData} columns={COLUMNS} />);

      await user.click(screen.getByRole('button'));

      // null value cell should display —
      const cells = screen.getAllByRole('cell');
      const emDashCells = cells.filter((c) => c.textContent === '—');
      expect(emDashCells.length).toBeGreaterThan(0);
    });
  });

  // ── Accessibility ──────────────────────────────────────────────────────────

  describe('accessibility', () => {
    it('column headers use scope="col"', async () => {
      const user = userEvent.setup();
      const { container } = render(<DataTableToggle data={DATA} columns={COLUMNS} />);

      await user.click(screen.getByRole('button'));

      const ths = container.querySelectorAll('th[scope="col"]');
      expect(ths).toHaveLength(COLUMNS.length);
    });

    it('button is keyboard activatable via Enter', async () => {
      const user = userEvent.setup();
      render(<DataTableToggle data={DATA} columns={COLUMNS} />);

      const btn = screen.getByRole('button');
      btn.focus();
      await user.keyboard('{Enter}');

      expect(screen.getByRole('table')).toBeInTheDocument();
    });
  });
});
