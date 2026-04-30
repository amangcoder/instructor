import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsOptional, MaxLength, IsIn, Matches } from 'class-validator';

export class SynthesizeDto {
  @ApiProperty({
    description: 'Text to synthesise into speech (max 5000 characters)',
    example: 'Take a deep breath and relax your shoulders.',
    maxLength: 5000,
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(5000)
  text!: string;

  @ApiPropertyOptional({
    description:
      'Voice ID to use for synthesis. Must contain only alphanumeric characters, hyphens, or underscores.',
    example: 'af_aoede',
    maxLength: 200,
  })
  @IsString()
  @IsOptional()
  @MaxLength(200)
  @Matches(/^[A-Za-z0-9_-]{1,200}$/, {
    message: 'voice must contain only alphanumeric characters, hyphens, or underscores',
  })
  voice?: string;

  @ApiPropertyOptional({
    description:
      'Locale code for accent selection. ' +
      'Gemini: enIN | enGB | enUS | enAU | enCA. ' +
      'Kokoro: en-us | en-gb.',
    example: 'en-us',
    maxLength: 20,
  })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  locale?: string;

  @ApiPropertyOptional({
    description: 'TTS provider to route to. Defaults to DEFAULT_TTS_PROVIDER env var (fallback: kokoro).',
    example: 'kokoro',
    enum: ['gemini', 'kokoro', 'elevenlabs'],
  })
  @IsOptional()
  @IsString()
  @IsIn(['gemini', 'kokoro', 'elevenlabs'], { message: 'provider must be "gemini", "kokoro", or "elevenlabs"' })
  provider?: string;

  @ApiPropertyOptional({
    description:
      'Speech rate multiplier as a decimal string (e.g. "1.0" = normal, "1.5" = 50% faster). ' +
      'Used in cache key computation — must match the Flutter client format.',
    example: '1.0',
    pattern: '^[0-3](\\.[0-9]{1,2})?$',
  })
  @IsOptional()
  @IsString()
  @Matches(/^[0-3](\.\d{1,2})?$/, {
    message: 'speechRate must be a decimal string between 0.25 and 3.99 (e.g. "1.0")',
  })
  speechRate?: string;
}
