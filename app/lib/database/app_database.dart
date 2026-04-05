import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/database/tables/execution_state_table.dart';
import 'package:instructor/database/tables/plans_table.dart';
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
@DriftDatabase(
  tables: [
    PlansTable,
    TtsCacheTable,
    ExecutionStateTable,
    AppSettingsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  /// Constructor used in tests to pass an in-memory executor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        beforeOpen: (OpeningDetails details) async {
          // Enable WAL mode for better concurrent read performance.
          await customStatement('PRAGMA journal_mode=WAL');
          // Enable foreign key enforcement.
          await customStatement('PRAGMA foreign_keys=ON');
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
