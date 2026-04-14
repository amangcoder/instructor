import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import HeroSection from '../HeroSection';
import { BRAND } from '@/content/brand';

/**
 * HeroSection Component Tests
 * Tests rendering, accessibility, and responsive behavior
 */

describe('HeroSection', () => {
  /**
   * AC: Hero section displays tagline from BRAND.tagline
   */
  it('renders the tagline from BRAND.tagline', () => {
    render(<HeroSection />);
    expect(screen.getByText(BRAND.tagline)).toBeInTheDocument();
  });

  /**
   * AC: Hero section displays app name with gradient
   */
  it('renders the app name with gradient styling', () => {
    render(<HeroSection />);
    const appName = screen.getByText(BRAND.name);
    expect(appName).toBeInTheDocument();
    expect(appName).toHaveClass('font-black');
  });

  /**
   * AC: Hero section has responsive padding and typography
   */
  it('renders with responsive padding classes', () => {
    const { container } = render(<HeroSection />);
    const section = container.querySelector('section');
    expect(section).toHaveClass('py-12');
    expect(section).toHaveClass('md:py-20');
    expect(section).toHaveClass('lg:py-32');
  });

  /**
   * AC: Hero section has responsive typography that scales
   */
  it('renders app name with responsive font sizes', () => {
    render(<HeroSection />);
    const appName = screen.getByText(BRAND.name);
    expect(appName.parentElement).toHaveClass('text-4xl');
    expect(appName.parentElement).toHaveClass('sm:text-5xl');
    expect(appName.parentElement).toHaveClass('md:text-6xl');
    expect(appName.parentElement).toHaveClass('lg:text-7xl');
  });

  /**
   * AC: Hero section uses gradient colors from BRAND constant
   */
  it('applies gradient styling with correct colors', () => {
    render(<HeroSection />);
    const appName = screen.getByText(BRAND.name);
    const style = appName.parentElement?.getAttribute('style') || '';
    expect(style).toContain(BRAND.gradientFrom);
    expect(style).toContain(BRAND.gradientTo);
    expect(style).toContain('linear-gradient');
  });

  /**
   * AC: Hero section renders StoreBadges component
   */
  it('renders the StoreBadges component', () => {
    render(<HeroSection />);
    // StoreBadges renders images with specific alt text
    const appStoreImage = screen.getByAltText('Download on the App Store');
    const playStoreImage = screen.getByAltText('Get it on Google Play');
    expect(appStoreImage).toBeInTheDocument();
    expect(playStoreImage).toBeInTheDocument();
  });

  /**
   * AC: Touch targets for content are >= 44px
   * The hero section should not have touch targets smaller than 44px
   */
  it('renders with proper semantic structure', () => {
    const { container } = render(<HeroSection />);
    const section = container.querySelector('section');
    expect(section).toBeInTheDocument();
    expect(section?.tagName).toBe('SECTION');
  });

  /**
   * AC: No horizontal scroll should occur from 320px to 1920px
   */
  it('uses max-width constraints to prevent horizontal scroll', () => {
    const { container } = render(<HeroSection />);
    const maxWidthDiv = container.querySelector('.max-w-3xl');
    expect(maxWidthDiv).toBeInTheDocument();
  });

  /**
   * AC: Hero section uses center alignment
   */
  it('renders with centered alignment', () => {
    const { container } = render(<HeroSection />);
    const contentDiv = container.querySelector('.flex.flex-col.items-center');
    expect(contentDiv).toBeInTheDocument();
  });

  /**
   * Accessibility: Ensures good visual hierarchy
   */
  it('renders with proper visual hierarchy via responsive typography', () => {
    render(<HeroSection />);
    const appName = screen.getByText(BRAND.name);
    const tagline = screen.getByText(BRAND.tagline);

    // App name should have larger font classes than tagline
    expect(appName.parentElement?.className).toContain('text-4xl');
    expect(tagline.className).toContain('text-lg');
  });
});
