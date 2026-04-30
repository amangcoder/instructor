import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class GeneratePlanDto {
  @ApiProperty({
    description: 'Natural-language prompt describing the coaching plan to generate',
    example: 'Create a 4-week morning meditation plan for stress relief',
    maxLength: 1000,
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(1000, { message: 'Prompt must be 1000 characters or less' })
  prompt!: string;

  @ApiPropertyOptional({
    description: 'BCP-47 language tag for the plan content (defaults to en-US)',
    example: 'en-US',
    maxLength: 50,
  })
  @IsString()
  @IsOptional()
  @MaxLength(50)
  language?: string;
}
