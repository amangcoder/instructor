import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import Home from '../page';
import { BRAND } from '@/content/brand';
import { CHANGELOG } from '@/content/changelog';

/**
 * Home Page (/) Tests
 * Tests that the landing page renders correctly with all sections
 */

describe('Home Page', () => {
  /**
   * AC: web/app/page.tsx renders HeroSection and compiles without errors
   */
  it('renders without errors', () => {
    render(<Home />);
    expect(screen.getByText(BRAND.tagline)).toBeInTheDocument();
  });

  /**
   * AC: Page renders as a main element with proper background
   */
  it('renders main element with correct styling', () => {
    const { container } = render(<Home />);
    const main = container.querySelector('main');
    expect(main).toBeInTheDocument();
    expect(main).toHaveClass('min-h-screen');
    expect(main).toHaveClass('bg-surface');
    expect(main).toHaveClass('text-on-surface');
  });

  /**
   * AC: Page renders HeroSection component content
   */
  it('renders HeroSection component with app name and tagline', () => {
    render(<Home />);
    expect(screen.getByText(BRAND.name)).toBeInTheDocument();
    expect(screen.getByText(BRAND.tagline)).toBeInTheDocument();
  });

  /**
   * AC: Page renders download badges from HeroSection
   */
  it('renders download badges through HeroSection', () => {
    render(<Home />);
    const appStoreBadge = screen.getByAltText('Download on the App Store');
    const playStoreBadge = screen.getByAltText('Get it on Google Play');
    expect(appStoreBadge).toBeInTheDocument();
    expect(playStoreBadge).toBeInTheDocument();
  });

  /**
   * AC: Page uses semantic HTML structure
   */
  it('uses semantic HTML with main element', () => {
    const { container } = render(<Home />);
    const main = container.querySelector('main');
    expect(main?.tagName).toBe('MAIN');
  });

  /**
   * AC: No TypeScript errors or compilation issues
   */
  it('exports a valid default component', () => {
    expect(Home).toBeDefined();
    expect(typeof Home).toBe('function');
  });

  /**
   * AC: Page renders VersionsSection with "What's New" heading
   */
  it('renders VersionsSection with heading', () => {
    render(<Home />);
    const versionsHeading = screen.getByText("What's New");
    expect(versionsHeading).toBeInTheDocument();
  });

  /**
   * AC: Page renders changelog versions from CHANGELOG constant
   */
  it('renders changelog versions on the page', () => {
    render(<Home />);
    CHANGELOG.forEach((entry) => {
      const versionText = screen.getByText(`v${entry.version}`);
      expect(versionText).toBeInTheDocument();
    });
  });

  /**
   * AC: Page renders app screenshot placeholder
   */
  it('renders app screenshot placeholder component', () => {
    render(<Home />);
    const screenshotPlaceholder = screen.getByText(
      'TODO: Replace with actual screenshot'
    );
    expect(screenshotPlaceholder).toBeInTheDocument();
  });

  /**
   * AC: Page renders changelog timeline as ordered list
   */
  it('renders changelog timeline as ordered list', () => {
    render(<Home />);
    const timelineList = screen.getByLabelText('Application version changelog');
    expect(timelineList).toBeInTheDocument();
    expect(timelineList.tagName).toBe('OL');
  });
});
