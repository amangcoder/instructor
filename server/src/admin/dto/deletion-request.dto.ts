import {
  ArrayMinSize,
  IsArray,
  IsEmail,
  IsIn,
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

/**
 * DeletionRequestDto — validated body for POST /api/admin/deletion-requests.
 *
 * Fields:
 *   email       — the requester's email address (validated format)
 *   scope       — which data to delete; one or more of:
 *                 'full_account' | 'audio_cache' | 'plans'
 *   reason      — optional free-text reason (max 1 000 chars)
 *   requestedAt — ISO-8601 timestamp from the client (for audit trail)
 */
export class DeletionRequestDto {
  @IsEmail({}, { message: 'email must be a valid email address' })
  @IsNotEmpty()
  email!: string;

  @IsArray({ message: 'scope must be an array of scope strings' })
  @ArrayMinSize(1, { message: 'scope must contain at least one value' })
  @IsString({ each: true, message: 'each scope value must be a string' })
  @IsIn(['full_account', 'audio_cache', 'plans'], {
    each: true,
    message: "each scope value must be one of: 'full_account', 'audio_cache', 'plans'",
  })
  scope!: string[];

  @IsOptional()
  @IsString()
  @MaxLength(1000, { message: 'reason must not exceed 1 000 characters' })
  reason?: string;

  @IsISO8601({}, { message: 'requestedAt must be a valid ISO-8601 timestamp' })
  @IsNotEmpty()
  requestedAt!: string;
}
