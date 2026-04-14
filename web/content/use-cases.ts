/**
 * Use cases for the Instructor app.
 * Describes how the app serves different routine types.
 */

export interface UseCase {
  title: string;
  description: string;
  icon: string; // Lucide icon name or emoji
}

export const USE_CASES: UseCase[] = [
  {
    icon: 'Dumbbell',
    title: 'Workouts',
    description:
      'Structure your fitness routines with timed exercises, rest periods, and voice guidance. Stay motivated with real-time spoken cues for every step.',
  },
  {
    icon: 'Lotus',
    title: 'Meditation',
    description:
      'Create guided meditation sessions with customized breathing exercises, mindfulness cues, and soothing voice narration to deepen your practice.',
  },
  {
    icon: 'BookOpen',
    title: 'Study Sessions',
    description:
      'Build focused study routines with Pomodoro-style timers, breaks, and voice reminders. Master subjects one step at a time with structured learning.',
  },
  {
    icon: 'UtensilsCrossed',
    title: 'Cooking Recipes',
    description:
      'Follow cooking instructions step-by-step with voice guidance for prep time, cooking duration, and plating tips. Never miss a crucial timing detail.',
  },
  {
    icon: 'Clock',
    title: 'Other Timed Routines',
    description:
      'Build any timed routine: morning stretches, evening wind-down routines, project planning sessions, or team standup meetings with synchronized voice guidance.',
  },
];
