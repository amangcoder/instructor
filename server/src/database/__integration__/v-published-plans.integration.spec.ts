/**
 * Integration tests for the v_published_plans database view.
 *
 * Tests the THREE conditions that must ALL be true for a plan to appear
 * in the view (v_published_plans CONTRACT from migration 0014):
 *
 *   1. plans.is_published = true
 *   2. plans.visibility   = 'public'
 *   3. EXISTS at least one plan_voices row with status = 'ready'
 *
 * Acceptance Criteria verified:
 *   AC-003  v_published_plans returns zero rows for plans WITHOUT ready voices
 *   AC-004  v_published_plans returns EXACTLY ONE row per published+public+ready plan
 *   AC-005  v_published_plans excludes plans whose ALL voices are 'failed'
 *
 * Additional edge cases:
 *   • is_published = false  → excluded regardless of voice state
 *   • visibility = 'private' → excluded regardless of voice state
 *   • One ready + N failed voices → INCLUDED (the ready voice is sufficient)
 *   • Mix of published/unpublished plans → only eligible ones appear
 *
 * Requires: TEST_DATABASE_URL, DATABASE_URL_DIRECT, or DATABASE_URL env var.
 * Tests are skipped automatically when no database is configured.
 */

import { eq } from 'drizzle-orm';
import { v4 as uuidv4 } from 'uuid';
import { describeDb, createTestDrizzle, rawSql, generateTestId } from './helpers/test-db';
import { plans, users, voices, planVoices } from '../schema';
import type { NeonHttpDatabase } from 'drizzle-orm/neon-http';
import type * as schema from '../schema';

// ── Test fixtures ──────────────────────────────────────────────────────────

const SUITE_ID = generateTestId('vpub');

/** Fixed user UUID for this test suite */
const TEST_USER_ID = uuidv4();
const TEST_USER_EMAIL = `${SUITE_ID}@test.local`;

/** Fixed voice UUID for all plan_voices rows in this suite */
const TEST_VOICE_ID = uuidv4();
const TEST_VOICE_SLUG = `${SUITE_ID}-voice`;

/** Plan IDs created in this suite, keyed by scenario name */
const planIds: Record<string, string> = {};

// ── Suite ──────────────────────────────────────────────────────────────────

describeDb('v_published_plans view contract (AC-003 / AC-004 / AC-005)', () => {
  let db: NeonHttpDatabase<typeof schema>;

  // ── Setup ────────────────────────────────────────────────────────────────

  beforeAll(async () => {
    db = createTestDrizzle();

    // Create a test user (required by plans.user_id FK)
    await db.insert(users).values({
      id: TEST_USER_ID,
      email: TEST_USER_EMAIL,
      createdAt: new Date(),
    });

    // Create a test voice (required by plan_voices.voice_id FK)
    await db.insert(voices).values({
      id: TEST_VOICE_ID,
      slug: TEST_VOICE_SLUG,
      displayName: 'Integration Test Voice',
      locale: 'en-US',
      provider: 'test-provider',
      isPublished: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    // ── Scenario A: Published + public + no voices (AC-003) ───────────────
    const planA = await db
      .insert(plans)
      .values({
        userId: TEST_USER_ID,
        name: `${SUITE_ID}-plan-no-voices`,
        planJson: '{}',
        isPublished: true,
        visibility: 'public',
        createdAt: new Date(),
        updatedAt: new Date(),
      })
      .returning({ id: plans.id });
    planIds['noVoices'] = planA[0].id;

    // ── Scenario B: Published + public + one ready voice (AC-004) ─────────
    const planB = await db
      .insert(plans)
      .values({
        userId: TEST_USER_ID,
        name: `${SUITE_ID}-plan-ready`,
        planJson: '{}',
        isPublished: true,
        visibility: 'public',
        createdAt: new Date(),
        updatedAt: new Date(),
      })
      .returning({ id: plans.id });
    planIds['readyVoice'] = planB[0].id;

    await db.insert(planVoices).values({
      planId: planIds['readyVoice'],
      voiceId: TEST_VOICE_ID,
      locale: 'en-US',
      status: 'ready',
      audioUrl: 's3://bucket/test-audio.mp3',
      durationMs: 3000,
      generatedAt: new Date(),
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    // ── Scenario C: Published + public + ALL voices failed (AC-005) ───────
    const planC = await db
      .insert(plans)
      .values({
        userId: TEST_USER_ID,
        name: `${SUITE_ID}-plan-all-failed`,
        planJson: '{}',
        isPublished: true,
        visibility: 'public',
        createdAt: new Date(),
        updatedAt: new Date(),
      })
      .returning({ id: plans.id });
    planIds['allFailed'] = planC[0].id;

    const TEST_VOICE_ID_2 = uuidv4();
    await db.insert(voices).values({
      id: TEST_VOICE_ID_2,
      slug: `${TEST_VOICE_SLUG}-2`,
      displayName: 'Integration Test Voice 2',
      locale: 'en-IN',
      provider: 'test-provider',
      isPublished: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    await db.insert(planVoices).values([
      {
        planId: planIds['allFailed'],
        voiceId: TEST_VOICE_ID,
        locale: 'en-US',
        status: 'failed',
        errorMsg: 'Synthesis timeout',
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        planId: planIds['allFailed'],
        voiceId: TEST_VOICE_ID_2,
        locale: 'en-IN',
        status: 'failed',
        errorMsg: 'Provider error',
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ]);
    planIds['voice2Id'] = TEST_VOICE_ID_2;

    // ── Scenario D: is_published = false, visibility = public, ready voice ─
    const planD = await db
      .insert(plans)
      .values({
        userId: TEST_USER_ID,
        name: `${SUITE_ID}-plan-not-published`,
        planJson: '{}',
        isPublished: false, // ← NOT published
        visibility: 'public',
        createdAt: new Date(),
        updatedAt: new Date(),
      })
      .returning({ id: plans.id });
    planIds['notPublished'] = planD[0].id;

    await db.insert(planVoices).values({
      planId: planIds['notPublished'],
      voiceId: TEST_VOICE_ID,
      locale: 'en-US',
      status: 'ready',
      audioUrl: 's3://bucket/test-audio-d.mp3',
      durationMs: 1500,
      generatedAt: new Date(),
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    // ── Scenario E: is_published = true, visibility = private, ready voice ─
    const planE = await db
      .insert(plans)
      .values({
        userId: TEST_USER_ID,
        name: `${SUITE_ID}-plan-private`,
        planJson: '{}',
        isPublished: true,
        visibility: 'private', // ← private
        createdAt: new Date(),
        updatedAt: new Date(),
      })
      .returning({ id: plans.id });
    planIds['privateVisibility'] = planE[0].id;

    await db.insert(planVoices).values({
      planId: planIds['privateVisibility'],
      voiceId: TEST_VOICE_ID,
      locale: 'en-US',
      status: 'ready',
      audioUrl: 's3://bucket/test-audio-e.mp3',
      durationMs: 2000,
      generatedAt: new Date(),
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    // ── Scenario F: Mixed voices (one ready + one failed) → should appear ─
    const planF = await db
      .insert(plans)
      .values({
        userId: TEST_USER_ID,
        name: `${SUITE_ID}-plan-mixed-voices`,
        planJson: '{}',
        isPublished: true,
        visibility: 'public',
        createdAt: new Date(),
        updatedAt: new Date(),
      })
      .returning({ id: plans.id });
    planIds['mixedVoices'] = planF[0].id;

    await db.insert(planVoices).values([
      {
        planId: planIds['mixedVoices'],
        voiceId: TEST_VOICE_ID,
        locale: 'en-US',
        status: 'ready',
        audioUrl: 's3://bucket/test-audio-f.mp3',
        durationMs: 2500,
        generatedAt: new Date(),
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        planId: planIds['mixedVoices'],
        voiceId: planIds['voice2Id'],
        locale: 'en-IN',
        status: 'failed',
        errorMsg: 'Secondary voice failed',
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ]);

    // ── Scenario G: pending voice (not failed, not ready) → should NOT appear
    const planG = await db
      .insert(plans)
      .values({
        userId: TEST_USER_ID,
        name: `${SUITE_ID}-plan-pending-voice`,
        planJson: '{}',
        isPublished: true,
        visibility: 'public',
        createdAt: new Date(),
        updatedAt: new Date(),
      })
      .returning({ id: plans.id });
    planIds['pendingVoice'] = planG[0].id;

    await db.insert(planVoices).values({
      planId: planIds['pendingVoice'],
      voiceId: TEST_VOICE_ID,
      locale: 'en-US',
      status: 'pending',
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });

  // ── Teardown ─────────────────────────────────────────────────────────────

  afterAll(async () => {
    if (!db) return;

    // Delete in FK-safe order: plan_voices → plans → voices → users
    const allPlanIds = Object.values(planIds).filter(
      (id) => !['voice2Id'].includes(id),
    );
    for (const planId of allPlanIds) {
      await db.delete(planVoices).where(eq(planVoices.planId, planId));
    }
    for (const planId of allPlanIds) {
      await db.delete(plans).where(eq(plans.id, planId));
    }
    // Delete both test voices
    await db.delete(voices).where(eq(voices.id, TEST_VOICE_ID));
    if (planIds['voice2Id']) {
      await db.delete(voices).where(eq(voices.id, planIds['voice2Id']));
    }
    await db.delete(users).where(eq(users.id, TEST_USER_ID));
  });

  // ── AC-003: Plans without ready voices → zero rows ───────────────────────

  describe('AC-003: zero rows for plans without ready voices', () => {
    it('returns zero rows for a plan with NO plan_voices rows at all', async () => {
      const rows = await rawSql<{ id: string }>(
        `SELECT id FROM "v_published_plans" WHERE id = $1`,
        [planIds['noVoices']],
      );
      expect(rows).toHaveLength(0);
    });

    it('returns zero rows for a plan whose only voice is pending', async () => {
      const rows = await rawSql<{ id: string }>(
        `SELECT id FROM "v_published_plans" WHERE id = $1`,
        [planIds['pendingVoice']],
      );
      expect(rows).toHaveLength(0);
    });

    it('returns zero rows for a plan where visibility is pending_review and has ready voice', async () => {
      // Insert a pending_review plan with a ready voice — should still be excluded
      const tempPlan = await db
        .insert(plans)
        .values({
          userId: TEST_USER_ID,
          name: `${SUITE_ID}-plan-pending-review`,
          planJson: '{}',
          isPublished: true,
          visibility: 'pending_review',
          createdAt: new Date(),
          updatedAt: new Date(),
        })
        .returning({ id: plans.id });

      await db.insert(planVoices).values({
        planId: tempPlan[0].id,
        voiceId: TEST_VOICE_ID,
        locale: 'en-US',
        status: 'ready',
        audioUrl: 's3://bucket/temp.mp3',
        durationMs: 1000,
        generatedAt: new Date(),
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      try {
        const rows = await rawSql<{ id: string }>(
          `SELECT id FROM "v_published_plans" WHERE id = $1`,
          [tempPlan[0].id],
        );
        expect(rows).toHaveLength(0);
      } finally {
        await db.delete(planVoices).where(eq(planVoices.planId, tempPlan[0].id));
        await db.delete(plans).where(eq(plans.id, tempPlan[0].id));
      }
    });
  });

  // ── AC-004: Exactly one row per eligible plan ─────────────────────────────

  describe('AC-004: exactly one row per published + public + ready plan', () => {
    it('returns exactly 1 row for a plan with one ready voice', async () => {
      const rows = await rawSql<{ id: string }>(
        `SELECT id FROM "v_published_plans" WHERE id = $1`,
        [planIds['readyVoice']],
      );
      expect(rows).toHaveLength(1);
      expect(rows[0].id).toBe(planIds['readyVoice']);
    });

    it('view does NOT duplicate the row when a plan has multiple ready voices', async () => {
      // Add a second ready voice to the readyVoice plan
      const secondVoiceId = uuidv4();
      await db.insert(voices).values({
        id: secondVoiceId,
        slug: `${TEST_VOICE_SLUG}-extra`,
        displayName: 'Extra Test Voice',
        locale: 'en-GB',
        provider: 'test-provider',
        isPublished: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      await db.insert(planVoices).values({
        planId: planIds['readyVoice'],
        voiceId: secondVoiceId,
        locale: 'en-GB',
        status: 'ready',
        audioUrl: 's3://bucket/extra-audio.mp3',
        durationMs: 4000,
        generatedAt: new Date(),
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      try {
        // The view selects p.* — so it returns one row per plan (not per voice)
        const rows = await rawSql<{ id: string }>(
          `SELECT id FROM "v_published_plans" WHERE id = $1`,
          [planIds['readyVoice']],
        );
        expect(rows).toHaveLength(1);
      } finally {
        await db.delete(planVoices).where(eq(planVoices.voiceId, secondVoiceId));
        await db.delete(voices).where(eq(voices.id, secondVoiceId));
      }
    });

    it('returns the full plan row (all plan columns)', async () => {
      const rows = await rawSql<Record<string, unknown>>(
        `SELECT * FROM "v_published_plans" WHERE id = $1`,
        [planIds['readyVoice']],
      );
      expect(rows).toHaveLength(1);
      const row = rows[0];
      // Verify is_published and visibility are present and correct
      expect(row['is_published']).toBe(true);
      expect(row['visibility']).toBe('public');
      expect(row['id']).toBe(planIds['readyVoice']);
    });

    it('does NOT return a plan where is_published = false (even with ready voice)', async () => {
      const rows = await rawSql<{ id: string }>(
        `SELECT id FROM "v_published_plans" WHERE id = $1`,
        [planIds['notPublished']],
      );
      expect(rows).toHaveLength(0);
    });

    it('does NOT return a plan where visibility = private (even with ready voice)', async () => {
      const rows = await rawSql<{ id: string }>(
        `SELECT id FROM "v_published_plans" WHERE id = $1`,
        [planIds['privateVisibility']],
      );
      expect(rows).toHaveLength(0);
    });
  });

  // ── AC-005: All-failed voices → excluded ──────────────────────────────────

  describe('AC-005: excludes plans where ALL voices are failed', () => {
    it('returns zero rows for a plan with 2 plan_voices both status=failed', async () => {
      const rows = await rawSql<{ id: string }>(
        `SELECT id FROM "v_published_plans" WHERE id = $1`,
        [planIds['allFailed']],
      );
      expect(rows).toHaveLength(0);
    });

    it('confirms plan_voices rows exist (ensures exclusion is due to status, not absence)', async () => {
      const rows = await rawSql<{ id: string }>(
        `SELECT id FROM "plan_voices" WHERE plan_id = $1`,
        [planIds['allFailed']],
      );
      // Should have 2 failed voice rows
      expect(rows.length).toBeGreaterThanOrEqual(2);
    });
  });

  // ── Edge-case: one ready + one failed → INCLUDED ──────────────────────────

  describe('edge case: plan with one ready + one failed voice is INCLUDED', () => {
    it('returns exactly 1 row when at least one voice is ready (others may be failed)', async () => {
      const rows = await rawSql<{ id: string }>(
        `SELECT id FROM "v_published_plans" WHERE id = $1`,
        [planIds['mixedVoices']],
      );
      expect(rows).toHaveLength(1);
    });
  });

  // ── Broad view correctness ─────────────────────────────────────────────────

  describe('view returns exactly the right set of plans for this suite', () => {
    it('only readyVoice and mixedVoices plans appear from this test suite', async () => {
      const suiteIds = Object.values(planIds).filter(
        (id) => !['voice2Id'].includes(id),
      );

      const rows = await rawSql<{ id: string }>(
        `SELECT id FROM "v_published_plans" WHERE id = ANY($1::uuid[])`,
        [suiteIds],
      );

      const returnedIds = new Set(rows.map((r) => r.id));
      expect(returnedIds.has(planIds['readyVoice'])).toBe(true);
      expect(returnedIds.has(planIds['mixedVoices'])).toBe(true);

      // These must NOT appear
      expect(returnedIds.has(planIds['noVoices'])).toBe(false);
      expect(returnedIds.has(planIds['allFailed'])).toBe(false);
      expect(returnedIds.has(planIds['notPublished'])).toBe(false);
      expect(returnedIds.has(planIds['privateVisibility'])).toBe(false);
      expect(returnedIds.has(planIds['pendingVoice'])).toBe(false);
    });
  });
});

// Re-export so unused-import linting doesn't flag the NeonHttpDatabase type
export type { NeonHttpDatabase };
