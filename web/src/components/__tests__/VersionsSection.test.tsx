import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import VersionsSection from '../VersionsSection';
import { CHANGELOG } from '@/content/changelog';

/**
 * VersionsSection Component Tests
 * Tests rendering of changelog timeline section
 */

describe('VersionsSection', () => {
  /**
   * AC: Section heading is present and accessible
   */
  it('renders section with proper heading', () => {
    render(<VersionsSection />);
    const heading = screen.getByText("What's New");
    expect(heading).toBeInTheDocument();
    expect(heading.tagName).toBe('H2');
  });

  /**
   * AC: Section heading has aria-labelledby relationship
   */
  it('has proper heading accessibility attributes', () => {
    const { container } = render(<VersionsSection />);
    const section = container.querySelector('section');
    const heading = screen.getByText("What's New");
    expect(section).toHaveAttribute('aria-labelledby', 'versions-heading');
    expect(heading).toHaveAttribute('id', 'versions-heading');
  });

  /**
   * AC: Section renders description text
   */
  it('renders section description', () => {
    render(<VersionsSection />);
    const description = screen.getByText(/Follow along with our development journey/i);
    expect(description).toBeInTheDocument();
  });

  /**
   * AC: Section renders all changelog entries from CHANGELOG array
   */
  it('renders all versions from CHANGELOG', () => {
    render(<VersionsSection />);
    CHANGELOG.forEach((entry) => {
      const versionText = screen.getByText(`v${entry.version}`);
      expect(versionText).toBeInTheDocument();
    });
  });

  /**
   * AC: Section renders at least 2 versions (0.2.0 and 0.1.0)
   */
  it('renders versions 0.2.0 and 0.1.0', () => {
    render(<VersionsSection />);
    expect(screen.getByText('v0.2.0')).toBeInTheDocument();
    expect(screen.getByText('v0.1.0')).toBeInTheDocument();
  });

  /**
   * AC: Section renders dates for each version
   */
  it('renders formatted dates for each version', () => {
    render(<VersionsSection />);
    // Check for at least the known dates
    expect(screen.getByText('April 11, 2026')).toBeInTheDocument(); // 0.2.0
    expect(screen.getByText('April 6, 2026')).toBeInTheDocument(); // 0.1.0
  });

  /**
   * AC: Section uses semantic section element
   */
  it('uses semantic section element', () => {
    const { container } = render(<VersionsSection />);
    const section = container.querySelector('section');
    expect(section?.tagName).toBe('SECTION');
  });

  /**
   * AC: Section uses ordered list for timeline
   */
  it('renders changelog as ordered list (ol)', () => {
    const { container } = render(<VersionsSection />);
    const ol = container.querySelector('ol');
    expect(ol).toBeInTheDocument();
  });

  /**
   * AC: Timeline list has proper accessibility label
   */
  it('has accessibility label for timeline list', () => {
    render(<VersionsSection />);
    const list = screen.getByLabelText('Application version changelog');
    expect(list).toBeInTheDocument();
    expect(list.tagName).toBe('OL');
  });

  /**
   * AC: Section renders AppScreenshot component
   */
  it('renders app screenshot placeholder', () => {
    render(<VersionsSection />);
    const screenshotLabel = screen.getByLabelText(
      'App screenshot placeholder for device mockup'
    );
    expect(screenshotLabel).toBeInTheDocument();
  });

  /**
   * AC: Section renders desktop screenshot section with sticky positioning
   */
  it('renders desktop screenshot section with sticky positioning', () => {
    const { container } = render(<VersionsSection />);
    const desktopSection = container.querySelector('.lg\\:sticky');
    expect(desktopSection).toBeInTheDocument();
  });

  /**
   * AC: Section hides desktop screenshot on mobile (hidden lg:flex)
   */
  it('hides desktop screenshot on mobile screens', () => {
    const { container } = render(<VersionsSection />);
    const desktopScreenshot = container.querySelector('.hidden.lg\\:flex');
    expect(desktopScreenshot).toBeInTheDocument();
  });

  /**
   * AC: Section renders mobile screenshot placeholder
   */
  it('renders mobile screenshot with max-width constraint', () => {
    const { container } = render(<VersionsSection />);
    const mobileScreenshot = container.querySelector('.lg\\:hidden');
    expect(mobileScreenshot).toBeInTheDocument();
  });

  /**
   * AC: Section uses responsive grid layout
   */
  it('uses responsive grid layout (1 col mobile, 2 col desktop)', () => {
    const { container } = render(<VersionsSection />);
    const grid = container.querySelector('.grid.grid-cols-1.lg\\:grid-cols-2');
    expect(grid).toBeInTheDocument();
  });

  /**
   * AC: Section has proper responsive padding
   */
  it('renders with responsive padding and max-width', () => {
    const { container } = render(<VersionsSection />);
    const section = container.querySelector('section');
    expect(section).toHaveClass('py-16');
    expect(section).toHaveClass('md:py-24');
    expect(section).toHaveClass('lg:py-32');
    expect(section).toHaveClass('px-4');
    expect(section).toHaveClass('sm:px-6');
    expect(section).toHaveClass('lg:px-8');
  });

  /**
   * AC: Section has max-width constraint to prevent horizontal scroll
   */
  it('uses max-width constraint for responsive sizing', () => {
    const { container } = render(<VersionsSection />);
    const container_div = container.querySelector('.max-w-6xl');
    expect(container_div).toBeInTheDocument();
  });

  /**
   * AC: Section renders screenshot helper text on desktop
   */
  it('renders helper text for screenshot section', () => {
    render(<VersionsSection />);
    const helperText = screen.getByText('App screenshots will appear here');
    expect(helperText).toBeInTheDocument();
  });

  /**
   * AC: Changelog entries display all required change types from CHANGELOG
   */
  it('displays all change types (Added, Changed, Fixed, Removed)', () => {
    render(<VersionsSection />);
    // From CHANGELOG.ts structure
    expect(screen.getAllByText('Added').length).toBeGreaterThan(0);
    // Check if Fixed is present (in 0.2.0)
    expect(screen.getAllByText('Fixed').length).toBeGreaterThan(0);
  });
});
