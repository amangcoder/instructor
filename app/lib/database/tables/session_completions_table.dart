import 'package:drift/drift.dart';

/// Drift table definition for session completion events.
///
/// Each row represents one completed plan execution session. Used for:
///   - Streak calculation (group by calendar day, detect gaps)
///   - Sync to server (filter by syncedAt IS NULL)
///   - Calendar view (completion history per day)
///
/// The `clientId` column is a UUID generated on the client to ensure
/// idempotent sync — the server uses ON CONFLICT (client_id) DO NOTHING.
class SessionCompletionsTable extends Table {
  @override
  String get tableName => 'session_completions';

  /// Auto-increment primary key.
  IntColumn get id => integer().autoIncrement()();

  /// User ID (string UUID from server) — identifies the user who completed the session.
  /// Allows querying completions per user for streak calculation and sync.
  TextColumn get userId => text()();

  /// Associated plan ID (UUID string from server).
  /// Not a FK — plan may be deleted but completion persists for streak history.
  TextColumn get planId => text()();

  /// UTC timestamp when the user finished the session.
  DateTimeColumn get completedAt => dateTime()();

  /// Session duration in milliseconds.
  IntColumn get durationMs => integer()();

  /// Client-generated UUID for idempotent server sync.
  TextColumn get clientId => text().unique()();

  /// Sync timestamp — null if not yet synced to server.
  DateTimeColumn get syncedAt => dateTime().nullable()();

  /// Record creation timestamp.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
