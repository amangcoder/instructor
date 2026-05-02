/**
 * Integration tests for CategoryRepository.reorder().
 *
 * Tests that the reorder() method correctly and atomically (within one
 * withRetry batch) updates the sort_order of multiple categories.
 *
 * Acceptance Criteria verified:
 *   • CategoryRepository.reorder() atomically updates multiple sort_orders
 *   • All items in the batch are updated — no partial writes
 *   • Empty array no-op doesn't throw
 *   • Non-existent IDs in the batch are silently ignored
 *
 * Implementation note on "atomicity":
 *   The current implementation uses Promise.all with individual UPDATE
 *   statements (not a single SQL transaction), so atomicity here means
 *   "all updates are dispatched in the same withRetry call" rather than
 *   strict SQL transaction atomicity.  Tests verify that ALL categories
 *   get updated, not just a subset.
 *
 * Requires: TEST_DATABASE_URL, DATABASE_URL_DIRECT, or DATABASE_URL env var.
 * Tests are skipped automatically when no database is configured.
 */

import { eq } from 'drizzle-orm';
import { v4 as uuidv4 } from 'uuid';
import { describeDb, createTestDrizzle, generateTestId } from './helpers/test-db';
import { categories } from '../schema';
import { DatabaseService } from '../database.service';
import { CategoryRepository } from '../repositories/category.repository';
import type { NeonHttpDatabase } from 'drizzle-orm/neon-http';
import type * as schema from '../schema';

// ── Suite ID ───────────────────────────────────────────────────────────────

const SUITE_ID = generateTestId('cat');

// ── Helpers ────────────────────────────────────────────────────────────────

/** Creates a category row and returns its UUID */
async function insertCategory(
  db: NeonHttpDatabase<typeof schema>,
  label: string,
  sortOrder: number,
): Promise<string> {
  const slug = `${SUITE_ID}-${label}`.toLowerCase().replace(/[^a-z0-9-]/g, '-');
  const rows = await db
    .insert(categories)
    .values({
      slug,
      name: `Test Category ${label}`,
      sortOrder,
      isPublished: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    })
    .returning({ id: categories.id });
  return rows[0].id;
}

// ── Suite ──────────────────────────────────────────────────────────────────

describeDb('CategoryRepository.reorder() — integration', () => {
  let db: NeonHttpDatabase<typeof schema>;
  let categoryRepo: CategoryRepository;

  /** IDs of all categories created in this suite (for cleanup) */
  const createdIds: string[] = [];

  // ── Setup ────────────────────────────────────────────────────────────────

  beforeAll(async () => {
    db = createTestDrizzle();

    // Wire up real DatabaseService + CategoryRepository
    // DatabaseService reads DATABASE_URL from env (already set by the test runner)
    const dbUrl =
      process.env.TEST_DATABASE_URL ||
      process.env.DATABASE_URL_DIRECT ||
      process.env.DATABASE_URL;

    // Temporarily pin the URL so DatabaseService picks it up from env
    const originalUrl = process.env.DATABASE_URL;
    process.env.DATABASE_URL = dbUrl;
    const dbService = new DatabaseService();
    process.env.DATABASE_URL = originalUrl;

    categoryRepo = new CategoryRepository(dbService);
  });

  // ── Teardown ─────────────────────────────────────────────────────────────

  afterAll(async () => {
    if (!db) return;
    for (const id of createdIds) {
      await db.delete(categories).where(eq(categories.id, id));
    }
  });

  // ── Atomicity: all updates applied ────────────────────────────────────────

  describe('reorder() updates ALL categories in the batch', () => {
    it('updates 3 categories to completely reversed sort_orders', async () => {
      // Create 3 categories with sortOrder 10, 20, 30
      const idA = await insertCategory(db, 'alpha', 10);
      const idB = await insertCategory(db, 'beta', 20);
      const idC = await insertCategory(db, 'gamma', 30);
      createdIds.push(idA, idB, idC);

      // Reverse the order: alpha→30, beta→20 (no change), gamma→10
      await categoryRepo.reorder([
        { id: idA, sortOrder: 30 },
        { id: idB, sortOrder: 20 },
        { id: idC, sortOrder: 10 },
      ]);

      // Verify ALL three were updated
      const [rowA] = await db
        .select({ id: categories.id, sortOrder: categories.sortOrder })
        .from(categories)
        .where(eq(categories.id, idA));
      const [rowB] = await db
        .select({ id: categories.id, sortOrder: categories.sortOrder })
        .from(categories)
        .where(eq(categories.id, idB));
      const [rowC] = await db
        .select({ id: categories.id, sortOrder: categories.sortOrder })
        .from(categories)
        .where(eq(categories.id, idC));

      expect(rowA.sortOrder).toBe(30);  // was 10 → now 30
      expect(rowB.sortOrder).toBe(20);  // was 20 → still 20
      expect(rowC.sortOrder).toBe(10);  // was 30 → now 10
    });

    it('updates a single category in the batch (edge case: batch of one)', async () => {
      const idSingle = await insertCategory(db, 'single', 50);
      createdIds.push(idSingle);

      await categoryRepo.reorder([{ id: idSingle, sortOrder: 99 }]);

      const [row] = await db
        .select({ sortOrder: categories.sortOrder })
        .from(categories)
        .where(eq(categories.id, idSingle));

      expect(row.sortOrder).toBe(99);
    });

    it('updates 5 categories in a single reorder call', async () => {
      const ids: string[] = [];
      for (let i = 0; i < 5; i++) {
        const id = await insertCategory(db, `five-${i}`, i + 1);
        ids.push(id);
        createdIds.push(id);
      }

      // Shuffle: reverse all 5
      await categoryRepo.reorder(
        ids.map((id, idx) => ({ id, sortOrder: 5 - idx })),
      );

      // Verify all 5 are updated
      for (let i = 0; i < 5; i++) {
        const [row] = await db
          .select({ sortOrder: categories.sortOrder })
          .from(categories)
          .where(eq(categories.id, ids[i]));
        expect(row.sortOrder).toBe(5 - i);
      }
    });
  });

  // ── Empty batch: no-op ────────────────────────────────────────────────────

  describe('reorder() with empty array', () => {
    it('does not throw when given an empty items array', async () => {
      await expect(categoryRepo.reorder([])).resolves.toBeUndefined();
    });

    it('does not modify any categories when given an empty array', async () => {
      const idStable = await insertCategory(db, 'stable', 77);
      createdIds.push(idStable);

      await categoryRepo.reorder([]);

      const [row] = await db
        .select({ sortOrder: categories.sortOrder })
        .from(categories)
        .where(eq(categories.id, idStable));

      expect(row.sortOrder).toBe(77); // unchanged
    });
  });

  // ── updatedAt is refreshed ────────────────────────────────────────────────

  describe('reorder() refreshes updatedAt timestamps', () => {
    it('sets updatedAt to a value >= the timestamp just before the call', async () => {
      const idTs = await insertCategory(db, 'timestamp-check', 100);
      createdIds.push(idTs);

      const beforeCall = new Date();

      // Small delay so updatedAt is strictly after beforeCall
      await new Promise((r) => setTimeout(r, 10));
      await categoryRepo.reorder([{ id: idTs, sortOrder: 200 }]);

      const [row] = await db
        .select({ updatedAt: categories.updatedAt })
        .from(categories)
        .where(eq(categories.id, idTs));

      expect(row.updatedAt.getTime()).toBeGreaterThanOrEqual(beforeCall.getTime());
    });
  });

  // ── Unknown IDs are silently ignored ─────────────────────────────────────

  describe('reorder() with non-existent IDs', () => {
    it('does not throw when given a non-existent UUID', async () => {
      const fakeId = uuidv4();
      await expect(
        categoryRepo.reorder([{ id: fakeId, sortOrder: 1 }]),
      ).resolves.toBeUndefined();
    });

    it('still updates valid IDs when batch contains a mix of valid and invalid UUIDs', async () => {
      const idValid = await insertCategory(db, 'valid-in-mixed', 55);
      createdIds.push(idValid);
      const fakeId = uuidv4();

      await categoryRepo.reorder([
        { id: idValid, sortOrder: 88 },
        { id: fakeId, sortOrder: 99 }, // non-existent — should be silently ignored
      ]);

      const [row] = await db
        .select({ sortOrder: categories.sortOrder })
        .from(categories)
        .where(eq(categories.id, idValid));

      expect(row.sortOrder).toBe(88); // valid ID was updated
    });
  });

  // ── Sort order data integrity ─────────────────────────────────────────────

  describe('reorder() allows duplicate sort_orders (no uniqueness constraint)', () => {
    it('can assign the same sort_order to multiple categories', async () => {
      const idDup1 = await insertCategory(db, 'dup1', 1);
      const idDup2 = await insertCategory(db, 'dup2', 2);
      createdIds.push(idDup1, idDup2);

      // Assign identical sort order (0) to both
      await expect(
        categoryRepo.reorder([
          { id: idDup1, sortOrder: 0 },
          { id: idDup2, sortOrder: 0 },
        ]),
      ).resolves.toBeUndefined();

      const [row1] = await db
        .select({ sortOrder: categories.sortOrder })
        .from(categories)
        .where(eq(categories.id, idDup1));
      const [row2] = await db
        .select({ sortOrder: categories.sortOrder })
        .from(categories)
        .where(eq(categories.id, idDup2));

      expect(row1.sortOrder).toBe(0);
      expect(row2.sortOrder).toBe(0);
    });
  });

  // ── listPublished reflects reorder changes ─────────────────────────────────

  describe('listPublished() ordering reflects reorder() changes', () => {
    it('listPublished() returns categories in the new sort_order after reorder()', async () => {
      // Create two published categories with initial order
      const idFirst = await insertCategory(db, 'order-first', 1000);
      const idSecond = await insertCategory(db, 'order-second', 1001);
      createdIds.push(idFirst, idSecond);

      // Swap their sort orders
      await categoryRepo.reorder([
        { id: idFirst, sortOrder: 1001 },
        { id: idSecond, sortOrder: 1000 },
      ]);

      // listPublished() orders by sortOrder ASC
      const allPublished = await categoryRepo.listPublished();
      const ourCategories = allPublished.filter(
        (c) => c.id === idFirst || c.id === idSecond,
      );

      // After swap: idSecond (1000) should come before idFirst (1001)
      expect(ourCategories[0].id).toBe(idSecond);
      expect(ourCategories[1].id).toBe(idFirst);
    });
  });
});
