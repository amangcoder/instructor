import 'package:drift/drift.dart';

/// Drift table definition for streak freeze records.
///
/// Users have a maximum of 2 active (unconsumed) freezes at any time.
/// Freezes are replenished at 1 per 7 consecutive active days.
///
/// When a gap day is detected during streak calculation, an available
/// freeze is consumed (consumedAt is set) to preserve the streak.
class StreakFreezesTable extends Table {
  @override
  String get tableName => 'streak_freezes';

  /// Auto-increment primary key.
  IntColumn get id => integer().autoIncrement()();

  /// User ID (string UUID from server) — identifies the user who owns this freeze.
  /// Allows querying active freezes per user for the freeze availability check.
  TextColumn get userId => text()();

  /// The date when this freeze was earned (UTC).
  DateTimeColumn get frozenAt => dateTime()();

  /// The date when this freeze expires if unused.
  DateTimeColumn get expiresAt => dateTime()();

  /// The date when this freeze was consumed (null if still available).
  DateTimeColumn get consumedAt => dateTime().nullable()();

  /// Record creation timestamp.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
