/**
 * DTOs for session completion sync endpoints.
 *
 * Request DTO: UploadCompletionsDto
 *   - POST /api/sync/completions
 *   - Body: { completions: [...] }
 *   - Each completion has: planId, completedAt, durationMs, clientId
 *   - clientId is the idempotency key (UUID from client)
 *
 * Response DTO: UploadCompletionsResponseDto
 *   - Returns: { syncedCount: number }
 *   - Indicates how many completions were successfully synced
 *
 * Query DTO: GetCompletionsQueryDto
 *   - GET /api/sync/completions?since=ISO8601
 *   - since is optional timestamp (ISO 8601 string)
 *
 * Response DTO: GetCompletionsResponseDto
 *   - Returns array of completions: { id, planId, completedAt, durationMs }
 */

import { IsUUID, IsISO8601, IsNumber, IsArray, IsOptional, ValidateNested, Type } from 'class-validator';

export class CompletionDto {
  /**
   * Plan ID (UUID) — associated plan for this completion.
   * Note: planId is not an FK — plan may be deleted but completion persists.
   */
  @IsUUID()
  planId: string;

  /**
   * Completion timestamp (ISO 8601 string, e.g., "2026-04-15T12:30:45.000Z").
   * Server converts to Date when storing.
   */
  @IsISO8601()
  completedAt: string;

  /**
   * Session duration in milliseconds.
   */
  @IsNumber()
  durationMs: number;

  /**
   * Client-generated UUID for idempotency (optional).
   * Server uses ON CONFLICT (client_id) DO NOTHING to prevent duplicates.
   * If omitted, the server generates a UUID (less idempotent but still accepted).
   */
  @IsOptional()
  @IsUUID()
  clientId?: string;
}

export class UploadCompletionsDto {
  /**
   * Array of session completions to sync.
   */
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CompletionDto)
  completions: CompletionDto[];
}

export class UploadCompletionsResponseDto {
  /**
   * Number of completions successfully synced.
   * May be less than the request size due to idempotency (duplicate clientIds).
   */
  syncedCount: number;
}

export class CompletionResponseDto {
  /**
   * Server-generated UUID for this completion record.
   */
  id: string;

  /**
   * Associated plan ID.
   */
  planId: string;

  /**
   * Completion timestamp (ISO 8601 string).
   */
  completedAt: string;

  /**
   * Session duration in milliseconds.
   */
  durationMs: number;
}

export class GetCompletionsResponseDto {
  /**
   * Array of session completions for the user (since the optional timestamp).
   */
  completions: CompletionResponseDto[];
}
