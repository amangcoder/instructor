import { IsString, IsNotEmpty, IsOptional, MaxLength, IsIn, Matches } from 'class-validator';

export class SynthesizeDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(5000)
  text!: string;

  @IsString()
  @IsOptional()
  @MaxLength(200)
  @Matches(/^[A-Za-z0-9_-]{1,200}$/, {
    message: 'voice must contain only alphanumeric characters, hyphens, or underscores',
  })
  voice?: string;

  /**
   * Locale code for accent selection.
   * Gemini: 'enIN' | 'enGB' | 'enUS' | 'enAU' | 'enCA'
   * Kokoro: 'en-us' | 'en-gb'
   */
  @IsOptional()
  @IsString()
  @MaxLength(20)
  locale?: string;

  /**
   * TTS provider to route to.
   * Defaults to DEFAULT_TTS_PROVIDER env var (fallback: 'kokoro') when not specified.
   */
  @IsOptional()
  @IsString()
  @IsIn(['gemini', 'kokoro', 'elevenlabs'], { message: 'provider must be "gemini", "kokoro", or "elevenlabs"' })
  provider?: string;

  /**
   * Speech rate multiplier (e.g. '1.0' = normal, '1.5' = 50% faster).
   * Used in cache key computation — must match the Flutter client's format.
   * Defaults to '1.0' when not specified.
   */
  @IsOptional()
  @IsString()
  @Matches(/^[0-3](\.\d{1,2})?$/, {
    message: 'speechRate must be a decimal string between 0.25 and 3.99 (e.g. "1.0")',
  })
  speechRate?: string;
}
