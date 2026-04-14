import { IsIn, IsNotEmpty, IsOptional, IsString, Matches, MaxLength } from 'class-validator';

export class ActivatePlanDto {
  @IsString()
  @IsNotEmpty()
  planId!: string;

  @IsString()
  @IsIn(['standard', 'studio'])
  voiceQuality!: string;

  /** TTS voice ID for pre-generation (e.g. 'af_heart'). */
  @IsOptional()
  @IsString()
  @MaxLength(200)
  voice?: string;

  /** TTS locale for pre-generation (e.g. 'enIN', 'enGB'). */
  @IsOptional()
  @IsString()
  @MaxLength(20)
  locale?: string;

  /**
   * Speech rate for pre-generation (e.g. '1.0').
   * Must match the client's configured rate so cache keys align.
   */
  @IsOptional()
  @IsString()
  @Matches(/^[0-3](\.\d{1,2})?$/, {
    message: 'speechRate must be a decimal string between 0.25 and 3.99 (e.g. "1.0")',
  })
  speechRate?: string;
}
