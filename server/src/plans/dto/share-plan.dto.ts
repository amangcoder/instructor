/**
 * DTOs for plan sharing endpoints.
 *
 * SharePlanDto: not needed (POST /plans/:id/share has no body).
 * SharedPlanResponseDto: defines the public response shape for shared plans.
 *
 * SECURITY: SharedPlanResponseDto intentionally excludes userId, database IDs,
 * share token, and all internal metadata to prevent PII leakage.
 */

// No request body needed for POST /plans/:id/share — planId comes from URL param.
// This file exists for the response DTO and future extensibility.
