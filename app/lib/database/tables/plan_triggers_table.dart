import 'package:drift/drift.dart';

/// Drift table for scheduled plan-start triggers.
///
/// Each row represents one user-scheduled "start this plan at this time"
/// entry. Rows are the source of truth for:
///
///   * Backend sync — unsynced rows are uploaded via `/sync/triggers`.
///   * Native rearm — on app startup we read all future rows and call
///     [PlanTriggerService.schedule] so the native AlarmManager queue matches
///     the Drift store after app reinstall / cache clear.
///   * UI listing and cancellation.
///
/// ## Sync columns
///
///   * [clientId]   — UUID generated on-device, stable across devices,
///                    sent to the server as the idempotency key.
///   * [serverId]   — server-assigned UUID after a successful push. Null
///                    while the row has never been synced.
///   * [syncedAt]   — when the row was last confirmed on the server.
///                    Null-or-stale rows are considered dirty and get pushed.
///   * [deletedAt]  — soft-delete tombstone for sync. Local cancellation
///                    marks this timestamp and pushes to the server so other
///                    devices cancel their native alarms.
class PlanTriggersTable extends Table {
  @override
  String get tableName => 'plan_triggers';

  /// Local auto-increment primary key. Separate from [clientId] so joins
  /// and watches stay integer-keyed.
  IntColumn get id => integer().autoIncrement()();

  /// Client-generated UUID — cross-device identity + idempotency key.
  TextColumn get clientId => text().unique()();

  /// Server-assigned UUID, null until first successful push.
  TextColumn get serverId => text().nullable()();

  /// User who owns the trigger (server UUID).
  TextColumn get userId => text()();

  /// Plan to start when the trigger fires.
  TextColumn get planId => text()();

  /// Display title captured at schedule time (plan name may change later).
  TextColumn get title => text()();

  /// First-occurrence start time (UTC).
  DateTimeColumn get startUtc => dateTime()();

  /// Session duration for the scheduled plan.
  IntColumn get durationMinutes => integer()();

  /// Recurrence rule — one of 'none' | 'daily' | 'weekdays' | 'weekly'.
  TextColumn get recurrence => text().withDefault(const Constant('none'))();

  /// Record creation timestamp.
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Last local mutation timestamp — bumped on every edit so the server can
  /// resolve concurrent updates via last-write-wins.
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Last successful sync timestamp. Null or stale → row is dirty.
  DateTimeColumn get syncedAt => dateTime().nullable()();

  /// Soft-delete tombstone. Non-null rows are hidden from UI but remain in
  /// the table so their delete can be synced to other devices.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
