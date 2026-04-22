import { IsString, IsNotEmpty, IsOptional, MaxLength, IsIn, Matches } from 'class-validator';

export class BatchPregenDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  planId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(500_000)
  planJson!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  voiceId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  locale!: string;

  @IsOptional()
  @IsString()
  @IsIn(['gemini', 'kokoro', 'elevenlabs'], { message: 'provider must be "gemini", "kokoro", or "elevenlabs"' })
  provider?: string;

  @IsOptional()
  @IsString()
  @Matches(/^[0-3](\.\d{1,2})?$/, {
    message: 'speechRate must be a decimal string between 0 and 3.99 (e.g. "1.0")',
  })
  speechRate?: string;
}
