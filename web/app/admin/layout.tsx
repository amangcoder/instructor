import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Admin Dashboard',
  robots: { index: false, follow: false },
};

/**
 * Admin root layout — wraps ALL /admin/* pages (login + authenticated).
 *
 * Uses position:fixed + inset-0 to visually cover the marketing Header/Footer
 * rendered by the parent RootLayout, without modifying the root layout file.
 * This avoids any risk to existing marketing pages.
 */
export default function AdminRootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div
      className="fixed inset-0 z-50 bg-surface flex flex-col overflow-hidden"
    >
      {children}
    </div>
  );
}
