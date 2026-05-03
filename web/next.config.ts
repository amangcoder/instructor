import type { NextConfig } from 'next';
import path from 'path';

const nextConfig: NextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  outputFileTracingRoot: path.join(__dirname),
  eslint: {
    ignoreDuringBuilds: false,
  },
  async redirects() {
    return [
      // ── Consolidated admin pages (moved to tabbed views) ────────────────────
      {
        source: '/admin/deletion-requests',
        destination: '/admin/users?tab=deletion-requests',
        permanent: true,
      },
      {
        source: '/admin/engagement',
        destination: '/admin/overview',
        permanent: true,
      },
      {
        source: '/admin/app-version',
        destination: '/admin/settings?tab=app-version',
        permanent: true,
      },
      {
        source: '/admin/admins',
        destination: '/admin/settings?tab=admins',
        permanent: true,
      },
      {
        source: '/admin/library',
        destination: '/admin/content?tab=library',
        permanent: true,
      },
      {
        source: '/admin/series',
        destination: '/admin/content?tab=series',
        permanent: true,
      },
      {
        source: '/admin/categories',
        destination: '/admin/content?tab=categories',
        permanent: true,
      },
    ];
  },
  async headers() {
    const isDev = process.env.NODE_ENV !== 'production';
    return [
      {
        // Apply security headers to all /admin/* routes
        source: '/admin/:path*',
        headers: [
          {
            key: 'Content-Security-Policy',
            value: [
              "default-src 'self'",
              // 'unsafe-inline' required for Tailwind CSS-in-JS variables
              "style-src 'self' 'unsafe-inline'",
              // Dev needs 'unsafe-eval' + 'unsafe-inline' for Next.js React Refresh / HMR
              isDev
                ? "script-src 'self' 'unsafe-eval' 'unsafe-inline'"
                : "script-src 'self'",
              "img-src 'self' data: https:",
              "font-src 'self'",
              // Voice preview pipes WAV bytes through URL.createObjectURL → blob:
              "media-src 'self' blob:",
              // Dev needs websocket for HMR
              isDev
                ? "connect-src 'self' ws: wss:"
                : "connect-src 'self'",
              "frame-ancestors 'none'",
            ].join('; '),
          },
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'strict-origin-when-cross-origin',
          },
          {
            key: 'Permissions-Policy',
            value: 'camera=(), microphone=(), geolocation=()',
          },
        ],
      },
    ];
  },
};

export default nextConfig;
