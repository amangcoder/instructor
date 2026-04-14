import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import AppScreenshot from '../AppScreenshot';

/**
 * AppScreenshot Component Tests
 * Tests rendering of device frame placeholder
 */

describe('AppScreenshot', () => {
  /**
   * AC: Device frame renders with correct aspect ratio and styling
   */
  it('renders a device frame with phone aspect ratio', () => {
    const { container } = render(<AppScreenshot />);
    const figure = container.querySelector('figure');
    expect(figure).toBeInTheDocument();
    expect(figure).toHaveClass('aspect-[9/16]');
  });

  /**
   * AC: Device frame has rounded corners and border styling
   */
  it('renders with rounded corners and border', () => {
    const { container } = render(<AppScreenshot />);
    const figure = container.querySelector('figure');
    expect(figure).toHaveClass('rounded-3xl');
    expect(figure).toHaveClass('border-8');
  });

  /**
   * AC: Device frame displays TODO marker text
   */
  it('displays TODO placeholder text', () => {
    render(<AppScreenshot />);
    const todoText = screen.getByText('TODO: Replace with actual screenshot');
    expect(todoText).toBeInTheDocument();
  });

  /**
   * AC: Device frame displays descriptive text
   */
  it('displays description text', () => {
    render(<AppScreenshot />);
    const description = screen.getByText('Device frame mockup placeholder');
    expect(description).toBeInTheDocument();
  });

  /**
   * AC: Device frame has accessibility attributes
   */
  it('has proper accessibility labels', () => {
    const { container } = render(<AppScreenshot />);
    const figure = container.querySelector('figure');
    expect(figure).toHaveAttribute(
      'aria-label',
      'App screenshot placeholder for device mockup'
    );
  });

  /**
   * AC: Device frame renders phone emoji
   */
  it('displays phone emoji as visual indicator', () => {
    render(<AppScreenshot />);
    const emojiContainer = screen.getByText('📱');
    expect(emojiContainer).toBeInTheDocument();
  });

  /**
   * AC: Device frame uses semantic figure element
   */
  it('uses semantic figure element', () => {
    const { container } = render(<AppScreenshot />);
    const figure = container.querySelector('figure');
    expect(figure?.tagName).toBe('FIGURE');
  });

  /**
   * AC: Device frame responsive at mobile (320px to 1920px)
   */
  it('uses max-width constraint for responsive sizing', () => {
    const { container } = render(<AppScreenshot />);
    const figure = container.querySelector('figure');
    expect(figure).toHaveClass('w-full');
    expect(figure).toHaveClass('max-w-sm');
  });

  /**
   * AC: Device frame displays centered content
   */
  it('centers content within the frame', () => {
    const { container } = render(<AppScreenshot />);
    const figure = container.querySelector('figure');
    expect(figure).toHaveClass('flex');
    expect(figure).toHaveClass('items-center');
    expect(figure).toHaveClass('justify-center');
  });

  /**
   * AC: Device frame has shadow for depth
   */
  it('renders with shadow for visual depth', () => {
    const { container } = render(<AppScreenshot />);
    const figure = container.querySelector('figure');
    expect(figure).toHaveClass('shadow-2xl');
  });
});
