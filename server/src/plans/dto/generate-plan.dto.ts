import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class GeneratePlanDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(1000, { message: 'Prompt must be 1000 characters or less' })
  prompt!: string;

  @IsString()
  @IsOptional()
  @MaxLength(50)
  language?: string;
}
