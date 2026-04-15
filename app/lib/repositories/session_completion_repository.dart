/// Session completion repository — CRUD operations for local session_completions table.
///
/// Responsibilities:
///   - Record a plan completion when PlanExecutionEngine.stateStream emits completed
///   - Query completions for a date range (used by StreakService)
///   - Retrieve unsynced completions (syncedAt IS NULL) for cloud sync
///   - Mark completions as synced (set syncedAt timestamp)
///   - Stream real-time updates when completions are recorded or synced
///
/// Dependency injection:
///   - AppDatabase injected (not a singleton) for testability
///   - All operations wrapped in error handling with logging
///
/// Usage:
/// ```dart
/// final repository = SessionCompletionRepository(database);
/// await repository.recordCompletion(
///   planId: planId,
///   completedAt: DateTime.now(),
///   durationMs: 600000,
/// );
/// final completions = await repository.getCompletionsSince(since);
/// ```

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';

import 'package:instructor/database/app_database.dart';

const _uuid = Uuid();

/// Session completion record with sync status.
///
/// Maps to the session_completions table.
/// syncedAt is nullable — null indicates unsynced, non-null indicates sent to server.
class SessionCompletionRecord {
  const SessionCompletionRecord({
    required this.id,
    required this.planId,
    required this.completedAt,
    required this.durationMs,
    required this.clientId,
    this.syncedAt,
  });

  /// Auto-increment primary key.
  final int id;

  /// Associated plan ID.
  final String planId;

  /// Completion timestamp (when the user finished the plan).
  final DateTime completedAt;

  /// Session duration in milliseconds.
  final int durationMs;

  /// Client-generated UUID for idempotent server sync.
  final String clientId;

  /// Sync timestamp — null if not yet synced to server.
  final DateTime? syncedAt;

  @override
  String toString() =>
      'SessionCompletionRecord(id=$id, planId=$planId, completedAt=$completedAt, '
      'durationMs=$durationMs, clientId=$clientId, syncedAt=$syncedAt)';
}

/// Repository for session completion CRUD operations.
///
/// All methods use try-catch with proper logging for database errors.
/// The repository is dependency-injected (not a singleton) for testability.
class SessionCompletionRepository {
  const SessionCompletionRepository(this._database);

  final AppDatabase _database;

  /// Record a new session completion.
  ///
  /// Called by: StreakService after PlanExecutionEngine completes a session.
  /// Returns: the recorded completion record with generated ID.
  /// Throws: Any Drift database errors (logged and rethrown).
  Future<SessionCompletionRecord> recordCompletion({
    required String planId,
    required DateTime completedAt,
    required int durationMs,
  }) async {
    try {
      final clientId = _uuid.v4();

      debugPrint(
        '[SessionCompletionRepository] Recording completion: '
        'planId=$planId, completedAt=$completedAt, durationMs=$durationMs',
      );

      final id = await _database
          .into(_database.sessionCompletionsTable)
          .insert(
            SessionCompletionsTableCompanion.insert(
              planId: planId,
              completedAt: completedAt,
              durationMs: durationMs,
              clientId: clientId,
            ),
          );

      return SessionCompletionRecord(
        id: id,
        planId: planId,
        completedAt: completedAt,
        durationMs: durationMs,
        clientId: clientId,
        syncedAt: null,
      );
    } catch (e) {
      debugPrint(
        '[SessionCompletionRepository] Error recording completion: $e',
      );
      rethrow;
    }
  }

  /// Query completions since a given timestamp.
  ///
  /// Used by: StreakService to fetch all completions for streak calculation.
  /// Returns: List of completions ordered by completedAt (ascending).
  Future<List<SessionCompletionRecord>> getCompletionsSince(
    DateTime since,
  ) async {
    try {
      debugPrint(
        '[SessionCompletionRepository] Fetching completions since $since',
      );

      final query = _database.select(_database.sessionCompletionsTable)
        ..where((t) => t.completedAt.isBiggerThanValue(since))
        ..orderBy([(t) => OrderingTerm.asc(t.completedAt)]);

      final rows = await query.get();
      return rows.map(_mapRow).toList();
    } catch (e) {
      debugPrint(
        '[SessionCompletionRepository] Error fetching completions: $e',
      );
      rethrow;
    }
  }

  /// Query all completions (no date filter).
  ///
  /// Used by: StreakService for full streak calculation from all history.
  Future<List<SessionCompletionRecord>> getAllCompletions() async {
    try {
      final query = _database.select(_database.sessionCompletionsTable)
        ..orderBy([(t) => OrderingTerm.asc(t.completedAt)]);

      final rows = await query.get();
      return rows.map(_mapRow).toList();
    } catch (e) {
      debugPrint(
        '[SessionCompletionRepository] Error fetching all completions: $e',
      );
      rethrow;
    }
  }

  /// Query unsynced completions.
  ///
  /// Used by: SyncService to find completions that need to be sent to the server.
  /// Returns: List of completions where syncedAt IS NULL.
  Future<List<SessionCompletionRecord>> getUnsyncedCompletions() async {
    try {
      debugPrint(
        '[SessionCompletionRepository] Fetching unsynced completions',
      );

      final query = _database.select(_database.sessionCompletionsTable)
        ..where((t) => t.syncedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.completedAt)]);

      final rows = await query.get();
      return rows.map(_mapRow).toList();
    } catch (e) {
      debugPrint(
        '[SessionCompletionRepository] Error fetching unsynced: $e',
      );
      rethrow;
    }
  }

  /// Mark completions as synced.
  ///
  /// Used by: SyncService after successfully uploading to the server.
  /// Updates syncedAt timestamp for the given completion IDs.
  Future<void> markSynced(List<int> completionIds) async {
    if (completionIds.isEmpty) return;

    try {
      debugPrint(
        '[SessionCompletionRepository] Marking ${completionIds.length} '
        'completions as synced',
      );

      final now = DateTime.now();
      await (_database.update(_database.sessionCompletionsTable)
            ..where((t) => t.id.isIn(completionIds)))
          .write(
        SessionCompletionsTableCompanion(syncedAt: Value(now)),
      );
    } catch (e) {
      debugPrint('[SessionCompletionRepository] Error marking synced: $e');
      rethrow;
    }
  }

  /// Stream real-time completion updates.
  ///
  /// Emits whenever:
  ///   - A new completion is recorded
  ///   - Completions are marked as synced
  ///
  /// Used by: StreakService to reactively update streak state.
  /// Returns: Stream<List<SessionCompletionRecord>> ordered by completedAt.
  Stream<List<SessionCompletionRecord>> watchCompletions() {
    try {
      debugPrint(
        '[SessionCompletionRepository] Watching completions stream',
      );

      final query = _database.select(_database.sessionCompletionsTable)
        ..orderBy([(t) => OrderingTerm.asc(t.completedAt)]);

      return query.watch().map(
            (rows) => rows.map(_mapRow).toList(),
          );
    } catch (e) {
      debugPrint(
        '[SessionCompletionRepository] Error watching completions: $e',
      );
      rethrow;
    }
  }

  /// Maps a Drift table row to a [SessionCompletionRecord] domain object.
  SessionCompletionRecord _mapRow(SessionCompletionsTableData row) {
    return SessionCompletionRecord(
      id: row.id,
      planId: row.planId,
      completedAt: row.completedAt,
      durationMs: row.durationMs,
      clientId: row.clientId,
      syncedAt: row.syncedAt,
    );
  }
}
