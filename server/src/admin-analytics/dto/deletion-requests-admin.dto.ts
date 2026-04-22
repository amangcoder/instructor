import { IsOptional, IsString, IsIn } from 'class-validator';

/**
 * Query parameters for listing deletion requests.
 *
 * GET /api/admin/analytics/deletion-requests?page=1&pageSize=20&search=john&status=pending
 */
export class ListDeletionRequestsQueryDto {
  @IsOptional()
  page?: number;

  @IsOptional()
  pageSize?: number;

  @IsOptional()
  @IsString()
  search?: string;

  @IsOptional()
  @IsIn(['pending', 'processed'])
  status?: 'pending' | 'processed';
}

/**
 * A deletion request row returned from the list endpoint.
 * Email is masked for privacy.
 */
export interface DeletionRequestRow {
  id: string;
  email: string; // Masked: jo***@gmail.com
  ipAddress: string | null;
  requestedAt: string; // ISO 8601
  processedAt: string | null; // ISO 8601 or null
  status: 'pending' | 'processed';
}

/**
 * Response for GET /api/admin/analytics/deletion-requests
 * Paginated list of deletion requests.
 */
export interface DeletionRequestListResponse {
  data: DeletionRequestRow[];
  total: number;
  page: number;
  pageSize: number;
}

/**
 * Response for PATCH /api/admin/analytics/deletion-requests/:id/process
 * Marks a deletion request as processed.
 */
export interface ProcessedDeletionRequest {
  id: string;
  status: 'processed';
  processedAt: string; // ISO 8601
}

/**
 * Response for GET /api/admin/analytics/deletion-requests/pending-count
 * Returns the count of pending (unprocessed) deletion requests.
 */
export interface PendingCountResponse {
  count: number;
}
