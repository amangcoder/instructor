import type { Metadata } from 'next';
import HeroSection from '@/components/HeroSection';
import FeaturesSection from '@/components/FeaturesSection';
import UseCasesSection from '@/components/UseCasesSection';
import HowItWorksSection from '@/components/HowItWorksSection';

export const metadata: Metadata = {
  title: 'Instructor — Voice-Guided Workout, Meditation, Study & Cooking Plans',
  description:
    'Instructor is a mobile app for creating and running voice-guided workout, meditation, study, and cooking plans. Download free on iOS and Android.',
  alternates: {
    canonical: '/',
  },
  openGraph: {
    title: 'Instructor — Voice-Guided Workout, Meditation, Study & Cooking Plans',
    description:
      'Create and run voice-guided workout, meditation, study, and cooking plans. Download free on iOS and Android.',
    url: '/',
    type: 'website',
    images: [
      {
        url: '/og-image.png',
        width: 1200,
        height: 630,
        alt: 'Instructor — Voice-guided plans for workout, meditation, study, and cooking',
      },
    ],
  },
};

/**
 * Home Page (route: /)
 * Landing page for the Instructor app marketing website.
 *
 * Section order:
 *   1. HeroSection       — app name, tagline, download CTAs
 *   2. FeaturesSection   — responsive 3-col grid of feature cards
 *   3. UseCasesSection   — workout, meditation, study, cooking use cases
 *   4. HowItWorksSection — 4 numbered steps
 *   5. VersionsSection   — changelog timeline with app screenshots
 *
 * Note: The <main> element is provided by the RootLayout wrapper.
 * This page uses a <div> to avoid duplicate <main> landmarks.
 */
export default function Home() {
  return (
    <div className="min-h-screen bg-slate-950 text-white">
      <HeroSection />
      <FeaturesSection />
      <UseCasesSection />
      <HowItWorksSection />
    </div>
  );
}
