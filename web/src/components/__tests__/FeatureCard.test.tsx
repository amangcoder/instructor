import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import FeatureCard from '../FeatureCard';
import type { Feature } from '@/content/features';

const mockFeature: Feature = {
  icon: 'Zap',
  title: 'AI-Powered Plan Generation',
  description: 'Let our AI generate custom plans tailored to your goals.',
};

const unknownIconFeature: Feature = {
  icon: 'UnknownIcon',
  title: 'Unknown Feature',
  description: 'A feature with an unmapped icon.',
};

describe('FeatureCard', () => {
  it('renders the feature title as an h3', () => {
    render(<FeatureCard feature={mockFeature} />);
    expect(
      screen.getByRole('heading', { level: 3, name: mockFeature.title })
    ).toBeInTheDocument();
  });

  it('renders the feature description', () => {
    render(<FeatureCard feature={mockFeature} />);
    expect(screen.getByText(mockFeature.description)).toBeInTheDocument();
  });

  it('renders the known emoji icon', () => {
    const { container } = render(<FeatureCard feature={mockFeature} />);
    const iconDiv = container.querySelector('[aria-hidden="true"]');
    expect(iconDiv).toBeInTheDocument();
    expect(iconDiv?.textContent).toBe('⚡');
  });

  it('falls back to ✨ for unknown icon names', () => {
    const { container } = render(<FeatureCard feature={unknownIconFeature} />);
    const iconDiv = container.querySelector('[aria-hidden="true"]');
    expect(iconDiv?.textContent).toBe('✨');
  });

  it('renders as an <article> element', () => {
    const { container } = render(<FeatureCard feature={mockFeature} />);
    const article = container.querySelector('article');
    expect(article).toBeInTheDocument();
  });

  it('icon container has aria-hidden to prevent screen reader noise', () => {
    const { container } = render(<FeatureCard feature={mockFeature} />);
    const iconDiv = container.querySelector('[aria-hidden="true"]');
    expect(iconDiv).toBeInTheDocument();
  });

  it('has hover transition classes', () => {
    const { container } = render(<FeatureCard feature={mockFeature} />);
    const article = container.querySelector('article');
    expect(article?.className).toMatch(/transition/);
    expect(article?.className).toMatch(/hover:shadow-md/);
  });
});
