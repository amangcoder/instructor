import { IsBoolean, IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class UpdateLibraryPlanDto {
  @IsString()
  @IsOptional()
  @MaxLength(200)
  name?: string;

  @IsString()
  @IsOptional()
  @MaxLength(1000)
  description?: string;

  @IsString()
  @IsOptional()
  @MaxLength(100)
  category?: string;

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
  @MaxLength(524288)
  planJson?: string;

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
