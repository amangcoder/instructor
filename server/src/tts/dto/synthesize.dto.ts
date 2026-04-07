import { IsString, IsNotEmpty, IsOptional, MaxLength, IsIn, Matches } from 'class-validator';

export class SynthesizeDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(5000)
  text!: string;

  @IsString()
  @IsOptional()
  voice?: string;

  /**
   * Locale code for accent selection.
   * Gemini: 'enIN' | 'enGB' | 'enUS' | 'enAU' | 'enCA'
   * Kokoro: 'en-us' | 'en-gb'
   */
  @IsOptional()
  @IsString()
  locale?: string;

  /**
   * TTS provider to route to.
   * Defaults to 'gemini' when not specified.
   */
  @IsOptional()
  @IsString()
  @IsIn(['gemini', 'kokoro'], { message: 'provider must be "gemini" or "kokoro"' })
  provider?: string;

  /**
   * Speech rate multiplier (e.g. '1.0' = normal, '1.5' = 50% faster).
   * Used in cache key computation — must match the Flutter client's format.
   * Defaults to '1.0' when not specified.
   */
  @IsOptional()
  @IsString()
  @Matches(/^\d+(\.\d+)?$/, { message: 'speechRate must be a positive decimal string' })
  speechRate?: string;
}
