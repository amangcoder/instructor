import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

/**
 * Request body for POST /api/series/:id/plans.
 * Creates an admin-curated plan attached to a series. Position is appended
 * to the end automatically; ownerUserId is null (admin-curated convention).
 */
export class CreateSeriesPlanDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  name!: string;

  @IsString()
  @IsOptional()
  @MaxLength(2000)
  description?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(524288)
  planJson!: string;

  @IsString()
  @IsOptional()
  @MaxLength(20)
  voiceQuality?: string;
}
