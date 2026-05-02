import { IsString, IsOptional, IsUUID, MaxLength, MinLength } from 'class-validator';

/**
 * Request body for POST /api/plans (user-authored plan creation).
 * Creates a plan with visibility='private' and owner_user_id from the JWT.
 */
export class CreatePlanDto {
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  title!: string;

  @IsString()
  @MaxLength(524288) // 512 KB
  steps!: string;

  @IsString()
  @IsOptional()
  @MaxLength(2000)
  description?: string;

  @IsUUID()
  @IsOptional()
  seriesId?: string;
}
