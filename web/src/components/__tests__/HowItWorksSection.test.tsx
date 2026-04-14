import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import HowItWorksSection from '../HowItWorksSection';

describe('HowItWorksSection', () => {
  it('renders the section heading', () => {
    render(<HowItWorksSection />);
    expect(
      screen.getByRole('heading', { level: 2, name: /how it works/i })
    ).toBeInTheDocument();
  });

  it('renders exactly 4 steps', () => {
    render(<HowItWorksSection />);
    const stepHeadings = screen.getAllByRole('heading', { level: 3 });
    expect(stepHeadings.length).toBe(4);
  });

  it('renders step 1 — Pick or create a plan', () => {
    render(<HowItWorksSection />);
    expect(
      screen.getByRole('heading', { level: 3, name: /pick or create a plan/i })
    ).toBeInTheDocument();
  });

  it('renders step 2 — Customise your routine', () => {
    render(<HowItWorksSection />);
    expect(
      screen.getByRole('heading', { level: 3, name: /customise your routine/i })
    ).toBeInTheDocument();
  });

  it('renders step 3 — Run with voice guidance', () => {
    render(<HowItWorksSection />);
    expect(
      screen.getByRole('heading', { level: 3, name: /run with voice guidance/i })
    ).toBeInTheDocument();
  });

  it('renders step 4 — Review and improve', () => {
    render(<HowItWorksSection />);
    expect(
      screen.getByRole('heading', { level: 3, name: /review and improve/i })
    ).toBeInTheDocument();
  });

  it('uses a numbered <ol> list for steps', () => {
    const { container } = render(<HowItWorksSection />);
    const ol = container.querySelector('ol');
    expect(ol).toBeInTheDocument();
  });

  it('renders step number badges 1–4', () => {
    const { container } = render(<HowItWorksSection />);
    const badges = container.querySelectorAll('ol > li > div[aria-hidden="true"]');
    expect(badges.length).toBe(4);
    expect(badges[0]?.textContent).toBe('1');
    expect(badges[1]?.textContent).toBe('2');
    expect(badges[2]?.textContent).toBe('3');
    expect(badges[3]?.textContent).toBe('4');
  });

  it('uses a <section> landmark with aria-labelledby', () => {
    const { container } = render(<HowItWorksSection />);
    const section = container.querySelector('section[aria-labelledby="how-it-works-heading"]');
    expect(section).toBeInTheDocument();
  });

  it('step badges are aria-hidden (decorative numbers)', () => {
    const { container } = render(<HowItWorksSection />);
    const badges = container.querySelectorAll('ol > li > div[aria-hidden="true"]');
    badges.forEach((badge) => {
      expect(badge.getAttribute('aria-hidden')).toBe('true');
    });
  });
});
