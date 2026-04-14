import type { Metadata } from 'next';
import { Manrope } from 'next/font/google';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import './globals.css';

const manrope = Manrope({
  variable: '--font-manrope',
  subsets: ['latin'],
  weight: ['400', '700', '800'],
});

const BASE_URL = process.env.NEXT_PUBLIC_BASE_URL ?? 'https://instructor-app.io';

export const metadata: Metadata = {
  metadataBase: new URL(BASE_URL),
  title: {
    default: 'Instructor — Voice-Guided Workout, Meditation, Study & Cooking Plans',
    template: '%s | Instructor',
  },
  description:
    'Instructor is a mobile app for creating and running voice-guided workout, meditation, study, and cooking plans. Download free on iOS and Android.',
  keywords: [
    'instructor app',
    'voice guided workout',
    'meditation timer',
    'study plan',
    'cooking timer',
    'routine planner',
    'AI plans',
    'TTS audio',
  ],
  authors: [{ name: 'Instructor Team' }],
  creator: 'Instructor',
  publisher: 'Instructor',
  formatDetection: {
    email: false,
    address: false,
    telephone: false,
  },
  openGraph: {
    type: 'website',
    locale: 'en_US',
    siteName: 'Instructor',
    title: 'Instructor — Voice-Guided Workout, Meditation, Study & Cooking Plans',
    description:
      'Create and run voice-guided workout, meditation, study, and cooking plans. Download free on iOS and Android.',
    images: [
      {
        url: '/og-image.png',
        width: 1200,
        height: 630,
        alt: 'Instructor — Voice-guided plans for workout, meditation, study, and cooking',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Instructor — Voice-Guided Plans',
    description:
      'Create and run voice-guided workout, meditation, study, and cooking plans.',
    images: ['/og-image.png'],
  },
  robots: {
    index: true,
    follow: true,
  },
  icons: {
    icon: '/favicon.ico',
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={manrope.variable}>
      <body className="flex flex-col min-h-screen">
        {/* Skip-to-content link for keyboard/screen-reader users */}
        <a href="#main-content" className="skip-link">
          Skip to main content
        </a>
        <Header />
        <main id="main-content" className="flex-1">
          <div className="mx-auto max-w-6xl px-4 py-8 w-full">
            {children}
          </div>
        </main>
        <Footer />
      </body>
    </html>
  );
}
