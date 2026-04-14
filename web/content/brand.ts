/**
 * Brand constants for the Instructor marketing website.
 * Matches the "Curated Stillness" design system from the Flutter app.
 */

export const BRAND = {
  // App name
  name: 'Instructor',

  // Marketing tagline
  tagline: 'Voice-guided workout, meditation, study, and cooking plans',

  // Gradient colors (Flutter "Curated Stillness" design system)
  // Primary: #565C8C, PrimaryContainer: #C0C6FD
  gradientFrom: '#565C8C',
  gradientTo: '#C0C6FD',

  // Font family (loaded via next/font/google)
  fontFamily: 'Manrope',

  // Font weight for brand name (extrabold = 800)
  fontWeight: 800,

  // Support email
  supportEmail: 'admin@layersiq.com',

  // Gradient angle (top-left to bottom-right in CSS: 135deg)
  gradientAngle: '135deg',
} as const;
