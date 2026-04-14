/**
 * Privacy Policy sections for the Instructor marketing website.
 * Provides comprehensive, legally-accurate disclosure of data practices.
 *
 * TODO: Legal review required before production deployment
 * This content reflects the actual data schema and processing practices.
 * Must be reviewed by legal counsel before publishing to ensure compliance
 * with GDPR (EU), CCPA (California), Apple App Store, and Google Play Store
 * data safety requirements.
 */

export interface PolicySection {
  id: string;
  title: string;
  content: string;
}

export const PRIVACY_POLICY_SECTIONS: PolicySection[] = [
  {
    id: 'intro',
    title: 'Introduction',
    content: `Instructor is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and otherwise process your personal data in connection with our mobile application (the "App") and related services.

This policy is effective as of April 2026 and was last updated on April 14, 2026.`,
  },
  {
    id: 'controller',
    title: 'Identity and Contact Information',
    content: `The data controller for Instructor is Layers IQ, a software development organization.

If you have questions about this Privacy Policy or our privacy practices, please contact us at:
Email: admin@layersiq.com

We will respond to all privacy inquiries within 30 days.`,
  },
  {
    id: 'collection',
    title: 'What Personal Data We Collect',
    content: `We collect the following categories of personal data when you use the App:

**Account Information:**
- Email address (required for authentication and account recovery)
- Display name (optional, shown to users who view shared plans)
- Username (unique identifier, optional)
- Profile photo URL (optional, stored as a URL reference only, not as file data)

**Plan and Routine Data:**
- User-created plans (routine names, step descriptions, timings, voice parameters)
- Plan metadata (creation date, modification date, category tags)
- Execution state (current progress in running routines, completion history)

**Audio and Text Processing:**
- Text submitted for voice synthesis (temporary, used only to generate audio)
- Resulting audio files (cached and stored as described in Section 4)
- Cache keys derived from text content (SHA-256 hashes)
- TTS voice preference (which voice profile you select)

**Authentication Data:**
- Email-based one-time passcodes (OTP) - hashed using SHA-256 before storage
- Refresh tokens for maintaining login sessions - stored securely with revocation support
- Session tokens (temporary, not persisted long-term)

We do not collect: passwords, credit card information, location data, contacts, or photos stored on your device.`,
  },
  {
    id: 'storage',
    title: 'How Data Is Stored and Secured',
    content: `**Primary Database:**
- All user account data, plans, execution state, and authentication records are stored in a PostgreSQL relational database hosted on Amazon Web Services (AWS) in compliance with AWS security best practices.
- The database is encrypted at rest using AWS-managed encryption keys.
- Network traffic to the database is encrypted in transit using TLS 1.3.
- Database backups are automated and encrypted before storage.

**Audio Cache:**
- Voice synthesis output (MP3 audio files) is cached on AWS S3 (Amazon Simple Storage Service).
- Cache entries are indexed using SHA-256 hashes of the input text.
- S3 objects are encrypted at rest using server-side encryption.
- Access to S3 is restricted to the application backend only; users do not have direct S3 URLs.

**Local Device Storage:**
- Plans and routine data are also cached locally on your device using a local SQLite database (Drift ORM).
- Authentication tokens are stored securely in your device's secure storage (iOS Keychain, Android Keystore).
- Local data remains on your device even when offline; it synchronizes with the backend when connectivity is restored.

**Data Retention:**
- Active user account data is retained for the duration of your account.
- Deleted accounts are permanently removed from the database within 30 days of deletion request.
- TTS audio cache entries are retained for 90 days after last access, then automatically purged.
- Execution history (e.g., "completed workout on date X") is retained for 1 year.
- Refresh token revocation records are maintained for 90 days.`,
  },
  {
    id: 'purposes',
    title: 'Purpose of Data Collection',
    content: `We process your personal data for the following purposes:

**Essential Service Delivery:**
- Authenticating your identity when you log in
- Storing and retrieving your plans and routines
- Generating voice guidance audio via the Kokoro TTS engine
- Syncing your data across devices
- Providing offline access to your data

**User Experience and Features:**
- Personalizing the app based on your preferences (voice type, speech speed)
- Tracking execution progress and session history
- Recommending starter plans based on your routine types

**Communication:**
- Sending transactional emails (account confirmations, OTP login links, deletion receipts)
- Notifying you of app updates and critical security issues

**Safety and Compliance:**
- Detecting and preventing fraudulent usage
- Enforcing our Terms of Service
- Complying with legal obligations (GDPR, CCPA, app store requirements)
- Responding to data subject rights requests (access, correction, deletion)`,
  },
  {
    id: 'third-party',
    title: 'Third-Party Services and Data Sharing',
    content: `We do not sell your personal data to third parties. However, we do engage the following service providers who process your data on our behalf:

**AWS (Amazon Web Services):**
- Hosts our PostgreSQL database and S3 storage
- May process and store data in the us-east-1 region (Virginia, USA)
- AWS has signed Data Processing Agreements (DPAs) to comply with GDPR

**Kokoro TTS Engine:**
- Processes text you submit for voice synthesis
- Generates audio output that we cache and return to you
- Does not retain your text or audio after synthesis is complete
- Kokoro processes data in-memory; outputs are not logged

**AWS SES (Simple Email Service):**
- Sends transactional emails from our infrastructure
- Does not store or use your email address for marketing purposes
- Only sends emails you have requested (account confirmations, OTP login links)

**We do NOT share data with:**
- Analytics platforms (we do not use Google Analytics or similar trackers)
- Advertising networks
- Social media platforms
- Data brokers or marketing services
- Any other commercial entities

If we are ever acquired or merged, we will notify you of any change in data ownership and your rights will be preserved.`,
  },
  {
    id: 'authentication',
    title: 'Authentication and Security',
    content: `**Email-Based Authentication:**
- We use email-based one-time passcodes (OTP) for secure login — no passwords required
- OTP codes are hashed using SHA-256 cryptographic hashing before storage in the database
- OTP codes expire after 10 minutes
- Failed authentication attempts are logged and rate-limited to prevent brute-force attacks

**Refresh Tokens:**
- Refresh tokens allow you to stay logged in across app sessions
- All refresh tokens are hashed and stored with a revocation flag
- Tokens expire after 30 days of inactivity
- You can revoke all active tokens by logging out of all sessions or requesting account deletion

**Session Security:**
- Authentication sessions use secure, httpOnly cookies (on web) or secure device storage (on mobile)
- Session tokens are encrypted in transit using TLS 1.3
- We do not use password-based authentication

**Rate Limiting and DDoS Protection:**
- API endpoints are protected by Redis-backed rate limiting
- We enforce limits: 10 deletion requests per user per hour, 100 API calls per IP per minute
- AWS WAFv2 provides additional DDoS protection and malicious request filtering`,
  },
  {
    id: 'tts-processing',
    title: 'Text-to-Speech Data Processing',
    content: `**How TTS Works:**
- When you create a plan step, the step text is submitted to the Kokoro TTS engine for voice synthesis
- The Kokoro engine generates an MP3 audio file based on your text and selected voice profile
- The resulting audio is cached on AWS S3 for future playback
- Cache entries are indexed using SHA-256 hashes of the input text (no raw text stored as the key)

**Data Retention for TTS:**
- Input text is used only for synthesis and is not permanently stored after audio generation
- Generated audio files are cached for 90 days after last access, then automatically deleted
- If the same text is submitted again, we reuse the cached audio (improving performance)

**No Data Selling:**
- The developer does not sell or use your text submissions or TTS audio for any commercial purpose
- We do not use your text to train AI models or sell voice data to third parties
- Kokoro TTS processing is a technical service, not a data monetization activity`,
  },
  {
    id: 'rights',
    title: 'Your Privacy Rights',
    content: `Depending on your location, you may have the following rights:

**Under GDPR (European Union residents):**
- Right of access: Request a copy of your personal data
- Right of correction: Ask us to update inaccurate data
- Right of erasure ("right to be forgotten"): Request deletion of your account and all associated data
- Right of data portability: Export your data in a machine-readable format
- Right to restrict processing: Limit how we use your data
- Right to object: Opt out of certain processing activities
- Right to lodge a complaint: File a complaint with your local data protection authority

**Under CCPA (California residents):**
- Right to know: Request what personal data we collect about you
- Right to delete: Request deletion of your data
- Right to opt-out: Opt out of data sales (though we do not sell your data)
- Right to correct: Request correction of inaccurate information
- Right to appeal: Appeal our decision on a data subject rights request

**How to Exercise Your Rights:**
Submit any data subject rights request to admin@layersiq.com with:
- Your email address and username (if applicable)
- A clear description of your request (access, correction, deletion, etc.)
- Proof of identity (email verification) if required

We will respond to all data subject rights requests within 30 days. Complex requests may take up to 60 days.`,
  },
  {
    id: 'deletion',
    title: 'Data Deletion and Account Removal',
    content: `**What Happens When You Request Deletion:**
When you submit a data deletion request, we permanently remove the following within 30 days:
1. Your account record (email, username, display name, profile photo URL)
2. All user-created plans and routines associated with your account
3. Execution history and session state
4. TTS audio cache files generated for your plans
5. All refresh tokens and OTP records (revoked immediately)
6. Any other personal data linked to your account

**What Is Not Deleted:**
- Backup data held for disaster recovery (deleted within 90 days)
- Aggregated, anonymized statistics (e.g., "1000 users completed a workout this week")
- Data required by law to retain (e.g., for tax or legal purposes, deleted after retention period expires)

**Fallback Methods:**
If the automated form is unavailable, you can request deletion by:
- Emailing admin@layersiq.com with "Delete My Account" in the subject line
- Including your registered email address and any identifying information

**Confirmation:**
You will receive an email confirmation within 24 hours confirming receipt of your deletion request. Another email will confirm completion within 30 days.`,
  },
  {
    id: 'cookies',
    title: 'Cookies and Local Storage',
    content: `**Cookies (Web App Only):**
- The Instructor web site uses minimal cookies: only a session authentication cookie (httpOnly, Secure, SameSite=Strict)
- This cookie is required for login functionality and is deleted when you log out
- We do not use tracking cookies, advertising cookies, or third-party analytics cookies
- No cookies are used to track your browsing behavior

**Local Storage:**
- The mobile app (iOS, Android, etc.) uses device-local SQLite databases and secure device storage (Keychain/Keystore) instead of cookies
- This local data is encrypted at rest on your device
- Local data synchronizes with our backend servers for backup and cross-device access

**Data Tracking:**
- We do not use Google Analytics, Mixpanel, Amplitude, or any third-party analytics platform
- We do not track your behavior across the web or on third-party sites
- Crash reporting is optional and only sent if you explicitly opt-in to the beta testing program`,
  },
  {
    id: 'children',
    title: "Children's Privacy",
    content: `**Minimum Age Requirement:**
The Instructor app is not intended for children under 13 years of age. We do not knowingly collect personal data from children under 13.

**For EU Residents (GDPR Article 8):**
In the European Union, parental consent is required for processing personal data of children under the age of digital majority (typically 13-16, depending on member state). If we become aware that we have collected data from a child under 13 without proper parental consent, we will delete the data immediately.

**For US Residents (COPPA):**
In the United States, the Children's Online Privacy Protection Act (COPPA) requires parental consent for children under 13. The Instructor app complies with COPPA by not intentionally collecting data from users under 13.

**If You Are a Parent or Guardian:**
If you believe your child has used the app or created an account, please contact us immediately at admin@layersiq.com and we will delete the account and associated data.`,
  },
  {
    id: 'changes',
    title: 'Changes to This Policy',
    content: `We may update this Privacy Policy from time to time to reflect changes in our practices, technology, legal requirements, or other factors.

**How We Notify You of Changes:**
- Material changes will be communicated via email to your registered email address
- The "Last Updated" date at the top of this policy will be updated
- We will provide at least 30 days' notice for any material changes that negatively affect your privacy rights
- Continued use of the app after changes take effect constitutes acceptance of the updated policy

**Policy History:**
- Original policy published: April 6, 2026 (version 0.1)
- Last updated: April 14, 2026 (version 0.2)`,
  },
  {
    id: 'law',
    title: 'Governing Law and Dispute Resolution',
    content: `**Applicable Law:**
This Privacy Policy and our privacy practices are governed by and construed in accordance with the laws of the United States, specifically the laws of the State of California, without regard to its conflict of law principles.

**Jurisdiction and Disputes:**
For any disputes, claims, or legal proceedings related to this policy:
- EU residents may bring proceedings in the courts of their member state or before their data protection authority
- California residents have rights under the California Consumer Privacy Act (CCPA)
- All other users consent to the jurisdiction of the state and federal courts located in California

**Dispute Resolution:**
In the event of a privacy dispute, we commit to good-faith resolution through discussion. If resolution cannot be reached, either party may pursue legal action as permitted by law.

**Contact for Disputes:**
admin@layersiq.com`,
  },
];
