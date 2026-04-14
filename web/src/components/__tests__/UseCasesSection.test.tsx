import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import UseCasesSection from '../UseCasesSection';
import { USE_CASES } from '@/content/use-cases';

describe('UseCasesSection', () => {
  it('renders the section heading', () => {
    render(<UseCasesSection />);
    expect(
      screen.getByRole('heading', { level: 2, name: /built for every routine/i })
    ).toBeInTheDocument();
  });

  it('renders a card for every use case', () => {
    render(<UseCasesSection />);
    USE_CASES.forEach((useCase) => {
      expect(screen.getByText(useCase.title)).toBeInTheDocument();
      expect(screen.getByText(useCase.description)).toBeInTheDocument();
    });
  });

  it('renders Workouts use case', () => {
    render(<UseCasesSection />);
    expect(screen.getByText('Workouts')).toBeInTheDocument();
  });

  it('renders Meditation use case', () => {
    render(<UseCasesSection />);
    expect(screen.getByText('Meditation')).toBeInTheDocument();
  });

  it('renders Study Sessions use case', () => {
    render(<UseCasesSection />);
    expect(screen.getByText('Study Sessions')).toBeInTheDocument();
  });

  it('renders Cooking Recipes use case', () => {
    render(<UseCasesSection />);
    expect(screen.getByText('Cooking Recipes')).toBeInTheDocument();
  });

  it('uses a <section> landmark with aria-labelledby', () => {
    const { container } = render(<UseCasesSection />);
    const section = container.querySelector('section[aria-labelledby="use-cases-heading"]');
    expect(section).toBeInTheDocument();
  });

  it('renders the list as a <ul> with role="list"', () => {
    const { container } = render(<UseCasesSection />);
    const list = container.querySelector('ul[role="list"]');
    expect(list).toBeInTheDocument();
  });

  it('has correct number of <li> items', () => {
    const { container } = render(<UseCasesSection />);
    const items = container.querySelectorAll('li');
    expect(items.length).toBe(USE_CASES.length);
  });

  it('icon containers are aria-hidden', () => {
    const { container } = render(<UseCasesSection />);
    const hiddenIcons = container.querySelectorAll('[aria-hidden="true"]');
    expect(hiddenIcons.length).toBeGreaterThanOrEqual(USE_CASES.length);
  });
});
