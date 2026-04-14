import React from 'react';

/**
 * AppScreenshot Component
 *
 * Renders a device frame mockup placeholder with a TODO marker.
 * The frame is a simple phone-like rectangle with rounded corners.
 *
 * Accessible:
 * - Uses <figure> semantic element for device mockup
 * - alt text via aria-label describes the placeholder purpose
 * - Clear text indication that this is a TODO placeholder
 *
 * Dark mode:
 * - Gradient and border use theme-aware colors
 */
export default function AppScreenshot() {
  return (
    <figure
      aria-label="App screenshot placeholder for device mockup"
      className="
        flex items-center justify-center
        w-full max-w-sm
        aspect-[9/16]
        rounded-3xl
        bg-gradient-to-b from-surface-dim to-outline-variant
        border-8 border-inverse-surface
        shadow-2xl
        overflow-hidden
      "
    >
      <div className="flex flex-col items-center justify-center gap-4 p-8 text-center">
        <div className="text-4xl" role="img" aria-label="Mobile phone">📱</div>
        <div className="flex flex-col gap-2">
          <p className="text-sm font-semibold text-on-surface">
            TODO: Replace with actual screenshot
          </p>
          <p className="text-xs text-on-surface-variant">
            Device frame mockup placeholder
          </p>
        </div>
      </div>
    </figure>
  );
}
