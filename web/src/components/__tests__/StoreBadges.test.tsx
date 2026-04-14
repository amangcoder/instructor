import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import userEvent from '@testing-library/user-event';
import StoreBadges from '../StoreBadges';
import { APP_STORE_URL, PLAY_STORE_URL } from '@/content/constants';

/**
 * StoreBadges Component Tests
 * Tests rendering, accessibility, responsiveness, and link functionality
 */

describe('StoreBadges', () => {
  /**
   * AC: web/components/StoreBadges.tsx renders official App Store and Google Play badge SVGs
   */
  it('renders both App Store and Google Play badge images', () => {
    render(<StoreBadges />);
    const appStoreBadge = screen.getByAltText('Download on the App Store');
    const playStoreBadge = screen.getByAltText('Get it on Google Play');
    expect(appStoreBadge).toBeInTheDocument();
    expect(playStoreBadge).toBeInTheDocument();
  });

  /**
   * AC: Badge SVGs are official assets from public/badges/
   */
  it('renders badge SVGs from correct public paths', () => {
    render(<StoreBadges />);
    const appStoreBadge = screen.getByAltText('Download on the App Store') as HTMLImageElement;
    const playStoreBadge = screen.getByAltText('Get it on Google Play') as HTMLImageElement;
    expect(appStoreBadge.src).toContain('/badges/app-store-badge.svg');
    expect(playStoreBadge.src).toContain('/badges/play-store-badge.svg');
  });

  /**
   * AC: Badges are rendered at equal height (60px)
   */
  it('renders both badges at equal dimensions', () => {
    render(<StoreBadges />);
    const appStoreBadge = screen.getByAltText('Download on the App Store') as HTMLImageElement;
    const playStoreBadge = screen.getByAltText('Get it on Google Play') as HTMLImageElement;
    expect(appStoreBadge.width).toBe(180);
    expect(appStoreBadge.height).toBe(60);
    expect(playStoreBadge.width).toBe(180);
    expect(playStoreBadge.height).toBe(60);
  });

  /**
   * AC: Badge links point to TODO constants with clear TODO comments
   */
  it('renders links pointing to store URLs from constants', () => {
    render(<StoreBadges />);
    const links = screen.getAllByRole('link');
    expect(links).toHaveLength(2);
    expect(links[0]).toHaveAttribute('href', APP_STORE_URL);
    expect(links[1]).toHaveAttribute('href', PLAY_STORE_URL);
  });

  /**
   * AC: Badge links contain TODO comments in the source
   */
  it('stores TODO URLs as intended placeholders', () => {
    expect(APP_STORE_URL).toContain('TODO');
    expect(PLAY_STORE_URL).toContain('TODO');
  });

  /**
   * AC: Badge alt text describes download action for accessibility
   */
  it('renders alt text that describes download actions', () => {
    render(<StoreBadges />);
    expect(screen.getByAltText('Download on the App Store')).toBeInTheDocument();
    expect(screen.getByAltText('Get it on Google Play')).toBeInTheDocument();
  });

  /**
   * AC: Badge links have descriptive aria-labels for screen readers
   */
  it('renders links with descriptive aria-labels', () => {
    render(<StoreBadges />);
    const appStoreLink = screen.getByRole('link', { name: /download on the app store/i });
    const playStoreLink = screen.getByRole('link', { name: /get it on google play/i });
    expect(appStoreLink).toBeInTheDocument();
    expect(playStoreLink).toBeInTheDocument();
  });

  /**
   * AC: Badge links have titles for hover tooltips
   */
  it('renders links with descriptive title attributes', () => {
    render(<StoreBadges />);
    const links = screen.getAllByRole('link');
    expect(links[0]).toHaveAttribute('title', 'Download Instructor on the Apple App Store');
    expect(links[1]).toHaveAttribute('title', 'Download Instructor on Google Play Store');
  });

  /**
   * AC: Download badges are responsive: stack vertically on mobile, side-by-side on tablet+
   */
  it('renders with responsive flex layout classes', () => {
    const { container } = render(<StoreBadges />);
    const badgesContainer = container.querySelector('.flex');
    expect(badgesContainer).toHaveClass('flex-col'); // Vertical on mobile
    expect(badgesContainer).toHaveClass('sm:flex-row'); // Horizontal on tablet+
  });

  /**
   * AC: Touch targets for badge buttons >= 44px on mobile
   */
  it('renders badge links with sufficient touch target sizes', () => {
    render(<StoreBadges />);
    const links = screen.getAllByRole('link');
    links.forEach((link) => {
      // min-h-[60px] is greater than 44px minimum touch target
      expect(link).toHaveClass('min-h-[60px]');
    });
  });

  /**
   * Accessibility: Badge links should be keyboard navigable
   */
  it('renders links that are keyboard navigable', () => {
    render(<StoreBadges />);
    const links = screen.getAllByRole('link');
    links.forEach((link) => {
      // Links are natively keyboard navigable
      expect(link).toBeInTheDocument();
      expect(link.tagName).toBe('A');
    });
  });

  /**
   * Interaction: Badge links should have hover and active states
   */
  it('renders badge links with transition and scale classes for interactivity', () => {
    render(<StoreBadges />);
    const links = screen.getAllByRole('link');
    links.forEach((link) => {
      expect(link).toHaveClass('transition-transform');
      expect(link).toHaveClass('hover:scale-105');
      expect(link).toHaveClass('active:scale-95');
    });
  });

  /**
   * AC: Badges are centered in their container
   */
  it('renders badges centered within their container', () => {
    const { container } = render(<StoreBadges />);
    const badgesContainer = container.querySelector('.justify-center');
    expect(badgesContainer).toBeInTheDocument();
    const itemsCenterDiv = container.querySelector('.items-center');
    expect(itemsCenterDiv).toBeInTheDocument();
  });

  /**
   * AC: Proper spacing between badges on responsive views
   */
  it('renders with proper gap between badges', () => {
    const { container } = render(<StoreBadges />);
    const badgesContainer = container.querySelector('.gap-4');
    expect(badgesContainer).toBeInTheDocument();
  });

  /**
   * Accessibility: Images should have proper alt text for screen readers
   */
  it('renders images with descriptive alt text for accessibility', () => {
    render(<StoreBadges />);
    const images = screen.getAllByRole('img');
    images.forEach((img) => {
      expect(img).toHaveAttribute('alt');
      const alt = img.getAttribute('alt');
      expect(alt).not.toBe('');
      expect(alt?.toLowerCase()).toContain('download');
    });
  });
});
