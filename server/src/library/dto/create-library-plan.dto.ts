import { IsBoolean, IsInt, IsNotEmpty, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class CreateLibraryPlanDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  name!: string;

  @IsString()
  @IsOptional()
  @MaxLength(1000)
  description?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  category!: string;

  @IsString()
  @IsOptional()
  @MaxLength(500)
  tags?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  defaultVoice!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(524288) // 512 KB max plan JSON
  planJson!: string;

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
