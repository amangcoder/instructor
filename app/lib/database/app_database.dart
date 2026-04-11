import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/database/tables/execution_state_table.dart';
import 'package:instructor/database/tables/plans_table.dart';
import 'package:instructor/database/tables/provider_catalog_table.dart';
import 'package:instructor/database/tables/settings_table.dart';
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
/// - [ProviderCatalogTable] — cached TTS provider catalog (single-row, id=1)
@DriftDatabase(
  tables: [
    PlansTable,
    TtsCacheTable,
    ExecutionStateTable,
    AppSettingsTable,
    ProviderCatalogTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  /// Constructor used in tests to pass an in-memory executor.
  AppDatabase.forTesting(super.executor);

  /// The absolute path to the `.db` file on disk.
  ///
  /// Used by [SyncService] to locate the database file for upload/restore.
  /// Returns an empty string when running with an in-memory executor (tests).
  String get dbFilePath {
    if (_documentsPath.isEmpty) return '';
    return p.join(_documentsPath, 'instructor.db');
  }

  /// Runs a WAL checkpoint to merge the WAL file into the main database file.
  ///
  /// Must be called before uploading the database to S3 to ensure all pending
  /// writes are flushed into `instructor.db`.
  Future<void> walCheckpoint() async {
    await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
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
          if (from < 4) {
            // v3 → v4: add provider_catalog table for caching TTS provider
            // catalogs fetched from GET /api/tts/providers. Single-row table
            // (id = 1) replaced via INSERT OR REPLACE on every refresh.
            await m.createTable(providerCatalogTable);
          }
          if (from < 3) {
            // v2 → v3: add ambientAssetKey column to execution_state for
            // crash-recovery ambient track identity persistence.
            await m.addColumn(
              executionStateTable,
              executionStateTable.ambientAssetKey,
            );
          }
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

          // plans: index on updated_at for the "recently modified" sort in
          //   PlanLibraryScreen.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_plans_updated_at '
            'ON plans (updated_at)',
          );

          // plans: index on last_used_at for the "recently played" sort.
          // Column is nullable; NULL rows are placed last automatically in
          // SQLite ORDER BY … ASC NULLS LAST.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_plans_last_used_at '
            'ON plans (last_used_at)',
          );

          // tts_cache: index on created_at for LRU eviction queries.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_tts_cache_created_at '
            'ON tts_cache (created_at)',
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
