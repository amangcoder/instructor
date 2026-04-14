/**
 * Feature list for the Instructor marketing website landing page.
 * Each feature includes an icon name, title, and description.
 */

export interface Feature {
  icon: string; // Lucide icon name or emoji
  title: string;
  description: string;
}

export const FEATURES: Feature[] = [
  {
    icon: 'Music', // or 'volume-2'
    title: 'Plan-Based Timer with Voice Guidance',
    description:
      'Execute timed routines with real-time voice guidance for each step. Perfect for workouts, meditation, study sessions, and cooking recipes.',
  },
  {
    icon: 'Zap', // or 'sparkles'
    title: 'AI-Powered Plan Generation',
    description:
      'Let our AI generate custom workout plans, meditation routines, and study schedules tailored to your goals.',
  },
  {
    icon: 'Library',
    title: 'Plan Library with Starter Templates',
    description:
      'Browse curated starter plans and templates. Filter by category: fitness, wellness, learning, and cooking.',
  },
  {
    icon: 'Bell',
    title: 'Background Execution & Notifications',
    description:
      'Keep your screen off while running routines. Get notifications for upcoming steps and session completion.',
  },
  {
    icon: 'Phone',
    title: 'Phone Call Auto-Pause',
    description:
      'Incoming calls automatically pause your routine. Resume where you left off when the call ends.',
  },
  {
    icon: 'Database',
    title: 'Offline-Capable Local Database',
    description:
      'All your plans and routines are stored locally. Use the app without internet — sync when connected.',
  },
  {
    icon: 'Sun', // represents light/dark theme
    title: 'Dark & Light Theme Support',
    description:
      'Switch between beautiful dark and light themes. Respects your device settings for seamless experience.',
  },
];
