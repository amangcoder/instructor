import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import FeaturesSection from '../FeaturesSection';
import { FEATURES } from '@/content/features';

describe('FeaturesSection', () => {
  it('renders the section heading', () => {
    render(<FeaturesSection />);
    expect(
      screen.getByRole('heading', { level: 2, name: /everything you need to stay on track/i })
    ).toBeInTheDocument();
  });

  it('renders a card for every feature in FEATURES', () => {
    render(<FeaturesSection />);
    FEATURES.forEach((feature) => {
      expect(screen.getByText(feature.title)).toBeInTheDocument();
      expect(screen.getByText(feature.description)).toBeInTheDocument();
    });
  });

  it('renders the feature list as a <ul> with role="list"', () => {
    const { container } = render(<FeaturesSection />);
    const list = container.querySelector('ul[role="list"]');
    expect(list).toBeInTheDocument();
  });

  it('has a responsive grid class for 1/2/3 columns', () => {
    const { container } = render(<FeaturesSection />);
    const grid = container.querySelector('ul[role="list"]');
    expect(grid?.className).toMatch(/grid-cols-1/);
    expect(grid?.className).toMatch(/sm:grid-cols-2/);
    expect(grid?.className).toMatch(/lg:grid-cols-3/);
  });

  it('uses a <section> landmark with aria-labelledby', () => {
    const { container } = render(<FeaturesSection />);
    const section = container.querySelector('section[aria-labelledby="features-heading"]');
    expect(section).toBeInTheDocument();
  });

  it('renders each feature inside a <li> element', () => {
    const { container } = render(<FeaturesSection />);
    const items = container.querySelectorAll('li');
    expect(items.length).toBe(FEATURES.length);
  });

  it('centers the last feature card on desktop (lg) using col-start-2', () => {
    const { container } = render(<FeaturesSection />);
    const items = container.querySelectorAll('li');
    const lastItem = items[items.length - 1];
    // Verify the centering class is applied to the last item
    expect(lastItem?.className).toMatch(/last:lg:col-start-2/);
  });
});
