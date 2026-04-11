import { IsNotEmpty, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

/**
 * Request body for POST /api/plans/save.
 *
 * SECURITY NOTE: userId is intentionally NOT accepted from the request body.
 * The controller always derives userId from req.user.sub (JWT payload) to
 * prevent Insecure Direct Object Reference (IDOR) attacks.
 */
export class SavePlanDto {
  /**
   * When provided, the existing plan with this ID is updated (if it belongs
   * to the authenticated user). When omitted, a new plan is created.
   */
  @IsOptional()
  @IsUUID('4', { message: 'planId must be a valid UUID v4' })
  planId?: string;

  /** Human-readable plan name shown in plan lists. */
  @IsString()
  @IsNotEmpty({ message: 'name must not be empty' })
  @MaxLength(200, { message: 'name must be 200 characters or less' })
  name!: string;

  /**
   * Full plan JSON serialised as a string.
   * 524,288 bytes ≈ 512 KB — hard cap to prevent DoS via oversized payloads.
   */
  @IsString()
  @IsNotEmpty({ message: 'planJson must not be empty' })
  @MaxLength(524288, { message: 'planJson must be 512 KB or less' })
  planJson!: string;
}
