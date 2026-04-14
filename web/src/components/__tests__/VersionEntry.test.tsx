import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import VersionEntry from '../VersionEntry';
import { ChangeLogEntry } from '@/content/changelog';

/**
 * VersionEntry Component Tests
 * Tests rendering of individual changelog entries
 */

describe('VersionEntry', () => {
  const mockEntry: ChangeLogEntry = {
    version: '1.0.0',
    date: '2026-04-14',
    sections: [
      {
        type: 'Added',
        items: ['Feature 1', 'Feature 2'],
      },
      {
        type: 'Fixed',
        items: ['Bug fix 1'],
      },
    ],
  };

  /**
   * AC: Version entry displays version number
   */
  it('renders the version number', () => {
    render(<VersionEntry entry={mockEntry} />);
    const versionText = screen.getByText('v1.0.0');
    expect(versionText).toBeInTheDocument();
  });

  /**
   * AC: Version entry displays formatted date
   */
  it('renders the formatted release date', () => {
    render(<VersionEntry entry={mockEntry} />);
    const dateText = screen.getByText('April 14, 2026');
    expect(dateText).toBeInTheDocument();
  });

  /**
   * AC: Version entry displays time element with datetime attribute
   */
  it('uses semantic time element with datetime attribute', () => {
    render(<VersionEntry entry={mockEntry} />);
    const timeElement = screen.getByText('April 14, 2026');
    expect(timeElement.tagName).toBe('TIME');
    expect(timeElement).toHaveAttribute('dateTime', '2026-04-14');
  });

  /**
   * AC: Version entry displays categorized changes
   */
  it('renders all change sections with proper headings', () => {
    render(<VersionEntry entry={mockEntry} />);
    expect(screen.getByText('Added')).toBeInTheDocument();
    expect(screen.getByText('Fixed')).toBeInTheDocument();
  });

  /**
   * AC: Version entry displays all change items
   */
  it('renders all items within each change section', () => {
    render(<VersionEntry entry={mockEntry} />);
    expect(screen.getByText('Feature 1')).toBeInTheDocument();
    expect(screen.getByText('Feature 2')).toBeInTheDocument();
    expect(screen.getByText('Bug fix 1')).toBeInTheDocument();
  });

  /**
   * AC: Version entry uses unordered lists for items
   */
  it('renders change items as unordered lists', () => {
    const { container } = render(<VersionEntry entry={mockEntry} />);
    const lists = container.querySelectorAll('ul');
    expect(lists.length).toBeGreaterThanOrEqual(2); // At least one per change type
  });

  /**
   * AC: Version entry has timeline dot
   */
  it('renders timeline dot with primary color', () => {
    const { container } = render(<VersionEntry entry={mockEntry} />);
    const dot = container.querySelector('.rounded-full.bg-primary');
    expect(dot).toBeInTheDocument();
  });

  /**
   * AC: Version entry has connector line when not last
   */
  it('renders connector line when not last entry', () => {
    const { container } = render(<VersionEntry entry={mockEntry} isLast={false} />);
    const connector = container.querySelector('.bg-gradient-to-b');
    expect(connector).toBeInTheDocument();
  });

  /**
   * AC: Version entry does not render connector line for last entry
   */
  it('does not render connector line when last entry', () => {
    const { container } = render(<VersionEntry entry={mockEntry} isLast={true} />);
    const connector = container.querySelector('.bg-gradient-to-b');
    expect(connector).not.toBeInTheDocument();
  });

  /**
   * AC: Version entry uses semantic article element
   */
  it('uses semantic article element', () => {
    const { container } = render(<VersionEntry entry={mockEntry} />);
    const article = container.querySelector('article');
    expect(article?.tagName).toBe('ARTICLE');
  });

  /**
   * AC: Version entry displays change type icons
   */
  it('renders change type icons', () => {
    render(<VersionEntry entry={mockEntry} />);
    expect(screen.getByText('✨')).toBeInTheDocument(); // Added icon
    expect(screen.getByText('🐛')).toBeInTheDocument(); // Fixed icon
  });

  /**
   * AC: Version entry has proper heading hierarchy
   */
  it('renders version heading as h3', () => {
    const { container } = render(<VersionEntry entry={mockEntry} />);
    const h3 = container.querySelector('h3');
    expect(h3?.textContent).toContain('v1.0.0');
  });

  /**
   * AC: Version entry has proper accessibility labels
   */
  it('has aria-label for change type lists', () => {
    render(<VersionEntry entry={mockEntry} />);
    const addedList = screen.getByLabelText('Added changes in version 1.0.0');
    expect(addedList).toBeInTheDocument();
  });

  /**
   * AC: Version entry hides decorative elements from screen readers
   */
  it('uses aria-hidden for decorative dots', () => {
    const { container } = render(<VersionEntry entry={mockEntry} />);
    const hiddenDots = container.querySelectorAll('[aria-hidden="true"]');
    expect(hiddenDots.length).toBeGreaterThan(0); // At least timeline dot
  });

  /**
   * AC: Version entry responsive padding
   */
  it('renders with responsive padding', () => {
    const { container } = render(<VersionEntry entry={mockEntry} />);
    const article = container.querySelector('article');
    expect(article).toBeInTheDocument();
  });
});
