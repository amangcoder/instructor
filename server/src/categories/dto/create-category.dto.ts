import {
  IsBoolean,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateCategoryDto {
  /**
   * URL-safe slug, e.g. "morning-meditation".
   * Must be unique across all categories.
   */
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  @Matches(/^[a-z0-9-]+$/, {
    message: 'slug must contain only lowercase letters, numbers, and hyphens',
  })
  slug!: string;

  /** Display name shown to users, e.g. "Morning Meditation". */
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  name!: string;

  /** Optional emoji or icon identifier, e.g. "🌅" or "sun". */
  @IsString()
  @IsOptional()
  @MaxLength(50)
  icon?: string;

  /** Optional colour hex or name, e.g. "#FF6B35". */
  @IsString()
  @IsOptional()
  @MaxLength(20)
  color?: string;

  /** Zero-based position in the ordered list. Defaults to 0. */
  @IsInt()
  @IsOptional()
  @Min(0)
  sortOrder?: number;

  /** Whether this category is visible to users. Defaults to false (draft). */
  @IsBoolean()
  @IsOptional()
  isPublished?: boolean;
}
