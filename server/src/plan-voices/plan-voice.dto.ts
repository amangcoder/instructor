/**
 * DTOs for the plan-voices admin endpoints.
 *
 * Endpoints:
 *   POST /api/admin/plans/:id/voices/:voiceId/regenerate  → RegenerateResponseDto
 *   GET  /api/admin/plan-voices?status=failed             → ListFailedResponseDto
 */

import { IsIn, IsInt, IsOptional, IsString, Min, ValidateIf } from 'class-validator';
import { Transform } from 'class-transformer';
import type { PlanVoice } from '../database/schema';

// ---------------------------------------------------------------------------
// Query DTOs
// ---------------------------------------------------------------------------

/**
 * Query parameters for GET /api/admin/plan-voices.
 *
 * status=failed is the primary filter supported; any other value is accepted
 * but results in an empty list (the repository only indexes 'failed' rows).
 */
export class ListPlanVoicesQueryDto {
  @IsOptional()
  @IsIn(['failed'], { message: "status must be 'failed'" })
  status?: 'failed';

  @IsOptional()
  @Transform(({ value }) => (value !== undefined ? parseInt(String(value), 10) : undefined))
  @IsInt({ message: 'page must be an integer' })
  @Min(1, { message: 'page must be at least 1' })
  page?: number;

  @IsOptional()
  @Transform(({ value }) => (value !== undefined ? parseInt(String(value), 10) : undefined))
  @IsInt({ message: 'pageSize must be an integer' })
  @Min(1, { message: 'pageSize must be at least 1' })
  pageSize?: number;
}

// ---------------------------------------------------------------------------
// Response DTOs
// ---------------------------------------------------------------------------

/**
 * Response body for POST /api/admin/plans/:id/voices/:voiceId/regenerate (202).
 *
 * jobId is a correlation UUID generated at request time; it does not
 * correspond to a single tts_jobs row but identifies the regeneration batch.
 */
export interface RegenerateResponseDto {
  /** Correlation UUID for tracking this regeneration request. */
  jobId: string;
  planId: string;
  voiceId: string;
  /** Always 'pending' — the plan_voices row is reset before queuing. */
  status: 'pending';
}

/**
 * Request body for POST /api/admin/plans/:id/voices.
 *
 * Either `voiceId` (UUID) or `voiceSlug` (e.g. 'aoede') must be provided.
 * If both are passed, `voiceId` wins.
 */
export class GenerateVoiceBodyDto {
  @IsOptional()
  @IsString()
  voiceId?: string;

  @ValidateIf((o: GenerateVoiceBodyDto) => !o.voiceId)
  @IsString({ message: 'Either voiceId or voiceSlug must be provided' })
  voiceSlug?: string;
}

/**
 * Response body for POST /api/admin/plans/:id/voices (202).
 *
 * Returned when a new plan_voice rendition is created (or reset) and queued
 * for TTS synthesis. Mirrors RegenerateResponseDto with the resolved locale
 * appended so callers can refresh the voice grid without a roundtrip.
 */
export interface GenerateResponseDto {
  jobId: string;
  planId: string;
  voiceId: string;
  locale: string;
  status: 'pending';
}

/**
 * Response body for GET /api/admin/plan-voices?status=failed.
 */
export interface ListFailedResponseDto {
  items: PlanVoice[];
  total: number;
  page: number;
  pageSize: number;
}

// ---------------------------------------------------------------------------
// Per-step synth
// ---------------------------------------------------------------------------

/**
 * Request body for POST /api/admin/plans/:id/synth-step.
 *
 * Synthesizes a single say-step's audio against a chosen voice (or the plan's
 * `defaultVoice` when neither voiceId nor voiceSlug is provided) and primes the
 * shared TTS cache so the mobile client can fetch it without re-synthesis.
 */
export class SynthStepBodyDto {
  @IsString()
  stepId!: string;

  @IsOptional()
  @IsString()
  voiceId?: string;

  @IsOptional()
  @IsString()
  voiceSlug?: string;
}

/** Response body for POST /api/admin/plans/:id/synth-step (200). */
export interface SynthStepResponseDto {
  stepId: string;
  voiceSlug: string;
  locale: string;
  provider: string;
  textLength: number;
}

/** Response body for DELETE /api/admin/plans/:id/voices/:voiceId. */
export interface DeleteVoiceResponseDto {
  /** Number of plan_voices rows removed (0 = no rendition existed). */
  deleted: number;
}
