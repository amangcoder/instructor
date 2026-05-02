import {
  IsEmail,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

/**
 * PlanRequestDto — validated body for POST /api/plan-requests.
 *
 * Submitted from the in-app "Request a Plan" screen when a user wants a
 * plan/schedule that isn't currently in the Discover library.
 *
 * Fields:
 *   email       — requester's email (auth'd users default to JWT email; the
 *                 dto still carries it so unauthenticated callers can submit)
 *   title       — short headline of the requested plan/schedule
 *   description — long-form description (max 2 000 chars)
 *   category    — optional plan category hint (matches PlanCategory.name)
 */
export class PlanRequestDto {
  @IsEmail({}, { message: 'email must be a valid email address' })
  @IsNotEmpty()
  email!: string;

  @IsString()
  @IsNotEmpty({ message: 'title is required' })
  @MinLength(3, { message: 'title must be at least 3 characters' })
  @MaxLength(200, { message: 'title must not exceed 200 characters' })
  title!: string;

  @IsString()
  @IsNotEmpty({ message: 'description is required' })
  @MinLength(10, { message: 'description must be at least 10 characters' })
  @MaxLength(2000, { message: 'description must not exceed 2 000 characters' })
  description!: string;

  @IsOptional()
  @IsString()
  @IsIn(
    [
      'yoga',
      'meditation',
      'workout',
      'cooking',
      'routine',
      'focus',
      'custom',
    ],
    { message: 'category must be one of the supported plan categories' },
  )
  category?: string;
}
