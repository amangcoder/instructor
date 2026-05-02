-- Migration: 0015_plans_plan_request_id
-- Adds plans.plan_request_id to make the promote-to-plan flow idempotent.
--
-- Problem: PlanRequestPromoteService.promote() performs sequential DB writes
-- (insert plan → insert plan_voices → mark request processed) with no wrapping
-- transaction (Neon HTTP driver does not support multi-statement transactions).
-- If the final step fails and the admin retries, the plan INSERT fires again,
-- creating a duplicate plan row from the same request.
--
-- Solution: Store the originating plan_request_id on the plans row. A UNIQUE
-- partial index (WHERE plan_request_id IS NOT NULL) lets Drizzle's
-- .onConflictDoNothing() turn the duplicate INSERT into a no-op. The service
-- then re-selects the existing planId and continues from the next step, making
-- the entire promote flow safely re-entrant.
--
-- Scope:
--   • Only promoted plans carry a plan_request_id (NOT NULL for admin-promoted,
--     NULL for all user-created plans). The partial index keeps overhead minimal.
--
-- Apply with:  npm run db:migrate   (from server/ directory)

--> statement-breakpoint

ALTER TABLE "plans"
    ADD COLUMN IF NOT EXISTS "plan_request_id" uuid;

--> statement-breakpoint

-- Partial unique index: enforces one plan per request while keeping the index
-- small (user-created plans have plan_request_id = NULL and are excluded).
CREATE UNIQUE INDEX IF NOT EXISTS "idx_plans_plan_request_id"
    ON "plans" ("plan_request_id")
    WHERE "plan_request_id" IS NOT NULL;
