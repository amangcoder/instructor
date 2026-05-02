import {
  IsString,
  IsOptional,
  IsUUID,
  IsBoolean,
  IsInt,
  IsIn,
  Min,
  IsArray,
  ArrayMaxSize,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

/**
 * One surgical edit to a single step inside `planJson.steps`.
 * Only fields applicable to the step's runtime type are honoured by the
 * service layer — unrelated fields are silently ignored.
 */
export class AdminUpdatePlanStepDto {
  @IsString()
  id!: string;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  text?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  voiceId?: string | null;

  /** Microseconds. Optional. Used for `say` steps. */
  @IsOptional()
  @IsInt()
  @Min(0)
  estimatedDuration?: number | null;

  /** Microseconds. Used for `wait` steps. */
  @IsOptional()
  @IsInt()
  @Min(0)
  duration?: number;
}

/**
 * Request body for PATCH /api/admin/plans/:id.
 *
 * Field groups:
 *   • Hierarchy / publish: parentPlanId, position, visibility, isPublished
 *   • Plan record:         name
 *   • Plan JSON:           description, category, tags, defaultVoice
 *   • Steps:               stepEdits[] — surgical merges keyed by step id
 *
 * All fields are optional. Only the fields actually present in the body are
 * applied; this keeps it backwards-compatible with the prior hierarchy-only
 * payload.
 */
export class AdminUpdatePlanDto {
  // ── Hierarchy / publish ─────────────────────────────────────────────────
  @IsUUID()
  @IsOptional()
  parentPlanId?: string | null;

  @IsInt()
  @Min(0)
  @IsOptional()
  position?: number;

  @IsString()
  @IsIn(['private', 'pending_review', 'public'])
  @IsOptional()
  visibility?: string;

  @IsBoolean()
  @IsOptional()
  isPublished?: boolean;

  // ── Plan record column ──────────────────────────────────────────────────
  @IsOptional()
  @IsString()
  @MaxLength(200)
  name?: string;

  // ── Plan JSON fields ────────────────────────────────────────────────────
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  category?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  tags?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(100)
  defaultVoice?: string;

  // ── Per-step surgical edits ─────────────────────────────────────────────
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => AdminUpdatePlanStepDto)
  stepEdits?: AdminUpdatePlanStepDto[];

  // ── Full plan_json replace ──────────────────────────────────────────────
  /**
   * Stringified JSON that replaces the stored plan_json wholesale. When
   * present, the service ignores the surgical fields above (description,
   * category, tags, defaultVoice, stepEdits) and mirrors the parsed object's
   * `name` into the plans.name column. 512 KB cap matches SavePlanDto.
   */
  @IsOptional()
  @IsString()
  @MaxLength(524288)
  planJson?: string;
}
