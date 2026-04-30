-- Migration: 0009_add_check_constraints
-- Adds PostgreSQL CHECK constraints to enforce valid status/enum values at the database layer.
-- This protects against invalid data being written via direct SQL, migrations, or seed scripts.
--
-- Strategy: Use NOT VALID for constraint addition, then VALIDATE CONSTRAINT separately.
-- This allows the migration to complete quickly without locking tables, and background
-- validation happens asynchronously. Existing rows are guaranteed to be valid (enforced
-- by application layer), so VALIDATE will succeed.

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- plans.tts_status CHECK constraint
-- Valid values: none | pending | processing | completed | partial | failed
-- ---------------------------------------------------------------------------

ALTER TABLE "plans"
  ADD CONSTRAINT "plans_tts_status_check"
  CHECK ("tts_status" IN ('none', 'pending', 'processing', 'completed', 'partial', 'failed'))
  NOT VALID;

--> statement-breakpoint

-- Validate the constraint asynchronously (allows migration to complete quickly)
ALTER TABLE "plans"
  VALIDATE CONSTRAINT "plans_tts_status_check";

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- tts_jobs.status CHECK constraint
-- Valid values: pending | processing | completed | failed
-- ---------------------------------------------------------------------------

ALTER TABLE "tts_jobs"
  ADD CONSTRAINT "tts_jobs_status_check"
  CHECK ("status" IN ('pending', 'processing', 'completed', 'failed'))
  NOT VALID;

--> statement-breakpoint

ALTER TABLE "tts_jobs"
  VALIDATE CONSTRAINT "tts_jobs_status_check";

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- deletion_requests.status CHECK constraint
-- Valid values: pending | processed
-- ---------------------------------------------------------------------------

ALTER TABLE "deletion_requests"
  ADD CONSTRAINT "deletion_requests_status_check"
  CHECK ("status" IN ('pending', 'processed'))
  NOT VALID;

--> statement-breakpoint

ALTER TABLE "deletion_requests"
  VALIDATE CONSTRAINT "deletion_requests_status_check";

--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- plan_triggers.recurrence CHECK constraint
-- Valid values: none | daily | weekdays | weekly
-- ---------------------------------------------------------------------------

ALTER TABLE "plan_triggers"
  ADD CONSTRAINT "plan_triggers_recurrence_check"
  CHECK ("recurrence" IN ('none', 'daily', 'weekdays', 'weekly'))
  NOT VALID;

--> statement-breakpoint

ALTER TABLE "plan_triggers"
  VALIDATE CONSTRAINT "plan_triggers_recurrence_check";

--> statement-breakpoint
