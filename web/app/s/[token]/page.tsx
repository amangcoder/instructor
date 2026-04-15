/**
 * Shared Plan Preview Page (route: /s/:token)
 *
 * Server component that renders a shared plan preview for users who open
 * a shared plan link in a browser without the Instructor app installed.
 *
 * AC-008: Shows plan name, description, step count, estimated duration,
 *         and App Store / Play Store install badges.
 *         Returns a styled 'Plan no longer available' page for invalid or
 *         revoked tokens.
 */

import type { Metadata } from 'next';

// ── Types ─────────────────────────────────────────────────────────────────────

interface SharedPlanData {
  name: string;
  description?: string;
  stepCount: number;
  estimatedDurationMs: number;
  steps?: unknown[];
}

// ── Data fetching ─────────────────────────────────────────────────────────────

const BASE_URL =
  process.env.NEXT_PUBLIC_API_URL ?? 'https://api.instructor-app.io';

async function fetchSharedPlan(token: string): Promise<SharedPlanData | null> {
  try {
    const res = await fetch(`${BASE_URL}/api/plans/shared/${token}`, {
      // No caching — plan may be revoked at any time.
      cache: 'no-store',
    });
    if (res.status === 404 || res.status === 410) return null;
    if (!res.ok) return null;
    return (await res.json()) as SharedPlanData;
  } catch {
    return null;
  }
}

// ── Metadata ──────────────────────────────────────────────────────────────────

export async function generateMetadata({
  params,
}: {
  params: Promise<{ token: string }>;
}): Promise<Metadata> {
  const { token } = await params;
  const plan = await fetchSharedPlan(token);

  if (!plan) {
    return {
      title: 'Plan Unavailable',
      description: 'This plan link is no longer available.',
    };
  }

  return {
    title: plan.name,
    description:
      plan.description ??
      `A ${plan.stepCount}-step plan on Instructor. Open the app to follow along.`,
    openGraph: {
      title: plan.name,
      description:
        plan.description ??
        `A ${plan.stepCount}-step voice-guided plan on Instructor.`,
      type: 'website',
    },
  };
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function formatDuration(ms: number): string {
  const totalSeconds = Math.round(ms / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  if (hours === 0) return `${minutes} min`;
  if (minutes === 0) return `${hours} hr`;
  return `${hours} hr ${minutes} min`;
}

// ── Sub-components ────────────────────────────────────────────────────────────

function StatBadge({ label }: { label: string }) {
  return (
    <span className="inline-flex items-center gap-1 rounded-full bg-surface-container px-3 py-1 text-sm text-on-surface-variant">
      {label}
    </span>
  );
}

function AppStoreBadges() {
  return (
    <div className="flex flex-wrap gap-4 justify-center">
      <a
        href="https://apps.apple.com/app/instructor/id0000000000"
        aria-label="Download Instructor on the App Store"
        className="transition-opacity hover:opacity-80"
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src="/app-store-badge.svg"
          alt="Download on the App Store"
          width={140}
          height={42}
        />
      </a>
      <a
        href="https://play.google.com/store/apps/details?id=io.instructorapp"
        aria-label="Get Instructor on Google Play"
        className="transition-opacity hover:opacity-80"
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src="/google-play-badge.svg"
          alt="Get it on Google Play"
          width={140}
          height={42}
        />
      </a>
    </div>
  );
}

function UnavailablePage() {
  return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] text-center px-6 py-12">
      <div aria-hidden="true" className="text-6xl mb-6">
        🔗
      </div>
      <h1 className="text-2xl font-bold text-on-surface mb-3">
        Plan No Longer Available
      </h1>
      <p className="text-on-surface-variant max-w-sm mb-8">
        This plan link has expired or been revoked by its owner. Ask them for a
        new link, or explore Instructor to create your own plans.
      </p>
      <a
        href="/"
        className="rounded-full bg-primary px-6 py-3 text-sm font-semibold text-on-primary transition-opacity hover:opacity-90"
      >
        Explore Instructor
      </a>
    </div>
  );
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default async function SharedPlanPage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;
  const plan = await fetchSharedPlan(token);

  if (!plan) {
    return <UnavailablePage />;
  }

  const durationLabel = formatDuration(plan.estimatedDurationMs);

  return (
    <div className="max-w-xl mx-auto px-4 py-10">
      {/* Plan name */}
      <h1 className="text-3xl font-extrabold text-on-surface mb-4 leading-tight">
        {plan.name}
      </h1>

      {/* Stats row */}
      <div className="flex flex-wrap gap-2 mb-6" aria-label="Plan details">
        <StatBadge label={`${plan.stepCount} ${plan.stepCount === 1 ? 'step' : 'steps'}`} />
        <StatBadge label={durationLabel} />
      </div>

      {/* Description */}
      {plan.description && plan.description.trim().length > 0 && (
        <p className="text-on-surface-variant text-base leading-relaxed mb-8">
          {plan.description}
        </p>
      )}

      {/* Divider */}
      <hr className="border-outline-variant mb-8" />

      {/* Install CTA */}
      <section aria-labelledby="install-heading">
        <h2
          id="install-heading"
          className="text-lg font-semibold text-on-surface mb-2 text-center"
        >
          Open in Instructor
        </h2>
        <p className="text-sm text-on-surface-variant text-center mb-6">
          Download the free Instructor app to follow this plan with voice
          guidance.
        </p>
        <AppStoreBadges />
      </section>
    </div>
  );
}
