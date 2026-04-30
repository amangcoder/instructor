-- Migration: 0011_migrate_speech_rate_numeric
-- Converts tts_jobs.speech_rate from TEXT to NUMERIC(4,2) for correct numeric semantics.
--
-- Problem with TEXT: Lexicographic ordering causes incorrect comparisons.
--   '0.9' > '1.0' (false — but this would be true in text comparison!)
--   '0.9' > '1.25' (false in text, when numerically true)
--
-- Solution: Use NUMERIC(4,2) for exact decimal representation and correct ordering.
-- The cast '1.0'::NUMERIC(4,2) → 1.00 preserves existing data.
--
-- Cache key generation must use consistent formatting: (1.0).toFixed(2) → '1.00'
-- to match existing tts-cache/ directory structure during rollout.

--> statement-breakpoint

ALTER TABLE "tts_jobs"
  ALTER COLUMN "speech_rate" TYPE NUMERIC(4, 2)
  USING "speech_rate"::NUMERIC(4, 2);

--> statement-breakpoint

-- Ensure the default is numeric, not text
ALTER TABLE "tts_jobs"
  ALTER COLUMN "speech_rate" SET DEFAULT 1.0;

--> statement-breakpoint
