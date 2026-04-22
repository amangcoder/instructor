/**
 * Mask email addresses for safe display in admin context.
 *
 * Pattern: show first 2 chars of local part + '***@domain'
 * Edge case: if local part is 1-2 chars, show '***@domain'
 *
 * Examples:
 *   - john@gmail.com       → jo***@gmail.com
 *   - ab@example.com       → ***@example.com  (local part too short)
 *   - a@example.com        → ***@example.com  (local part too short)
 */
export function maskEmail(email: string): string {
  const [localPart, domain] = email.split('@');

  if (!localPart || !domain) {
    return email; // Invalid email, return as-is
  }

  if (localPart.length <= 2) {
    return `***@${domain}`;
  }

  return `${localPart.slice(0, 2)}***@${domain}`;
}
