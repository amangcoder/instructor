/**
 * Typed entity interfaces for the single-table DynamoDB design.
 *
 * Table key schema:
 *   pk (partition key) — entity type + identifier
 *   sk (sort key)      — entity subtype or timestamp
 *
 * GSI:
 *   gsi1pk / gsi1sk — secondary lookup axis (e.g. email → user)
 *
 * Entity pk/sk patterns:
 *   User profile:     pk=USER#<userId>    sk=PROFILE
 *   OTP record:       pk=OTP#<email>      sk=<ISO>#<uuid>
 *   Refresh token:    pk=TOKEN#<hash>     sk=TOKEN
 *   Sync metadata:    pk=USER#<userId>    sk=SYNC
 *   Rate limit:       pk=RATELIMIT#<ns>#<id>  sk=COUNTER
 */

// ── User ─────────────────────────────────────────────────────────────────────

export interface UserEntity {
  /** Partition key: USER#<userId> */
  pk: string;
  /** Sort key: PROFILE */
  sk: string;
  /** GSI1 partition key: email address (enables email → user lookup) */
  gsi1pk: string;
  /** GSI1 sort key: PROFILE */
  gsi1sk: string;
  /** UUID assigned at user creation */
  id: string;
  /** Lowercase normalised email address */
  email: string;
  /** ISO string timestamp of account creation */
  createdAt: string;
}

// ── OTP ──────────────────────────────────────────────────────────────────────

export interface OtpEntity {
  /** Partition key: OTP#<email> */
  pk: string;
  /** Sort key: <ISO created_at>#<uuid> — unique per OTP, sorts by creation time */
  sk: string;
  /** Email address that the OTP was issued for */
  email: string;
  /** HMAC-SHA256 hex hash of the plaintext OTP code */
  code: string;
  /** ISO string expiry timestamp */
  expiresAt: string;
  /** Number of failed verification attempts (max 5) */
  attempts: number;
  /** Whether this OTP has been used or invalidated */
  used: boolean;
  /** DynamoDB TTL — Unix epoch seconds (auto-deletes the item after expiry) */
  ttl: number;
}

// ── Refresh Token ─────────────────────────────────────────────────────────────

export interface RefreshTokenEntity {
  /** Partition key: TOKEN#<tokenHash> */
  pk: string;
  /** Sort key: TOKEN */
  sk: string;
  /** GSI1 partition key: USER#<userId> (enables "revoke all tokens for user" scans) */
  gsi1pk: string;
  /** GSI1 sort key: TOKEN */
  gsi1sk: string;
  /** Owner user ID */
  userId: string;
  /** SHA-256 hex hash of the opaque refresh token UUID */
  tokenHash: string;
  /** Whether this token has been revoked */
  revoked: boolean;
  /** ISO string expiry timestamp */
  expiresAt: string;
  /** DynamoDB TTL — Unix epoch seconds */
  ttl: number;
}

// ── Sync Metadata ─────────────────────────────────────────────────────────────

export interface SyncMetadataEntity {
  /** Partition key: USER#<userId> */
  pk: string;
  /** Sort key: SYNC */
  sk: string;
  /** Owner user ID */
  userId: string;
  /** ISO string of last confirmed sync */
  lastSyncAt: string | null;
  /** Byte size of the last uploaded database file */
  sizeBytes: number | null;
}

// ── Rate Limit Counter ────────────────────────────────────────────────────────

export interface RateLimitEntity {
  /** Partition key: RATELIMIT#<namespace>#<identifier> */
  pk: string;
  /** Sort key: COUNTER */
  sk: string;
  /** Current request count in the window */
  count: number;
  /** DynamoDB TTL — Unix epoch seconds (auto-expires counter after window closes) */
  ttl: number;
}
