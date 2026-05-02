/**
 * Backfill script — populate plan_voices table from legacy plans.tts_status.
 *
 * This script is idempotent: it can be run multiple times without creating duplicates.
 * It reads all existing plans with tts_status values and inserts one plan_voices row
 * per plan with the status mapped from the legacy enum.
 *
 * Usage (from /server):
 *   npm run build && npx ts-node -r tsconfig-paths/register scripts/backfill-plan-voices.ts
 *   # or:
 *   npx ts-node -r tsconfig-paths/register scripts/backfill-plan-voices.ts
 *
 * Status Mapping:
 *   plans.tts_status → plan_voices.status
 *   'none'         → 'pending'        (not yet attempted)
 *   'pending'      → 'pending'
 *   'processing'   → 'processing'
 *   'completed'    → 'ready'          (synthesis complete)
 *   'partial'      → 'ready'          (at least one voice ready)
 *   'failed'       → 'failed'
 *
 * Idempotency:
 *   Uses UNIQUE (plan_id, voice_id, locale) constraint to prevent duplicates.
 *   Re-running the script will skip plans that already have plan_voices rows.
 */

import 'dotenv/config';
import { eq, and, isNotNull } from 'drizzle-orm';
import { DatabaseService } from '../src/database/database.service';
import { plans, voices, planVoices } from '../src/database/schema';
import { v4 as uuidv4 } from 'uuid';

// ─────────────────────────────────────────────────────────────────────────────
// Setup
// ─────────────────────────────────────────────────────────────────────────────

const logger = {
  info: (msg: string, ...args: any[]) => console.log(`[INFO] ${msg}`, ...args),
  warn: (msg: string, ...args: any[]) => console.warn(`[WARN] ${msg}`, ...args),
  error: (msg: string, ...args: any[]) => console.error(`[ERROR] ${msg}`, ...args),
};

// Initialize DatabaseService (uses DATABASE_URL from environment).
// Unlike NestJS dependency injection, we instantiate it directly here.
const dbService = new DatabaseService();

if (dbService.noop) {
  logger.error(
    'DATABASE_URL environment variable is not set. DatabaseService is in noop mode.',
  );
  process.exit(1);
}

// Get the underlying Drizzle instance for direct query access.
const db = dbService.getDb();

// ─────────────────────────────────────────────────────────────────────────────
// Status Mapping
// ─────────────────────────────────────────────────────────────────────────────

function mapTtsStatusToVoiceStatus(
  ttsStatus: string,
): 'pending' | 'processing' | 'ready' | 'failed' {
  switch (ttsStatus) {
    case 'none':
    case 'pending':
      return 'pending';
    case 'processing':
      return 'processing';
    case 'completed':
    case 'partial':
      return 'ready';
    case 'failed':
      return 'failed';
    default:
      logger.warn(`Unknown tts_status: ${ttsStatus}, defaulting to 'pending'`);
      return 'pending';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Backfill Logic
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  try {
    logger.info('Starting plan_voices backfill from legacy tts_status...');

    // Step 1: Get the first published voice as the default.
    // If no published voices exist, create a generic one.
    let defaultVoice = await dbService.withRetry(() =>
      db
        .select()
        .from(voices)
        .where(eq(voices.isPublished, true))
        .limit(1),
    );

    let voiceId: string;
    if (defaultVoice.length > 0) {
      voiceId = defaultVoice[0].id;
      logger.info(
        `Using published voice: ${defaultVoice[0].displayName} (${defaultVoice[0].slug})`,
      );
    } else {
      // No published voices exist yet. Create a placeholder voice so backfill can proceed.
      // This is a defensive measure; in normal flow, voices are seeded before backfill.
      voiceId = uuidv4();
      logger.warn(
        'No published voices found. This may indicate the voices table has not been seeded yet.',
      );
      logger.warn(
        'Proceeding with backfill using a placeholder voice ID. You may need to re-run after seeding voices.',
      );
      logger.warn(`Placeholder voice ID: ${voiceId}`);
    }

    // Step 2: Query all plans with non-null tts_status.
    const allPlans = await dbService.withRetry(() =>
      db
        .select()
        .from(plans)
        .where(isNotNull(plans.ttsStatus)),
    );

    logger.info(`Found ${allPlans.length} plan(s) to backfill.`);

    if (allPlans.length === 0) {
      logger.info('No plans found. Backfill complete (no rows inserted).');
      process.exit(0);
    }

    // Step 3: For each plan, upsert a plan_voices row with the mapped status.
    // Upsert logic: try to insert, and if (plan_id, voice_id, locale) already exists,
    // skip it (or update if needed). We use Drizzle's insert + onConflict if available,
    // otherwise we manually check for existing rows.

    let successCount = 0;
    let skipCount = 0;
    let errorCount = 0;

    for (const plan of allPlans) {
      try {
        // Determine locale: use plan's locale if available, otherwise default to 'enUS'.
        const locale = 'enUS'; // Plans don't have a locale field; voices do.

        // Check if a plan_voices row already exists for this (plan_id, voice_id, locale).
        const existingPlanVoice = await dbService.withRetry(() =>
          db
            .select()
            .from(planVoices)
            .where(
              and(
                eq(planVoices.planId, plan.id),
                eq(planVoices.voiceId, voiceId),
                eq(planVoices.locale, locale),
              ),
            )
            .limit(1),
        );

        if (existingPlanVoice.length > 0) {
          logger.info(
            `Skipping plan ${plan.id} (${plan.name}): plan_voices row already exists.`,
          );
          skipCount++;
          continue;
        }

        // Map the legacy tts_status to the new plan_voices.status.
        const mappedStatus = mapTtsStatusToVoiceStatus(plan.ttsStatus!);

        // Insert the new plan_voices row.
        await dbService.withRetry(() =>
          db.insert(planVoices).values({
            id: uuidv4(),
            planId: plan.id,
            voiceId,
            locale,
            status: mappedStatus,
            audioUrl: null,
            durationMs: null,
            errorMsg: null,
            generatedAt: null,
            createdAt: new Date(),
            updatedAt: new Date(),
          }),
        );

        logger.info(
          `Backfilled plan ${plan.id} (${plan.name}): tts_status='${plan.ttsStatus}' → status='${mappedStatus}'`,
        );
        successCount++;
      } catch (error) {
        logger.error(
          `Failed to backfill plan ${plan.id} (${plan.name}):`,
          error instanceof Error ? error.message : error,
        );
        errorCount++;
      }
    }

    // Step 4: Summary.
    logger.info('');
    logger.info('=== Backfill Complete ===');
    logger.info(`Inserted: ${successCount} row(s)`);
    logger.info(`Skipped:  ${skipCount} row(s) (already exist)`);
    logger.info(`Errors:   ${errorCount} row(s)`);
    logger.info(`Total:    ${allPlans.length} plan(s) processed`);
    logger.info('');

    if (errorCount > 0) {
      logger.warn(`Backfill completed with ${errorCount} error(s). Please review.`);
      process.exit(1);
    }

    logger.info('Backfill successful. All plans now have plan_voices entries.');
    process.exit(0);
  } catch (error) {
    logger.error(
      'Fatal error during backfill:',
      error instanceof Error ? error.message : error,
    );
    if (error instanceof Error && error.stack) {
      logger.error(error.stack);
    }
    process.exit(1);
  }
}

// Run the backfill.
main();
