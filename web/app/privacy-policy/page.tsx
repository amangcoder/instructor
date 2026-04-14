import type { Metadata } from 'next';
import PolicySection from '@/components/PolicySection';
import { PRIVACY_POLICY_SECTIONS } from '@/content/privacy-policy';

/**
 * Privacy Policy Page
 * Renders the complete, legally compliant privacy policy for the Instructor app.
 * All sections are rendered from the PRIVACY_POLICY_SECTIONS array using the
 * PolicySection reusable wrapper component.
 *
 * TODO: Legal review required before production deployment
 */

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description:
    'Privacy Policy for the Instructor app. Learn how we collect, use, and protect your personal data in compliance with GDPR and CCPA.',
  alternates: {
    canonical: '/privacy-policy',
  },
  openGraph: {
    title: 'Privacy Policy | Instructor',
    description:
      'Privacy Policy for the Instructor app. Learn how we collect, use, and protect your personal data.',
    url: '/privacy-policy',
    type: 'website',
    images: [
      {
        url: '/og-image.png',
        width: 1200,
        height: 630,
        alt: 'Instructor — Privacy Policy',
      },
    ],
  },
};

/**
 * RenderContent Component
 * Parses and renders content with markdown-like formatting:
 * - **text** → bold
 * - Regular line breaks → paragraphs
 * - Leading "- " → list items
 */
function RenderContent({ content }: { content: string }) {
  const paragraphs = content.split('\n\n');

  return (
    <>
      {paragraphs.map((para, idx) => {
        // Check if this is a list (lines starting with "- ")
        if (para.includes('\n- ') || para.startsWith('- ')) {
          const items = para
            .split('\n')
            .filter((line) => line.trim())
            .map((line) => line.replace(/^- /, ''));

          return (
            <ul key={idx} className="list-disc list-inside space-y-2">
              {items.map((item, itemIdx) => (
                <li key={itemIdx} className="ml-4">
                  <RenderText text={item} />
                </li>
              ))}
            </ul>
          );
        }

        // Regular paragraph with potential bold formatting
        return (
          <p key={idx} className="leading-relaxed">
            <RenderText text={para} />
          </p>
        );
      })}
    </>
  );
}

/**
 * RenderText Component
 * Handles inline formatting: **text** → <strong>text</strong>
 */
function RenderText({ text }: { text: string }) {
  const parts: (string | React.ReactNode)[] = [];
  let lastIdx = 0;

  const boldRegex = /\*\*(.*?)\*\*/g;
  let match;

  while ((match = boldRegex.exec(text)) !== null) {
    if (match.index > lastIdx) {
      parts.push(text.substring(lastIdx, match.index));
    }
    parts.push(
      <strong key={`bold-${match.index}`} className="font-semibold">
        {match[1]}
      </strong>
    );
    lastIdx = boldRegex.lastIndex;
  }

  if (lastIdx < text.length) {
    parts.push(text.substring(lastIdx));
  }

  return parts.length > 0 ? <>{parts}</> : text;
}

export default function PrivacyPolicyPage() {
  const lastUpdatedDate = 'April 14, 2026';

  return (
    <article className="py-8">
      {/* Page Header */}
      <header className="mb-8 pb-8 border-b border-outline-variant">
        <h1 className="text-4xl font-bold text-on-surface mb-4">Privacy Policy</h1>
        <div className="flex flex-col gap-2">
          <p className="text-sm text-on-surface-variant">
            <span className="font-semibold">Last Updated:</span> {lastUpdatedDate}
          </p>
          <p className="text-sm text-on-surface-variant">
            <span className="font-semibold">Effective Date:</span> April 2026
          </p>
        </div>
      </header>

      {/* Table of Contents / Quick Links */}
      <nav aria-label="Privacy policy sections" className="mb-12 p-6 bg-primary-container/10 rounded-lg border border-primary/20">
        <h2 className="text-lg font-bold text-on-surface mb-4">Quick Navigation</h2>
        <ul className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {PRIVACY_POLICY_SECTIONS.map((section) => (
            <li key={section.id}>
              <a
                href={`#${section.id}`}
                className="text-primary hover:text-primary-container transition-colors font-medium text-sm block p-2 rounded hover:bg-primary/5 min-h-[44px] flex items-center"
              >
                {section.title}
              </a>
            </li>
          ))}
        </ul>
      </nav>

      {/* Policy Sections */}
      <div className="space-y-8">
        {PRIVACY_POLICY_SECTIONS.map((section) => (
          <PolicySection key={section.id} id={section.id} title={section.title}>
            <RenderContent content={section.content} />
          </PolicySection>
        ))}
      </div>

      {/* Footer Note */}
      <footer className="mt-12 pt-8 border-t border-outline-variant">
        <p className="text-sm text-on-surface-variant italic">
          This privacy policy was last updated on {lastUpdatedDate}. We recommend reviewing this
          policy periodically to stay informed about how we protect your information.
        </p>
      </footer>
    </article>
  );
}
