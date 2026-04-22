/**
 * DTO for PATCH /api/admin/app-version
 *
 * All fields are optional — only provided fields are updated.
 * Version strings must follow semver pattern (e.g., "1.0.0", "2.3.1").
 */

import { IsBoolean, IsOptional, IsString, Matches, MaxLength } from 'class-validator';

const SEMVER_PATTERN = /^[0-9]+(\.[0-9]+){0,2}$/;

export class UpdateVersionConfigDto {
  @IsOptional()
  @IsString()
  @MaxLength(20)
  @Matches(SEMVER_PATTERN, {
    message: 'iosMinVersion must be a valid version string (e.g., "1.0.0")',
  })
  iosMinVersion?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  @Matches(SEMVER_PATTERN, {
    message: 'androidMinVersion must be a valid version string (e.g., "1.0.0")',
  })
  androidMinVersion?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  @Matches(SEMVER_PATTERN, {
    message: 'iosForceVersion must be a valid version string (e.g., "1.0.0")',
  })
  iosForceVersion?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  @Matches(SEMVER_PATTERN, {
    message: 'androidForceVersion must be a valid version string (e.g., "1.0.0")',
  })
  androidForceVersion?: string;

  @IsOptional()
  @IsBoolean()
  forceUpdateEnabled?: boolean;
}
