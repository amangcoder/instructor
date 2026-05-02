# Backfill Plan Voices Script

## Overview

The `backfill-plan-voices.ts` script populates the new `plan_voices` table from legacy `plans.tts_status` values. It is designed to run **after** migration 0014 has created the `plan_voices` table and the Drizzle schema has been extended.

This script is **idempotent**: it can be safely run multiple times without creating duplicate rows.

## Status Mapping

The script maps the legacy `plans.tts_status` enum values to the new `plan_voices.status` values:

| `plans.tts_status` | `plan_voices.status` | Meaning |
|---|---|---|
| `'none'` | `'pending'` | TTS not yet attempted |
| `'pending'` | `'pending'` | TTS job queued, not started |
| `'processing'` | `'processing'` | TTS worker actively synthesizing |
| `'completed'` | `'ready'` | Synthesis complete |
| `'partial'` | `'ready'` | At least one voice rendition is ready |
| `'failed'` | `'failed'` | Synthesis failed |

## Usage

### Prerequisites

1. **Migration 0014** must have been applied:
   ```bash
   pnpm drizzle:migrate
   ```

2. **Schema extension** (TASK-003) must have been completed to add Drizzle table definitions

3. **Voices table** must be seeded with at least one published voice:
   ```bash
   npx ts-node -r tsconfig-paths/register scripts/seed-voices.ts
   ```

### Running the Script

From the `/server` directory:

```bash
# Development (with ts-node):
npx ts-node -r tsconfig-paths/register scripts/backfill-plan-voices.ts

# After building:
npm run build
npx ts-node -r tsconfig-paths/register scripts/backfill-plan-voices.ts
```

**Note**: Make sure `DATABASE_URL` is set in your `.env` file.

### Expected Output

```
[INFO] Starting plan_voices backfill from legacy tts_status...
[INFO] Using published voice: <voice name> (<voice slug>)
[INFO] Found N plan(s) to backfill.
[INFO] Backfilled plan <plan-id> (<plan-name>): tts_status='completed' → status='ready'
[INFO] Skipping plan <plan-id> (<plan-name>): plan_voices row already exists.
...

=== Backfill Complete ===
Inserted: M row(s)
Skipped:  K row(s) (already exist)
Errors:   0 row(s)
Total:    N plan(s) processed

Backfill successful. All plans now have plan_voices entries.
```

## Idempotency

The script is idempotent because:

1. **Before inserting**, it checks if a `plan_voices` row already exists for `(plan_id, voice_id, locale)`
2. **If a row exists**, it skips the plan (logs a "Skipping" message)
3. **If no row exists**, it inserts a new one
4. The database has a **UNIQUE constraint** on `(plan_id, voice_id, locale)` that prevents duplicates even if re-run

This means:
- ✅ Safe to run multiple times
- ✅ No duplicates created
- ✅ Existing rows are not overwritten
- ✅ Partial failures can be retried

## Error Handling

The script includes comprehensive error handling:

### Missing DATABASE_URL
```
[ERROR] DATABASE_URL environment variable is not set.
```
**Action**: Set `DATABASE_URL` in your `.env` file and retry.

### No Published Voices
```
[WARN] No published voices found. This may indicate the voices table has not been seeded yet.
[WARN] Proceeding with backfill using a placeholder voice ID...
```
**Action**: Seed the voices table and re-run the script, or manually insert voice records.

### Database Insert Errors
```
[ERROR] Failed to backfill plan <plan-id>: <error message>
```
**Action**: Check database connectivity, schema, and constraints. Retry after fixing the underlying issue.

### Fatal Errors
```
[ERROR] Fatal error during backfill: <error message>
```
**Action**: Review the error message and logs. Fix the issue and re-run.

## Voice Selection Strategy

The script uses the following strategy to select a voice for each plan:

1. **Query all published voices** from the `voices` table
2. **Select the first published voice** (ordered by insertion)
3. **If no published voices exist**, use a placeholder UUID (with warning)
4. **Use 'enUS' locale** as the default for all backfilled rows (plans don't have a locale field)

**Note**: This strategy assumes all plans should use the same voice for backfill purposes. In production, you may want to customize the voice selection based on plan metadata (e.g., `defaultVoice` field if it exists).

## Database Constraints

The script respects the following database constraints:

### UNIQUE Constraint on plan_voices
```sql
UNIQUE (plan_id, voice_id, locale)
```
Prevents duplicate renditions and enables idempotent upserts.

### CHECK Constraint on plan_voices.status
```sql
CHECK (status IN ('pending', 'processing', 'ready', 'failed'))
```
The script only inserts valid status values.

### CHECK Constraint on plans.tts_status
```sql
CHECK (tts_status IN ('none', 'pending', 'processing', 'completed', 'partial', 'failed'))
```
The script reads only valid legacy status values.

## Performance Considerations

### Time Complexity
- **O(N)** where N is the number of plans
- Single query to fetch all plans
- Single INSERT per plan (or SELECT + SKIP if exists)
- Typically < 100ms for < 1000 plans

### Network Overhead
- Uses Neon HTTP driver (zero idle connections)
- ~2 RTT per plan (SELECT to check existence + INSERT)
- Total: ~2N RTT for N plans (can be optimized with batch inserts if needed)

## Testing

Run the test suite:

```bash
npm test -- scripts/backfill-plan-voices.spec.ts
```

Tests cover:
- ✅ Status mapping for all legacy values
- ✅ Single plan backfill
- ✅ Multiple plan backfill
- ✅ Idempotency (no duplicates on re-run)
- ✅ Skipping existing rows
- ✅ UNIQUE constraint enforcement
- ✅ Error handling

## Rollback

If the backfill needs to be rolled back:

1. **Identify the inserted rows** by timestamp or other metadata
2. **Delete the rows**:
   ```sql
   DELETE FROM plan_voices
   WHERE created_at > '<backfill start time>';
   ```
3. **Verify** that `plans.tts_status` values are still intact
4. **Re-run the script** if needed

**Note**: Rollback is only possible before migration 0015 drops the `plans.tts_status` column. After that, the legacy status information is lost.

## Related Tasks

- **TASK-002**: Database migration 0014 (creates `plan_voices` table)
- **TASK-003**: Drizzle schema extension (defines table types)
- **TASK-006**: PlanVoicesRepository (CRUD operations)
- **TASK-010**: TTS batch pregen dual-write (writes to `plan_voices`)

## Future Improvements

Potential optimizations:
1. **Batch inserts**: Use `insertMany()` instead of individual inserts
2. **Parallel processing**: Process multiple plans concurrently
3. **Custom voice selection**: Allow per-plan voice selection based on metadata
4. **Dry-run mode**: Preview changes without writing to database
5. **Resume capability**: Track progress and resume from last completed plan

## Support

If you encounter issues:

1. **Check logs**: Review the console output for error messages
2. **Verify prerequisites**: Ensure migration 0014 and TASK-003 are complete
3. **Check database connectivity**: Verify `DATABASE_URL` and network access
4. **Review constraints**: Ensure `plans` table has valid `tts_status` values
5. **Check voices table**: Verify at least one published voice exists

For additional help, consult:
- Architecture document: `workspace/artifacts/architecture.json`
- Task definition: `workspace/artifacts/tasks.json`
- Database schema: `server/src/database/schema.ts`
