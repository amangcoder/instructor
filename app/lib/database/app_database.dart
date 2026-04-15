import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/database/tables/execution_state_table.dart';
import 'package:instructor/database/tables/plan_triggers_table.dart';
import 'package:instructor/database/tables/plans_table.dart';
import 'package:instructor/database/tables/session_completions_table.dart';
import 'package:instructor/database/tables/settings_table.dart';
import 'package:instructor/database/tables/streak_freezes_table.dart';
import 'package:instructor/database/tables/tts_cache_table.dart';
import 'package:instructor/database/type_converters.dart';
import 'package:instructor/models/plan_step.dart';

part 'app_database.g.dart';

/// The Drift database for the Instructor app.
///
/// Runs on a background isolate via [NativeDatabase.createInBackground] to
/// prevent UI jank during heavy read/write operations.
///
/// ## Schema
/// - [PlansTable] — all user Plans
/// - [TtsCacheTable] — cached TTS audio file paths keyed by content hash
/// - [ExecutionStateTable] — crash-recovery state for the execution engine
/// - [AppSettingsTable] — key/value app preferences
@DriftDatabase(
  tables: [
    PlansTable,
    TtsCacheTable,
    ExecutionStateTable,
    AppSettingsTable,
    SessionCompletionsTable,
    StreakFreezesTable,
    PlanTriggersTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  /// Constructor used in tests to pass an in-memory executor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // ── Guards are ordered sequentially (ascending) ──────────────────
          // CRITICAL: Migration guards must be in ascending order so that
          // upgrading from any prior schema version applies all necessary
          // migrations in the correct sequence.
          if (from < 2) {
            // v1 → v2: add provider and speechRate columns to tts_cache.
            await m.addColumn(ttsCacheTable, ttsCacheTable.provider);
            await m.addColumn(ttsCacheTable, ttsCacheTable.speechRate);

            // Remap OpenAI voice names → Gemini voice names in plans.
            const voiceMapping = {
              'nova': 'aoede',
              'shimmer': 'leda',
              'onyx': 'charon',
              'alloy': 'puck',
              'echo': 'kore',
              'fable': 'fenrir',
            };
            for (final entry in voiceMapping.entries) {
              await customStatement(
                "UPDATE plans SET default_voice = '${entry.value}' "
                "WHERE default_voice = '${entry.key}'",
              );
            }

            // Remap saved voice preference in app_settings too.
            for (final entry in voiceMapping.entries) {
              await customStatement(
                "UPDATE app_settings SET value = '${entry.value}' "
                "WHERE key = 'default_voice' AND value = '${entry.key}'",
              );
            }

            // Clear TTS cache — audio was generated with the old provider
            // (OpenAI) and old voice IDs, so it's no longer valid.
            await customStatement('DELETE FROM tts_cache');
          }
          if (from < 3) {
            // v2 → v3: add ambientAssetKey column to execution_state for
            // crash-recovery ambient track identity persistence.
            await m.addColumn(
              executionStateTable,
              executionStateTable.ambientAssetKey,
            );
          }
          if (from < 5) {
            // v4 → v5: add is_user_created column to plans.
            // SQLite ALTER TABLE applies the column default (true = 1) to all
            // existing rows, so current user plans retain isUserCreated=true.
            // Then mark the five built-in starter plan names as false so they
            // appear in the "Starter Plans" section after the upgrade.
            await customStatement(
              'ALTER TABLE plans ADD COLUMN is_user_created INTEGER NOT NULL DEFAULT 1',
            );
            const starterPlanNames = [
              '108 Surya Namaskar',
              'Yoga Nidra',
              'Full Body Strength Circuit',
              'Morning Routine',
              'Deep Work Session',
            ];
            for (final name in starterPlanNames) {
              // Single-quote escape: replace ' with ''
              final escaped = name.replaceAll("'", "''");
              await customStatement(
                "UPDATE plans SET is_user_created = 0 WHERE name = '$escaped'",
              );
            }
          }
          if (from < 6) {
            // ── Pre-migration plan capture (TASK-059) ──────────────────────
            //
            // Before dropping the plans table, capture all user-created plans
            // and persist them as a JSON blob in app_settings. This survives
            // the migration and is later read by _migratePlansToServer() in
            // main.dart to upload the plans to the server.
            //
            // We use app_settings because:
            //  • It is not dropped in this migration.
            //  • Data written here persists even if the app is killed before
            //    the upload completes, enabling retry on next launch.
            //  • NativeDatabase.createInBackground runs on a background
            //    isolate — static Dart variables are not shared across
            //    isolates, so SQLite storage is the only safe mechanism.
            //
            // The plans_migrated_v2 flag is checked first so a re-entry
            // (e.g. app killed after upload but before the flag was set)
            // does not overwrite already-captured data.
            try {
              final flagRow = await customSelect(
                "SELECT value FROM app_settings "
                "WHERE key = 'plans_migrated_v2'",
              ).getSingleOrNull();
              final alreadyMigrated = flagRow?.data['value'] == 'true';

              if (!alreadyMigrated) {
                // Capture user-created plans only (is_user_created = 1).
                // Starter plans (is_user_created = 0) exist in the server
                // library — no need to upload them.
                //
                // Note: if upgrading from schema < v5, the is_user_created
                // column is added by the `if (from < 5)` block above and
                // defaults to 1 for existing rows, so this query is safe.
                final rows = await customSelect(
                  'SELECT id, name, description, category, tags, '
                  'default_voice, steps, created_at, updated_at, last_used_at '
                  'FROM plans WHERE is_user_created = 1',
                ).get();

                if (rows.isNotEmpty) {
                  final plansJson = jsonEncode(
                    rows
                        .map((r) => Map<String, dynamic>.from(r.data))
                        .toList(),
                  );
                  await customStatement(
                    'INSERT OR REPLACE INTO app_settings '
                    '(key, value, updated_at) VALUES (?, ?, ?)',
                    [
                      '_pending_migration_plans',
                      plansJson,
                      DateTime.now().millisecondsSinceEpoch,
                    ],
                  );
                  debugPrint(
                    '[DB Migration v6] Captured ${rows.length} pre-v6 '
                    'user plan(s) for server upload.',
                  );
                }
              }
            } catch (e) {
              // Non-fatal: fresh install, table missing, or read error.
              // Proceed with the schema migration; no plans will be migrated.
              debugPrint('[DB Migration v6] Plan capture failed: $e');
            }

            // v5 → v6: server-first architecture migration.
            //
            // plans.id changes from INTEGER (auto-increment) to TEXT (UUID),
            // gains is_active/tts_status/tts_total/tts_completed columns, and
            // loses is_user_created. tts_cache.plan_id changes from INTEGER FK
            // to TEXT FK to match the new plans PK type.
            //
            // All existing local plans are discarded — they will be re-fetched
            // from the server. Drop tts_cache first to satisfy the FK constraint.
            await customStatement('DROP TABLE IF EXISTS tts_cache');
            await customStatement('DROP TABLE IF EXISTS plans');
            await m.createTable(plansTable);
            await m.createTable(ttsCacheTable);
          }
          if (from == 6) {
            // v6 → v7: add library_id column to plans for duplicate detection.
            // NULL for all existing plans (they were not cloned from the library).
            //
            // Guarded on `from == 6` (not `from < 7`): when upgrading from any
            // version < 6, the `from < 6` block above drops and recreates the
            // plans table via `m.createTable(plansTable)`, which uses the
            // current Drift schema — so `library_id` already exists and the
            // ALTER would fail with "duplicate column name".
            await customStatement(
              'ALTER TABLE plans ADD COLUMN library_id TEXT',
            );
          }
          if (from < 8) {
            // v7 → v8: add session_completions and streak_freezes tables
            // for streak tracking feature.
            // Idempotent: CREATE TABLE IF NOT EXISTS prevents errors on re-entry.
            // Uses Drift table definitions for type safety and consistency.
            await m.createTable(sessionCompletionsTable);
            await m.createTable(streakFreezesTable);

            // Performance indexes for streak queries.
            // These are created idempotently to ensure they exist regardless of
            // which migration path was taken.
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_session_completions_user_id '
              'ON session_completions (user_id)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_session_completions_completed_at '
              'ON session_completions (completed_at)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_session_completions_synced_at '
              'ON session_completions (synced_at)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_streak_freezes_user_id '
              'ON streak_freezes (user_id)',
            );
          }
          if (from < 9) {
            // v8 → v9: add plan_triggers table for scheduled auto-start
            // triggers (Android AlarmManager / iOS notification fallback).
            await m.createTable(planTriggersTable);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_plan_triggers_user_updated '
              'ON plan_triggers (user_id, updated_at)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_plan_triggers_user_start '
              'ON plan_triggers (user_id, start_utc)',
            );
          }
        },
        beforeOpen: (OpeningDetails details) async {
          // Enable WAL mode for better concurrent read performance.
          await customStatement('PRAGMA journal_mode=WAL');
          // Enable foreign key enforcement.
          await customStatement('PRAGMA foreign_keys=ON');

          // ── Performance indexes ─────────────────────────────────────────
          //
          // Drift's schema versioning only tracks structural changes (columns,
          // tables). Indexes are created idempotently here so they are always
          // present regardless of which migration path was taken.
          //
          // tts_cache: index on plan_id for bulk cache eviction when a plan
          //   is deleted or its steps are modified.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_tts_cache_plan_id '
            'ON tts_cache (plan_id)',
          );

          // tts_cache: index on created_at for LRU eviction queries.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_tts_cache_created_at '
            'ON tts_cache (created_at)',
          );

          // session_completions: index on user_id for querying completions per user.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_session_completions_user_id '
            'ON session_completions (user_id)',
          );

          // session_completions: index on completed_at for streak date range queries.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_session_completions_completed_at '
            'ON session_completions (completed_at)',
          );

          // session_completions: index on synced_at for unsynced records filter.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_session_completions_synced_at '
            'ON session_completions (synced_at)',
          );

          // streak_freezes: index on user_id for querying active freezes per user.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_streak_freezes_user_id '
            'ON streak_freezes (user_id)',
          );
        },
      );
}

/// Opens the production SQLite database on a background isolate.
QueryExecutor _openConnection() {
  return NativeDatabase.createInBackground(_dbFile());
}

/// Resolves the database file path in the app's documents directory.
File _dbFile() {
  // Synchronous path resolution — safe to call before app is fully initialised.
  // The actual file open is deferred until first use.
  return File(
    p.join(
      // Lazy resolution via a closure so we don't block at import time.
      _documentsPath,
      'instructor.db',
    ),
  );
}

/// Cached documents-directory path, resolved lazily on first database open.
///
/// In production this is set by [initDatabase]; in tests, override the
/// [appDatabaseProvider] with an in-memory executor instead.
String _documentsPath = '';

/// Initialises [_documentsPath] before the first database query.
///
/// Must be called from [main] after [WidgetsFlutterBinding.ensureInitialized].
Future<void> initDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  _documentsPath = dir.path;
}

/// Riverpod provider that exposes the singleton [AppDatabase].
///
/// [keepAlive: true] ensures the database is never garbage-collected while
/// the app is running.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  // In tests, override this provider with AppDatabase.forTesting(inMemory).
  return AppDatabase();
}
