/**
 * SharedPlanResponseDto — response DTO for GET /api/plans/shared/:shareToken.
 *
 * SECURITY: Includes only non-sensitive fields.
 * Excludes:
 *   - userId (privacy)
 *   - planId (internal identifier)
 *   - createdAt, updatedAt (server metadata)
 *   - ttsStatus, ttsTotal, ttsCompleted (internal state)
 *   - voiceQuality, sourceLibraryPlanId (internal fields)
 *
 * Includes:
 *   - name: plan title
 *   - description: optional plan description
 *   - steps: full step array (used for preview)
 *   - stepCount: number of steps
 *   - estimatedDurationMs: total duration in milliseconds
 */

export class SharedPlanResponseDto {
  /** Plan name / title */
  name: string;

  /** Optional plan description */
  description?: string;

  /** Full step array for preview */
  steps: unknown[];

  /** Count of steps */
  stepCount: number;

  /** Total estimated duration in milliseconds */
  estimatedDurationMs: number;
}
