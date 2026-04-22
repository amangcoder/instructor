/**
 * Deletion Requests API — Response types for admin management of data deletion requests.
 *
 * These mirror the server-side DTOs in server/src/admin/dto/deletion-request.dto.ts.
 * They are duplicated here so the Next.js web app does not depend on the
 * NestJS server package at build time.
 */

// ---------------------------------------------------------------------------
// Deletion Request Row  — GET /api/admin/analytics/deletion-requests
// ---------------------------------------------------------------------------

/** Status of a deletion request */
export type DeletionRequestStatus = 'pending' | 'processed' | 'rejected';

/** Scope of data deletion */
export type DeletionRequestScope = 'full_account' | 'audio_cache' | 'plans';

/** Single deletion request record for admin listing */
export interface DeletionRequestRow {
  /** Unique identifier for the deletion request */
  id: string;
  /** User's email address associated with the deletion request */
  email: string;
  /** Scope(s) of deletion: one or more of 'full_account', 'audio_cache', 'plans' */
  scope: DeletionRequestScope[];
  /** Current status of the request */
  status: DeletionRequestStatus;
  /** Optional reason provided by the user for the deletion request */
  reason: string | null;
  /** ISO 8601 timestamp when the request was created */
  createdAt: string;
  /** ISO 8601 timestamp when the request was processed, or null if still pending */
  processedAt: string | null;
}

// ---------------------------------------------------------------------------
// Deletion Request List Response  — GET /api/admin/analytics/deletion-requests?page&pageSize&search&status
// ---------------------------------------------------------------------------

/** Paginated list of deletion requests with filtering and search */
export interface DeletionRequestListResponse {
  /** Array of deletion request records for this page */
  data: DeletionRequestRow[];
  /** Total number of deletion requests matching the filter criteria */
  total: number;
  /** Current page number (1-indexed) */
  page: number;
  /** Number of items per page */
  pageSize: number;
}

// ---------------------------------------------------------------------------
// Pending Count Response  — GET /api/admin/analytics/deletion-requests/pending-count
// ---------------------------------------------------------------------------

/** Count of pending deletion requests for sidebar badge */
export interface PendingCountResponse {
  /** Number of deletion requests with status='pending' */
  count: number;
}
