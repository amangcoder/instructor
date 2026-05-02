import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
} from 'class-validator';

export class UpdateSeriesDto {
  @IsString()
  @IsOptional()
  @MaxLength(200)
  name?: string;

  @IsString()
  @IsOptional()
  @MaxLength(1000)
  description?: string;

  /**
   * Legacy free-text category label. Kept for backward compatibility during
   * the migration period while category_id is being backfilled (migration 0015).
   */
  @IsString()
  @IsOptional()
  @MaxLength(100)
  category?: string;

  /**
   * FK to categories.id. Optional during rollout — omit if category_id has not
   * yet been backfilled for this series. Takes priority over `category` once set.
   */
  @IsUUID('4')
  @IsOptional()
  categoryId?: string;

  @IsString()
  @IsOptional()
  @MaxLength(500)
  tags?: string;

  @IsString()
  @IsOptional()
  @MaxLength(100)
  defaultVoice?: string;

  @IsString()
  @IsOptional()
  @MaxLength(20)
  locale?: string;

  @IsBoolean()
  @IsOptional()
  isPublished?: boolean;

  @IsInt()
  @IsOptional()
  @Min(0)
  sortOrder?: number;
}
