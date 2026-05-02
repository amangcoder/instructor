/**
 * Request body for POST /api/admin/plan-requests/:id/promote
 *
 * Promotes a plan request into a real plan with N plan_voices rows
 * (one per voiceId), then enqueues TTS batch jobs post-commit.
 */

import {
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ArrayMinSize,
} from 'class-validator';

export class PromotePlanRequestDto {
  /** Voice UUIDs to create plan_voices rows for (at least one required). */
  @IsArray()
  @ArrayMinSize(1, { message: 'At least one voiceId is required' })
  @IsUUID('4', { each: true, message: 'Each voiceId must be a valid UUID' })
  voiceIds!: string[];

  /** Optional series to assign the plan to. */
  @IsOptional()
  @IsUUID('4')
  seriesId?: string;

  /** Optional category to assign the plan's series to. */
  @IsOptional()
  @IsUUID('4')
  categoryId?: string;

  /** Optional position for ordering within the parent or series. */
  @IsOptional()
  @IsInt()
  @Min(0)
  position?: number;
}
