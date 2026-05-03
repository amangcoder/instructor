/** S3 key prefix for profile photos. */
export const AVATAR_PREFIX = 'avatars';

interface PhotoUrlOptions {
  bucket?: string | null;
  region?: string;
}

function defaults(): { bucket: string | null; region: string } {
  return {
    bucket: process.env.AWS_S3_BUCKET || null,
    region: process.env.AWS_REGION || 'ap-south-1',
  };
}

export function buildPublicPhotoUrl(
  s3Key: string,
  opts?: PhotoUrlOptions,
): string | null {
  const merged = { ...defaults(), ...opts };
  if (!merged.bucket) return null;
  return `https://${merged.bucket}.s3.${merged.region}.amazonaws.com/${s3Key}`;
}

/**
 * If the stored value is an S3 key (starts with 'avatars/'), return the
 * public virtual-hosted S3 URL. Otherwise returns the value unchanged
 * (handles externally-hosted photos like OAuth provider URLs).
 */
export function resolvePhotoUrl(
  raw: string | null,
  opts?: PhotoUrlOptions,
): string | null {
  if (!raw || !raw.startsWith(`${AVATAR_PREFIX}/`)) return raw;
  return buildPublicPhotoUrl(raw, opts);
}
